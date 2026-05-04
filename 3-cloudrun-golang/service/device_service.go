package service

import (
	"time"

	"github.com/benchmark/cloudrun-go/model"
	"github.com/benchmark/cloudrun-go/repository"
	"github.com/google/uuid"
)

type DeviceService struct {
	repo *repository.DeviceRepository
}

func NewDeviceService(repo *repository.DeviceRepository) *DeviceService {
	return &DeviceService{repo: repo}
}

func (s *DeviceService) Create(req model.CreateDeviceRequest) model.Device {
	device := model.Device{
		ID:        uuid.New().String(),
		Name:      req.Name,
		Status:    req.Status,
		CreatedAt: time.Now().UTC(),
	}
	return s.repo.Save(device)
}

func (s *DeviceService) GetByID(id string) (model.Device, bool) {
	return s.repo.FindByID(id)
}

func (s *DeviceService) ListByStatus(status string) []model.Device {
	if status == "" {
		return s.repo.FindAll()
	}
	return s.repo.FindByStatus(status)
}
