package controller

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/benchmark/cloudrun-go/model"
	"github.com/benchmark/cloudrun-go/service"
)

type DeviceController struct {
	service *service.DeviceService
}

func NewDeviceController(svc *service.DeviceService) *DeviceController {
	return &DeviceController{service: svc}
}

func (c *DeviceController) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("POST /api/devices", c.Create)
	mux.HandleFunc("GET /api/devices/{id}", c.GetByID)
	mux.HandleFunc("GET /api/devices", c.List)
}

func (c *DeviceController) Create(w http.ResponseWriter, r *http.Request) {
	var req model.CreateDeviceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request body"}`, http.StatusBadRequest)
		return
	}

	device := c.service.Create(req)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(device)
}

func (c *DeviceController) GetByID(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if id == "" {
		http.Error(w, `{"error":"id required"}`, http.StatusBadRequest)
		return
	}

	device, found := c.service.GetByID(id)
	if !found {
		http.Error(w, `{"error":"not found"}`, http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(device)
}

func (c *DeviceController) List(w http.ResponseWriter, r *http.Request) {
	status := strings.TrimSpace(r.URL.Query().Get("status"))
	devices := c.service.ListByStatus(status)

	if devices == nil {
		devices = []model.Device{}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(devices)
}
