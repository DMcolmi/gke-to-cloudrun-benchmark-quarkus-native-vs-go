# GKE to Cloud Run: Quarkus Native vs Go Benchmark

> **A performance and cost-optimization lab** comparing GKE (Standard JVM) with Cloud Run (Quarkus Native & Go).  
> Designed to demonstrate how to slash cold-start times and infrastructure costs during a serverless migration.

---

## The Story

This project tells the story of a cloud-native evolution:

```
Phase 1: "We're on Kubernetes"
  └─ Quarkus on JVM, deployed to GKE
  └─ Comfortable, but expensive idle nodes and slow cold-starts

Phase 2: "Let's go serverless and native"
  └─ Same Quarkus code, compiled to GraalVM Native Image
  └─ Deployed to Cloud Run with scale-to-zero

Phase 3: "What if we rewrote the hot path in Go?"
  └─ Pure Go implementation on Cloud Run
  └─ Near-instant startup, minimal image, lowest cost
```

Each phase implements the **same API** (Device Registry) so metrics are directly comparable.

---

## Project Structure

```
├── 1-gke-quarkus-jvm/          # Phase 1: Baseline — Quarkus JVM on GKE
├── 2-cloudrun-quarkus-native/  # Phase 2: Optimization — Quarkus Native on Cloud Run
├── 3-cloudrun-golang/          # Phase 3: Alternative — Go on Cloud Run
├── benchmarks/                 # k6 load tests & cold-start measurement
├── Makefile                    # Build, deploy, and benchmark 
```

---


## Quick Start

### Prerequisites

- Docker
- Google Cloud SDK (`gcloud`)
- A GCP project with Artifact Registry, GKE, and Cloud Run enabled
- [k6](https://k6.io/) (for load testing)

### Environment Setup

```bash
export PROJECT_ID="your-gcp-project"
export REGION="europe-west8"
export AR_REPO="benchmark-lab"
```

---

## API Reference

All three services expose the same endpoints:

| Method | Endpoint | Description | Response |
|--------|----------|-------------|----------|
| POST | `/api/devices` | Create a new device | 201 Created |
| GET | `/api/devices/{id}` | Get device by ID | 200 OK / 404 Not Found |
| GET | `/api/devices?status={status}` | List devices by status | 200 OK (array) |

**Request body (POST):**
```json
{
  "name": "sensor-01",
  "status": "ACTIVE"
}
```

**Response:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "sensor-01",
  "status": "ACTIVE",
  "createdAt": "2026-04-30T10:15:30Z"
}
```

---