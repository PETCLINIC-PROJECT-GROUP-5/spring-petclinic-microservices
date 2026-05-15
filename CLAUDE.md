# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Spring PetClinic Microservices is a distributed version of the Spring PetClinic sample application built with Spring Cloud (2025.1.0 Oakwood) and Spring Boot 4. It demonstrates microservices patterns including service discovery (Eureka), API gateway (Spring Cloud Gateway), circuit breakers (Resilience4j), distributed tracing (Zipkin), and monitoring (Prometheus/Grafana).

## Quick Start Commands

**Build the entire project:**
```bash
./mvnw clean package
```

**Run all services via Docker Compose:**
```bash
# First build Docker images
./mvnw clean install -P buildDocker

# Then start services
docker-compose up
```

**Run a single service locally (examples):**
```bash
# Start Discovery Server (must run first)
cd spring-petclinic-discovery-server && ../mvnw spring-boot:run

# Start Config Server (must run before other services)
cd spring-petclinic-config-server && ../mvnw spring-boot:run

# Start API Gateway
cd spring-petclinic-api-gateway && ../mvnw spring-boot:run

# Start a microservice (e.g., customers)
cd spring-petclinic-customers-service && ../mvnw spring-boot:run
```

**Run tests:**
```bash
./mvnw clean test
```

**Run tests for a single module:**
```bash
./mvnw test -pl spring-petclinic-customers-service
```

**Compile CSS (if modifying SCSS):**
```bash
cd spring-petclinic-api-gateway && mvn generate-resources -P css
```

**Build and push Docker images:**
```bash
export REPOSITORY_PREFIX=<your-docker-registry>
./mvnw clean install -Dmaven.test.skip -P buildDocker \
  -Ddocker.image.prefix=${REPOSITORY_PREFIX} \
  -Dcontainer.build.extraarg="--push" \
  -Dcontainer.platform="linux/amd64,linux/arm64"
```

## Project Structure

```
spring-petclinic-microservices/
├── spring-petclinic-discovery-server/      # Eureka service registry
├── spring-petclinic-config-server/         # Centralized configuration (Git-backed)
├── spring-petclinic-customers-service/     # Owners and pets management
├── spring-petclinic-vets-service/          # Veterinarians data
├── spring-petclinic-visits-service/        # Visit records
├── spring-petclinic-genai-service/         # Chat interface (Spring AI)
├── spring-petclinic-admin-server/          # Spring Boot Admin monitoring
├── spring-petclinic-api-gateway/           # Frontend + API routing
├── docker/                                  # Dockerfile and Docker config
├── terraform/                               # Infrastructure as Code (AWS)
├── scripts/                                 # Helper scripts (Docker, push, chaos)
└── pom.xml                                  # Parent Maven POM
```

## Microservices Architecture

### Service Startup Order

Services have dependencies and must start in this order:

1. **Config Server** (port 8888) - Must run first
   - Provides centralized configuration from Git repository
   - Default Git repo: https://github.com/spring-petclinic/spring-petclinic-microservices-config
   - Can use local repo with: `-Dspring.profiles.active=native -DGIT_REPO=/path/to/config`

2. **Discovery Server** (port 8761) - Must run second
   - Eureka service registry
   - All services register themselves here
   - Dashboard shows service availability

3. **Data Services** (can start in parallel after #2)
   - `customers-service` (Owners, Pets)
   - `vets-service` (Veterinarians)
   - `visits-service` (Visit records)
   - `genai-service` (Chat/AI features)

4. **API Gateway** (port 8080) - Frontend entry point
   - Routes requests to appropriate microservices
   - AngularJS UI served from here

5. **Optional Infrastructure**
   - Admin Server (port 9090) - Spring Boot Admin
   - Zipkin (port 9411) - Distributed tracing
   - Prometheus (port 9091) - Metrics
   - Grafana (port 3030) - Dashboards

### Key Communication Patterns

- **Service-to-service**: REST APIs via Spring Cloud Gateway routing
- **Resilience**: Circuit breakers with Resilience4j
- **Tracing**: Micrometer Tracing with Zipkin integration
- **Metrics**: Micrometer with Prometheus export
- **Configuration**: Externalized via Config Server (Git-backed)

### Database Configuration

- **Default**: HSQLDB (in-memory, auto-populated on startup)
- **MySQL**: Available via `mysql` Spring profile
  - Start services with: `--spring.profiles.active=mysql`
  - Requires MySQL instance: `docker run -e MYSQL_ROOT_PASSWORD=petclinic -e MYSQL_DATABASE=petclinic -p 3306:3306 mysql:8.4.5`

## Technology Stack

- **Java 17** (enforced via maven-enforcer-plugin)
- **Spring Boot 4.0.1** (parent version)
- **Spring Cloud 2025.1.0 (Oakwood)**
- **Spring Cloud Gateway** - API gateway routing
- **Eureka** - Service discovery
- **Resilience4j** - Circuit breakers
- **Spring AI** - GenAI/chatbot integration
- **Micrometer** - Metrics and distributed tracing
- **AngularJS** - Frontend (compiled via Gulp/Bower)

## Infrastructure & Terraform

Terraform code in `terraform/` directory provisions AWS infrastructure (EKS, ECR, VPC, etc.). Key files:

- `backend.tf` - State backend configuration
- `main.tf` - Primary resource declarations
- `modules/` - Reusable infrastructure modules (EKS, VPC, ECR, RDS)
- `.terraform.lock.hcl` - Terraform dependency lock file

**Important**: When modifying Terraform, ensure state is properly configured and tested before pushing.

## Common Development Tasks

### Adding a new REST endpoint

1. Create controller/resource class in `spring-petclinic-<service>/src/main/java/org/springframework/samples/petclinic/<service>/web/`
2. Add `@RestController` and `@RequestMapping` annotations
3. Register service in Eureka (happens automatically via Spring Cloud starter)
4. Optionally add `@Timed` annotation for metrics collection
5. Update Config Server repository if new configuration needed

### Debugging a single service

```bash
cd spring-petclinic-<service>
../mvnw spring-boot:run -Dspring-boot.run.jvmArguments="-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=y,address=5005"
```

### Testing a service in isolation

- Unit tests run with `mvn test`
- Services can be tested individually without starting all dependencies
- Use Spring Boot Test with `@SpringBootTest` for integration tests

### Modifying CSS/UI

CSS is compiled from SCSS in `spring-petclinic-api-gateway/src/main/scss/petclinic.scss`:
```bash
cd spring-petclinic-api-gateway
mvn generate-resources -P css
```

### Enabling Chaos Engineering

Chaos Monkey is available for testing resilience:
```bash
./scripts/chaos/call_chaos.sh  # See scripts/chaos/README.md for options
```

## Testing Notes

- Each service can be tested independently
- Full integration testing typically requires all services running (via docker-compose)
- Test database uses HSQLDB by default
- Tests verify REST endpoints, service discovery integration, and circuit breaker behavior

## Configuration Management

- **Config Server** stores application properties in a Git repository
- Each service reads its config from `http://config-server:8888/`
- Profiles (e.g., `mysql`, `native`, `chaos-monkey`) can be activated via `spring.profiles.active`
- Environment variables can override properties (e.g., `SPRING_PROFILES_ACTIVE=mysql`)

## Monitoring & Observability

- **Eureka Dashboard**: http://localhost:8761 (see service health and instances)
- **Spring Boot Admin**: http://localhost:9090 (monitor actuator endpoints)
- **Zipkin**: http://localhost:9411/zipkin/ (trace distributed requests)
- **Prometheus**: http://localhost:9091 (query raw metrics)
- **Grafana**: http://localhost:3030 (visualize metrics)

Custom metrics available:
- `customers-service`: `petclinic.owner`, `petclinic.pet`
- `visits-service`: `petclinic.visit`

## Notes for Future Work

- Spring Boot Admin updated to 4.0.2
- Spring Cloud upgraded to 2025.1.0 (Oakwood)
- Terraform infrastructure manages AWS deployment
- GenAI service supports OpenAI (default) or Azure OpenAI via configuration
- Docker images support multiple architectures (`linux/amd64`, `linux/arm64`)
