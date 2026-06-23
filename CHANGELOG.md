# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

---

## [0.0.5] - 2026-06-22

### Added
- `.skills/plugins/sonar.sh`, `.skills/plugins/xlint-removal.sh`, `.skills/plugins/trivy.sh` — each plugin's full procedure as a self-contained script that emits reviewer-format findings on stdout (noise to stderr, non-zero exit = blocked)
- `sonar.sh` prepare hook: an optional, build-system-agnostic prepare command (compile + dependency-classpath staging) resolved as `--prepare "<cmd>"` (orchestrator-inferred when undeclared) → a `# bsdd.sonar.prepare=` line in `sonar-project.properties` → none

### Changed
- `bsdd-ship`: plugins now run via a single **Haiku** plugin-runner sub-agent — a context firewall that executes the `.sh` scripts and returns their stdout verbatim — spawned in parallel with the **Opus** reviewer; cross-source merge/dedupe stays in the orchestrator. Replaces the previous LLM-driven, step-by-step plugin execution
- `reviewer`: no longer runs plugins (removed the plugin loop and the conditional plugin skill loads); focuses on plan audit + guidelines
- `.skills/plugins/{sonar,xlint-removal,trivy}.md`: reduced from executable procedures to thin script contracts (purpose, auto-detection, prerequisites, invocation, output format)

---

## [0.0.4] - 2026-06-17

### Changed
- `bsdd-plan`: plan approval now uses native plan mode — the command runs inside `EnterPlanMode` and presents the plan through `ExitPlanMode`, giving the native approval UI (including auto-accept) instead of going straight from text to a saved file; the `.plans/` copy is written only after approval
- `bsdd-plan`: after approval, the command auto-chains into `/bsdd-implement <title>` (via the Skill tool) so an approved-with-auto-accept plan flows straight into implementation in the same run

---

## [0.0.3] - 2026-06-05

### Added
- `bsdd-prd`: slice decomposition step for features estimated at > 500 lines — collects kebab-case title, description, estimated size, and dependencies per slice; saved PRD includes a `## Slices` table; if decomposition is declined, a note is added to the PRD instead
- `bsdd-ship`: PR size warning — warns at 600–900 changed lines (vs `main`), stronger warning above 900 suggesting a return to `/bsdd-prd`; flow is never blocked

---

## [0.0.2] - 2026-06-05

### Added
- Plugin system: `.bsdd-plugins.yml` at the target project root declares external tool plugins per sub-agent
- `.skills/plugins/sonar.md` — SonarQube static analysis plugin (extracted from `sonar-analysis.md`)
- `.skills/plugins/xlint-removal.md` — Java `@Deprecated(forRemoval=true)` compiler warnings via `-Xlint:removal`; supports Gradle (init script) and Maven
- `.skills/plugins/trivy.md` — CVE scan on direct and transitive dependencies via Docker
- `enabled` values per plugin: `auto` (opt-in by detection), `true` (always run), `false` (never run)
- Backward compatible: absent `.bsdd-plugins.yml` defaults all plugins to `auto`

### Changed
- `reviewer.md` step 7: replaced hardcoded SonarQube check with dynamic plugin loop
- Documentation updated in `CLAUDE.md`, `README.md`, `docs/workflow.md`, `docs/workflow.pt-br.md`: "Optional integrations (experimental)" → "Plugins (experimental)"

### Removed
- `.skills/sonar-analysis.md` — content split into individual plugin files under `.skills/plugins/`

---

## [0.0.1] - 2026-06-04

### Added
- Experimental SonarQube static analysis integration in the `reviewer` agent
- Opt-in via `sonar-project.properties` at the project root (sentinel file pattern)
- Auto-generated token stored in `.bsdd-sonar-token` (gitignored)
- Docker-only setup: `bsdd-sonarqube` server container + ephemeral `sonarsource/sonar-scanner-cli` scanner
- Severity mapping: BLOCKER/CRITICAL → `BLOCKER`, MAJOR BUG/VULNERABILITY → `BLOCKER`, MAJOR CODE_SMELL → `WARNING`, MINOR/INFO → `SUGGESTION`
- `bsdd-ship` command updated to reference SonarQube opt-in

---

## [0.0.0] - 2026-06-03

### Added
- Initial behavioral-sdd workflow template
- Core commands: `bsdd-prd`, `bsdd-plan`, `bsdd-implement`, `bsdd-ship`, `bsdd-optimize`, `bsdd-sync-patterns`
- Sub-agents: `feature-implementer`, `test-implementer`, `reviewer`, `optimizer`, `git-agent`
- Skills: `caveman`, `karpathy-guidelines`, `code-style`, `diff-review`, `grill-me`, `plan-first-development`, `edge-case-generation`, `error-handling`, `testing-strategy`, `benchmark-execution`, `database-seeding`, `postgres-explain-analyze`, `optimization-reporting`
- Workflow documentation in English (`docs/workflow.md`) and Portuguese BR (`docs/workflow.pt-br.md`)

[Unreleased]: https://github.com/ddmfuhrmann/behavioral-sdd/compare/v0.0.5...HEAD
[0.0.5]: https://github.com/ddmfuhrmann/behavioral-sdd/compare/v0.0.4...v0.0.5
[0.0.4]: https://github.com/ddmfuhrmann/behavioral-sdd/compare/v0.0.3...v0.0.4
[0.0.3]: https://github.com/ddmfuhrmann/behavioral-sdd/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/ddmfuhrmann/behavioral-sdd/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/ddmfuhrmann/behavioral-sdd/compare/v0.0.0...v0.0.1
[0.0.0]: https://github.com/ddmfuhrmann/behavioral-sdd/releases/tag/v0.0.0
