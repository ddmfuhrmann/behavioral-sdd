# Plugin: Compiler Removal Warnings

## Purpose

Detects usage of APIs annotated `@Deprecated(forRemoval=true)` — the JDK flags these
natively (`-Xlint:removal`) but standard static analysis tools miss them because they
require indexing dependency JARs deeply.

The procedure is fully scripted in [`xlint-removal.sh`](xlint-removal.sh). This file is
the contract, not a procedure to execute by hand.

## Scope & auto-detection

Java projects only.

- `enabled: auto` → active if `build.gradle.kts`, `build.gradle`, or `pom.xml` exists
  at the project root.
- `enabled: true` → always active.

`xlint-removal.sh` self-guards: with no Java build file it prints
`Compiler: skipped (no Java build file).` and exits 0.

## Prerequisites

- A Gradle (`build.gradle.kts` / `build.gradle`) or Maven (`pom.xml`) build at the root.
- The build must be able to `compileJava` (Gradle) / `compile` (Maven). **Tests are not
  run** — `compileJava` is the minimal target for detecting deprecation-for-removal.

## Invocation

```bash
.skills/plugins/xlint-removal.sh
```

Gradle path compiles with `-Xlint:removal` injected via a temporary init script and
`--rerun` (incremental compile would skip unchanged files and miss their warnings).
Maven path uses `mvn compile` with compiler warnings enabled.

- **stdout:** `[BLOCKER]` findings (see below).
- **exit 0:** always — a failing compile is **not** a review failure; only `[removal]`
  lines are reported.

## Severity mapping

All `[removal]` warnings → **BLOCKER**: APIs marked for removal break on the next major
version upgrade.

## Output format

```
### Compiler Removal Warnings

[BLOCKER] sales/application/usecase/ListCommissionsUseCase.java:41 — where(Specification<T>) in JpaSpecificationExecutor has been deprecated and marked for removal
```

No warnings → `Compiler: no removal warnings found.`
