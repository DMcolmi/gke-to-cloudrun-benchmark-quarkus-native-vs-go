package com.benchmark.device;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;

import java.lang.management.ManagementFactory;

@SpringBootApplication
public class DeviceApplication {

    private static final Logger LOG = LoggerFactory.getLogger(DeviceApplication.class);

    public static void main(String[] args) {
        SpringApplication.run(DeviceApplication.class, args);
    }

    @EventListener(ApplicationReadyEvent.class)
    public void onReady() {
        long jvmStartTime = ManagementFactory.getRuntimeMXBean().getStartTime();
        long elapsed = System.currentTimeMillis() - jvmStartTime;
        LOG.info("🚀 Application started in {} ms", elapsed);
    }
}
