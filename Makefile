# ============================================================================
# GKE to Cloud Run Benchmark Lab — Makefile
# ============================================================================

PROJECT_ID   ?= your-gcp-project
REGION       ?= europe-west1
AR_REPO      ?= benchmark-lab
TAG          ?= latest

REGISTRY     := $(REGION)-docker.pkg.dev/$(PROJECT_ID)/$(AR_REPO)

# ----------------------------------------------------------------------------
# Help (default target)
# ----------------------------------------------------------------------------
.DEFAULT_GOAL := help

.PHONY: help
help: ## Show available targets
	@echo ""
	@echo "GKE-to-CloudRun Benchmark Lab"
	@echo "=============================="
	@echo ""
	@echo "Build targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Environment variables:"
	@echo "  PROJECT_ID   = $(PROJECT_ID)"
	@echo "  REGION       = $(REGION)"
	@echo "  AR_REPO      = $(AR_REPO)"
	@echo "  TAG          = $(TAG)"
	@echo ""

# ----------------------------------------------------------------------------
# Build targets
# ----------------------------------------------------------------------------
.PHONY: build-jvm
build-jvm: ## Build Quarkus JVM Docker image
	docker build --platform linux/amd64 -f 1-gke-quarkus-jvm/Dockerfile.jvm -t $(REGISTRY)/device-api-jvm:$(TAG) 1-gke-quarkus-jvm/

.PHONY: build-spring-jvm
build-spring-jvm: ## Build Spring Boot 4 JVM Docker image
	docker build --platform linux/amd64 -f 1b-gke-spring-jvm/Dockerfile.jvm -t $(REGISTRY)/device-api-spring-jvm:$(TAG) 1b-gke-spring-jvm/

.PHONY: build-native
build-native: ## Build Quarkus Native Docker image (slow, ~5 min)
	docker build --platform linux/amd64 -f 2-cloudrun-quarkus-native/Dockerfile.native -t $(REGISTRY)/device-api-native:$(TAG) 2-cloudrun-quarkus-native/

.PHONY: build-go
build-go: ## Build Go Docker image
	docker build --platform linux/amd64 -f 3-cloudrun-golang/Dockerfile -t $(REGISTRY)/device-api-go:$(TAG) 3-cloudrun-golang/

.PHONY: build-all
build-all: build-jvm build-spring-jvm build-native build-go ## Build all Docker images

# ----------------------------------------------------------------------------
# Push targets
# ----------------------------------------------------------------------------
.PHONY: push-jvm
push-jvm: ## Push Quarkus JVM image to Artifact Registry
	docker push $(REGISTRY)/device-api-jvm:$(TAG)

.PHONY: push-spring-jvm
push-spring-jvm: ## Push Spring Boot JVM image to Artifact Registry
	docker push $(REGISTRY)/device-api-spring-jvm:$(TAG)

.PHONY: push-native
push-native: ## Push Quarkus Native image to Artifact Registry
	docker push $(REGISTRY)/device-api-native:$(TAG)

.PHONY: push-go
push-go: ## Push Go image to Artifact Registry
	docker push $(REGISTRY)/device-api-go:$(TAG)

.PHONY: push-all
push-all: push-jvm push-spring-jvm push-native push-go ## Push all images to Artifact Registry

# ----------------------------------------------------------------------------
# Deploy targets
# ----------------------------------------------------------------------------
.PHONY: deploy-gke
deploy-gke: ## Deploy Quarkus JVM to GKE
	kubectl apply -f 1-gke-quarkus-jvm/k8s/

.PHONY: deploy-spring-gke
deploy-spring-gke: ## Deploy Spring Boot JVM to GKE
	kubectl apply -f 1b-gke-spring-jvm/k8s/

.PHONY: deploy-quarkus-jvm-cloudrun
deploy-quarkus-jvm-cloudrun: ## Deploy Quarkus JVM to Cloud Run
	cd 1-gke-quarkus-jvm && deploy-cloudrun-jvm.sh

.PHONY: deploy-spring-cloudrun
deploy-spring-cloudrun: ## Deploy Spring Boot JVM to Cloud Run
	cd 1b-gke-spring-jvm && ./deploy-cloudrun-spring-jvm.sh

.PHONY: deploy-native
deploy-native: ## Deploy Quarkus Native to Cloud Run
	cd 2-cloudrun-quarkus-native && ./deploy-cloudrun.sh

.PHONY: deploy-go
deploy-go: ## Deploy Go to Cloud Run
	cd 3-cloudrun-golang && ./deploy-cloudrun.sh

.PHONY: deploy-all
deploy-all: deploy-gke deploy-spring-gke deploy-native deploy-go deploy-quarkus-jvm-cloudrun ## Deploy all services

# Image names for local benchmarks (no registry prefix)
LOCAL_JVM    := device-api-jvm:local
LOCAL_SPRING := device-api-spring-jvm:local
LOCAL_NATIVE := device-api-native:local
LOCAL_GO     := device-api-go:local

# Benchmark port and resource limits (mirrors Cloud Run defaults)
BENCH_PORT   ?= 18080
BENCH_CPUS   ?= 1
BENCH_MEM    ?= 256m
BENCH_URL    := http://localhost:$(BENCH_PORT)

# ----------------------------------------------------------------------------
# Benchmark targets
# ----------------------------------------------------------------------------
.PHONY: benchmark-load
benchmark-load: ## Run k6 stress test (requires BASE_URL env var)
	@if [ -z "$(BASE_URL)" ]; then echo "ERROR: Set BASE_URL=https://your-service.run.app"; exit 1; fi
	k6 run -e BASE_URL=$(BASE_URL) benchmarks/k6/stress_test.js

.PHONY: k6-report
k6-report: ## Run k6 stress test and produce HTML report at benchmarks/k6/stress_report.html
	@if [ -z "$(BASE_URL)" ]; then echo "ERROR: Set BASE_URL=https://your-service.run.app"; exit 1; fi
	@echo "Running k6 stress test and generating HTML report..."
	mkdir -p benchmarks/k6
	k6 run -e BASE_URL=$(BASE_URL) benchmarks/k6/stress_test.js
	@echo "Report generated: benchmarks/k6/stress_report.html"

.PHONY: build-local
build-local: ## Build all local benchmark images (no registry push needed)
	docker build --platform linux/amd64 -f 1-gke-quarkus-jvm/Dockerfile.jvm           -t $(LOCAL_JVM)    1-gke-quarkus-jvm/
	docker build --platform linux/amd64 -f 1b-gke-spring-jvm/Dockerfile.jvm           -t $(LOCAL_SPRING) 1b-gke-spring-jvm/
	docker build --platform linux/amd64 -f 2-cloudrun-quarkus-native/Dockerfile.native -t $(LOCAL_NATIVE) 2-cloudrun-quarkus-native/
	docker build --platform linux/amd64 -f 3-cloudrun-golang/Dockerfile                -t $(LOCAL_GO)     3-cloudrun-golang/

.PHONY: benchmark-all
benchmark-all: ## Run k6 against all 3 runtimes in Docker with equal resources. Reports in benchmarks/k6/
	@echo ""
	@echo "================================================"
	@echo " Benchmark ALL — equal Docker resources"
	@echo " CPUs=$(BENCH_CPUS)  MEM=$(BENCH_MEM)  PORT=$(BENCH_PORT)"
	@echo "================================================"
	mkdir -p benchmarks/k6

	@echo "\n▶ [1/3] Quarkus JVM"
	-docker rm -f bench-svc 2>/dev/null || true
	docker run -d --name bench-svc --cpus=$(BENCH_CPUS) --memory=$(BENCH_MEM) \
		-p $(BENCH_PORT):8080 $(LOCAL_JVM)
	@echo "  Waiting for JVM startup (15s)..."; sleep 15
	BASE_URL=$(BENCH_URL) k6 run \
		-e REPORT_FILE=benchmarks/k6/report-jvm.html \
		benchmarks/k6/stress_test.js \
		|| true
	docker rm -f bench-svc

	@echo "\n▶ [2/3] Quarkus Native"
	-docker rm -f bench-svc 2>/dev/null || true
	docker run -d --name bench-svc --platform linux/amd64 \
		--cpus=$(BENCH_CPUS) --memory=$(BENCH_MEM) \
		-p $(BENCH_PORT):8080 $(LOCAL_NATIVE)
	@echo "  Waiting for Native startup (5s)..."; sleep 5
	BASE_URL=$(BENCH_URL) k6 run \
		-e REPORT_FILE=benchmarks/k6/report-native.html \
		benchmarks/k6/stress_test.js \
		|| true
	docker rm -f bench-svc

	@echo "\n▶ [3/3] Go"
	-docker rm -f bench-svc 2>/dev/null || true
	docker run -d --name bench-svc --cpus=$(BENCH_CPUS) --memory=$(BENCH_MEM) \
		-p $(BENCH_PORT):8080 $(LOCAL_GO)
	@echo "  Waiting for Go startup (3s)..."; sleep 3
	BASE_URL=$(BENCH_URL) k6 run \
		-e REPORT_FILE=benchmarks/k6/report-go.html \
		benchmarks/k6/stress_test.js \
		|| true
	docker rm -f bench-svc

	@echo "\n▶ [4/4] Spring Boot JVM"
	-docker rm -f bench-svc 2>/dev/null || true
	docker run -d --name bench-svc --platform linux/amd64 \
		--cpus=$(BENCH_CPUS) --memory=$(BENCH_MEM) \
		-p $(BENCH_PORT):8080 $(LOCAL_SPRING)
	@echo "  Waiting for Spring JVM startup (15s)..."; sleep 15
	BASE_URL=$(BENCH_URL) k6 run \
		-e REPORT_FILE=benchmarks/k6/report-spring-jvm.html \
		benchmarks/k6/stress_test.js \
		|| true
	docker rm -f bench-svc

	@echo ""
	@echo "✓ Done. Reports:"
	@echo "  benchmarks/k6/report-jvm.html"
	@echo "  benchmarks/k6/report-spring-jvm.html"
	@echo "  benchmarks/k6/report-native.html"
	@echo "  benchmarks/k6/report-go.html"

.PHONY: benchmark-coldstart
benchmark-coldstart: ## Measure cold-start latency for Cloud Run services (requires PROJECT_ID)
	@if [ -z "$(PROJECT_ID)" ]; then echo "ERROR: Set PROJECT_ID=your-gcp-project"; exit 1; fi
	PROJECT_ID=$(PROJECT_ID) REGION=$(REGION) ITERATIONS=$(or $(ITERATIONS),7) \
		./benchmarks/cold-start/measure.sh

.PHONY: benchmark-all-remote
benchmark-all-remote: ## Run 3 k6 rounds against all Cloud Run services from GCE VM (requires PROJECT_ID, GKE_IP)
	@if [ -z "$(PROJECT_ID)" ]; then echo "ERROR: Set PROJECT_ID"; exit 1; fi
	@if [ -z "$(GKE_IP)" ]; then echo "ERROR: Set GKE_IP (kubectl get svc device-api-jvm -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"; exit 1; fi
	$(eval NATIVE_URL := $(shell gcloud run services describe device-api-native --region=$(REGION) --project=$(PROJECT_ID) --format="value(status.url)"))
	$(eval GO_URL     := $(shell gcloud run services describe device-api-go     --region=$(REGION) --project=$(PROJECT_ID) --format="value(status.url)"))
	@echo "Native : $(NATIVE_URL)"
	@echo "Go     : $(GO_URL)"
	@echo "GKE    : http://$(GKE_IP)"
	gcloud compute scp benchmarks/k6/stress_test.js k6-runner:~/stress_test.js --zone=$(REGION)-b --project=$(PROJECT_ID)
	@for i in 1 2 3; do \
		gcloud compute ssh k6-runner --zone=$(REGION)-b --project=$(PROJECT_ID) -- \
			"k6 run -e BASE_URL='$(NATIVE_URL)' -e REPORT_FILE='report-native-$$i.html' stress_test.js && \
			 k6 run -e BASE_URL='$(GO_URL)'     -e REPORT_FILE='report-go-$$i.html'     stress_test.js && \
			 k6 run -e BASE_URL='http://$(GKE_IP)' -e REPORT_FILE='report-gke-$$i.html' stress_test.js"; \
	done
	mkdir -p benchmarks/k6
	gcloud compute scp 'k6-runner:~/report-*.html' benchmarks/k6/ --zone=$(REGION)-b --project=$(PROJECT_ID)
	@echo "✓ Reports downloaded to benchmarks/k6/"

# ----------------------------------------------------------------------------
# Utility targets
# ----------------------------------------------------------------------------
.PHONY: image-sizes
image-sizes: ## Show Docker image sizes for comparison
	@echo "Docker Image Sizes:"
	@echo "==================="
	@docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep device-api || echo "No images found. Run 'make build-all' first."

.PHONY: clean
clean: ## Remove built Docker images
	-docker rmi $(REGISTRY)/device-api-jvm:$(TAG) 2>/dev/null
	-docker rmi $(REGISTRY)/device-api-spring-jvm:$(TAG) 2>/dev/null
	-docker rmi $(REGISTRY)/device-api-native:$(TAG) 2>/dev/null
	-docker rmi $(REGISTRY)/device-api-go:$(TAG) 2>/dev/null
