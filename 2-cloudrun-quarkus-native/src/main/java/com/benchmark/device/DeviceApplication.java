package com.benchmark.device;

import io.quarkus.runtime.StartupEvent;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import org.jboss.logging.Logger;

import java.lang.management.ManagementFactory;

@ApplicationScoped
public class DeviceApplication {

    private static final Logger LOG = Logger.getLogger(DeviceApplication.class);

    void onStart(@Observes StartupEvent ev) {
        long jvmStartTime = ManagementFactory.getRuntimeMXBean().getStartTime();
        long elapsed = System.currentTimeMillis() - jvmStartTime;
        LOG.infof("\uD83D\uDE80 Application started in %d ms", elapsed);
    }
}
