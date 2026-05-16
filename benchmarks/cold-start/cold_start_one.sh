#!/usr/bin/env bash
# =============================================================================
# Cold-Start Manual Probe — single service, single shot
#
# Usage:
#   ./cold_start_one.sh <service-name>
#
# Examples:
#   ./cold_start_one.sh device-api-jvm
#   ./cold_start_one.sh device-api-native
#   ./cold_start_one.sh device-api-go
#   ./cold_start_one.sh device-api-spring-jvm
#
# What it does:
#      Fires a real POST /api/devices request and measures:
#      TTFB - TLS handshake = application boot time (cold start)
#      The POST goes through the full stack: controller → service → in-memory
#      repository (ConcurrentHashMap, no DB). HTTP 201 = success.
#
# Run this once per service, once per hour (or whenever you want a data point).
# Collect the output and assemble results manually in Google Sheets.
#
# Requires:
#   PROJECT_ID and REGION env vars (or edit defaults below).
# =============================================================================
set -euo pipefail

SERVICE="${1:?Usage: $0 <service-name>}"

: "${PROJECT_ID:?Set PROJECT_ID environment variable}"
: "${REGION:=europe-west8}"

# ---------------------------------------------------------------------------
# Step 1 — Get service URL
# ---------------------------------------------------------------------------
URL=$(gcloud run services describe "${SERVICE}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="value(status.url)")

if [ -z "${URL}" ]; then
  echo "ERROR: service '${SERVICE}' not found in region ${REGION}"
  exit 1
fi

echo "Service : ${SERVICE}"
echo "URL     : ${URL}"
echo "Time    : $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo ""

# ---------------------------------------------------------------------------
# Step 2 — Probe: real POST /api/devices, measure cold start
#
# Metrics (all cumulative from request start, in seconds):
#   time_namelookup   — DNS resolution
#   time_connect      — TCP connect
#   time_appconnect   — TLS handshake complete
#   time_starttransfer — TTFB (first byte of response body)
#   time_total        — full response received
#
# cold_start = time_starttransfer - time_appconnect
#   → removes DNS + TCP + TLS overhead; isolates app boot latency
# ---------------------------------------------------------------------------
echo "► Firing cold-start probe: POST ${URL}/api/devices"

TIME_DATA=$(curl -s -o /tmp/cold_start_response.json \
  -w "%{time_namelookup}|%{time_connect}|%{time_appconnect}|%{time_starttransfer}|%{time_total}|%{http_code}" \
  -X POST "${URL}/api/devices" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"cold-start-probe-$(date +%s)\",\"status\":\"ACTIVE\"}" \
  --max-time 60)

HTTP_CODE=$(echo "${TIME_DATA}" | cut -d'|' -f6)
T_DNS=$(echo "${TIME_DATA}"  | cut -d'|' -f1)
T_TCP=$(echo "${TIME_DATA}"  | cut -d'|' -f2)
T_TLS=$(echo "${TIME_DATA}"  | cut -d'|' -f3)
T_TTFB=$(echo "${TIME_DATA}" | cut -d'|' -f4)
T_TOTAL=$(echo "${TIME_DATA}" | cut -d'|' -f5)

COLD_START_MS=$(python3 -c "print(round(($T_TTFB - $T_TLS) * 1000))")
TLS_MS=$(python3       -c "print(round(($T_TLS  - $T_TCP) * 1000))")
DNS_MS=$(python3       -c "print(round($T_DNS * 1000))")
TOTAL_MS=$(python3     -c "print(round($T_TOTAL * 1000))")

echo ""
echo "┌─────────────────────────────────────────────┐"
printf "│  %-20s  %8s  %8s        │\n" "Metric" "ms" ""
echo "├─────────────────────────────────────────────┤"
printf "│  %-20s  %8d ms                   │\n" "DNS lookup"        "${DNS_MS}"
printf "│  %-20s  %8d ms                   │\n" "TLS handshake"     "${TLS_MS}"
printf "│  %-20s  %8d ms  ← cold start     │\n" "App boot (TTFB-TLS)" "${COLD_START_MS}"
printf "│  %-20s  %8d ms                   │\n" "Total request"     "${TOTAL_MS}"
printf "│  %-20s  %8s                      │\n" "HTTP status"       "${HTTP_CODE}"
echo "└─────────────────────────────────────────────┘"

if [ "${HTTP_CODE}" != "201" ]; then
  echo ""
  echo "⚠️  WARNING: expected HTTP 201, got ${HTTP_CODE}"
  echo "   Response body:"
  cat /tmp/cold_start_response.json
  exit 1
fi

echo ""
echo "✓  Result to record in spreadsheet:"
echo "   $(date -u '+%Y-%m-%dT%H:%M:%SZ')  ${SERVICE}  ${COLD_START_MS} ms"
