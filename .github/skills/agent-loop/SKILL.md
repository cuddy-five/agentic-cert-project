---
name: agent-loop
description: Claim a ready-for-agent issue, branch from main, open a pull request inside Allowed scope, and stop after one failed check. Use when starting work from a GitHub issue in this repo.
---

# Agent loop

The contract record is `docs/adr/agent-loop-contract.md`. Follow this procedure. Do not invent a second process.

## Claim

1. Start only when the issue body has **Goal**, **Allowed scope**, and **Success criteria**, and a human has applied `ready-for-agent`.
2. Assign yourself. Remove `ready-for-agent`. Add `in-progress`.
3. Do not apply `ready-for-agent` to any issue.

## Branch

Branch from `main` only. Name it `feat/#<n>-…`, `fix/#<n>-…`, or `chore/#<n>-…`. Do not commit or push on `main` or `master`.

## Pull request

1. Open the pull request ready for review.
2. Include `Fixes #<n>` or `Closes #<n>`.
3. Fill **Goal**, **Scope**, **Steps**, and **Success criteria**. **Scope (paths/files):** is one line of comma-separated repo paths. A changed file must equal a path or sit under it. Stay inside the issue's Allowed scope. The rule is `docs/02-scope-match.md`.
4. For a code change, fill **Risks** and **Rollback**. For docs-only work those fields are optional.
5. When a check or scan ran, fill **Evidence**. Otherwise write `n/a`. The heading is exactly `## Evidence`.
6. Leave the review checklist for the human reviewer.

## Stop

Revise the branch once when a check fails. If that same check fails again, stop. Do not push a third time for the same failure. On the pull request, write what failed, what you tried, the evidence, and the next step for a human. The rule is `docs/02-fail-twice.md`.

If you cannot finish inside the Allowed scope, remove `in-progress`, add `needs-info` or `ready-for-human`, unassign yourself, and comment why.

## Bans

1. Do not push or commit on `main` or `master`.
2. Do not merge your own pull request.
3. Do not change rulesets or branch protection. Do not weaken or remove `CODEOWNERS`, Plan Gate, or the hook.
4. Do not read or print secrets. Do not commit tokens.
5. Do not edit a path outside the issue's Allowed scope unless a human comment widens it. Update the Scope line in the same push.
6. Do not apply `ready-for-agent`.
7. Do not force-push.

A human merges. Merge to `main` finishes the loop. The closing keyword closes the issue. Remove `in-progress`.
