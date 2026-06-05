# Plugin: Dependency Vulnerability Scan (Trivy)

## Purpose

Scans project dependencies for known CVEs — covers direct and transitive dependencies. SonarQube Community does not include this check.

## Auto-detection

When `enabled: auto`: active if Docker is available (`docker info` exits 0).
When `enabled: true`: always active; fail with `[TRIVY BLOCKED]` if Docker unavailable.

## Procedure

### 1. Run Trivy

```bash
docker run --rm \
  -v "$(pwd):/project" \
  aquasec/trivy:latest fs /project \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --format json \
  --quiet \
  2>/dev/null
```

If Docker is unavailable or the image fails to run: skip silently and emit `Trivy: skipped (Docker unavailable).`

### 2. Parse JSON output

Extract from `.Results[].Vulnerabilities[]`:
- `VulnerabilityID` — CVE ID
- `PkgName` + `InstalledVersion` — affected library
- `Severity` — `HIGH` or `CRITICAL`
- `Title` — short description
- `CVSS.nvd.V3Score` or `CVSS.ghsa.V3Score` — numeric score

Deduplicate by `VulnerabilityID` + `PkgName`.

## Severity mapping

| Trivy severity | → Reviewer severity |
|---|---|
| CRITICAL | BLOCKER |
| HIGH | WARNING |

## Output format

```
### Dependency Vulnerability Scan

[BLOCKER] commons-lang3:3.17.0 — CVE-2025-XXXX Remote code execution via deserialization (CVSS 9.8)
[WARNING]  jackson-databind:2.17.0 — CVE-2024-XXXX Deserialization of untrusted data (CVSS 7.5)
```

If no vulnerabilities: emit `Trivy: no HIGH/CRITICAL vulnerabilities found.`
