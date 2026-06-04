# /bsdd-ship

Unifies review, ADR check, and handoff into a single conversational flow. Triggered manually after `/bsdd-implement` completes.

## Procedure

1. Spawn the `git-agent` to get the diff (`git diff main`).
2. Identify the related plan (from conversation context or ask).
3. Spawn the `reviewer` with: plan content + diff + implementation summary + test summary.
4. For each relevant finding from the reviewer, use `AskUserQuestion`:
   - Present the finding and ask for action: "Fix now" / "Defer" / "Open issue" (Recommended varies by severity: BLOCKER → fix, WARNING → defer, SUGGESTION → open issue).
   - If "Fix now": spawn the `feature-implementer` to apply the fix.
5. ADR check — analyze the diff for architectural decisions that deviate from patterns or are hard to reverse. If candidates are found:
   - Present via `AskUserQuestion`: "Record all" / "Choose which" / "None for now".
   - If recording: save ADR(s) locally in `.ship/YYYY-MM-DD-<title>/adrs/`.
6. Handoff grill-me — use `AskUserQuestion` to collect context:
   - "What is the next step after this delivery?" (options based on context)
   - "Are there pending decisions that should be recorded?"
   - "Are there known risks for production?"
7. Save locally in `.ship/YYYY-MM-DD-<title>/`: review summary + ADRs (if any) + handoff doc.
8. Spawn the `git-agent` to create the PR with the generated summary.
9. Confirm with the PR URL created.
