# Skill: SonarQube Analysis (experimental)

## Purpose
Run SonarQube static analysis on the project and return severity-labeled findings mapped to the reviewer format. Only active when `sonar-project.properties` exists at the project root. Requires only Docker — no manual token setup or extra CLI installation.

> **Experimental.** This integration works well in practice but has not been widely validated across stacks and CI configurations. Treat findings as supplementary signal, not a hard gate.

## Docker resources

| Resource | Name |
|---|---|
| Network | `bsdd-sonar-net` |
| Server container | `bsdd-sonarqube` |
| Scanner container | ephemeral (`sonarsource/sonar-scanner-cli`) |

## Token management

The skill auto-generates a SonarQube token on first use and stores it in `.bsdd-sonar-token` at the project root. Subsequent runs read from this file. No manual token setup required.

`.bsdd-sonar-token` must be gitignored — add it if not already present:

```bash
echo ".bsdd-sonar-token" >> .gitignore
```

## Opt-in detection

Check for `sonar-project.properties` in the project root:
- **File absent** → skip this skill entirely. Do not mention Sonar in the review output.
- **File present** → analysis is mandatory. Block review if any Docker step fails.

## Prerequisites (project-side)

The project must have a `sonar-project.properties` at the root. Keep it to **project identity only** — do not hardcode `sonar.host.url` or `sonar.token` here, as those values differ between local and CI environments and would cause CI failures if picked up by a pipeline runner:

```properties
# sonar-project.properties — safe to commit
sonar.projectKey=my-project
sonar.sources=src
sonar.exclusions=**/test/**,**/vendor/**
```

`sonar.host.url` and `sonar.token` are injected by this skill at runtime (local) and by the CI workflow via its own flags or environment variables. No overlap, no conflict.

## Procedure

### 1. Ensure Docker network exists

```bash
docker network inspect bsdd-sonar-net >/dev/null 2>&1 || docker network create bsdd-sonar-net
```

### 2. Ensure SonarQube server is running

Check if the server is already healthy:

```bash
curl -s http://localhost:9000/api/system/status | grep -q '"status":"UP"'
```

If not healthy, start or create the container:

```bash
docker start bsdd-sonarqube 2>/dev/null || \
  docker run -d \
    --name bsdd-sonarqube \
    --network bsdd-sonar-net \
    -p 9000:9000 \
    sonarqube:community
```

Poll until healthy (timeout: 120s, interval: 5s):

```bash
until curl -s http://localhost:9000/api/system/status | grep -q '"status":"UP"'; do
  sleep 5
done
```

If SonarQube does not become healthy within 120s: **abort and block the review** with message:
> `[SONAR BLOCKED] bsdd-sonarqube did not become healthy within 120s. Check: docker logs bsdd-sonarqube`

### 3. Resolve token

```bash
TOKEN_FILE=".bsdd-sonar-token"

if [ -f "$TOKEN_FILE" ]; then
  SONAR_TOKEN=$(cat "$TOKEN_FILE")
else
  # Generate token using default admin credentials (valid on a fresh local instance)
  SONAR_TOKEN=$(curl -s -u admin:admin -X POST \
    "http://localhost:9000/api/user_tokens/generate?name=bsdd-local" \
    | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

  if [ -z "$SONAR_TOKEN" ]; then
    echo "[SONAR BLOCKED] Could not generate token. If the admin password was changed, create a token manually at http://localhost:9000/account/security and save it to .bsdd-sonar-token"
    exit 1
  fi

  echo "$SONAR_TOKEN" > "$TOKEN_FILE"
  echo ".bsdd-sonar-token" >> .gitignore
fi
```

If token generation fails (admin password was changed from the default): block review with instructions to create the token manually at `http://localhost:9000/account/security` and save it to `.bsdd-sonar-token`.

### 4. Run sonar-scanner

Run as an ephemeral container on the same network. The scanner reaches the server via container name (`bsdd-sonarqube:9000`) within the network:

```bash
docker run --rm \
  --network bsdd-sonar-net \
  -v "$(pwd):/usr/src" \
  sonarsource/sonar-scanner-cli \
  -Dsonar.host.url=http://bsdd-sonarqube:9000 \
  -Dsonar.token="${SONAR_TOKEN}"
```

If the command fails (non-zero exit): block review with the scanner output.

### 5. Wait for analysis to complete

Poll the Compute Engine queue until the task for this project completes (timeout: 60s):

```bash
curl -s -u "${SONAR_TOKEN}:" \
  "http://localhost:9000/api/ce/component?component=<projectKey>"
```

Wait until `status` is `SUCCESS`. If `FAILED`: block review with the CE task error message.

### 6. Fetch issues

```bash
curl -s -u "${SONAR_TOKEN}:" \
  "http://localhost:9000/api/issues/search?componentKeys=<projectKey>&resolved=false&ps=500"
```

Filter results to only files present in the current diff. Ignore issues in files not touched by this change.

### 7. Severity mapping

| Sonar severity | Sonar type | → Reviewer severity |
|---|---|---|
| BLOCKER | any | BLOCKER |
| CRITICAL | any | BLOCKER |
| MAJOR | BUG | BLOCKER |
| MAJOR | VULNERABILITY | BLOCKER |
| MAJOR | CODE_SMELL | WARNING |
| MINOR | any | SUGGESTION |
| INFO | any | SUGGESTION |

Security hotspots: include as WARNING regardless of severity.

### 8. Output format

Emit findings in the reviewer's standard format, under a dedicated section:

```
### Sonar Analysis Findings

[BLOCKER] src/foo/Bar.java:42 — Cognitive Complexity of method 'process' is 25 (allowed: 15). (squid:S3776)
[WARNING] src/foo/Bar.java:88 — Remove this unused private field 'cache'. (squid:S1068)
[SUGGESTION] src/foo/Util.java:10 — Rename this local variable to match the regular expression '^[a-z][a-zA-Z0-9]*$'. (squid:S117)
```

If no issues found in the diff scope: emit `Sonar: no issues found in changed files.`
