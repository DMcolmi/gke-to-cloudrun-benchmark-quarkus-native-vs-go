package repository

import (
	"strings"
	"sync"

	"github.com/benchmark/cloudrun-go/model"
)

type DeviceRepository struct {
	mu    sync.RWMutex
	store map[string]model.Device
}

func NewDeviceRepository() *DeviceRepository {
	return &DeviceRepository{
		store: make(map[string]model.Device),
	}
}

func (r *DeviceRepository) Save(device model.Device) model.Device {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.store[device.ID] = device
	return device
}

func (r *DeviceRepository) FindByID(id string) (model.Device, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	device, ok := r.store[id]
	return device, ok
}

func (r *DeviceRepository) FindByStatus(status string) []model.Device {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var result []model.Device
	for _, d := range r.store {
		if strings.EqualFold(d.Status, status) {
			result = append(result, d)
		}
	}
	return result
}

func (r *DeviceRepository) FindAll() []model.Device {
	r.mu.RLock()
	defer r.mu.RUnlock()

	result := make([]model.Device, 0, len(r.store))
	for _, d := range r.store {
		result = append(result, d)
	}
	return result
}
