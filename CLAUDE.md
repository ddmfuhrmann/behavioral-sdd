# <Project Name> — CLAUDE.md

<One paragraph describing the project.>

---

## Workflow

```
/bsdd-prd (optional) → /bsdd-plan → /bsdd-implement → /bsdd-ship → [/bsdd-optimize]
```

- No code before a saved plan exists (`.plans/`).
- No optimization without a measured baseline.
- No scope expansion without an explicit note in the plan.

See `docs/workflow.md` for the full guide.

---

## Stack

- **Language:** <language>
- **Framework:** <framework>
- **Database:** <database>
- **Test framework:** <test framework>
- **Build:** <build tool>

---

## Architecture

<Describe your package structure here.>

**Layering rule:** <describe your layering convention>

---

## Critical Domain Constraints

<List your non-negotiable invariants here. These will be enforced by all agents.>

---

## Global Skills (always active)

| Skill | Purpose |
|---|---|
| `.skills/caveman.md` | Ultra-compressed mode — always active by default |
| `.skills/karpathy-guidelines.md` | Coding behavior: think before coding, simplicity first, surgical changes |

---

## Skills

| Skill | Purpose |
|---|---|
| `.skills/code-style.md` | Naming conventions, method size, comments (adapt to your stack) |
| `.skills/error-handling.md` | Exception strategy (adapt to your stack) |
| `.skills/plan-first-development.md` | Plan workflow rules |
| `.skills/diff-review.md` | Review process and severity labeling |
| `.skills/testing-strategy.md` | Which test type to use and when (adapt to your stack) |
| `.skills/edge-case-generation.md` | Systematic edge case discovery |
| `.skills/benchmark-execution.md` | Load testing methodology |
| `.skills/database-seeding.md` | Seeding realistic data for perf tests |
| `.skills/postgres-explain-analyze.md` | Query analysis procedure |
| `.skills/optimization-reporting.md` | Optimization report format |

## Plugins *(experimental)*

Plugins augment sub-agents with external tool analysis. Declare them per sub-agent in `.bsdd-plugins.yml` at your project root:

```yaml
# .bsdd-plugins.yml
plugins:
  reviewer:
    sonar:
      enabled: auto        # auto = only if sonar-project.properties exists
    xlint-removal:
      enabled: auto        # auto = only if Java build file exists
    trivy:
      enabled: auto        # auto = only if Docker is available
```

`enabled` values: `auto` (default — opt-in by detection), `true` (always run), `false` (never run).

If `.bsdd-plugins.yml` is absent, all plugins default to `auto`.

| Plugin | Sub-agent | Purpose | Auto-detection |
|---|---|---|---|
| `sonar` | reviewer | SonarQube static analysis | `sonar-project.properties` present |
| `xlint-removal` | reviewer | `@Deprecated(forRemoval=true)` warnings — Java only | Java build file present |
| `trivy` | reviewer | CVE scan on dependencies | Docker available |

> Plugins for other sub-agents (`implementer`, `ship`, `optimizer`) and per-plugin options (e.g. `severity: MAJOR`) are reserved for future versions.
