#!/usr/bin/env bash
# trivy.sh — scan project dependencies for HIGH/CRITICAL CVEs.
#
# Usage:  trivy.sh
# stdout: reviewer-format findings (no diff filter — CVEs are not tied to lines)
# stderr: progress/logs
# exit:   0 = ran or skipped; non-zero = blocked
set -uo pipefail

# Auto-detection guard: Docker required.
if ! docker info >/dev/null 2>&1; then
  echo "Trivy: skipped (Docker unavailable)."
  exit 0
fi
command -v jq >/dev/null 2>&1 || { echo "[TRIVY BLOCKED] jq not found on PATH."; exit 1; }

echo "### Dependency Vulnerability Scan"
echo

OUT=$(docker run --rm -v "$(pwd):/project" aquasec/trivy:latest fs /project \
  --scanners vuln --severity HIGH,CRITICAL --format json --quiet 2>/dev/null)

if [ -z "$OUT" ]; then
  echo "Trivy: skipped (Docker unavailable)."
  exit 0
fi

# CRITICAL -> BLOCKER, HIGH -> WARNING. Dedupe by VulnerabilityID + PkgName.
findings=$(echo "$OUT" | jq -r '
  [ .Results[]?.Vulnerabilities[]? ]
  | unique_by(.VulnerabilityID + .PkgName)
  | .[]
  | (if .Severity == "CRITICAL" then "BLOCKER" else "WARNING" end) as $sev
  | (.CVSS.nvd.V3Score // .CVSS.ghsa.V3Score // empty) as $score
  | "[\($sev)] \(.PkgName):\(.InstalledVersion) — \(.VulnerabilityID) \(.Title // "")"
    + (if $score then " (CVSS \($score))" else "" end)
')

if [ -n "$findings" ]; then
  echo "$findings"
else
  echo "Trivy: no HIGH/CRITICAL vulnerabilities found."
fi
