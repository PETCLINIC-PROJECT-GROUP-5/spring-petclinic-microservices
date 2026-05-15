# EPIC-2 Containerisation Tasks

## CONT-1: Validate docker-compose Stack Locally

Validated the PetClinic microservices stack locally using Docker Compose.

Verified:
- Config Server
- Discovery Server
- API Gateway
- Customers Service
- Visits Service
- Vets Service
- Admin Server
- Prometheus
- Grafana
- Zipkin

Application accessible at:
http://localhost:8080

Eureka dashboard:
http://localhost:8761

---

## CONT-2: Build Docker Images

Verified all services are running as Docker containers.

Command used:

docker compose up -d

---

## CONT-3: Image Tagging

Verified images can be tagged using Git SHA tags instead of latest.

Example:

docker tag springcommunity/spring-petclinic-api-gateway api-gateway:<git-sha>

---

## CONT-4: Authenticate Docker to ECR

Prepared environment for ECR authentication using AWS CLI.

---

## CONT-5: Push Images to ECR

Ready for image push to AWS ECR repositories.

---

## CONT-6: Verify AMD64 Compatibility

Validated containers run successfully on linux/amd64 architecture without exec format errors.
