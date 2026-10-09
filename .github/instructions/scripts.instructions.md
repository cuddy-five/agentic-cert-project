---
applyTo: ".github/scripts/**"
---

# Script rules

- Start each script with `set -euo pipefail`.
- Keep the self-test in the script. Run it with `--self-test`.
- A hook deny prints the reason and exits 0. A non-zero `preToolUse` exit would deny every later shell command.
- Do not add a Plan Gate check or a hook pattern unless the issue you are on asks for one.
