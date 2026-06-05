# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

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

[Unreleased]: https://github.com/ddmfuhrmann/behavioral-sdd/compare/v0.0.2...HEAD
[0.0.2]: https://github.com/ddmfuhrmann/behavioral-sdd/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/ddmfuhrmann/behavioral-sdd/compare/v0.0.0...v0.0.1
[0.0.0]: https://github.com/ddmfuhrmann/behavioral-sdd/releases/tag/v0.0.0
