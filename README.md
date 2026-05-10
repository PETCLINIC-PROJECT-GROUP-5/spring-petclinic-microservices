# Spring PetClinic Microservices
### DevOps Micro Internship (DMI) — Group 5
**Project Start:** May 3, 2025 | **Final Demo:** May 16, 2025

> A production-grade, distributed veterinary clinic management system — containerised, deployed to AWS EKS, with full CI/CD and observability.

---

## Table of Contents
1. [What This Project Is](#1-what-this-project-is)
2. [Architecture](#2-architecture)
3. [Tech Stack](#3-tech-stack)
4. [Services Overview](#4-services-overview)
5. [Team](#5-team)
6. [Prerequisites](#6-prerequisites)
7. [Running Locally (Docker Compose)](#7-running-locally-docker-compose)
8. [Deploying to AWS EKS](#8-deploying-to-aws-eks)
9. [CI/CD Pipeline](#9-cicd-pipeline)
10. [Observability](#10-observability)
11. [Runbook — Common Commands](#11-runbook--common-commands)
12. [Known Issues & Fixes](#12-known-issues--fixes)

---

## 1. What This Project Is

Spring PetClinic Microservices is a distributed veterinary clinic management system built with **Java 17** and **Spring Cloud**. It demonstrates real-world microservices architecture patterns including service discovery, centralised configuration, circuit breaking, distributed tracing, and AI-powered natural language interaction.

As a DevOps internship project, the team's focus was **not** writing Java code — it was:
- Containerising all 9 services with Docker
- Deploying to **AWS EKS** using Kubernetes manifests
- Automating delivery with **GitHub Actions**
- Configuring monitoring with **Prometheus, Grafana, and Zipkin**

---

## 2. Architecture

> 📌 *Architecture diagram will be inserted here — showing all 9 services, AWS infrastructure (EKS, ECR, ALB, VPC), and traffic flow.*

**Figure 1 — Architecture Diagram**
`[Insert high-resolution architecture diagram PNG here]`

**Traffic Flow Summary:**
- All external traffic enters through the **AWS Application Load Balancer (ALB)**
- The ALB forwards requests to the **API Gateway** (port 8080)
- The API Gateway routes to backend services via **Eureka Service Discovery**
- All services pull their configuration from the **Config Server** on startup
- **MySQL StatefulSets** (3 instances) persist data for customers, vets, and visits

---

## 3. Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| Backend | Java 17 + Spring Boot 3 | Each microservice runtime |
| Service Discovery | Eureka (Spring Cloud Netflix) | Services find each other by name |
| API Gateway | Spring Cloud Gateway | Single entry point, routes all traffic |
| Config Management | Spring Cloud Config Server | Centralised config for all services |
| Circuit Breaker | Resilience4j | Graceful failure handling |
| Tracing | Zipkin + OpenTelemetry | Distributed request tracing |
| Metrics | Micrometer + Prometheus | JVM and business metrics |
| Dashboards | Grafana | Visualise metrics |
| Database | MySQL 8 (prod) / HSQLDB (dev) | Persistent storage |
| AI Chatbot | Spring AI + OpenAI | Natural language interface |
| Containerisation | Docker | Local development stack |
| Container Registry | AWS ECR | Store and serve Docker images |
| Kubernetes | AWS EKS | Production container orchestration |
| IaC | Terraform | Provision all AWS infrastructure |
| CI/CD | GitHub Actions | Automated build, test, deploy |

---

## 4. Services Overview

| Service | Port | Purpose |
|---|---|---|
| `config-server` | 8888 | Serves config to all services from Git |
| `discovery-server` | 8761 | Eureka service registry |
| `customers-service` | dynamic | Manages pet owners and pets |
| `vets-service` | dynamic | Manages veterinarians |
| `visits-service` | dynamic | Manages pet visit records |
| `genai-service` | dynamic | AI chatbot via OpenAI |
| `api-gateway` | 8080 | Routes all client requests |
| `admin-server` | 9090 | Spring Boot Admin health UI |
| Prometheus | 9091 | Scrapes metrics from all services |
| Grafana | 3030 | Visualises Prometheus metrics |
| Zipkin | 9411 | Collects distributed traces |

> ⚠️ **Critical Startup Order:** config-server → discovery-server → MySQL DBs → customers/vets/visits → genai-service → api-gateway → admin-server/Prometheus/Grafana/Zipkin

---

## 5. Team

| Name | Role |
|---|---|
| Ed Eguaikhide | Project Lead / Scrum Master |
| Solomon | Infrastructure Lead |
| Justin | Infrastructure Engineer |
| Dube | Kubernetes Lead |
| Adegboyega | Kubernetes Engineer |
| Bello | CI/CD Lead |
| Jennifer | CI/CD Engineer |
| Walker | Observability Lead |
| Chukwuma | Observability Engineer |
| Lucy | App / Docker Lead |
| Ugochukwu | Documentation Lead |

---

## 6. Prerequisites

| Tool | Min Version | Purpose |
|---|---|---|
| Docker Desktop / Engine | 24+ | Run all services as containers |
| Java JDK | 17 | Build without Docker |
| Git | Any | Clone the repository |
| AWS CLI | 2.x | Interact with AWS |
| kubectl | 1.29+ | Manage Kubernetes cluster |
| Terraform | 1.7+ | Provision AWS infrastructure |
| Helm | 3.x | Install AWS Load Balancer Controller |

---

## 7. Running Locally (Docker Compose)

### Step 1 — Clone the repo
```bash
git clone https://github.com/YOUR-ORG/spring-petclinic-microservices.git
cd spring-petclinic-microservices
```

### Step 2 — Set the OpenAI API key
```bash
export OPENAI_API_KEY=demo
```
> The `demo` key is free but rate-limited. If the chatbot stops responding during heavy testing, this is normal.

### Step 3 — Build all Docker images
```bash
# Standard (Linux/Windows)
./mvnw clean install -P buildDocker -Dmaven.test.skip

# Mac M1/M2/M3 users MUST use this instead
./mvnw clean install -P buildDocker -Dcontainer.platform=linux/amd64
```
> First run takes 10–15 minutes.

### Step 4 — Start the stack
```bash
docker compose up -d
```

### Step 5 — Verify (wait 3–5 minutes after startup)

| URL | Expected Result |
|---|---|
| http://localhost:8080 | PetClinic homepage |
| http://localhost:8761 | Eureka — all services green |
| http://localhost:8888/actuator/health | Config Server — `UP` |
| http://localhost:9411/zipkin | Zipkin — traces visible |
| http://localhost:9090 | Admin Server — all instances green |
| http://localhost:3030 | Grafana — PetClinic dashboard |
| http://localhost:9091 | Prometheus — all targets UP |

---

## 8. Deploying to AWS EKS

### Step 1 — Provision infrastructure with Terraform
```bash
cd terraform/
terraform init
terraform plan
terraform apply
```

### Step 2 — Configure kubectl
```bash
aws eks update-kubeconfig --region us-east-1 --name petclinic-cluster
kubectl get nodes   # should show Ready
```

### Step 3 — Create namespaces
```bash
kubectl apply -f k8s/namespaces.yaml
# Creates: petclinic and monitoring namespaces
```

### Step 4 — Apply Secrets and ConfigMaps
```bash
kubectl apply -f k8s/secrets/
kubectl apply -f k8s/configmaps/
```

### Step 5 — Deploy MySQL StatefulSets
```bash
kubectl apply -f k8s/mysql/
kubectl get pods -n petclinic   # wait for all 3 MySQL pods to show Running
```

### Step 6 — Deploy services in order
```bash
kubectl apply -f k8s/config-server/
# Wait for Running before continuing
kubectl apply -f k8s/discovery-server/
kubectl apply -f k8s/customers-service/
kubectl apply -f k8s/vets-service/
kubectl apply -f k8s/visits-service/
kubectl apply -f k8s/genai-service/
kubectl apply -f k8s/api-gateway/
kubectl apply -f k8s/admin-server/
```

### Step 7 — Deploy observability stack
```bash
kubectl apply -f k8s/monitoring/
```

### Step 8 — Install AWS Load Balancer Controller and apply Ingress
```bash
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=petclinic-cluster

kubectl apply -f k8s/ingress.yaml
kubectl get ingress -n petclinic   # shows public ALB URL
```

### Step 9 — Verify everything is running
```bash
kubectl get pods -n petclinic
kubectl get pods -n monitoring
```

> **Figure 2** — `kubectl get pods -n petclinic` screenshot: `[Insert screenshot]`
> **Figure 3** — `kubectl get ingress -n petclinic` screenshot showing public ALB URL: `[Insert screenshot]`

---

## 9. CI/CD Pipeline

The project uses **GitHub Actions** for automated build, push, and deploy on every merge to `main`.

**Workflow triggers:**
- On pull request → runs build and tests
- On merge to `main` → builds Docker images, pushes to ECR, deploys to EKS

**Authentication:** GitHub OIDC (no static AWS keys stored in GitHub secrets)

**Image tagging:** All images are tagged with the Git commit SHA — `latest` is never used.

> **Figure 4** — GitHub Actions green pipeline run: `[Insert screenshot]`

---

## 10. Observability

### Prometheus
Scrapes metrics from all petclinic services in the `petclinic` namespace. Accessible via port-forward or Ingress.

### Grafana
- Datasource: Prometheus
- Dashboard: Spring PetClinic Metrics (imported from `docker/grafana/dashboards/grafana-petclinic-dashboard.json`)

> **Figure 5** — Grafana dashboard with live JVM and business metrics: `[Insert screenshot]`

### Zipkin
Collects distributed traces from all services. Accessible at port 9411.

> **Figure 6** — Zipkin showing distributed traces: `[Insert screenshot]`

---

## 11. Runbook — Common Commands

### Check service status
```bash
kubectl get pods -n petclinic
kubectl get pods -n monitoring
```

### Debug a failing pod
```bash
kubectl describe pod <pod-name> -n petclinic   # read the Events section
kubectl logs <pod-name> -n petclinic
kubectl logs <pod-name> -n petclinic --previous   # logs from crashed container
```

### If you can't connect to EKS
```bash
aws sts get-caller-identity   # confirm your AWS identity
aws eks update-kubeconfig --region us-east-1 --name petclinic-cluster
```

### If services show DOWN in Eureka
1. Confirm `config-server` pod is Running first
2. Check logs: `kubectl logs -l app=customers-service -n petclinic | grep -i error`
3. Confirm the ConfigMap has the correct config-server URL
4. Confirm the config repo is accessible from inside the cluster

### Roll back a deployment
```bash
kubectl rollout undo deployment/<service-name> -n petclinic
kubectl rollout status deployment/<service-name> -n petclinic
```

### Destroy all AWS infrastructure (after demo)
```bash
cd terraform/
terraform destroy
```
> Only the Infrastructure Lead runs `terraform destroy`.

---

## 12. Known Issues & Fixes

| Issue | Severity | Fix Applied |
|---|---|---|
| Hardcoded MySQL passwords | HIGH | Moved to Kubernetes Secrets |
| No resource limits on containers | HIGH | CPU/memory requests and limits added to all Deployments |
| HSQLDB used by default (data lost on restart) | MEDIUM | `mysql` Spring profile activated in all K8s Deployments |
| No readiness/liveness probes | HIGH | `readinessProbe` and `livenessProbe` added to all Deployments |
| OpenAI key exposed in environment | HIGH | Stored in K8s Secret, mounted via `secretKeyRef` |
| No Ingress manifest | MEDIUM | Ingress written for api-gateway using AWS ALB Controller |
| Images tagged as `latest` | HIGH | All images tagged with Git SHA in CI/CD pipeline |
| ARM/AMD64 mismatch on Mac | MEDIUM | Build enforced with `-Dcontainer.platform=linux/amd64` |

---

*DMI Group 5 — Documentation Lead: Ugochukwu | Project Lead: Ed Eguaikhide | Final Demo: May 16, 2025*
