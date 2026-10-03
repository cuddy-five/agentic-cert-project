# Agent instructions

This repository is control-plane practice for the GH-600 path. The stack is bash, GitHub Actions, and Markdown. There is no application, no package manager, and no `pytest` or `npm test`.

Issue #11 is the loop contract. This file is the index an agent reads first. The checks below already enforce it. Do not invent a second process, and do not add a check unless the issue you are on asks for one.

## Commands

Run the self-test for any script you change:

```bash
bash .github/scripts/require-plan-headings.sh --self-test
bash .github/scripts/require-scope-match.sh --self-test
bash .github/scripts/block-high-risk-command.sh --self-test
```

Plan Gate (`.github/workflows/plan_gate.yml`) runs those self-tests on every pull request, then checks that pull request's body and diff. Its `GITHUB_TOKEN` is `contents: read`.

## How work moves

1. A human adds `ready-for-agent` only when the issue body has **Goal**, **Allowed scope**, and **Success criteria**. Do not apply that label.
2. Claim by assigning yourself. Remove `ready-for-agent`. Add `in-progress`.
3. Branch from `main` only. Name it `feat/#<n>-…`, `fix/#<n>-…`, or `chore/#<n>-…`.
4. Open the pull request ready for review. Include `Fixes #<n>` or `Closes #<n>`. Fill the plan. Stay inside the issue's Allowed scope.
5. A human merges. Merge to `main` finishes the loop. The closing keyword closes the issue. Remove `in-progress`.
6. If you cannot finish inside the scope, stop. Remove `in-progress`, add `needs-info` or `ready-for-human`, unassign yourself, and comment why.

An Agent-plan issue is optional. Use one when Corey must approve the plan before an implementation pull request. Plan Gate reads the pull request body, not that issue.

## Pull request plan

| Field | Rule |
| --- | --- |
| Goal, Scope, Steps, Success criteria | Required. Plan Gate fails the pull request when one is missing or blank. |
| Risks, Rollback | Required for code changes. Optional for docs-only. Plan Gate does not read these fields. |
| Evidence | Required when a check or scan ran. Otherwise write `n/a`. |
| Review checklist | Human. Leave it for the reviewer. |

**Scope (paths/files):** is one line of comma-separated repo paths. A changed file must equal a path or sit under it. `docs` covers `docs/02-scope-match.md`. It does not cover `docs-other/a.md`. `.` is not a path. `*` is not a path. A sentence does not cover a file it does not name. Unused paths are allowed. A rename counts the old path and the new path. The check is `docs/02-scope-match.md`.

## When a check fails

Revise the branch once. If that same check fails again, stop. Do not push a third time for the same failure. On the pull request, write four lines: what failed (check name and run URL), what you tried, the evidence (run URL and commit SHA), and the next step for a human. The rule is `docs/02-fail-twice.md`.

## Do not

1. Push or commit on `main` or `master`.
2. Merge your own pull request, including through `gh api`, `curl`, or `wget`.
3. Change rulesets or branch protection. Do not weaken or remove `CODEOWNERS`, Plan Gate, or the hook.
4. Read or print secrets. Do not commit tokens.
5. Edit a path outside the issue's Allowed scope unless a human comment widens it. Update the Scope line in the same push so the diff still matches.
6. Apply `ready-for-agent` to any issue.
7. Force-push, including `--force-with-lease` and a refspec that starts with `+`.

`.github/hooks/block-high-risk-command.json` runs `.github/scripts/block-high-risk-command.sh` before `bash` and `powershell`. A printed `{}` means the hook has no opinion. A deny includes the reason and still exits 0. The command list and its limits are in `docs/02-hooks.md`.

## Leave these as they are

- `copilot/managed-settings.json` stays `{}`. This personal account has no enterprise MCP allow list. See `docs/03-mcp-servers-registries-allow-lists.md`.
- `agents/example-agent.md` stays commented out. Repository agents belong in `.github/agents/` and need an explicit `tools` list. Omitting `tools` grants every tool.
- Skills stay in `.github/skills/`. The review procedure is `.github/skills/code-review/SKILL.md`.
- Plan Gate stays traditional Actions and stays the merge check. A later agentic workflow may comment. It does not replace `require-plan`. See `docs/03-apis-and-workflows.md`.

## What to build next

Open work is the checklist in issue #37. Build the first issue that is open and not blocked. Do not open a Plan Gate or hook change unless that issue asks for it.
