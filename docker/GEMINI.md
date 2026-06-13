# Spring PetClinic Microservices - Docker Configuration

This directory contains the Docker and monitoring configuration for the Spring PetClinic Microservices project.

## Project Overview
A microservices-based implementation of the classic Spring PetClinic application. It uses Spring Cloud for service discovery, configuration management, and API gateway.

## Tech Stack
- **Runtime:** Java 17 (Eclipse Temurin)
- **Framework:** Spring Boot, Spring Cloud
- **Build Tool:** Maven (expected at the root)
- **Containerization:** Docker
- **Monitoring:** Prometheus & Grafana

## Architecture
The system consists of several microservices:
- `api-gateway` (Port 8080)
- `customers-service` (Port 8081)
- `visits-service` (Port 8082)
- `vets-service` (Port 8083)

Prometheus scrapes metrics from these services via the `/actuator/prometheus` endpoint.

## Key Workflows

### Building Images
Images are built using a multi-stage Dockerfile that compiles the code inside the container using Maven. You no longer need to run `mvn package` manually before building the image.

Example command (run from root):
```bash
# Build the api-gateway (default)
docker build -f docker/Dockerfile -t api-gateway .

# Build a specific service with its port
docker build -f docker/Dockerfile \
  --build-arg MODULE=spring-petclinic-customers-service \
  --build-arg PORT=8081 \
  -t customers-service .
```

### Monitoring
- **Prometheus:** Accessible at `http://localhost:9090`. Configured to scrape all microservices.
- **Grafana:** Accessible at `http://localhost:3000`. Includes a pre-provisioned PetClinic dashboard.

## Conventions
- **Base Image:** Always use `eclipse-temurin:17` for Java-based services.
- **Profiles:** The `docker` Spring profile is active by default in containers (`ENV SPRING_PROFILES_ACTIVE=docker`).
- **Layering:** Follow the Spring Boot layering convention in Dockerfiles to optimize image size and build speed.
