#!/bin/bash
set -e

echo "============================================"
echo "  PetClinic K8s Full Deployment Script"
echo "============================================"

export AWS_PROFILE=dmi-group5

# Verify kubectl works
kubectl get nodes > /dev/null 2>&1 || {
  echo "ERROR: kubectl cannot connect to cluster. Run setup-cluster.sh first."
  exit 1
}

echo ""
echo "Step 1 — Namespaces"
kubectl apply -f k8s/namespaces/
echo "✅ Namespaces ready"

echo ""
echo "Step 1b — ConfigMaps"
kubectl apply -f k8s/configmaps/
echo "✅ ConfigMaps ready"

echo ""
echo "Step 2 — MySQL StatefulSets"
kubectl apply -f k8s/mysql/
echo "Waiting for MySQL pods to be Ready..."
kubectl wait --for=condition=Ready pod \
  -l app=customers-db \
  -n petclinic \
  --timeout=180s
kubectl wait --for=condition=Ready pod \
  -l app=vets-db \
  -n petclinic \
  --timeout=180s
kubectl wait --for=condition=Ready pod \
  -l app=visits-db \
  -n petclinic \
  --timeout=180s
echo "✅ MySQL databases ready"

# Create pets stub table in visits-db
echo "Creating pets stub table in visits-db..."
kubectl exec -n petclinic visits-db-0 -- \
  mysql -u root -ppetclinic123 petclinic \
  -e "CREATE TABLE IF NOT EXISTS pets (
    id INT(4) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(30),
    birth_date DATE,
    type_id INT(4) UNSIGNED NOT NULL,
    owner_id INT(4) UNSIGNED NOT NULL
  ) engine=InnoDB;" 2>/dev/null || true
echo "✅ Pets stub table created"

echo ""
echo "Step 3 — Config Server"
kubectl apply -f k8s/config-server/
echo "Waiting for config-server to be Ready..."
kubectl wait --for=condition=Ready pod \
  -l app=config-server \
  -n petclinic \
  --timeout=180s
echo "✅ Config server ready"

echo ""
echo "Step 4 — Discovery Server"
kubectl apply -f k8s/discovery-server/
echo "Waiting for discovery-server to be Ready..."
kubectl wait --for=condition=Ready pod \
  -l app=discovery-server \
  -n petclinic \
  --timeout=180s
echo "✅ Discovery server ready"

echo ""
echo "Step 5 — App Services"
kubectl apply -f k8s/customers-service/
kubectl apply -f k8s/vets-service/
kubectl apply -f k8s/visits-service/
echo "✅ App services applied"

echo ""
echo "Step 6 — GenAI Service"
kubectl apply -f k8s/genai-service/
echo "✅ GenAI service applied"

echo ""
echo "Step 7 — Zipkin"
kubectl apply -f k8s/Zipkin/
echo "✅ Zipkin applied"

echo ""
echo "Step 8 — Admin Server"
kubectl apply -f k8s/admin-server/
echo "✅ Admin server applied"

echo ""
echo "Step 9 — API Gateway (last)"
kubectl apply -f k8s/api-gateway/
echo "✅ API gateway applied"

echo ""
echo "Step 10 — Ingress"
kubectl apply -f k8s/ingress/
echo "✅ Ingress applied"

echo ""
echo "============================================"
echo "  Deployment complete. Checking pod status..."
echo "============================================"
kubectl get pods -n petclinic

echo ""
echo "NOTE: App services take 2-4 minutes to fully start."
echo "Run: kubectl get pods -n petclinic -w to watch progress"
