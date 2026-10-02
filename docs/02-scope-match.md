# Scope must match the diff (module 2 unit 3)

Source: https://learn.microsoft.com/en-us/training/modules/design-agent-architecture-integration/3-inputs-outputs-success-criteria

Repo: `cuddy-five/agentic-cert-project`

Unit 3 says a task is done when scope matches intent: no unexpected files changed. Unit 2 says limit which directories an agent can modify. The plan line already had to be non-empty. This check makes that line an allowlist.

## Rule

`- **Scope (paths/files):**` is one line of comma-separated repo paths.

A changed file passes when it equals a path or sits under it. `docs` covers `docs/02-scope-match.md`. It does not cover `docs-other/a.md`. Extra words are unused paths. A sentence does not cover a file it does not name.

Renames count the old path and the new path. A copy does too.

## This repo

| Piece | Role |
| --- | --- |
| `.github/scripts/require-scope-match.sh` | Compares the diff to the Scope line. |
| Plan Gate | Runs `--self-test`, then the check on `base.sha`..`head.sha`. |
| Checkout `fetch-depth: 0` | Both SHAs have to be in the clone. Depth 1 only has the merge commit. |

The diff is `git diff` in the checkout. Not an API call.

## What this is not

- Not a requirement that every scoped path changed. Unused paths are fine.
- Not globs. `*` is not a path. `.` is not a path.
- Not CODEOWNERS. Ownership still routes review.
- Not Risks or Rollback. Those stay optional.
- Not spaces in file names. A quoted diff path fails the check.
- Not the plan issue. Approval stays a person.

## Prove it

```bash
bash .github/scripts/require-scope-match.sh --self-test
```
