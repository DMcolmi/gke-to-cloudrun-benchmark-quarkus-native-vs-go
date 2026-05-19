# GKE to Cloud Run: Spring Boot, Quarkus JVM, Quarkus Native & Go Benchmark

> **A performance and cost-optimization lab** comparing four Java/Go runtimes on Cloud Run (scale-to-zero).  
> Cold starts, CPU efficiency, memory footprint, and cost — measured with real Cloud Monitoring data.

Full write-up: [link to article]

---

## The Story

This project tells the story of a cloud-native evolution — and three benchmark results that went against conventional wisdom:

```
Phase 1a: "We're on Kubernetes — Spring Boot"
  └─ Spring Boot on JVM, deployed to GKE
  └─ Familiar ecosystem, but 5s+ cold starts and expensive idle nodes

Phase 1b: "We're on Kubernetes — Quarkus"
  └─ Quarkus on JVM, deployed to GKE
  └─ Faster startup than Spring, same JVM constraints

Phase 2: "Let's go serverless and native"
  └─ Same Quarkus code, compiled to GraalVM Native Image
  └─ Deployed to Cloud Run with scale-to-zero
  └─ Cold start wins — but CPU efficiency surprises

Phase 3: "What if we rewrote the hot path in Go?"
  └─ Pure Go implementation on Cloud Run
  └─ 358ms cold start, 10x less memory than JVM, lowest cost
```

Each implementation exposes the **same Device Registry API** so metrics are directly comparable.

---

## Project Structure

```
├── 1-gke-quarkus-jvm/          # Quarkus JVM — GKE baseline + Cloud Run cold-start reference
│   ├── k8s/                    # Kubernetes manifests (Deployment, Service)
│   └── Dockerfile.jvm
├── 1b-gke-spring-jvm/          # Spring Boot 3 JVM — Cloud Run cold-start reference
│   ├── k8s/                    # Kubernetes manifests
│   └── Dockerfile.jvm
├── 2-cloudrun-quarkus-native/  # Quarkus Native (GraalVM AOT) — Cloud Run
│   └── Dockerfile.native
├── 3-cloudrun-golang/          # Go 1.22 — Cloud Run
│   └── Dockerfile
├── benchmarks/
│   ├── cold-start/             # Manual cold-start probes (curl + timing scripts)
│   ├── k6/                     # k6 stress test scripts + HTML reports
│   └── metrics/                # Python Cloud Monitoring collector + JSON results
├── Makefile                    # Build, push, and deploy all services
└── Cost Estimate Summary.csv   # GKE vs Cloud Run cost breakdown
```

---

## Hardware Configuration

All Cloud Run services are deployed under identical constraints to ensure a fair comparison:

| Parameter | Value |
|-----------|-------|
| CPU | 1 vCPU |
| Memory | 256 Mi |
| Min instances | 0 (scale-to-zero) |
| Max instances | 1 |
| CPU allocation | Only during request processing |
| Region | `europe-west8` (Milan) |

The 256Mi limit is intentionally tight — it's the tier where the JVM is genuinely uncomfortable, and it represents the kind of constraint common in cost-optimized Cloud Run deployments.

JVM services are tuned with: `-XX:MaxRAMPercentage=75 -XX:+UseSerialGC -XX:ActiveProcessorCount=1`

> **Architectural note:** Cloud Run sits behind a managed L7 reverse proxy that adds ~1–3ms of overhead equally to all four services. This overhead does not affect relative comparisons, but makes absolute latency numbers incomparable to bare GKE.

---

## Image Sizes

| Service | Image Size |
|---------|-----------|
| Spring Boot JVM | **92 MB** |
| Quarkus JVM | **90.1 MB** |
| Quarkus Native | **26.7 MB** |
| Go | **2.33 MB** |

Go ships as a single statically-linked binary in a `scratch` container. JVM images carry the full JRE. Native has no JRE but the compiled binary includes a subset of the GraalVM runtime.

---

## Benchmark Results

### Cold Start (TTFB − TLS handshake)

*Average of 7 guaranteed from-zero measurements per service.*

| Service | App startup (logged) | Container overhead | Total cold start | vs Spring JVM |
|---------|---------------------|--------------------|-----------------|---------------|
| Spring Boot JVM | 4,214 ms | ~959 ms | **5,173 ms** | 1x |
| Quarkus JVM | 1,880 ms | ~1,430 ms | **3,310 ms** | 1.56x faster |
| Quarkus Native | 675 ms | ~430 ms | **1,105 ms** | 4.68x faster |
| Go | 0.6 ms | ~357 ms | **358 ms** | 14.5x faster |

For Go, essentially the entire cold start (358ms) is Cloud Run infrastructure overhead — image pull, process spawn, network wiring. The application itself is ready in under 1ms.

### CPU Utilization at Steady State (~798 req/s)

*200 virtual users, `sleep(0.1)` per iteration. Cloud Monitoring 60s-interval average.*

| Service | CPU Utilization |
|---------|----------------|
| Spring Boot JVM | 43–44% |
| Quarkus JVM | 45–47% |
| **Quarkus Native** | **67–70%** ← higher than JVM |
| Go | 38–43% |

### Server-side Mean Latency at Steady State

*`run.googleapis.com/request_latencies`, container-side only (excludes L7 proxy overhead).*

| Service | Mean Latency |
|---------|-------------|
| Go | 0.79–1.02 ms |
| Spring Boot JVM | 1.0–1.9 ms |
| Quarkus JVM | 1.3–1.6 ms |
| **Quarkus Native** | **1.6–2.4 ms** ← slowest Java option |

### Memory Utilization

| Service | Under load (~798 req/s) | After load (idle) |
|---------|------------------------|------------------|
| Spring Boot JVM | 67–74% | ~74% (heap retained) |
| Quarkus JVM | 62–67% | ~70% (heap retained) |
| Quarkus Native | 28–37% | ~27% (releases) |
| Go | 7.4–7.5% | ~7.5% (barely moves) |

On 256Mi, Spring JVM peaks at ~190Mi. Go peaks at ~19Mi — a **10x difference**.

---

## Key Findings

Three results that contradict the common narrative:

**1. Quarkus Native uses ~54% more CPU than the JVM at steady state.**  
GraalVM AOT-compiles everything without runtime profiling data. After warmup, HotSpot's JIT has optimized the hot framework paths (HTTP parsing, JSON serialization, CDI proxies) into hardware-specific machine code. Native cannot do this adaptive optimization.

**2. Quarkus Native has higher latency than Quarkus JVM under sustained load.**  
Same codebase, same framework — the JIT-compiled variant responds ~33% faster. Native's advantages are concentrated at startup; its disadvantages emerge under sustained load.

**3. The memory difference between Go and Java isn't a rounding error — it's a different category.**  
Go's runtime doesn't preallocate a heap sized for what it *might* need. It could run this workload on a 64Mi Cloud Run tier. Spring JVM at 256Mi is already tight.

---

## Quick Start

### Prerequisites

- Docker
- Google Cloud SDK (`gcloud`)
- A GCP project with Artifact Registry, GKE, and Cloud Run enabled
- [k6](https://k6.io/) (for load testing)
- Python 3 + `pip install -r benchmarks/metrics/requirements.txt` (for Cloud Monitoring collection)

### Environment Setup

```bash
export PROJECT_ID="your-gcp-project"
export REGION="europe-west8"
export AR_REPO="benchmark-lab"
```

### Build & Push All Images

```bash
make build-all push-all PROJECT_ID=${PROJECT_ID}
```

Individual targets: `build-jvm`, `build-spring-jvm`, `build-native`, `build-go`

### Deploy

```bash
# Cloud Run — Quarkus JVM (cold-start reference)
make deploy-quarkus-jvm-cloudrun PROJECT_ID=${PROJECT_ID}

# Cloud Run — Spring Boot JVM (cold-start reference)
make deploy-spring-cloudrun PROJECT_ID=${PROJECT_ID}

# Cloud Run — Quarkus Native
make deploy-native PROJECT_ID=${PROJECT_ID}

# Cloud Run — Go
make deploy-go PROJECT_ID=${PROJECT_ID}

# GKE — Quarkus JVM (baseline)
make deploy-gke PROJECT_ID=${PROJECT_ID}
```

---

## Running Benchmarks

### Cold Start Measurement

```bash
# Single probe for a given service
cd benchmarks/cold-start
./cold_start_one.sh device-api-spring-jvm
./cold_start_one.sh device-api-jvm
./cold_start_one.sh device-api-native
./cold_start_one.sh device-api-go
```

Each probe fires a `POST /api/devices` after verifying the service has 0 running instances, and reports `TTFB − TLS handshake` as the application boot time.

### Load Test (k6)

```bash
cd benchmarks/k6
BASE_URL=https://<your-service-url> k6 run stress_test.js
# or use the wrapper
./stress_test.sh <service-name>
```

The test runs 200 VUs with `sleep(0.1)`, producing ~798 req/s. It generates an HTML report in `benchmarks/k6/`.

### Cloud Monitoring Metrics Collection

```bash
cd benchmarks/metrics
python collect_metrics.py   # fetches CPU, memory, latency from Cloud Monitoring
python compare_services.py  # generates side-by-side comparison from collected JSON
```

Raw results are stored in `benchmarks/metrics/results/`.

---

## API Reference

All four services expose the same endpoints:

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

Storage is in-memory (`ConcurrentHashMap`) — no database dependency, isolating compute from I/O.

---