#!/usr/bin/env bash
# Copilot preToolUse hook. Deny shell commands the agent loop forbids.
#
# Loaded from .github/hooks/block-high-risk-command.json.
# Stdin is the hook payload. Stdout is one JSON object.
# {} leaves Copilot's normal permission flow in place.
#
# A non-zero exit on preToolUse denies every later bash call, so this
# script exits 0 even when it denies a command.
#
# Prove the denials:
#   bash .github/scripts/block-high-risk-command.sh --self-test
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK_JSON="${ROOT}/.github/hooks/block-high-risk-command.json"

deny() {
  printf '{"permissionDecision":"deny","permissionDecisionReason":"%s"}\n' "$1"
  exit 0
}

pass() {
  printf '{}\n'
  exit 0
}

# Lowercase the payload and unescape JSON newlines so a command written
# with \n is still visible as words.
normalize() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/\\n/ /g; s/\\r/ /g; s/\\t/ /g; s/\\"/"/g'
}

tool_name() {
  local text="$1"
  if [[ "$text" =~ \"toolname\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "$text" =~ \"tool_name\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi
  printf ''
}

match_pr_merge() {
  local text="$1"
  local re='(^|[^[:alnum:]_])gh[[:space:]]+pr[[:space:]]+merge([^[:alnum:]_]|$)'
  if [[ "$text" =~ $re ]]; then
    printf '%s' "gh pr merge is blocked. The agent does not merge its own pull request."
  fi
}

match_api_merge() {
  local text="$1"
  local api='(^|[^[:alnum:]_])gh[[:space:]]+api[[:space:]]+'
  local merge='pulls/[0-9]+/merge([^[:alnum:]_]|$)'
  if [[ "$text" =~ $api ]] && [[ "$text" =~ $merge ]]; then
    printf '%s' "Merging through the pulls merge API is blocked. The agent does not merge its own pull request."
  fi
}

match_ruleset_write() {
  local text="$1"
  local api='(^|[^[:alnum:]_])gh[[:space:]]+api[[:space:]]+'
  local method='(--method|-x)[[:space:]]+(put|patch|delete)([^[:alnum:]_]|$)'
  local target='(rulesets|branches/[^[:space:]"]*/protection)'
  if [[ "$text" =~ $api ]] && [[ "$text" =~ $method ]] && [[ "$text" =~ $target ]]; then
    printf '%s' "Changing rulesets or branch protection through gh api is blocked."
  fi
}

match_ready_label() {
  local text="$1"
  local re='--add-label(=|[[:space:]]+)["[:space:]]*ready-for-agent([^[:alnum:]_]|$)'
  if [[ "$text" =~ $re ]]; then
    printf '%s' "Adding the ready-for-agent label is blocked. A human applies that label."
  fi
}

match_checkout_commit() {
  local text="$1"
  local checkout='(^|[^[:alnum:]_])git[[:space:]]+(checkout|switch)[[:space:]]+([^;&|"]*[[:space:]])?(main|master)([^[:alnum:]_]|$)'
  local commit='(^|[^[:alnum:]_])git[[:space:]]+commit([^[:alnum:]_]|$)'
  if [[ "$text" =~ $checkout ]] && [[ "$text" =~ $commit ]]; then
    printf '%s' "Checking out main or master and committing in the same command is blocked."
  fi
}

match_governance_rm() {
  local text="$1"
  local re='(^|[^[:alnum:]_])(rm|mv)[[:space:]]+[^;&|"]*(codeowners|\.github/hooks|\.github/workflows/plan_gate\.yml|\.github/scripts/block-high-risk-command\.sh)([^[:alnum:]_.]|$)'
  if [[ "$text" =~ $re ]]; then
    printf '%s' "Removing or moving CODEOWNERS, Plan Gate, or this hook is blocked."
  fi
}

# Inspect one git push argument list. Protected destinations win over force.
classify_push_args() {
  local args="$1"
  local -a words=()
  local word
  local force=0
  local protected=0
  local end_opts=0
  local short_force='^-[^-]*f[^-]*$'
  local protected_ref='^(\+)?([a-z0-9._/-]*:)?(refs/heads/)?(main|master)$'

  # The payload continues after the command. Keep the shell words only.
  args="${args%%\"*}"
  read -r -a words <<< "$args"
  for word in "${words[@]}"; do
    if [[ "$end_opts" -eq 0 && "$word" == "--" ]]; then
      end_opts=1
      continue
    fi
    if [[ "$end_opts" -eq 0 && "$word" == --* ]]; then
      case "$word" in
        --force|--force=*|--force-with-lease|--force-with-lease=*|--force-if-includes|--force-if-includes=*)
          force=1
          ;;
      esac
      continue
    fi
    if [[ "$end_opts" -eq 0 && "$word" == -* ]]; then
      if [[ "$word" =~ $short_force ]]; then
        force=1
      fi
      continue
    fi
    if [[ "$word" == +* ]]; then
      force=1
    fi
    if [[ "$word" =~ $protected_ref ]]; then
      protected=1
    fi
  done
  if [[ "$protected" -eq 1 ]]; then
    printf '%s' "git push to main or master is blocked. Open a pull request instead."
    return 0
  fi
  if [[ "$force" -eq 1 ]]; then
    printf '%s' "force-push is blocked."
  fi
}

match_push() {
  local text="$1"
  local rest="$text"
  local re='(^|[^[:alnum:]_])git[[:space:]]+((-[cC][[:space:]]+[^[:space:]]+|--git-dir[[:space:]]+[^[:space:]]+|--work-tree[[:space:]]+[^[:space:]]+)[[:space:]]+){0,4}push[[:space:]]+([^;&|]*)'
  local reason
  while [[ "$rest" =~ $re ]]; do
    reason="$(classify_push_args "${BASH_REMATCH[4]}")"
    if [[ -n "$reason" ]]; then
      printf '%s' "$reason"
      return 0
    fi
    rest="${rest#*"${BASH_REMATCH[0]}"}"
  done
}

decide() {
  local text="$1"
  local tool reason
  tool="$(tool_name "$text")"
  case "$tool" in
    ""|bash|powershell) ;;
    *) pass ;;
  esac

  reason="$(match_pr_merge "$text")"
  [[ -z "$reason" ]] || deny "$reason"
  reason="$(match_api_merge "$text")"
  [[ -z "$reason" ]] || deny "$reason"
  reason="$(match_ruleset_write "$text")"
  [[ -z "$reason" ]] || deny "$reason"
  reason="$(match_push "$text")"
  [[ -z "$reason" ]] || deny "$reason"
  reason="$(match_ready_label "$text")"
  [[ -z "$reason" ]] || deny "$reason"
  reason="$(match_checkout_commit "$text")"
  [[ -z "$reason" ]] || deny "$reason"
  reason="$(match_governance_rm "$text")"
  [[ -z "$reason" ]] || deny "$reason"
  pass
}

expect_deny() {
  local name="$1"
  local payload="$2"
  local needle="$3"
  local out
  out="$(printf '%s' "$payload" | bash "${BASH_SOURCE[0]}")"
  if [[ "$out" != *'"permissionDecision":"deny"'* ]]; then
    echo "FAIL ${name}: expected deny, got ${out}" >&2
    return 1
  fi
  if [[ "$out" != *"$needle"* ]]; then
    echo "FAIL ${name}: reason missing '${needle}', got ${out}" >&2
    return 1
  fi
  echo "ok deny ${name}"
}

expect_allow() {
  local name="$1"
  local payload="$2"
  local out
  out="$(printf '%s' "$payload" | bash "${BASH_SOURCE[0]}")"
  if [[ "$out" != '{}' ]]; then
    echo "FAIL ${name}: expected {}, got ${out}" >&2
    return 1
  fi
  echo "ok allow ${name}"
}

self_test() {
  local failed=0
  local payload

  if [[ ! -f "$HOOK_JSON" ]]; then
    echo "::error::${HOOK_JSON} is required for the hook self-test." >&2
    exit 1
  fi
  python3 -m json.tool "$HOOK_JSON" >/dev/null
  if ! grep -q '"preToolUse"' "$HOOK_JSON"; then
    echo "::error::${HOOK_JSON} must register preToolUse." >&2
    exit 1
  fi
  if ! grep -q 'block-high-risk-command.sh' "$HOOK_JSON"; then
    echo "::error::${HOOK_JSON} must call block-high-risk-command.sh." >&2
    exit 1
  fi
  echo "self-test: hook config is valid JSON and points at this script."

  payload='{"toolName":"bash","toolArgs":{"command":"git push origin main"}}'
  expect_deny "push origin main" "$payload" "main or master" || failed=1

  payload='{"toolName":"bash","toolArgs":"{\"command\":\"git push origin HEAD:main\"}"}'
  expect_deny "stringified push HEAD:main" "$payload" "main or master" || failed=1

  payload='{"toolName":"bash","toolArgs":{"command":"git push origin feature:refs/heads/master"}}'
  expect_deny "push to refs/heads/master" "$payload" "main or master" || failed=1

  payload='{"toolName":"bash","toolArgs":{"command":"git push origin :main"}}'
  expect_deny "delete remote main" "$payload" "main or master" || failed=1

  payload='{"toolName":"powershell","toolArgs":{"command":"git push --force origin feature"}}'
  expect_deny "force-push" "$payload" "force-push" || failed=1

  payload='{"toolName":"bash","toolArgs":{"command":"git push -uf origin feature"}}'
  expect_deny "short -uf" "$payload" "force-push" || failed=1

  payload='{"toolName":"bash","toolArgs":{"command":"git push --force-with-lease origin feature"}}'
  expect_deny "force-with-lease" "$payload" "force-push" || failed=1

  payload='{"toolName":"bash","toolArgs":{"command":"git push origin +feature"}}'
  expect_deny "plus refspec" "$payload" "force-push" || failed=1

  payload='{"toolName":"bash","toolArgs":{"command":"git -c user.name=agent push origin main"}}'
  expect_deny "git -c then push main" "$payload" "main or master" || failed=1

  payload='{"toolName":"bash","toolArgs":{"command":"git push origin feature && git push origin main"}}'
  expect_deny "second push targets main" "$payload" "main or master" || failed=1

  payload='{"toolName":"bash","toolArgs":{"command":"gh api -X PUT repos/acme/widgets/branches/main/protection"}}'
  expect_deny "branch protection write" "$payload" "branch protection" || failed=1

  payload='{"toolName":"bash","toolArgs":{"command":"gh pr merge --squash 12"}}'
  expect_deny "gh pr merge" "$payload" "gh pr merge" || failed=1

  payload='{"toolName":"bash","toolArgs":{"command":"gh api -X PUT repos/acme/widgets/pulls/12/merge"}}'
  expect_deny "pulls merge API" "$payload" "merge API" || failed=1

  payload='{"toolName":"bash","toolArgs":{"command":"gh api --method DELETE repos/acme/widgets/rulesets/4"}}'
  expect_deny "delete ruleset" "$payload" "rulesets" || failed=1

  payload='{"toolName":"bash","toolArgs":{"command":"gh issue edit 12 --add-label ready-for-agent"}}'
  expect_deny "add ready-for-agent" "$payload" "ready-for-agent" || failed=1

  payload='{"toolName":"bash","toolArgs":{"command":"git checkout main && git commit -m update"}}'
  expect_deny "checkout main and commit" "$payload" "Checking out main" || failed=1

  payload='{"toolName":"bash","toolArgs":{"command":"rm -rf .github/hooks"}}'
  expect_deny "rm hooks dir" "$payload" "CODEOWNERS" || failed=1

  payload='{"toolName":"bash","toolArgs":{"command":"git push -u origin HEAD"}}'
  expect_allow "push current feature branch" "$payload" || failed=1

  payload='{"toolName":"bash","toolArgs":{"command":"git push origin feature/main-docs"}}'
  expect_allow "branch named feature/main-docs" "$payload" || failed=1

  payload='{"toolName":"bash","toolArgs":{"command":"gh pr view 12"}}'
  expect_allow "gh pr view" "$payload" || failed=1

  payload='{"toolName":"bash","toolArgs":{"command":"gh api repos/acme/widgets/rulesets"}}'
  expect_allow "read rulesets" "$payload" || failed=1

  payload='{"toolName":"bash","toolArgs":{"command":"gh issue edit 12 --remove-label ready-for-agent"}}'
  expect_allow "remove ready-for-agent" "$payload" || failed=1

  payload='{"toolName":"bash","toolArgs":{"command":"git commit -m update"}}'
  expect_allow "commit on current branch" "$payload" || failed=1

  payload='{"toolName":"view","toolArgs":{"path":"CODEOWNERS"}}'
  expect_allow "view tool is not a shell" "$payload" || failed=1

  payload='{"toolName":"bash","toolArgs":{"command":"echo git push origin main"}}'
  expect_deny "echo of a blocked push" "$payload" "main or master" || failed=1

  if [[ "$failed" -ne 0 ]]; then
    echo "::error::self-test: high-risk command hook failed." >&2
    exit 1
  fi
  echo "self-test: blocked commands are denied and ordinary commands pass."
}

if [[ "${1:-}" == "--self-test" ]]; then
  self_test
  exit 0
fi

if [[ $# -gt 0 ]]; then
  echo "::error::Unknown argument: $1" >&2
  exit 1
fi

INPUT="$(cat || true)"
if [[ -z "${INPUT}" ]]; then
  pass
fi
decide "$(normalize "$INPUT")"
