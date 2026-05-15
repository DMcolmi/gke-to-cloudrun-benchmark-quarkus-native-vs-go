#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# k6 Stress Test Wrapper
#
# Resolves Cloud Run service URL automatically using gcloud.
# Usage: ./benchmarks/k6/stress_test.sh <service-name>
# =============================================================================

SERVICE="${1:?Usage: $0 <service-name>}"

: "${PROJECT_ID:=gke-to-cloudrun-benchmark}"
: "${REGION:=europe-west8}"

# ---------------------------------------------------------------------------
# Step 1 — Get service URL
# ---------------------------------------------------------------------------
echo "--> Fetching URL for service '${SERVICE}'..."
URL=$(gcloud run services describe "${SERVICE}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="value(status.url)" 2>/dev/null || echo "")

if [ -z "${URL}" ]; then
  echo "ERROR: service '${SERVICE}' not found in region ${REGION} (project: ${PROJECT_ID})"
  exit 1
fi

echo "Service : ${SERVICE}"
echo "URL     : ${URL}"
echo "Time    : $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo ""

# ---------------------------------------------------------------------------
# Step 2 — Run k6 stress test
# ---------------------------------------------------------------------------
# Path to the JS script relative to this shell script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JS_SCRIPT="${SCRIPT_DIR}/stress_test.js"

if [ ! -f "${JS_SCRIPT}" ]; then
  echo "ERROR: k6 script not found at ${JS_SCRIPT}"
  exit 1
fi

REPORT_FILE="${SCRIPT_DIR}/stress_report.html"
echo "--> Running k6... (Report will be saved to ${REPORT_FILE})"
k6 run -e BASE_URL="${URL}" -e REPORT_FILE="${REPORT_FILE}" "${JS_SCRIPT}"
