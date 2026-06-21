#!/bin/bash
set -e
echo Tearing down observability stack...

export AWS_PROFILE=dmi-group5

echo Deleting Grafana LoadBalancer service...
kubectl delete service grafana -n monitoring --ignore-not-found
echo Waiting 60 seconds for AWS NLB and ENIs to be deprovisioned...
sleep 60

helm uninstall grafana -n monitoring 2>/dev/null || true
helm uninstall prometheus -n monitoring 2>/dev/null || true

echo Observability stack torn down
