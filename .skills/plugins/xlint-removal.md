# Plugin: Compiler Removal Warnings

## Purpose

Detects usage of APIs annotated `@Deprecated(forRemoval=true)` — the JDK flags these natively but standard static analysis tools miss them because they require indexing dependency JARs deeply.

## Scope

Java projects only. Skip for non-Java projects (no `build.gradle.kts`, `build.gradle`, or `pom.xml` at the root).

## Auto-detection

When `enabled: auto`: active if `build.gradle.kts`, `build.gradle`, or `pom.xml` exists at the project root.
When `enabled: true`: always active; emit skip message if no Java build file found.

## Procedure

### 1. Create temporary Gradle init script

```bash
INIT_SCRIPT=$(mktemp /tmp/xlint-removal-XXXXXX.gradle.kts)
cat > "$INIT_SCRIPT" << 'GRADLE'
allprojects {
    tasks.withType<JavaCompile> {
        options.compilerArgs.addAll(listOf("-Xlint:removal"))
    }
}
GRADLE
```

**Maven variant:** if only `pom.xml` is present (no Gradle files), run:

```bash
mvn compile -q -Dmaven.compiler.showWarnings=true -Dmaven.compiler.verbose=false 2>&1 \
  | grep -E "warning:.*\[removal\]" \
  | sort -u
```

### 2. Compile with removal warnings enabled

```bash
./gradlew compileJava --rerun --init-script "$INIT_SCRIPT" 2>&1 \
  | grep -E "warning:.*\[removal\]" \
  | sort -u
rm -f "$INIT_SCRIPT"
```

Do not fail the review if compilation itself fails — only report `[removal]` lines.

## Severity mapping

All `[removal]` warnings → **[BLOCKER]**: APIs marked for removal will break on the next major version upgrade.

## Output format

```
### Compiler Removal Warnings

[BLOCKER] sales/application/usecase/ListCommissionsUseCase.java:41 — where(Specification<T>) in JpaSpecificationExecutor has been deprecated and marked for removal
```

If no warnings: emit `Compiler: no removal warnings found.`
