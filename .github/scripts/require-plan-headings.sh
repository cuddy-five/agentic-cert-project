#!/usr/bin/env bash
# Fail when a pull request body is missing a required plan heading,
# or when Goal, Scope, Steps, or Success criteria is still blank.
#
# Headings come from .github/pull_request_template.md:
#   ## Plan (required)
#   ## Evidence
#   ## Review checklist
#
# The workflow passes the pull request payload GitHub already provides:
#   PR_BODY="${{ github.event.pull_request.body }}" bash .github/scripts/require-plan-headings.sh
#
# Prove a missing heading or a blank field fails this check:
#   bash .github/scripts/require-plan-headings.sh --self-test
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMPLATE="${ROOT}/.github/pull_request_template.md"

REQUIRED_HEADINGS=(
  "Plan (required)"
  "Evidence"
  "Review checklist"
)

# Trim a trailing CR and trailing whitespace so the heading line matches the template.
normalize_line() {
  local line="$1"
  line="${line%$'\r'}"
  line="${line%"${line##*[![:space:]]}"}"
  printf '%s' "$line"
}

heading_present() {
  local body="$1"
  local heading="$2"
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$(normalize_line "$line")" == "## ${heading}" ]]; then
      return 0
    fi
  done <<< "$body"
  return 1
}

# Print each missing heading. Return 0 only when every required heading is present.
missing_headings() {
  local body="$1"
  local mode="$2"
  local heading
  local missing=0
  for heading in "${REQUIRED_HEADINGS[@]}"; do
    if ! heading_present "$body" "$heading"; then
      if [[ "$mode" == "error" ]]; then
        echo "::error::Pull request body is missing required heading: ## ${heading}"
      fi
      echo "missing heading: ## ${heading}"
      missing=1
    fi
  done
  return "$missing"
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

value_after_label() {
  local section="$1"
  local label="$2"
  local line trimmed head="- **${label}:**" value
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

success_criteria_present() {
  local section="$1"
  local line trimmed rest seen=0
  local head="- **Success criteria (verifiable):**"
  while IFS= read -r line || [[ -n "$line" ]]; do
    trimmed="$(normalize_line "$line")"
    trimmed="${trimmed#"${trimmed%%[![:space:]]*}"}"
    if [[ "$seen" -eq 0 ]]; then
      if [[ "$trimmed" == "$head"* ]]; then
        rest="${trimmed#"$head"}"
        rest="${rest#"${rest%%[![:space:]]*}"}"
        if [[ -n "$rest" ]]; then
          return 0
        fi
        seen=1
      fi
      continue
    fi
    if [[ "$trimmed" == "- **"* ]]; then
      break
    fi
    if [[ "$trimmed" =~ ^-[[:space:]]\[[[:space:]xX]\][[:space:]]+[^[:space:]] ]]; then
      return 0
    fi
  done <<< "$section"
  return 1
}

# Goal, Scope, and Success criteria must have text. At least one step must too.
# Risks, Rollback, Evidence text, and the review checklist stay out of this check.
missing_fields() {
  local body="$1"
  local mode="$2"
  local section value missing=0
  section="$(plan_section "$body")"

  report_empty() {
    local name="$1"
    if [[ "$mode" == "error" ]]; then
      echo "::error::Plan field is empty: ${name}"
    fi
    echo "empty plan field: ${name}"
    missing=1
  }

  if ! value="$(value_after_label "$section" "Goal")" || [[ -z "$value" ]]; then
    report_empty "Goal"
  fi
  if ! value="$(value_after_label "$section" "Scope (paths/files)")" || [[ -z "$value" ]]; then
    report_empty "Scope (paths/files)"
  fi
  if ! printf '%s\n' "$section" | grep -Eq '^[[:space:]]*[0-9]+\.[[:space:]]*[^[:space:]]'; then
    report_empty "Steps"
  fi
  if ! success_criteria_present "$section"; then
    report_empty "Success criteria"
  fi
  return "$missing"
}

strip_heading() {
  local body="$1"
  local heading="$2"
  local line kept=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$(normalize_line "$line")" == "## ${heading}" ]]; then
      continue
    fi
    kept+="${line}"$'\n'
  done <<< "$body"
  printf '%s' "$kept"
}

self_test() {
  local template heading body
  if [[ ! -f "$TEMPLATE" ]]; then
    echo "::error::${TEMPLATE} is required for the heading self-test."
    exit 1
  fi
  template="$(<"$TEMPLATE")"
  for heading in "${REQUIRED_HEADINGS[@]}"; do
    if ! heading_present "$template" "$heading"; then
      echo "::error::${TEMPLATE} does not contain required heading: ## ${heading}"
      exit 1
    fi
  done
  if ! missing_headings "$template" quiet; then
    echo "::error::self-test: complete template was rejected."
    exit 1
  fi
  echo "self-test: complete template passed."

  for heading in "${REQUIRED_HEADINGS[@]}"; do
    body="$(strip_heading "$template" "$heading")"
    if missing_headings "$body" quiet; then
      echo "::error::self-test: removing ## ${heading} should fail the check."
      exit 1
    fi
    echo "self-test: removed ## ${heading}; checker failed as required."
  done
  echo "self-test: checker fails when any required heading is missing."

  if missing_fields "$template" quiet; then
    echo "::error::self-test: blank template fields should fail the check."
    exit 1
  fi
  echo "self-test: blank Goal, Scope, and Steps failed the check."

  local filled
  filled="$(cat <<'EOF'
## Plan (required)
- **Goal:** ship the field check
- **Scope (paths/files):** .github/workflows/plan_gate.yml
- **Steps:**
  1. Check Goal, Scope, and Steps.
- **Success criteria (verifiable):**
  - [ ] Required checks pass

## Evidence
- Workflow run(s): n/a

## Review checklist
- [ ] Plan reviewed and approved
EOF
)"
  if ! missing_fields "$filled" quiet; then
    echo "::error::self-test: filled plan fields were rejected."
    exit 1
  fi
  echo "self-test: filled Goal, Scope, Steps, and Success criteria passed."

  local cleared="${filled/- **Goal:** ship the field check/- **Goal:**}"
  if missing_fields "$cleared" quiet; then
    echo "::error::self-test: clearing Goal should fail the check."
    exit 1
  fi
  echo "self-test: cleared Goal failed the check."

  local no_criteria
  no_criteria="$(printf '%s\n' "$filled" | grep -v 'Required checks pass')"
  if missing_fields "$no_criteria" quiet; then
    echo "::error::self-test: removing the success criteria bullet should fail the check."
    exit 1
  fi
  echo "self-test: blank Success criteria failed the check."
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

if ! missing_headings "$PR_BODY" error; then
  exit 1
fi
if ! missing_fields "$PR_BODY" error; then
  exit 1
fi
echo "Pull request body includes the required headings and filled Goal, Scope, Steps, and Success criteria."
