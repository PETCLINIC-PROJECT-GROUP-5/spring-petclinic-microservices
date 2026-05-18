# Runbook — Spring PetClinic Microservices
**DMI Group 5 | Documentation Lead: Ugochukwu | Project Lead: Ed Eguaikhide**

This runbook covers the top 5 failure scenarios for the Spring PetClinic Microservices deployment on AWS EKS. Each scenario includes exact commands to diagnose and fix the problem.

---

## Table of Contents

1. [Service Not Starting](#1-service-not-starting)
2. [Cannot Connect to EKS](#2-cannot-connect-to-eks)
3. [Eureka Shows Services DOWN](#3-eureka-shows-services-down)
4. [MySQL Pod Crash](#4-mysql-pod-crash)
5. [ECR Authentication Expiry](#5-ecr-authentication-expiry)

---

## 1. Service Not Starting

### Symptoms
- `kubectl get pods -n petclinic` shows a pod in `CrashLoopBackOff`, `Error`, or `Pending` state
- The service does not appear in the Eureka dashboard
- App features related to that service stop working (e.g. pet owners page fails to load)

### Diagnosis

**Step 1 — Identify which pod is failing**
```bash
kubectl get pods -n petclinic
```
Look for any pod not showing `Running` in the STATUS column.

**Step 2 — Read the Kubernetes event log**
```bash
kubectl describe pod <pod-name> -n petclinic
```
Scroll to the **Events** section at the bottom. This tells you exactly why Kubernetes could not start the pod — common reasons include image pull failures, missing secrets, or insufficient memory.

**Step 3 — Read the application logs**
```bash
kubectl logs <pod-name> -n petclinic
```

**Step 4 — If the pod has already crashed, read the previous container logs**
```bash
kubectl logs <pod-name> -n petclinic --previous
```

### Common Causes and Fixes

**Cause: CrashLoopBackOff — config-server not ready yet**
Services start before config-server is healthy. Fix by restarting the failing pod after config-server is fully Running:
```bash
kubectl rollout restart deployment/<service-name> -n petclinic
```

**Cause: ImagePullBackOff — ECR image not found or auth expired**
```bash
# Check the exact error
kubectl describe pod <pod-name> -n petclinic | grep -A5 "Events"
# Fix — see Scenario 5 (ECR Authentication Expiry)
```

**Cause: OOMKilled — pod ran out of memory**
```bash
# Confirm OOMKill
kubectl describe pod <pod-name> -n petclinic | grep -i oom
# Fix — increase memory limit in the Deployment manifest then reapply
kubectl apply -f k8s/<service-name>/deployment.yaml
```

**Cause: Missing Secret or ConfigMap**
```bash
# Check secrets exist
kubectl get secrets -n petclinic
kubectl get configmaps -n petclinic
# If missing, reapply
kubectl apply -f k8s/secrets/
kubectl apply -f k8s/configmaps/
```

### Verify Fix
```bash
kubectl get pods -n petclinic
# Pod should show Running
kubectl logs <pod-name> -n petclinic | tail -20
# Logs should show successful startup, no ERROR lines
```

---

## 2. Cannot Connect to EKS

### Symptoms
- `kubectl get pods` returns `Unable to connect to the server`
- `kubectl get nodes` returns `error: You must be logged in to the server`
- AWS CLI commands fail with `Unable to locate credentials`

### Diagnosis

**Step 1 — Verify your AWS identity**
```bash
aws sts get-caller-identity
```
Expected output: your AWS account ID, user ARN, and username.
If this fails, your AWS credentials are missing or expired — go to Step 2.
If this works but kubectl still fails — go to Step 3.

**Step 2 — Check AWS credentials are configured**
```bash
aws configure list
```
All four fields (access_key, secret_key, region, output) should show values. If any show `None`, run:
```bash
aws configure
# Enter your Access Key ID, Secret Access Key, region: us-east-1, output: json
```
> Never share your AWS credentials in Discord, WhatsApp, or any chat. Contact the Infrastructure Lead privately if you need new credentials.

**Step 3 — Check your kubeconfig is pointing to the right cluster**
```bash
kubectl config current-context
# Should show: arn:aws:eks:us-east-1:<account-id>:cluster/petclinic-cluster
```

### Fix

**Re-authenticate kubectl with the EKS cluster**
```bash
aws eks update-kubeconfig --region us-east-1 --name petclinic-cluster
```

**Verify the fix**
```bash
kubectl get nodes
# Should show 2 or more nodes with STATUS: Ready
kubectl get pods -n petclinic
# Should show all petclinic pods
```

**If nodes show NotReady**
```bash
kubectl describe node <node-name>
# Read the Conditions section — look for memory pressure or disk pressure
```

### Additional Checks
```bash
# Confirm the cluster exists in AWS
aws eks list-clusters --region us-east-1

# Confirm your IAM user has EKS permissions
aws eks describe-cluster --name petclinic-cluster --region us-east-1
```

---

## 3. Eureka Shows Services DOWN

### Symptoms
- Visiting the Eureka dashboard (port 8761) shows services in red or not listed at all
- API Gateway returns `503 Service Unavailable` for specific routes
- Application pages fail to load (e.g. vets list is empty)

### Diagnosis

**Step 1 — Check config-server is Running first**
Every service depends on config-server. If config-server is down, all other services will fail to start.
```bash
kubectl get pods -n petclinic | grep config-server
# Must show Running before investigating anything else
```

**Step 2 — Check discovery-server (Eureka) is Running**
```bash
kubectl get pods -n petclinic | grep discovery-server
# Must show Running
```

**Step 3 — Check logs of the service showing DOWN in Eureka**
```bash
kubectl logs -l app=customers-service -n petclinic | grep -i error
kubectl logs -l app=vets-service -n petclinic | grep -i error
kubectl logs -l app=visits-service -n petclinic | grep -i error
```

**Step 4 — Check the ConfigMap has the correct config-server URL**
```bash
kubectl get configmap -n petclinic
kubectl describe configmap <configmap-name> -n petclinic
# Look for the spring.cloud.config.uri value
# It should point to http://config-server:8888
```

**Step 5 — Confirm the config repo is reachable from inside the cluster**
```bash
kubectl run curl-test --image=curlimages/curl -it --rm --restart=Never -n petclinic \
  -- curl http://config-server:8888/actuator/health
# Should return {"status":"UP"}
```

### Fix

**Fix 1 — Restart services in the correct order**
```bash
kubectl rollout restart deployment/config-server -n petclinic
# Wait 60 seconds
kubectl rollout restart deployment/discovery-server -n petclinic
# Wait 60 seconds
kubectl rollout restart deployment/customers-service -n petclinic
kubectl rollout restart deployment/vets-service -n petclinic
kubectl rollout restart deployment/visits-service -n petclinic
kubectl rollout restart deployment/api-gateway -n petclinic
```

**Fix 2 — If ConfigMap has wrong config-server URL**
```bash
# Edit the ConfigMap
kubectl edit configmap <configmap-name> -n petclinic
# Update the config server URL to: http://config-server:8888
# Save and exit, then restart the affected service
kubectl rollout restart deployment/<service-name> -n petclinic
```

### Verify Fix
```bash
# Port-forward to Eureka and check in browser
kubectl port-forward svc/discovery-server 8761:8761 -n petclinic
# Open http://localhost:8761 — all services should show UP (green)
```

---

## 4. MySQL Pod Crash

### Symptoms
- `kubectl get pods -n petclinic` shows `customers-db`, `vets-db`, or `visits-db` in `CrashLoopBackOff` or `Error`
- The dependent service (customers, vets, or visits) fails to start or returns database errors
- Application shows errors when creating or loading pet/owner/vet data

### Diagnosis

**Step 1 — Identify which database pod is failing**
```bash
kubectl get pods -n petclinic | grep -E "db|mysql"
```

**Step 2 — Read the MySQL pod logs**
```bash
kubectl logs <db-pod-name> -n petclinic
kubectl logs <db-pod-name> -n petclinic --previous
```
Common log errors to look for:
- `Access denied` — wrong password in Secret
- `No space left on device` — PVC is full
- `Table already exists` — schema initialisation conflict

**Step 3 — Check the PersistentVolumeClaim is bound**
```bash
kubectl get pvc -n petclinic
# All PVCs should show STATUS: Bound
# If STATUS shows Pending, the storage could not be provisioned
```

**Step 4 — Check the database Secret exists**
```bash
kubectl get secret -n petclinic | grep mysql
kubectl describe secret <mysql-secret-name> -n petclinic
# Confirm MYSQL_ROOT_PASSWORD and MYSQL_PASSWORD keys exist
```

### Fix

**Fix 1 — PVC is Pending (storage not provisioned)**
```bash
kubectl describe pvc <pvc-name> -n petclinic
# Read the Events section for the exact reason
# Usually means the StorageClass is wrong or EBS CSI driver is not installed
kubectl get storageclass
# Confirm gp2 or gp3 storage class exists
```

**Fix 2 — Wrong database password in Secret**
```bash
# Delete and recreate the secret with correct values
kubectl delete secret <mysql-secret-name> -n petclinic
kubectl apply -f k8s/secrets/mysql-secret.yaml
# Restart the database pod
kubectl rollout restart statefulset/<db-statefulset-name> -n petclinic
```

**Fix 3 — MySQL pod stuck — force delete and let StatefulSet recreate it**
```bash
kubectl delete pod <db-pod-name> -n petclinic
# Kubernetes will automatically recreate it via the StatefulSet
# Wait 60 seconds then check
kubectl get pods -n petclinic | grep db
```

**Fix 4 — Verify data survived the restart (persistence check)**
```bash
# Connect into the MySQL pod
kubectl exec -it <db-pod-name> -n petclinic -- mysql -u root -p
# Enter the root password from your Secret
# Then run:
SHOW DATABASES;
USE petclinic;
SHOW TABLES;
# Tables should exist with data intact
EXIT;
```

### Verify Fix
```bash
kubectl get pods -n petclinic | grep db
# All 3 db pods should show Running
kubectl get pvc -n petclinic
# All PVCs should show Bound
```

---

## 5. ECR Authentication Expiry

### Symptoms
- GitHub Actions pipeline fails with `no basic auth credentials` or `unauthorized`
- `kubectl get pods` shows `ImagePullBackOff` on new deployments
- `docker push` fails with `denied: Your authorization token has expired`

### Diagnosis

**Step 1 — Check the pod image pull error**
```bash
kubectl describe pod <pod-name> -n petclinic | grep -A10 "Events"
# Look for: Failed to pull image — 401 Unauthorized or no basic auth credentials
```

**Step 2 — Check GitHub Actions logs**
Go to your GitHub repo → Actions tab → click the failed workflow run → expand the failing step. Look for:
```
Error: buildah push failed with exit code 1
unauthorized: authentication required
```

**Step 3 — Verify ECR repos exist**
```bash
aws ecr describe-repositories --region us-east-1
# Should list all 9 repos
```

### Fix

**Fix 1 — Re-authenticate Docker with ECR (for manual pushes)**
```bash
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin \
  <your-account-id>.dkr.ecr.us-east-1.amazonaws.com
```
Replace `<your-account-id>` with your 12-digit AWS account ID.

**Fix 2 — Re-authenticate kubectl to pull from ECR**
```bash
# Get a fresh ECR token and create a K8s image pull secret
kubectl create secret docker-registry ecr-secret \
  --docker-server=<account-id>.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region us-east-1) \
  -n petclinic --dry-run=client -o yaml | kubectl apply -f -
```

**Fix 3 — GitHub Actions OIDC auth broken (no static keys)**
OIDC authentication should not expire. If the pipeline is failing with auth errors:
```bash
# Check the IAM role trust policy still includes GitHub Actions
aws iam get-role --role-name <github-actions-role-name>
# Confirm the trust policy includes:
# "token.actions.githubusercontent.com" as a federated principal
```
If the role is misconfigured, contact the CI/CD Lead — do not attempt to fix IAM roles yourself.

**Fix 4 — Force a fresh image pull on all pods**
```bash
kubectl rollout restart deployment -n petclinic
# This forces all pods to re-pull their images from ECR
```

### Verify Fix
```bash
# Confirm Docker is authenticated to ECR
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin \
  <account-id>.dkr.ecr.us-east-1.amazonaws.com
# Should return: Login Succeeded

# Confirm pods are pulling images successfully
kubectl get pods -n petclinic
# All pods should show Running with no ImagePullBackOff
```

---

## Quick Reference — All Commands

| Scenario | First command to run |
|---|---|
| Service not starting | `kubectl describe pod <pod-name> -n petclinic` |
| Cannot connect to EKS | `aws sts get-caller-identity` |
| Eureka shows DOWN | `kubectl get pods -n petclinic \| grep config-server` |
| MySQL pod crash | `kubectl get pvc -n petclinic` |
| ECR auth expiry | `kubectl describe pod <pod-name> -n petclinic \| grep -A10 Events` |

---

*DMI Group 5 — Documentation Lead: Bestman Ugochukwu Afokwalam | Project Lead: Ed Eguaikhide | Final Demo: May 16, 2025*
