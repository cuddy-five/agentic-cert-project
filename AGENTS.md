# Agent instructions

This repository is control-plane practice for the GH-600 path. The stack is bash, GitHub Actions, and Markdown. There is no application, no package manager, and no `pytest` or `npm test`.

Follow `docs/adr/agent-loop-contract.md` for how work enters, is claimed, branched, reviewed, and finished, and for the seven bans. Label meanings are in `docs/agents/triage-labels.md`. Do not invent a second process, and do not add a check unless the issue you are on asks for one.

## Commands

Run the self-test for any script you change:

```bash
bash .github/scripts/require-plan-headings.sh --self-test
bash .github/scripts/require-scope-match.sh --self-test
bash .github/scripts/block-high-risk-command.sh --self-test
```

Plan Gate (`.github/workflows/plan_gate.yml`) runs those self-tests on every pull request, then checks that pull request's body and diff. Its `GITHUB_TOKEN` is `contents: read`.

## Checks the contract names only in brief

- **Scope line.** `docs/02-scope-match.md`. One line of comma-separated repo paths. `.` and `*` are not paths.
- **A failed check.** `docs/02-fail-twice.md`. One revision, then stop.
- **Shell hook.** `docs/02-hooks.md`. The bans, as command text the hook denies.

## Leave these as they are

- `copilot/managed-settings.json` stays `{}`. See `docs/03-mcp-servers-registries-allow-lists.md`.
- `agents/example-agent.md` stays commented out. Repository agents belong in `.github/agents/` and need an explicit `tools` list.
- Skills stay in `.github/skills/`. The review procedure is `.github/skills/code-review/SKILL.md`.
- Plan Gate stays traditional Actions and stays the merge check. See `docs/03-apis-and-workflows.md`.

## What to build next

Open work is the checklist in issue #37. Build the first issue that is open and not blocked.
