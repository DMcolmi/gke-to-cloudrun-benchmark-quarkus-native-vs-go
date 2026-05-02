package com.benchmark.device;

import io.quarkus.runtime.StartupEvent;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import org.jboss.logging.Logger;

@ApplicationScoped
public class DeviceApplication {

    private static final Logger LOG = Logger.getLogger(DeviceApplication.class);

    private final long startTime = System.currentTimeMillis();

    void onStart(@Observes StartupEvent ev) {
        long elapsed = System.currentTimeMillis() - startTime;
        LOG.infof("\uD83D\uDE80 Application started in %d ms", elapsed);
    }
}
