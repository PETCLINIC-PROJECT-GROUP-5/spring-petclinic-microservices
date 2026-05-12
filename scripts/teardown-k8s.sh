#!/bin/bash
set -e

echo "============================================"
echo "  PetClinic K8s Teardown Script"
echo "============================================"

export AWS_PROFILE=dmi-group5

echo ""
echo "Step 1 — Delete Ingress (removes ALB first)"
kubectl delete -f k8s/ingress/ --ignore-not-found
echo "Waiting for ALB to be deprovisioned..."
sleep 30

echo ""
echo "Step 2 — Delete App Services"
kubectl delete -f k8s/api-gateway/ --ignore-not-found
kubectl delete -f k8s/admin-server/ --ignore-not-found
kubectl delete -f k8s/Zipkin/ --ignore-not-found
kubectl delete -f k8s/genai-service/ --ignore-not-found
kubectl delete -f k8s/visits-service/ --ignore-not-found
kubectl delete -f k8s/vets-service/ --ignore-not-found
kubectl delete -f k8s/customers-service/ --ignore-not-found
echo "✅ App services deleted"

echo ""
echo "Step 3 — Delete Discovery and Config Servers"
kubectl delete -f k8s/discovery-server/ --ignore-not-found
kubectl delete -f k8s/config-server/ --ignore-not-found
echo "✅ Core servers deleted"

echo ""
echo "Step 4 — Delete MySQL StatefulSets"
kubectl delete -f k8s/mysql/ --ignore-not-found
echo "Waiting for MySQL pods to terminate..."
kubectl wait --for=delete pod \
  -l app=customers-db \
  -n petclinic \
  --timeout=120s 2>/dev/null || true
kubectl wait --for=delete pod \
  -l app=vets-db \
  -n petclinic \
  --timeout=120s 2>/dev/null || true
kubectl wait --for=delete pod \
  -l app=visits-db \
  -n petclinic \
  --timeout=120s 2>/dev/null || true
echo "✅ MySQL deleted"

echo ""
echo "Step 5 — Delete PVCs (EBS volumes)"
kubectl delete pvc --all -n petclinic --ignore-not-found
echo "✅ PVCs deleted"

echo ""
echo "Step 6 — Delete Secrets"
kubectl delete secret --all -n petclinic --ignore-not-found
echo "✅ Secrets deleted"

echo ""
echo "Step 7 — Delete Load Balancer Controller"
helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null || true
echo "✅ Load Balancer Controller removed"

echo ""
echo "Step 8 — Delete Namespaces"
kubectl delete namespace petclinic --ignore-not-found
kubectl delete namespace monitoring --ignore-not-found
echo "✅ Namespaces deleted"

echo ""
echo "============================================"
echo "  K8s teardown complete."
echo "  Safe to run terraform destroy now."
echo "============================================"
