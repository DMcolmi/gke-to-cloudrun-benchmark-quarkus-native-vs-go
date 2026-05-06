package main

import (
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/benchmark/cloudrun-go/controller"
	"github.com/benchmark/cloudrun-go/repository"
	"github.com/benchmark/cloudrun-go/service"
)

// processStart is initialized at package load time, before main() is called.
// This captures the Go runtime bootstrap time, analogous to JVM start time in Java.
var processStart = time.Now()

func main() {
	// Wire dependencies
	repo := repository.NewDeviceRepository()
	svc := service.NewDeviceService(repo)
	ctrl := controller.NewDeviceController(svc)

	// Register routes
	mux := http.NewServeMux()
	ctrl.RegisterRoutes(mux)

	// Startup logging
	elapsed := time.Since(processStart)
	fmt.Printf("🚀 Application started in %d ms\n", elapsed.Milliseconds())

	// Start server
	log.Printf("Server listening on :8080")
	if err := http.ListenAndServe(":8080", mux); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}

