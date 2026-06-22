#!/usr/bin/env bash
# sonar.sh — run SonarQube analysis and emit reviewer-format findings.
#
# Usage:  sonar.sh [--prepare "<cmd>"] [changed_file ...]
# stdout: reviewer-format findings (filtered to changed files when any are passed)
# stderr: progress/logs
# exit:   0 = ran or skipped; non-zero = blocked
set -uo pipefail

log() { echo "$@" >&2; }

PROPS="sonar-project.properties"
NET="bsdd-sonar-net"
SERVER="bsdd-sonarqube"
TOKEN_FILE=".bsdd-sonar-token"
HOST="http://localhost:9000"

# Optional prepare step: a project-specific command that produces the inputs the
# Java sensor needs (compiled bytecode for sonar.java.binaries, staged dependency
# jars for sonar.java.libraries). The script stays build-system agnostic — it only
# runs the string it is given. Source, in precedence order:
#   1. --prepare "<cmd>"  — passed by the orchestrator (typically LLM-inferred)
#   2. a `# bsdd.sonar.prepare=<cmd>` line in sonar-project.properties
#   3. none — skipped (e.g. non-compiled projects)
PREPARE=""
if [ "${1:-}" = "--prepare" ]; then
  PREPARE="${2:-}"
  shift 2
fi

# Auto-detection guard.
if [ ! -f "$PROPS" ]; then
  echo "Sonar: skipped (no sonar-project.properties)."
  exit 0
fi
command -v jq >/dev/null 2>&1 || { echo "[SONAR BLOCKED] jq not found on PATH."; exit 1; }

# 0. Resolve projectKey.
PROJECT_KEY=$(grep "^sonar.projectKey" "$PROPS" | cut -d'=' -f2 | tr -d ' ')
if [ -z "$PROJECT_KEY" ]; then
  echo "[SONAR BLOCKED] sonar.projectKey not found in $PROPS"
  exit 1
fi

# 1. Network.
docker network inspect "$NET" >/dev/null 2>&1 || docker network create "$NET" >&2

# 2. Server (start if needed, poll health up to 120s).
if ! curl -s "$HOST/api/system/status" | grep -q '"status":"UP"'; then
  log "Sonar: starting $SERVER ..."
  docker start "$SERVER" >/dev/null 2>&1 || \
    docker run -d --name "$SERVER" --network "$NET" -p 9000:9000 sonarqube:community >/dev/null 2>&1
  deadline=$(( $(date +%s) + 120 ))
  until curl -s "$HOST/api/system/status" | grep -q '"status":"UP"'; do
    if [ "$(date +%s)" -ge "$deadline" ]; then
      echo "[SONAR BLOCKED] $SERVER did not become healthy within 120s. Check: docker logs $SERVER"
      exit 1
    fi
    sleep 5
  done
fi

# 3. Token (read from file, else generate via default admin creds).
if [ -f "$TOKEN_FILE" ]; then
  SONAR_TOKEN=$(cat "$TOKEN_FILE")
else
  SONAR_TOKEN=$(curl -s -u admin:admin -X POST \
    "$HOST/api/user_tokens/generate?name=bsdd-local" \
    | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
  if [ -z "$SONAR_TOKEN" ]; then
    echo "[SONAR BLOCKED] Could not generate token. If the admin password was changed, create a token manually at $HOST/account/security and save it to $TOKEN_FILE"
    exit 1
  fi
  echo "$SONAR_TOKEN" > "$TOKEN_FILE"
  grep -qxF "$TOKEN_FILE" .gitignore 2>/dev/null || echo "$TOKEN_FILE" >> .gitignore
fi

# 3b. Prepare step — compile + stage the dependency classpath so the Java sensor
# finds sonar.java.binaries / sonar.java.libraries. Falls back to the props line
# when no --prepare was passed; skipped entirely when neither is set.
if [ -z "$PREPARE" ]; then
  PREPARE=$(grep "^# *bsdd.sonar.prepare=" "$PROPS" | head -1 | cut -d'=' -f2-)
fi
if [ -n "$PREPARE" ]; then
  log "Sonar: prepare — $PREPARE"
  if ! eval "$PREPARE" >&2; then
    echo "[SONAR BLOCKED] prepare step failed: $PREPARE"
    exit 1
  fi
fi

# 4. Scanner (ephemeral container, reaches server by name on the network).
log "Sonar: running scanner ..."
if ! docker run --rm --network "$NET" -v "$(pwd):/usr/src" \
    sonarsource/sonar-scanner-cli \
    -Dsonar.host.url="http://$SERVER:9000" \
    -Dsonar.token="$SONAR_TOKEN" >&2; then
  echo "[SONAR BLOCKED] sonar-scanner failed. See output above."
  exit 1
fi

# 5. Wait for the Compute Engine task to finish (up to 60s).
deadline=$(( $(date +%s) + 60 ))
while true; do
  status=$(curl -s -u "$SONAR_TOKEN:" "$HOST/api/ce/component?component=$PROJECT_KEY" \
    | jq -r '.current.status // (.queue[0].status) // "PENDING"')
  case "$status" in
    SUCCESS) break ;;
    FAILED|CANCELED) echo "[SONAR BLOCKED] Compute Engine task $status for $PROJECT_KEY"; exit 1 ;;
  esac
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "[SONAR BLOCKED] Compute Engine task did not complete within 60s"
    exit 1
  fi
  sleep 3
done

# 6-8. Fetch issues, map severity, format.
ISSUES=$(curl -s -u "$SONAR_TOKEN:" \
  "$HOST/api/issues/search?componentKeys=$PROJECT_KEY&resolved=false&ps=500")

# Severity: BLOCKER/CRITICAL -> BLOCKER; MAJOR+BUG/VULN -> BLOCKER;
# MAJOR (other) -> WARNING; MINOR/INFO -> SUGGESTION.
findings=$(echo "$ISSUES" | jq -r --arg pk "$PROJECT_KEY" '
  .issues[]?
  | (.component | sub("^" + $pk + ":"; "")) as $file
  | (.line // 0) as $line
  | (if   .severity == "BLOCKER" then "BLOCKER"
     elif .severity == "CRITICAL" then "BLOCKER"
     elif .severity == "MAJOR" and (.type == "BUG" or .type == "VULNERABILITY") then "BLOCKER"
     elif .severity == "MAJOR" then "WARNING"
     else "SUGGESTION" end) as $sev
  | "[\($sev)] \($file):\($line) — \(.message) (\(.rule))"
')

# Filter to changed files when the caller passed any.
if [ "$#" -gt 0 ] && [ -n "$findings" ]; then
  findings=$(echo "$findings" | grep -Ff <(printf '%s\n' "$@") || true)
fi

echo "### Sonar Analysis Findings"
echo
if [ -n "$findings" ]; then
  echo "$findings"
else
  echo "Sonar: no issues found in changed files."
fi
