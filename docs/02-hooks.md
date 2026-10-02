# Hooks that block high-risk shell commands (module 2 unit 7)

Source: https://learn.microsoft.com/en-us/training/modules/design-agent-architecture-integration/7-agent-operations-controls

Hook schema: https://docs.github.com/en/copilot/reference/hooks-reference

Repo: `cuddy-five/agentic-cert-project`

The Learn unit shows a short JSON example that checks `$TOOL == "delete"`. That shape is not the Copilot hook file. This repo uses the real file: `.github/hooks/block-high-risk-command.json`, `version` 1, event `preToolUse`.

## What runs

| Piece | Role |
| --- | --- |
| `.github/hooks/block-high-risk-command.json` | Copilot CLI and Copilot cloud agent load this from the default branch. Matcher `bash\|powershell`. |
| `.github/scripts/block-high-risk-command.sh` | Reads the hook payload on stdin. Prints `permissionDecision` `deny` or `{}`. |
| Plan Gate step | Runs `--self-test` so a broken denylist fails `require-plan`. |

`{}` means this hook has no opinion. Copilot's normal permission flow still applies. A deny includes `permissionDecisionReason`. Exit code is 0 on purpose: a non-zero `preToolUse` exit would deny every later shell command.

## Commands denied

These are the agent-loop bans that show up as shell text:

- `git push` whose destination is `main` or `master`, including `HEAD:main`, `refs/heads/master`, and `:main`
- force-push: `--force`, `--force-with-lease`, `--force-if-includes`, a short flag cluster that contains `f`, or a `+refspec`
- `gh pr merge` and `gh api` calls to `pulls/<n>/merge`
- `gh api` writes (`PUT`, `PATCH`, `DELETE`) aimed at rulesets or branch protection
- `--add-label ready-for-agent` (removing that label is still allowed)
- `git checkout` or `git switch` to `main` or `master` in the same command as `git commit`
- `rm` or `mv` aimed at `CODEOWNERS`, `.github/hooks`, Plan Gate, or this script

`git push -u origin HEAD` and `git push origin feature/main-docs` are allowed. A branch name that merely contains the letters `main` is not `main`.

## What this hook does not do

- It does not run until the JSON file is on the default branch. Cloud agent reads `.github/hooks/*.json` from the clone.
- It does not see the `edit` or `create` tools. A file change to `CODEOWNERS` or Plan Gate still has to pass CODEOWNERS review and `require-plan`.
- It does not know whether `HEAD` is `main`. `git push -u origin HEAD` from a checkout of `main` is not visible here.
- It does not block `printenv` or `env`. Secret handling stays out of committed files. Plan Gate's token is `contents: read`.
- It matches command text. `echo git push origin main` is denied because the blocked words are in the command.
- Cloud agent is Linux and honors `bash`. The `powershell` entry is for Copilot CLI on Windows and still calls `bash`, so Git Bash has to be on `PATH`.
- A hook timeout fails open. This script is a local text check with `timeoutSec` 10 so it stays inside that window.
- Files the hook writes would be discarded with the cloud agent sandbox. This hook does not write a log file. The deny reason is the record the agent sees.

## Prove it

```bash
bash .github/scripts/block-high-risk-command.sh --self-test
```
