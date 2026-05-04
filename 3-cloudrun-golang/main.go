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

func main() {
	startTime := time.Now()

	// Wire dependencies
	repo := repository.NewDeviceRepository()
	svc := service.NewDeviceService(repo)
	ctrl := controller.NewDeviceController(svc)

	// Register routes
	mux := http.NewServeMux()
	ctrl.RegisterRoutes(mux)

	// Startup logging
	elapsed := time.Since(startTime)
	fmt.Printf("🚀 Application started in %d ms\n", elapsed.Milliseconds())

	// Start server
	log.Printf("Server listening on :8080")
	if err := http.ListenAndServe(":8080", mux); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
