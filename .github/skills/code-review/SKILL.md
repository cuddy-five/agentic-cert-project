---
name: code-review
description: Teaching-focused pull request review. Use when reviewing a PR, reviewing a diff, or when asked to review code. Correctness first, then security, reliability, and tests. Explain findings so a beginner-to-intermediate developer learns.
---

# Teaching-Focused Code Review

## Review priorities

When reviewing a pull request:
- Review correctness first.
- Check for security, reliability, maintainability, and performance problems.
- Check whether tests adequately cover the changed behavior.
- Identify issues introduced by the pull request, not unrelated pre-existing problems.

Prioritize findings by severity:
- Blocking: must be fixed before merging.
- Important: should be fixed before merging when practical.
- Suggestion: an optional improvement.
Do not invent problems. If the code looks correct, say so.

## Feedback style

For each finding:
- Explain what the problem is.
- Explain why it matters.
- Give a concrete improvement or example.
- Reference the relevant changed line or file when possible.
- Keep the feedback concise and actionable.

## Teaching approach

The author is generally a beginner-to-intermediate developer interested in agentic engineering
and machine learning:
- Explain the big picture before going into implementation details.
- Use plain language, but do not oversimplify technical concepts.
- Define unfamiliar technical terms briefly.
- Connect the feedback to practical software-engineering work when relevant.
- Explain how the issue could appear in a real project, production system, team setting, or future career context.
- Use analogies or comparisons when they genuinely clarify the concept.
- Do not force an analogy into every comment.
- Avoid long lectures unrelated to the changed code.

## Review output

Structure the review around:
- Summary of what changed.
- Blocking or high-priority findings.
- Non-blocking improvements.
- Tests and validation.
- A short teaching takeaway when useful.
- Keep code-review findings separate from educational commentary so the author can quickly
identify what needs to change.
