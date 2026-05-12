#!/bin/bash
set -e

echo "============================================"
echo "  Full Cluster Destroy Script"
echo "============================================"

export AWS_PROFILE=dmi-group5

# Step 1 — Teardown Kubernetes resources
echo "Running K8s teardown first..."
./scripts/teardown-k8s.sh

# Step 2 — Destroy Terraform infrastructure
echo ""
echo "Running terraform destroy..."
cd terraform
terraform destroy -auto-approve
cd ..

echo ""
echo "============================================"
echo "  Cluster fully destroyed."
echo "  To rebuild: ./scripts/setup-cluster.sh"
echo "              ./scripts/deploy-all.sh"
echo "============================================"