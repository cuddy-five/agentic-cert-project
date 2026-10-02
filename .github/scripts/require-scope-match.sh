#!/usr/bin/env bash
# Fail when a changed file is outside the paths named on the Scope line.
#
# Scope is the same-line value of:
#   - **Scope (paths/files):**
# Comma-separated repo paths. A file matches a path when it equals that
# path or lives under it. `docs` covers `docs/a.md`, not `docs-other/a.md`.
# `.` and `*` are not paths.
#
# Plan Gate passes the pull request payload and the two commits:
#   PR_BODY=... BASE_SHA=... HEAD_SHA=... bash .github/scripts/require-scope-match.sh
#
# Prove a file outside Scope fails, and prove a rename counts both paths:
#   bash .github/scripts/require-scope-match.sh --self-test
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMPLATE="${ROOT}/.github/pull_request_template.md"

normalize_line() {
  local line="$1"
  line="${line%$'\r'}"
  line="${line%"${line##*[![:space:]]}"}"
  printf '%s' "$line"
}

plan_section() {
  local body="$1"
  local line trimmed in_plan=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    trimmed="$(normalize_line "$line")"
    if [[ "$in_plan" -eq 0 ]]; then
      if [[ "$trimmed" == "## Plan (required)" ]]; then
        in_plan=1
      fi
      continue
    fi
    if [[ "$trimmed" == "## "* ]]; then
      break
    fi
    printf '%s\n' "$line"
  done <<< "$body"
}

scope_value() {
  local section="$1"
  local line trimmed head="- **Scope (paths/files):**" value
  while IFS= read -r line || [[ -n "$line" ]]; do
    trimmed="$(normalize_line "$line")"
    trimmed="${trimmed#"${trimmed%%[![:space:]]*}"}"
    if [[ "$trimmed" == "$head"* ]]; then
      value="${trimmed#"$head"}"
      value="${value#"${value%%[![:space:]]*}"}"
      printf '%s' "$value"
      return 0
    fi
  done <<< "$section"
  return 1
}

# Strip decoration so `.github/a.md` and `/.github/a.md` and `docs/` are paths.
normalize_token() {
  local token="$1"
  token="${token#"${token%%[![:space:]]*}"}"
  token="${token%"${token##*[![:space:]]}"}"
  if [[ ${#token} -ge 2 && "$token" == \"*\" && "$token" == *\" ]]; then
    token="${token:1:${#token}-2}"
  elif [[ ${#token} -ge 2 && "$token" == \'*\' && "$token" == *\' ]]; then
    token="${token:1:${#token}-2}"
  fi
  while [[ "$token" == ./* ]]; do
    token="${token#./}"
  done
  if [[ "$token" == /* ]]; then
    token="${token#/}"
  fi
  while [[ "$token" == */ ]]; do
    token="${token%/}"
  done
  printf '%s' "$token"
}

valid_path() {
  local token="$1" part rest
  [[ "$token" =~ ^[-A-Za-z0-9._/]+$ ]] || return 1
  [[ "$token" == "." || "$token" == ".." ]] && return 1
  rest="$token"
  while [[ -n "$rest" ]]; do
    part="${rest%%/*}"
    if [[ -z "$part" || "$part" == "." || "$part" == ".." ]]; then
      return 1
    fi
    if [[ "$rest" == */* ]]; then
      rest="${rest#*/}"
    else
      break
    fi
  done
  return 0
}

# Fill SCOPES. Invalid tokens land in BAD_TOKENS.
# Return 1 when the line is not an allowlist. Do not call this in a subshell.
parse_scope_value() {
  local value="$1" token
  local -a bad=()
  SCOPES=()
  BAD_TOKENS=()
  value="${value//$'\r'/}"
  value="${value//\`/}"
  value="${value//,/ }"
  # Keep `*` as a token. Globbing would turn it into real filenames.
  set -f
  # shellcheck disable=SC2086
  for token in $value; do
    token="$(normalize_token "$token")"
    [[ -z "$token" ]] && continue
    if ! valid_path "$token"; then
      bad+=("$token")
      continue
    fi
    SCOPES+=("$token")
  done
  set +f
  if [[ ${#bad[@]} -gt 0 ]]; then
    BAD_TOKENS=("${bad[@]}")
  fi
  [[ ${#bad[@]} -eq 0 && ${#SCOPES[@]} -gt 0 ]]
}

file_in_scope() {
  local file="$1" scope
  for scope in "${SCOPES[@]}"; do
    if [[ "$file" == "$scope" || "$file" == "$scope"/* ]]; then
      return 0
    fi
  done
  return 1
}

# Fill COLLECTED from `git diff --name-status` text. Renames and copies
# contribute both paths. A quoted path fails closed.
collect_name_status() {
  local text="$1" line status rest code old new
  COLLECTED=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "$line" ]] && continue
    if [[ "$line" == *'"'* ]]; then
      echo "::error::A changed path is quoted. This check does not parse spaces in paths."
      return 1
    fi
    status="${line%%$'\t'*}"
    rest="${line#*$'\t'}"
    if [[ "$rest" == "$line" || -z "$status" ]]; then
      echo "::error::Unexpected diff line: ${line}"
      return 1
    fi
    code="${status:0:1}"
    if [[ "$code" == "R" || "$code" == "C" ]]; then
      old="${rest%%$'\t'*}"
      new="${rest#*$'\t'}"
      if [[ "$rest" != *$'\t'* || -z "$old" || -z "$new" ]]; then
        echo "::error::Rename line did not include both paths: ${line}"
        return 1
      fi
      COLLECTED+=("$old" "$new")
    else
      if [[ "$rest" == *$'\t'* ]]; then
        echo "::error::Unexpected diff line: ${line}"
        return 1
      fi
      COLLECTED+=("$rest")
    fi
  done <<< "$text"
}

# Return 0 when every changed file sits inside Scope.
check_scope() {
  local body="$1" files="$2" mode="$3"
  local section value file missing=0
  section="$(plan_section "$body")"
  if ! value="$(scope_value "$section")"; then
    if [[ "$mode" == "error" ]]; then
      echo "::error::Pull request body is missing the Scope line."
    fi
    echo "missing scope line"
    return 1
  fi
  if [[ -z "$value" ]]; then
    if [[ "$mode" == "error" ]]; then
      echo "::error::Scope is empty. Name comma-separated repo paths."
    fi
    echo "empty scope"
    return 1
  fi
  if ! parse_scope_value "$value"; then
    local token
    if [[ ${#BAD_TOKENS[@]} -eq 0 ]]; then
      if [[ "$mode" == "error" ]]; then
        echo "::error::Scope has no repo paths."
      fi
      echo "empty scope"
      return 1
    fi
    for token in "${BAD_TOKENS[@]}"; do
      if [[ "$mode" == "error" ]]; then
        echo "::error::Scope token is not a repo path: ${token}"
      fi
      echo "bad scope token: ${token}"
    done
    return 1
  fi
  while IFS= read -r file || [[ -n "$file" ]]; do
    [[ -z "$file" ]] && continue
    if ! file_in_scope "$file"; then
      if [[ "$mode" == "error" ]]; then
        echo "::error::Changed file is outside Scope: ${file}"
      fi
      echo "outside scope: ${file}"
      missing=1
    fi
  done <<< "$files"
  return "$missing"
}

assert_pass() {
  local name="$1" body="$2" files="$3"
  if ! check_scope "$body" "$files" quiet; then
    echo "::error::self-test: ${name} should pass."
    exit 1
  fi
  echo "self-test: ${name} passed."
}

assert_fail() {
  local name="$1" body="$2" files="$3"
  if check_scope "$body" "$files" quiet; then
    echo "::error::self-test: ${name} should fail."
    exit 1
  fi
  echo "self-test: ${name} failed as required."
}

body_with_scope() {
  printf '%s\n' "## Plan (required)" "- **Scope (paths/files):** $1" "## Evidence"
}

self_test() {
  local body
  body="$(body_with_scope ".github/workflows/plan_gate.yml, docs/02-scope-match.md")"
  assert_pass "exact file and a second path" "$body" $'.github/workflows/plan_gate.yml\ndocs/02-scope-match.md'
  assert_pass "directory prefix" "$(body_with_scope "docs")" $'docs/02-scope-match.md'
  assert_pass "empty diff" "$(body_with_scope "docs")" ""
  local bt='`'
  local quoted="${bt}.github/workflows/plan_gate.yml${bt}, \"/docs/02-scope-match.md\""
  assert_pass "backticks, quotes, and a leading slash" \
    "$(body_with_scope "$quoted")" \
    $'.github/workflows/plan_gate.yml\ndocs/02-scope-match.md'
  assert_pass "trailing slash is the directory" "$(body_with_scope "docs/")" $'docs/a.md'
  assert_fail "file outside the named paths" "$body" $'.github/workflows/plan_gate.yml\nREADME.md'
  assert_fail "prefix must end on a path boundary" "$(body_with_scope "docs")" $'docs-other/a.md'
  assert_fail "a file path is not a prefix of a longer name" \
    "$(body_with_scope "docs/a.md")" $'docs/a.md.bak'
  assert_fail "a sentence does not cover the changed file" \
    "$(body_with_scope "the hook script")" $'.github/scripts/foo.sh'
  assert_pass "extra words do not hide a named path" \
    "$(body_with_scope "see docs/a.md")" $'docs/a.md'
  assert_fail "dot is the whole repo" "$(body_with_scope ".")" $'README.md'
  assert_fail "star is not a path" "$(body_with_scope "*")" $'README.md'
  assert_fail "dotdot segment" "$(body_with_scope "docs/../README.md")" $'README.md'
  assert_fail "empty scope line" "$(body_with_scope "")" $'README.md'
  assert_fail "scope line only outside the plan" \
    $'## Plan (required)\n- **Goal:** x\n## Evidence\n- **Scope (paths/files):** README.md' \
    $'README.md'

  local status collected
  status=$'M\tREADME.md\nR100\tCODEOWNERS\tdocs/CODEOWNERS\nC100\tLICENSE\tagents/LICENSE\n'
  collect_name_status "$status"
  collected="$(printf '%s\n' "${COLLECTED[@]}")"
  if [[ "$collected" != $'README.md\nCODEOWNERS\ndocs/CODEOWNERS\nLICENSE\nagents/LICENSE' ]]; then
    echo "::error::self-test: name-status parse got: ${collected}"
    exit 1
  fi
  echo "self-test: rename and copy contribute both paths."
  if collect_name_status $'M\t"my file.md"' quiet; then
    echo "::error::self-test: a quoted path should fail closed."
    exit 1
  fi
  echo "self-test: quoted path failed as required."

  local dir base head files
  dir="$(mktemp -d)"
  git -C "$dir" init -q -b main
  printf 'a\n' > "${dir}/old.txt"
  printf 'k\n' > "${dir}/keep.txt"
  git -C "$dir" add old.txt keep.txt
  git -C "$dir" -c user.email=scope-test@example.com -c user.name=scope-test -c core.hooksPath=/dev/null commit -qm base
  base="$(git -C "$dir" rev-parse HEAD)"
  git -C "$dir" mv old.txt new.txt
  printf 'e\n' > "${dir}/extra.txt"
  git -C "$dir" add extra.txt
  git -C "$dir" -c user.email=scope-test@example.com -c user.name=scope-test -c core.hooksPath=/dev/null commit -qm head
  head="$(git -C "$dir" rev-parse HEAD)"
  status="$(git -C "$dir" diff --name-status --find-renames "$base" "$head")"
  collect_name_status "$status"
  if [[ ${#COLLECTED[@]} -eq 0 ]]; then
    echo "::error::self-test: git diff produced no changed paths."
    rm -rf "$dir"
    exit 1
  fi
  files="$(printf '%s\n' "${COLLECTED[@]}")"
  rm -rf "$dir"
  assert_fail "rename keeps the old path in the diff" "$(body_with_scope "new.txt, extra.txt")" "$files"
  assert_pass "rename passes when both paths are in scope" "$(body_with_scope "old.txt, new.txt, extra.txt")" "$files"
  if printf '%s\n' "$files" | grep -qx 'keep.txt'; then
    echo "::error::self-test: an unchanged file was treated as changed."
    exit 1
  fi
  echo "self-test: unchanged file is not part of the diff."

  if [[ ! -f "$TEMPLATE" ]]; then
    echo "::error::${TEMPLATE} is required for the scope self-test."
    exit 1
  fi
  local template_scope
  if template_scope="$(scope_value "$(plan_section "$(<"$TEMPLATE")")")" && [[ -n "$template_scope" ]]; then
    echo "::error::self-test: the pull request template Scope line must stay empty."
    exit 1
  fi
  echo "self-test: template Scope line is empty."

  local bad
  if bad="$(PR_BODY="$(body_with_scope docs)" BASE_SHA="not-a-sha" HEAD_SHA="not-a-sha" bash "$0" 2>&1)"; then
    echo "::error::self-test: a bad BASE_SHA should fail."
    exit 1
  fi
  if ! printf '%s\n' "$bad" | grep -q 'BASE_SHA is not a commit SHA'; then
    echo "::error::self-test: bad BASE_SHA did not report the SHA check."
    printf '%s\n' "$bad"
    exit 1
  fi
  echo "self-test: a bad BASE_SHA failed before git."
}

sha40() {
  [[ "$1" =~ ^[0-9a-fA-F]{40}$ ]]
}

if [[ "${1:-}" == "--self-test" ]]; then
  self_test
  exit 0
fi

if [[ $# -gt 0 ]]; then
  echo "::error::Unknown argument: $1" >&2
  exit 1
fi

if [[ ! -v PR_BODY ]]; then
  echo "::error::PR_BODY is unset. Pass github.event.pull_request.body through the environment."
  exit 1
fi

FILES_TEXT=""
if [[ -v CHANGED_FILES ]]; then
  FILES_TEXT="$CHANGED_FILES"
else
  if [[ ! -v BASE_SHA || ! -v HEAD_SHA ]]; then
    echo "::error::Set BASE_SHA and HEAD_SHA, or set CHANGED_FILES."
    exit 1
  fi
  if ! sha40 "$BASE_SHA" || ! sha40 "$HEAD_SHA"; then
    echo "::error::BASE_SHA is not a commit SHA."
    exit 1
  fi
  if ! git rev-parse --verify --quiet "${BASE_SHA}^{commit}" >/dev/null; then
    echo "::error::BASE_SHA ${BASE_SHA} is not in this checkout."
    exit 1
  fi
  if ! git rev-parse --verify --quiet "${HEAD_SHA}^{commit}" >/dev/null; then
    echo "::error::HEAD_SHA ${HEAD_SHA} is not in this checkout."
    exit 1
  fi
  name_status="$(git diff --name-status --find-renames "$BASE_SHA" "$HEAD_SHA")"
  collect_name_status "$name_status"
  if [[ ${#COLLECTED[@]} -gt 0 ]]; then
    FILES_TEXT="$(printf '%s\n' "${COLLECTED[@]}")"
  fi
fi

if ! check_scope "$PR_BODY" "$FILES_TEXT" error; then
  exit 1
fi
echo "Changed files stay inside Scope (${#SCOPES[@]} paths)."
