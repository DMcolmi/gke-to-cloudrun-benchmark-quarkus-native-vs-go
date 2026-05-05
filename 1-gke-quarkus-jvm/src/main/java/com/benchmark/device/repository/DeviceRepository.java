package com.benchmark.device.repository;

import com.benchmark.device.model.Device;
import jakarta.enterprise.context.ApplicationScoped;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

@ApplicationScoped
public class DeviceRepository {

    private final ConcurrentHashMap<UUID, Device> store = new ConcurrentHashMap<>();

    public Device save(Device device) {
        // Prevent OOM during heavy load testing
        if (store.size() > 1000) {
            store.remove(store.keys().nextElement());
        }
        store.put(device.getId(), device);
        return device;
    }

    public Optional<Device> findById(UUID id) {
        return Optional.ofNullable(store.get(id));
    }

    public List<Device> findByStatus(String status) {
        return store.values().stream()
                .filter(d -> d.getStatus().equalsIgnoreCase(status))
                .toList();
    }

    public List<Device> findAll() {
        return List.copyOf(store.values());
    }
}
