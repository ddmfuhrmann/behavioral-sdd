# /bsdd-ship

Unifies review, ADR check, and handoff into a single conversational flow. Triggered manually after `/bsdd-implement` completes.

## Procedure

1. Spawn the `git-agent` to get the diff (`git diff main`) and `git diff main --stat`.
1b. Count changed lines from the `--stat` output.
   - If 600–900 lines: emit an inline warning — "⚠ This PR touches N lines. Consider splitting into slices before review."
   - If >900 lines: emit a stronger inline warning — "⚠ This PR touches N lines (>900). Large PRs make review harder. Consider returning to `/bsdd-prd` to decompose into slices."
   - In both cases: continue to step 2 normally — do NOT block, do NOT use `AskUserQuestion` for this.
2. Identify the related plan (from conversation context or ask).
3. Spawn the `reviewer` with: plan content + diff + implementation summary + test summary.
   - Before spawning, check whether `sonar-project.properties` exists at the project root. If yes, instruct the reviewer explicitly: "SonarQube is active — execute `.skills/sonar-analysis.md` before producing findings."
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
7. Save locally in `.ship/YYYY-MM-DD-<title>/`: review summary + ADRs (if any) + handoff doc. These files are listed in `.gitignore` and must **not** be committed.
8. Spawn the `git-agent` to create the PR with the generated summary. Pass only source-code files as the files to stage — never `.plans/`, `.ship/`, or `.prds/` paths.
9. Confirm with the PR URL created.
