#!/usr/bin/env bash
# xlint-removal.sh — compile Java with -Xlint:removal and report APIs marked
# @Deprecated(forRemoval=true). Compiles only (no tests).
#
# Usage:  xlint-removal.sh
# stdout: reviewer-format [BLOCKER] findings
# stderr: build output
# exit:   0 always (a failed compile is not a review failure — only [removal]
#         lines are reported)
set -uo pipefail

if [ -f build.gradle.kts ] || [ -f build.gradle ]; then
  MODE=gradle
elif [ -f pom.xml ]; then
  MODE=maven
else
  echo "Compiler: skipped (no Java build file)."
  exit 0
fi

echo "### Compiler Removal Warnings"
echo

if [ "$MODE" = gradle ]; then
  # --rerun is required: incremental compile skips unchanged files and would
  # miss their warnings.
  INIT_SCRIPT=$(mktemp /tmp/xlint-removal-XXXXXX.gradle.kts)
  cat > "$INIT_SCRIPT" << 'GRADLE'
allprojects {
    tasks.withType<JavaCompile> {
        options.compilerArgs.addAll(listOf("-Xlint:removal"))
    }
}
GRADLE
  warnings=$(./gradlew compileJava --rerun --init-script "$INIT_SCRIPT" 2>&1 \
    | grep -E "warning:.*\[removal\]" | sort -u)
  rm -f "$INIT_SCRIPT"
else
  warnings=$(mvn compile -q -Dmaven.compiler.showWarnings=true -Dmaven.compiler.verbose=false 2>&1 \
    | grep -E "warning:.*\[removal\]" | sort -u)
fi

if [ -z "$warnings" ]; then
  echo "Compiler: no removal warnings found."
  exit 0
fi

# javac line: "path/File.java:41: warning: [removal] <msg>"  ->
#             "[BLOCKER] path/File.java:41 — <msg>"
# Fallback: any unmatched [removal] line is emitted raw, still as [BLOCKER].
echo "$warnings" | sed -E \
  -e 's/^(.+\.java:[0-9]+):[[:space:]]*warning:[[:space:]]*\[removal\][[:space:]]*(.*)$/[BLOCKER] \1 — \2/' \
  -e 't' \
  -e 's/^/[BLOCKER] /'
