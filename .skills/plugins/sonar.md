# Plugin: Sonar Analysis

## Purpose

Run SonarQube static analysis and return severity-labeled findings in reviewer
format. Requires only Docker — no manual token setup or extra CLI installation.

> **Experimental.** Works well in practice but is not widely validated across stacks
> and CI configurations. Treat findings as supplementary signal, not a hard gate.

The procedure is fully scripted in [`sonar.sh`](sonar.sh) — the orchestrator runs the
script and consumes its stdout. This file is the contract, not a procedure to execute
by hand.

## Auto-detection

- `enabled: auto` → active only if `sonar-project.properties` exists at the project root.
- `enabled: true` → always active.

`sonar.sh` self-guards: if `sonar-project.properties` is missing it prints
`Sonar: skipped (no sonar-project.properties).` and exits 0.

## Prerequisites

- **Docker** running, and **`jq`** on PATH.
- A `sonar-project.properties` at the root, kept to **project identity only** — do not
  hardcode `sonar.host.url` or `sonar.token` (they differ between local and CI and
  would break a pipeline runner). The script injects host/token at runtime.

  ```properties
  # sonar-project.properties — safe to commit
  sonar.projectKey=my-project
  sonar.sources=src
  sonar.exclusions=**/test/**,**/vendor/**
  ```

- The script auto-generates a token on first use and stores it in `.bsdd-sonar-token`
  (gitignored, added automatically if missing).

## Prepare step (compiled projects)

The Java sensor needs **compiled bytecode** (`sonar.java.binaries`) and the **dependency
classpath** (`sonar.java.libraries`) — and a non-matching `libraries` glob is a hard
error. Producing those is build-system specific, so the script does not bake it in; it
runs an optional **prepare command**, resolved in precedence order:

1. `--prepare "<cmd>"` passed by the caller (the orchestrator infers it when the project
   declares none — see `/bsdd-ship`).
2. a `# bsdd.sonar.prepare=<cmd>` line in `sonar-project.properties`.
3. none → skipped (non-compiled projects need nothing).

The project still owns the artifacts the command relies on — e.g. a Gradle task that
stages the dependency jars, plus the matching `sonar.java.binaries` / `sonar.java.libraries`
paths in `sonar-project.properties`. Example (Gradle):

```kotlin
// build.gradle.kts
tasks.register<Copy>("sonarLibs") {
    from(configurations.compileClasspath, configurations.testCompileClasspath)
    into(layout.buildDirectory.dir("sonar-libs"))
    include("*.jar")
}
```

```properties
# sonar-project.properties
sonar.java.binaries=build/classes/java/main
sonar.java.test.binaries=build/classes/java/test
sonar.java.libraries=build/sonar-libs/*.jar
# bsdd.sonar.prepare=./gradlew --quiet classes testClasses sonarLibs
```

## Invocation

```bash
.skills/plugins/sonar.sh [--prepare "<cmd>"] <changed_file>...
```

Pass the list of files in the diff. The script filters findings to those files; with
no arguments it reports all issues. The optional `--prepare` runs before the scanner.
Server lifecycle (network, container, health poll), token, scanner run, CE-queue wait,
issue fetch, severity mapping, and diff filtering all happen inside the script.

- **stdout:** reviewer-format findings (see below).
- **exit 0:** ran (with or without findings) or skipped.
- **exit ≠ 0:** blocked — stdout carries a `[SONAR BLOCKED] …` reason (missing
  projectKey, server not healthy in 120s, token failure, scanner failure, CE failure).

## Severity mapping

| Sonar severity | Sonar type | → Reviewer |
|---|---|---|
| BLOCKER | any | BLOCKER |
| CRITICAL | any | BLOCKER |
| MAJOR | BUG / VULNERABILITY | BLOCKER |
| MAJOR | CODE_SMELL | WARNING |
| MINOR / INFO | any | SUGGESTION |

## Output format

```
### Sonar Analysis Findings

[BLOCKER] src/foo/Bar.java:42 — Cognitive Complexity of method 'process' is 25 (allowed: 15). (squid:S3776)
[WARNING] src/foo/Bar.java:88 — Remove this unused private field 'cache'. (squid:S1068)
[SUGGESTION] src/foo/Util.java:10 — Rename this local variable to match '^[a-z][a-zA-Z0-9]*$'. (squid:S117)
```

No issues in scope → `Sonar: no issues found in changed files.`
