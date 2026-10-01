#!/usr/bin/env bash
# Fail when a pull request body is missing a required plan heading.
#
# Headings come from .github/pull_request_template.md:
#   ## Plan (required)
#   ## Evidence
#   ## Review checklist
#
# The workflow passes the pull request payload GitHub already provides:
#   PR_BODY="${{ github.event.pull_request.body }}" bash .github/scripts/require-plan-headings.sh
#
# Prove a missing heading fails this check:
#   bash .github/scripts/require-plan-headings.sh --self-test
#   PR_BODY="$(sed '/^## Evidence$/d' .github/pull_request_template.md)" \
#     bash .github/scripts/require-plan-headings.sh
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

if missing_headings "$PR_BODY" error; then
  echo "Pull request body includes ## Plan (required), ## Evidence, and ## Review checklist."
else
  exit 1
fi
