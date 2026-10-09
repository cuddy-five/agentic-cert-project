---
applyTo: ".github/workflows/**"
---

# Workflow rules

- Plan Gate (`.github/workflows/plan_gate.yml`) stays a traditional GitHub Actions workflow and stays the merge check.
- Plan Gate keeps `permissions: contents: read`.
- A new workflow does not get write permissions. `contents: write` or `pull-requests: write` would let that workflow change the branch or the pull request and bypass Plan Gate.
- A later agentic workflow may comment. It does not replace `require-plan`.
