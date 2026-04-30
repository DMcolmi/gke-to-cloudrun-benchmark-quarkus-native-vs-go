# GKE to Cloud Run: Quarkus Native vs Go Benchmark

> **A performance and cost-optimization lab** comparing GKE (Standard JVM) with Cloud Run (Quarkus Native & Go).  
> Designed to demonstrate how to slash cold-start times and infrastructure costs during a serverless migration.

---

## The Migration Story

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