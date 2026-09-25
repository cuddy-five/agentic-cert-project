# APIs and workflows (module 3 unit 2)

An agent does not edit `main`. It talks to GitHub through the API:
create a branch, commit, open or update a pull request, and that
pull request can start a workflow.

## This repo

| Piece | Role |
| --- | --- |
| Issue form / PR template | Plan the agent must fill in |
| Pull request | How work enters `main` |
| `.github/workflows/plan_gate.yml` | Traditional Actions workflow: isolated job, `GITHUB_TOKEN` |
| Job `require-plan` | Execution layer: fail the PR if the template file is missing |
| Ruleset `protect-main` + Corey merge | Human accepts or rejects the API-created change |

`GITHUB_TOKEN` on Plan Gate is the **job** token (`contents: read`).
It is not Copilot’s identity when Copilot opens a PR.

## Traditional vs agentic

Plan Gate is a **traditional** workflow: YAML, fixed steps, same
check every PR.

An **agentic** workflow (markdown + frontmatter, model chooses
steps) is not in this repo yet. MCP is the next Learn unit; do
not add it in this file’s PR.
