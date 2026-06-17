# /bsdd-ship

Unifies review, ADR check, and handoff into a single conversational flow. Triggered manually after `/bsdd-implement` completes.

## Procedure

1. Spawn the `git-agent` to get the diff (`git diff main`) and `git diff main --stat`.
1b. Count changed lines from the `--stat` output.
   - If 600–900 lines: emit an inline warning — "⚠ This PR touches N lines. Consider splitting into slices before review."
   - If >900 lines: emit a stronger inline warning — "⚠ This PR touches N lines (>900). Large PRs make review harder. Consider returning to `/bsdd-prd` to decompose into slices."
   - In both cases: continue to step 2 normally — do NOT block, do NOT use `AskUserQuestion` for this.
2. Identify the related plan (from conversation context or ask).
3. **Plugin detection** — read `.bsdd-plugins.yml` from the project root (if it exists). For each plugin declared under `reviewer:`, evaluate the auto-detection condition inline:
   - `sonar`: enabled if `sonar-project.properties` exists at the project root
   - `xlint-removal`: enabled if `build.gradle.kts`, `build.gradle`, or `pom.xml` exists at the project root
   - `trivy`: enabled if `docker info` exits 0
   A plugin with `enabled: false` is always skipped. A plugin with `enabled: true` always runs regardless of auto-detection.
4. **Spawn reviewer + active plugins in parallel** — all in the same message turn, so they run concurrently:
   - Read `.handoff/YYYY-MM-DD-<title>.yml` if it exists. Spawn the `reviewer` sub-agent with: plan content + diff + handoff YAML (replaces separate implementation summary and test summary — contains `changed_files`, `implementation`, `tests`, `constraints`, `accepted_risks`, `deferred`). If no handoff exists, fall back to passing implementation summary + test summary from conversation context. If neither handoff nor conversation summaries are available (e.g. context was compacted), halt and ask the user to run `/bsdd-handoff <title>` to reconstruct state before continuing. The reviewer follows `.skills/plugins/diff-review.md` and returns severity-labeled findings.
   - For each active plugin, spawn a separate sub-agent that reads `.skills/plugins/<name>.md` and executes the full procedure described there. Pass it the list of files changed in the diff so it filters findings to that scope only.
5. **Merge findings** — collect the findings from the reviewer and all plugin sub-agents. Deduplicate: if the same file+line is flagged by multiple sources, keep the highest severity. Prefix each finding with its source in brackets: `[REVIEWER]`, `[SONAR]`, `[XLINT]`, `[TRIVY]`. Present a brief summary of which plugins ran and how many findings each produced before entering the finding loop.
6. For each relevant finding (merged list), use `AskUserQuestion`:
   - Present the finding and ask for action: "Fix now" / "Defer" / "Open issue" (Recommended varies by severity: BLOCKER → fix, WARNING → defer, SUGGESTION → open issue).
   - If "Fix now": spawn the `feature-implementer` to apply the fix.
7. ADR check — analyze the diff for architectural decisions that deviate from patterns or are hard to reverse. If candidates are found:
   - Present via `AskUserQuestion`: "Record all" / "Choose which" / "None for now".
   - If recording: save ADR(s) locally in `.ship/YYYY-MM-DD-<title>/adrs/`.
8. Handoff grill-me — use `AskUserQuestion` to collect context:
   - Before asking questions: read `.handoff/YYYY-MM-DD-<title>.yml` if it exists. Use existing handoff content as context — skip or pre-fill questions whose answers are already captured there.
   - "What is the next step after this delivery?" (options based on context)
   - "Are there pending decisions that should be recorded?"
   - "Are there known risks for production?"
9. Save locally in `.ship/YYYY-MM-DD-<title>/`: review summary + ADRs (if any) + handoff doc. These files are listed in `.gitignore` and must **not** be committed.
10. Spawn the `git-agent` to create the PR with the generated summary. Pass only source-code files as the files to stage — never `.plans/`, `.ship/`, or `.prds/` paths.
11. After PR is created: ensure `.handoff/` directory exists (`mkdir -p .handoff` if needed). Then spawn `handoff-keeper` with:
    - Plan path: `.plans/YYYY-MM-DD-<title>.md`
    - Handoff path: `.handoff/YYYY-MM-DD-<title>.yml` if it exists, otherwise `"none"`
    - Phase summary: `stage=shipped`, `ready_for_ship=true` (was ready and has been delivered), PR URL in `notes_for_next_agent`
12. Confirm with the PR URL created.
