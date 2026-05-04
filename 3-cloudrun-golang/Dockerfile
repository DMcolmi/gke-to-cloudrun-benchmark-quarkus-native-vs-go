# Stage 1: Build
FROM golang:1.22-alpine AS build
WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o /app/server .

# Stage 2: Minimal runtime (scratch)
FROM scratch

# Copy CA certificates for HTTPS outbound calls
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

COPY --from=build /app/server /server

EXPOSE 8080

ENTRYPOINT ["/server"]
