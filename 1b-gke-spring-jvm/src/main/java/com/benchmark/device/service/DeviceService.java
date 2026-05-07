package com.benchmark.device.service;

import com.benchmark.device.model.Device;
import com.benchmark.device.repository.DeviceRepository;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
public class DeviceService {

    private final DeviceRepository repository;

    public DeviceService(DeviceRepository repository) {
        this.repository = repository;
    }

    public Device create(Device device) {
        device.setId(UUID.randomUUID());
        device.setCreatedAt(Instant.now());
        return repository.save(device);
    }

    public Optional<Device> getById(UUID id) {
        return repository.findById(id);
    }

    public List<Device> listByStatus(String status) {
        if (status == null || status.isBlank()) {
            return repository.findAll();
        }
        return repository.findByStatus(status);
    }
}
