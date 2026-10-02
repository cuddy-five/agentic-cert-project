# Fail twice, then a human

Source: https://learn.microsoft.com/en-us/training/modules/design-agent-architecture-integration/7-agent-operations-controls

Repo: `cuddy-five/agentic-cert-project`

## Rule

If a **required** check fails:

1. Revise the PR branch and push once.
2. If **that same check** fails again, stop.
3. Do not push a third time for the same failure.

## Hand the human this

On the PR, write four lines:

- What failed (check name + run URL)
- What was tried (the one revision)
- Evidence (run URL + commit SHA)
- Next step for a human (merge anyway, change the plan, or close)

## What this is not

- Not an Actions job. Plan Gate does not count failures.
- Not the shell hook. Push, merge, and ruleset bans are in `docs/02-hooks.md`.
- Not a cap on different checks. A new check name is a new first failure.
- Not rollback. Rollback stays the PR template field.
- Not `prod`. No environment yet.

## Who merges

Corey. The agent does not merge to clear a red check.
