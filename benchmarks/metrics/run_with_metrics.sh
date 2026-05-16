#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# run_with_metrics.sh — Run a k6 stress test and collect GCP Cloud Monitoring
# metrics for the target Cloud Run service.
#
# Usage:
#   ./benchmarks/metrics/run_with_metrics.sh <service-name>
#
# Examples:
#   PROJECT_ID=my-project ./run_with_metrics.sh device-api-go
#   PROJECT_ID=my-project ./run_with_metrics.sh device-api-native
#   PROJECT_ID=my-project ./run_with_metrics.sh device-api-jvm
#   PROJECT_ID=my-project ./run_with_metrics.sh device-api-spring-jvm
#
# What it does:
#   1. Records START_TIME (UTC, before k6 runs)
#   2. Runs benchmarks/k6/stress_test.sh — saves the HTML k6 report as usual
#   3. Waits 90s for Cloud Monitoring data ingestion (~60s native delay + buffer)
#   4. Records END_TIME and calls collect_metrics.py
#   5. JSON result saved to benchmarks/metrics/results/<service>_<start>.json
#
# After running all services, compare them:
#   python benchmarks/metrics/compare_services.py benchmarks/metrics/results/*.json
#
# Requirements:
#   - PROJECT_ID env var set
#   - gcloud auth application-default login (for Python metrics script)
#   - k6 installed and on PATH
#   - Python 3.11+ with: pip install -r benchmarks/metrics/requirements.txt
# =============================================================================

SERVICE="${1:?Usage: $0 <service-name>}"

: "${PROJECT_ID:?Set PROJECT_ID environment variable}"
: "${REGION:=europe-west8}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K6_SCRIPT="${SCRIPT_DIR}/../k6/stress_test.sh"
COLLECT_SCRIPT="${SCRIPT_DIR}/collect_metrics.py"
RESULTS_DIR="${SCRIPT_DIR}/results"

if [ ! -f "${K6_SCRIPT}" ]; then
  echo "ERROR: k6 wrapper not found at ${K6_SCRIPT}"
  exit 1
fi

if [ ! -f "${COLLECT_SCRIPT}" ]; then
  echo "ERROR: collect_metrics.py not found at ${COLLECT_SCRIPT}"
  exit 1
fi

mkdir -p "${RESULTS_DIR}"

# ---------------------------------------------------------------------------
# Step 1 — Record start time before k6 runs
# Cloud Monitoring buckets data into 60s windows; starting the window slightly
# before the test ensures the first minute of load is captured.
# ---------------------------------------------------------------------------
START_TIME=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
echo "╔══════════════════════════════════════════════════════════╗"
echo "  Service   : ${SERVICE}"
echo "  Region    : ${REGION}"
echo "  Project   : ${PROJECT_ID}"
echo "  Start     : ${START_TIME}"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ---------------------------------------------------------------------------
# Step 2 — Run k6 stress test
# stress_test.sh resolves the Cloud Run URL via gcloud and saves an HTML report
# to benchmarks/k6/stress_report.html (overwriting).
# ---------------------------------------------------------------------------
echo "==> Running k6 stress test..."
bash "${K6_SCRIPT}" "${SERVICE}"

END_TIME=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
echo ""
echo "==> k6 finished at ${END_TIME}"

# ---------------------------------------------------------------------------
# Step 3 — Wait for Cloud Monitoring ingestion
# Cloud Monitoring has up to 60s ingest delay. We wait 90s to ensure all
# data points from the test window are visible before querying.
# ---------------------------------------------------------------------------
echo "==> Waiting 90s for Cloud Monitoring data ingestion..."
sleep 90

# ---------------------------------------------------------------------------
# Step 4 — Collect metrics
# ---------------------------------------------------------------------------
echo "==> Collecting GCP metrics (${START_TIME} → ${END_TIME})..."
python3 "${COLLECT_SCRIPT}" \
  --project "${PROJECT_ID}" \
  --service "${SERVICE}" \
  --region  "${REGION}" \
  --start   "${START_TIME}" \
  --end     "${END_TIME}" \
  --out-dir "${RESULTS_DIR}"

echo ""
echo "Done. To compare all services:"
echo "  python3 ${SCRIPT_DIR}/compare_services.py ${RESULTS_DIR}/*.json"
