#!/bin/bash
set -e
echo ============================================
echo   Observability Stack Deployment
echo ============================================

export AWS_PROFILE=dmi-group5

helm upgrade --install prometheus k8s/monitoring-charts/prometheus.tgz \
  -n monitoring \
  -create-namespace \
  --set server.persistentVolume.enabled=false

helm upgrade --install grafana k8s/monitoring-charts/grafana.tgz \
  -n monitoring \
  --set persistence.enabled=false \
  --set service.type=LoadBalancer

echo Applying custom monitoring configurations and Zipkin...
kubectl apply -f k8s/monitoring/
kubectl apply -f k8s/Zipkin/deployment.yaml

echo Waiting for Grafana LoadBalancer...
kubectl wait --for=condition=Available deployment/grafana \
  -n monitoring --timeout=180s

echo Observability stack deployed
kubectl get svc -n monitoring | grep grafana
