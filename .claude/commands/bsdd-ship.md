# /bsdd-ship

Unifies review, ADR check, and handoff into a single conversational flow. Triggered manually after `/bsdd-implement` completes.

## Procedure

1. Spawn the `git-agent` to get the diff (`git diff main`) and `git diff main --stat`.
1b. Count changed lines from the `--stat` output.
   - If 600–900 lines: emit an inline warning — "⚠ This PR touches N lines. Consider splitting into slices before review."
   - If >900 lines: emit a stronger inline warning — "⚠ This PR touches N lines (>900). Large PRs make review harder. Consider returning to `/bsdd-prd` to decompose into slices."
   - In both cases: continue to step 2 normally — do NOT block, do NOT use `AskUserQuestion` for this.
2. Identify the related plan (from conversation context or ask).
3. **Plugin detection** — read `.bsdd-plugins.yml` from the project root (if it exists). For each plugin declared under `reviewer:`, resolve which script to run:
   - `sonar` → `.skills/plugins/sonar.sh` (auto-detects if `sonar-project.properties` exists)
   - `xlint-removal` → `.skills/plugins/xlint-removal.sh` (auto-detects if `build.gradle.kts`, `build.gradle`, or `pom.xml` exists)
   - `trivy` → `.skills/plugins/trivy.sh` (auto-detects if `docker info` exits 0)
   A plugin with `enabled: false` is skipped — do not invoke its script. With `enabled: auto` or `true`, include it; each script self-guards (`enabled: true` still emits a skip line if its prerequisite is absent). If `.bsdd-plugins.yml` is absent, treat all three as `auto`.
   **Sonar prepare:** if `sonar` is active and the project is compiled (Java/Gradle/Maven) but declares no `# bsdd.sonar.prepare=` line in `sonar-project.properties`, infer the build's compile command and pass it to the runner as `sonar.sh --prepare "<cmd>" …` so the Java sensor has bytecode + classpath (e.g. `./gradlew --quiet classes testClasses` plus the project's classpath-staging task). Non-compiled projects need no `--prepare`.
4. **Spawn the plugin-runner (Haiku) + reviewer (Opus) in parallel** — both in the same message turn, so they run concurrently:
   - Spawn **one** plugin-runner sub-agent on **Haiku** (a single runner for all active plugins, not one per plugin). Its sole job is mechanical: run each active plugin's `.sh`, passing the diff file list as arguments where the script accepts them (`sonar.sh`) plus the `--prepare "<cmd>"` resolved in step 3 for `sonar`, and return each script's stdout **verbatim** under its section header. It must NOT summarize, reformat, or deduplicate — it is a context firewall that keeps the scripts' verbose output (docker pull, scanner/gradle logs) out of the orchestrator. If a script exits non-zero, return its `[… BLOCKED]` message verbatim.
   - Spawn the `reviewer` sub-agent on **Opus** with: plan content + diff + implementation summary + test summary. The reviewer returns severity-labeled findings. It does **not** run plugins.
5. **Merge findings (orchestrator)** — collect the reviewer's findings and the plugin-runner's per-plugin sections. Deduplicate across sources: if the same file+line is flagged by multiple sources, keep the highest severity. Prefix each finding with its source in brackets: `[REVIEWER]`, `[SONAR]`, `[XLINT]`, `[TRIVY]`. This cross-source dedupe stays here — the Haiku runner never sees the reviewer's output. Present a brief summary of which plugins ran and how many findings each produced before entering the finding loop.
6. For each relevant finding (merged list), use `AskUserQuestion`:
   - Present the finding and ask for action: "Fix now" / "Defer" / "Open issue" (Recommended varies by severity: BLOCKER → fix, WARNING → defer, SUGGESTION → open issue).
   - If "Fix now": spawn the `feature-implementer` to apply the fix.
7. ADR check — analyze the diff for architectural decisions that deviate from patterns or are hard to reverse. If candidates are found:
   - Present via `AskUserQuestion`: "Record all" / "Choose which" / "None for now".
   - If recording: save ADR(s) locally in `.ship/YYYY-MM-DD-<title>/adrs/`.
8. Handoff grill-me — use `AskUserQuestion` to collect context:
   - "What is the next step after this delivery?" (options based on context)
   - "Are there pending decisions that should be recorded?"
   - "Are there known risks for production?"
9. Save locally in `.ship/YYYY-MM-DD-<title>/`: review summary + ADRs (if any) + handoff doc. These files are listed in `.gitignore` and must **not** be committed.
10. Spawn the `git-agent` to create the PR with the generated summary. Pass only source-code files as the files to stage — never `.plans/`, `.ship/`, or `.prds/` paths.
11. Confirm with the PR URL created.
