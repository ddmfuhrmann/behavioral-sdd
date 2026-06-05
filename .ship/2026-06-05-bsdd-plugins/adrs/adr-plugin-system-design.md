# ADR: Plugin System Design

**Date:** 2026-06-05
**Status:** Accepted

## Decision

Plugins are declared per sub-agent in `.bsdd-plugins.yml` (at the target project root) and implemented as self-contained files in `.skills/plugins/<name>.md`. The sub-agent reads the YAML at runtime and iterates declared plugins in order.

## Context

The behavioral-sdd framework previously had a single hardcoded opt-in integration (SonarQube) loaded directly by `reviewer.md` via a sentinel file. As new external tool checks were added (compiler removal warnings, Trivy CVE scan), it became clear a general mechanism was needed.

## Alternatives considered

- **Filesystem scan** — automatically discover plugins by scanning `.skills/plugins/*.md` at runtime. Discarded: requires `Bash` tool access in the reviewer agent, which is not guaranteed across all environments.
- **Flags in `sonar-project.properties`** — extend the existing sentinel file. Discarded: couples the mechanism to SonarQube, not general.
- **Environment variables** — `BSDD_SONAR=true`. Discarded: not project-portable, not version-controlled.

## Tradeoff accepted

Adding a new plugin requires updating two places: the plugin's `.md` file under `.skills/plugins/` and the hardcoded `known plugins` list in `reviewer.md` step 7 (for the fallback when `.bsdd-plugins.yml` is absent). This two-place change has no enforcement mechanism. Accepted as the cost of simplicity — the filesystem scan alternative would be cleaner but requires Bash access.

## Consequences

- Plugin system is opt-in by default (`enabled: auto`) — backward compatible with projects that have no `.bsdd-plugins.yml`
- Each plugin is self-contained (purpose, detection, procedure, severity mapping, output format)
- Extending to other sub-agents (`implementer`, `ship`, `optimizer`) follows the same pattern: declare under the sub-agent key in `.bsdd-plugins.yml`, load in the agent's procedure
