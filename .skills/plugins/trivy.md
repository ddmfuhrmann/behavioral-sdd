# Plugin: Dependency Vulnerability Scan (Trivy)

## Purpose

Scans project dependencies for known CVEs — direct and transitive. SonarQube Community
does not include this check.

The procedure is fully scripted in [`trivy.sh`](trivy.sh). This file is the contract,
not a procedure to execute by hand.

## Auto-detection

- `enabled: auto` → active if Docker is available (`docker info` exits 0).
- `enabled: true` → always active.

`trivy.sh` self-guards: with Docker unavailable it prints
`Trivy: skipped (Docker unavailable).` and exits 0.

## Prerequisites

- **Docker** running, and **`jq`** on PATH.

## Invocation

```bash
.skills/plugins/trivy.sh
```

**No diff filter** — a CVE in a dependency is not tied to a changed line; the scan is
over the dependency tree, not the diff. The script runs Trivy (`fs`, `--scanners vuln`,
`--severity HIGH,CRITICAL`, JSON), parses with `jq`, dedupes by `VulnerabilityID` +
`PkgName`, and formats.

- **stdout:** reviewer-format findings (see below).
- **exit 0:** ran or skipped.
- **exit ≠ 0:** blocked (e.g. `[TRIVY BLOCKED] jq not found`).

## Severity mapping

| Trivy severity | → Reviewer |
|---|---|
| CRITICAL | BLOCKER |
| HIGH | WARNING |

## Output format

```
### Dependency Vulnerability Scan

[BLOCKER] commons-lang3:3.17.0 — CVE-2025-XXXX Remote code execution via deserialization (CVSS 9.8)
[WARNING] jackson-databind:2.17.0 — CVE-2024-XXXX Deserialization of untrusted data (CVSS 7.5)
```

No vulnerabilities → `Trivy: no HIGH/CRITICAL vulnerabilities found.`
