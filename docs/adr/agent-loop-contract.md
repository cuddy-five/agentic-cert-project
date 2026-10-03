1. **Entry.** An issue gets ready-for-agent only when the body has Goal, Allowed scope, and Success criteria. A human applies that label. 
The plan itself lives on the pull request. A separate "Agent plan" issue is optional, for large work that needs Corey before any code change.

2. **Claim.** The assignee is the claim. On claim, remove ready-for-agent and add in-progress. That label already exists.

3. **Branch.** Base is main only. Name it feat/#<n>-…, fix/#<n>-…, or chore/#<n>-….

4. **Pull request.** Open it ready for review. The body includes Fixes #<n> or Closes #<n>, and the plan stays inside the issue's Allowed scope.

5. **Required plan fields.** Goal, Scope, Steps, and Success criteria are always required. Risks and Rollback are required for code changes and 
optional for docs-only. Evidence is required when checks ran, otherwise n/a. The review checklist is for a human.

6. **Merge.** protect-main already requires a pull request, a CODEOWNERS review, and the require-plan check. Merge to main finishes the loop. 
The closing keyword closes the issue. Clear in-progress.

7. **Stuck.** If the agent cannot finish inside scope, it removes in-progress, adds needs-info or ready-for-human, unassigns itself, and comments why.

8. **Seven bans.** No push or commit to main. No merging its own pull request. No weakening rulesets, CODEOWNERS, or Plan Gate. No reading or printing 
secrets. No expanding past Allowed scope without a human approval comment. No applying ready-for-agent to other issues. No force-push to someone else's branch.
