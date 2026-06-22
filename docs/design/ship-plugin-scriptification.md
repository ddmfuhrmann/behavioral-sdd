# Design: Ship plugin scriptification

**Status:** evaluation (no implementation yet)
**Scope:** `/bsdd-ship` reviewer plugins — `sonar`, `xlint-removal`, `trivy`

## Problem

The three reviewer plugins are written as **procedures executed step-by-step by an
LLM sub-agent**. Each bash block in `.skills/plugins/<name>.md` becomes its own LLM
turn (think → run → read output → think → run next). Sonar is the worst case: ~8
sequential steps plus two polling loops (server health, 120s; CE queue, 60s), all
driven by an Opus sub-agent.

The LLM adds no judgment to this. The only non-mechanical parts are:

- **severity mapping** → a static lookup table
- **filter to files in the diff** → a `grep` over a file list the command already passes

Everything else is fixed procedure. The LLM in the execution loop is pure latency and
token overhead.

> Note: the slowness is **not** about running tests. `xlint-removal` already compiles
> without tests (`./gradlew compileJava` / `mvn compile` — neither touches test
> sources). The cost is the LLM-driven step execution, not the build target.

## Pattern

**Plugin = executable script that emits findings in reviewer-format; an LLM only
consumes the result.**

Move the procedure logic out of the `.md` and into a `.sh`:

- `.skills/plugins/sonar.sh`
- `.skills/plugins/xlint-removal.sh`
- `.skills/plugins/trivy.sh`

Each script does detection, execution, severity mapping, and formatting internally,
printing `[BLOCKER]/[WARNING]/[SUGGESTION]` lines to stdout. An abort becomes a
non-zero exit with a clear `[<PLUGIN> BLOCKED] …` message that the orchestrator
relays verbatim.

### Output contract

- **stdout:** only reviewer-format finding lines (or the "no issues" message).
- **logs/noise** (docker pull, scanner/gradle logs, raw JSON): redirected to a
  logfile or stderr — never mixed into the findings on stdout.
- **exit code:** `0` = ran (with or without findings); non-zero = blocked, stdout/
  stderr carries the reason.

## Per-plugin notes

### sonar.sh
Encapsulates steps 0–8 of `sonar.md`: resolve projectKey → ensure network/container
→ resolve token → **prepare** → run scanner → poll CE queue → fetch issues → apply
severity table → **filter to the diff file list passed as an argument** → print
findings. Token still read from / written to `.bsdd-sonar-token` (stays gitignored).

**Prepare hook (compiled projects).** The Java sensor needs compiled bytecode
(`sonar.java.binaries`) and the dependency classpath (`sonar.java.libraries`); a
non-matching `libraries` glob is a hard error. Producing those is build-system
specific, so the generic script must not bake it in — that would re-couple the
portable plugin to one project's build (Gradle vs Maven, a custom classpath-staging
task, etc.). Instead the script runs an optional **prepare command** it is handed,
resolved in precedence order: `--prepare "<cmd>"` (the orchestrator infers it when the
project declares none) → a `# bsdd.sonar.prepare=<cmd>` line in
`sonar-project.properties` → none. The project still owns the artifacts the command
depends on (e.g. a Gradle `Copy` task staging dependency jars + the matching
`sonar.java.*` paths) — that part is irreducible, as there is no cross-build-system
way to materialize a dependency classpath into a folder.

### xlint-removal.sh
`compileJava` (Gradle) or `mvn compile` + `grep -E "warning:.*\[removal\]"` + `sort -u`,
printed as `[BLOCKER]`. Keep `--rerun` — incremental compile skips unchanged files and
would miss warnings. `compileJava` is already the minimal target for detecting
deprecation-for-removal.

### trivy.sh
Easiest of the three: a single `docker run`, no container lifecycle, no polling, no
token. Trivy already emits JSON, so parsing is pure `jq` over
`.Results[].Vulnerabilities[]`; map `CRITICAL→BLOCKER`, `HIGH→WARNING`; dedupe by
`VulnerabilityID`+`PkgName`. **No diff filter** — a CVE in a dependency is not tied to
a changed line; the scan is over the dependency tree, not the diff. Docker unavailable
→ silent skip message.

## Execution topology

**Haiku sub-agent runs the scripts; Opus reviewer does the judgment.**

The value of the sub-agent is **not** decision-making (there is none left) — it is a
**context firewall**. Scripts emit volume and noise (`docker pull` progress, scanner
logs, gradle output, raw JSON). A Haiku sub-agent absorbs that in its own context and
returns only the clean reviewer-format findings. This is the textbook Haiku case: high
volume, low judgment.

| Role | Model | Responsibility |
|---|---|---|
| Plugin runner | Haiku | Run the `.sh` scripts, return findings verbatim |
| Reviewer | Opus | Plan audit, scope creep, guidelines |
| Orchestrator (`/bsdd-ship`) | Opus | Spawn both; merge + dedupe across sources |

Rules:

1. **One Haiku for all active plugins**, not one per plugin. Same context-firewall
   benefit, fewer spawns. The Haiku fires the scripts in background and waits for all
   three; sonar (120s container) dominates wall-clock, so parallelism happens inside
   the single sub-agent.
2. **Cross-source dedupe stays in Opus.** Haiku returns plugin findings as clean text;
   the Opus reviewer produces its own; the merge (file+line, keep highest severity)
   happens where both are visible = the orchestrator. Haiku must **not** dedupe against
   the reviewer — it never sees it.
3. **Haiku passes stdout through verbatim.** Contract: run the script, return exactly
   the `[BLOCKER]/[WARNING]/…` lines it emitted. No summarizing or reformatting.

> Alternative considered: orchestrator runs the scripts directly via Bash, no
> sub-agent. Works only if every script stays perfectly quiet (findings to stdout,
> everything else to a logfile). Rejected as the default because third-party tool
> noise (e.g. `docker pull` progress) can't be guaranteed silent. Haiku is the robust
> default — it absorbs what the scripts can't promise to suppress.

## What stays a "skill"

After scriptification the plugin `.md` files **stop being loaded skills**. Today they
play a double role: a skill loaded into the sub-agent's context **and** the procedure
it executes step-by-step. With the logic in the `.sh` and the orchestrator/Haiku
invoking it directly, the `.md` is no longer loaded into the loop (also saves the
conditional context load in `reviewer.md`).

What remains in each `.md` is the **script's spec/contract**, not an executable
procedure: purpose, auto-detection rule, project-side prerequisites, output format,
and how to invoke. Same markdown, same `.skills/plugins/` location (minimal churn;
`.bsdd-plugins.yml` detection and the CLAUDE.md/README tables already point there) —
but the role shifts from *"procedure the LLM runs"* to *"documentation for the tool."*

## Files to touch (deferred to implementation)

- **add:** `.skills/plugins/{sonar,xlint-removal,trivy}.sh` (`chmod +x`, versioned)
- **rewrite:** `.skills/plugins/{sonar,xlint-removal,trivy}.md` as thin script
  contracts
- **`.claude/commands/bsdd-ship.md`:** spawn one Haiku plugin-runner + the Opus
  reviewer; keep the merge/dedupe in the orchestrator
- **`.claude/agents/reviewer.md`:** drop the three `load .skills/plugins/<name>.md`
  lines (no procedure left to load); the invocation contract moves to `bsdd-ship.md`
- **confirm:** `.bsdd-sonar-token` remains gitignored
