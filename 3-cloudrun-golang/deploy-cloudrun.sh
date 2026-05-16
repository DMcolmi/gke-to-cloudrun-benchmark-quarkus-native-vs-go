#!/usr/bin/env bash
set -euo pipefail

# Configuration — set these environment variables before running
: "${PROJECT_ID:?Set PROJECT_ID environment variable}"
: "${REGION:=europe-west8}"

SERVICE_NAME="device-api-go"
IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/benchmark-lab/${SERVICE_NAME}:latest"

echo "==> Building Go image..."
docker build --platform linux/amd64 -t "${IMAGE}" .

echo "==> Pushing to Artifact Registry..."
docker push "${IMAGE}"

echo "==> Deploying to Cloud Run..."
gcloud run deploy "${SERVICE_NAME}" \
  --image="${IMAGE}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --platform=managed \
  --port=8080 \
  --memory=256Mi \
  --cpu=1 \
  --min-instances=0 \
  --max-instances=1 \
  --timeout=60s \  
  --allow-unauthenticated

echo "==> Done! Service URL:"
gcloud run services describe "${SERVICE_NAME}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="value(status.url)"
