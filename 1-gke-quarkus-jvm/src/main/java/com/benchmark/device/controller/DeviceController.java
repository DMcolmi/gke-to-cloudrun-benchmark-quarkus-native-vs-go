package com.benchmark.device.controller;

import com.benchmark.device.model.Device;
import com.benchmark.device.service.DeviceService;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import java.util.List;
import java.util.UUID;

@Path("/api/devices")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class DeviceController {

    @Inject
    DeviceService service;

    @POST
    public Response create(Device device) {
        Device created = service.create(device);
        return Response.status(Response.Status.CREATED).entity(created).build();
    }

    @GET
    @Path("/{id}")
    public Response getById(@PathParam("id") UUID id) {
        return service.getById(id)
                .map(d -> Response.ok(d).build())
                .orElse(Response.status(Response.Status.NOT_FOUND).build());
    }

    @GET
    public List<Device> list(@QueryParam("status") String status) {
        return service.listByStatus(status);
    }
}
