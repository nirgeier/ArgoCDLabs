#!/bin/bash

###
### Monitoring lab - expose ArgoCD metrics for Prometheus and Grafana
###

set -euo pipefail

ROOT_FOLDER=$(git rev-parse --show-toplevel)
source $ROOT_FOLDER/_utils/common.sh 2>/dev/null || true

echo "----------------------------------------------------------------------"
echo "* ArgoCD metrics endpoints"
echo "----------------------------------------------------------------------"
echo "ArgoCD exposes Prometheus metrics on these endpoints:"
echo "  argocd-metrics:8082/metrics           - application controller metrics"
echo "  argocd-server-metrics:8083/metrics     - API server metrics"
echo "  argocd-repo-server:8084/metrics        - repo server metrics"

echo ""
echo "----------------------------------------------------------------------"
echo "* Current ArgoCD services (metrics ports)"
echo "----------------------------------------------------------------------"
kubectl get svc -n argocd | grep -E "NAME|metrics" || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Installing kube-prometheus-stack (Prometheus + Grafana)"
echo "----------------------------------------------------------------------"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update 2>/dev/null || true

helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --wait --timeout 5m || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Deploying ServiceMonitors for ArgoCD"
echo "----------------------------------------------------------------------"
cat <<'EOF' | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
spec:
  namespaceSelector:
    matchNames:
      - argocd
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  endpoints:
    - port: metrics
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-server-metrics
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
spec:
  namespaceSelector:
    matchNames:
      - argocd
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server-metrics
  endpoints:
    - port: metrics
EOF

echo ""
echo "----------------------------------------------------------------------"
echo "* Verifying monitoring stack pods"
echo "----------------------------------------------------------------------"
kubectl get pods -n monitoring | head -20 || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Key ArgoCD Prometheus metrics"
echo "----------------------------------------------------------------------"
echo "  argocd_app_info                  - app info (health, sync status)"
echo "  argocd_app_sync_total            - total sync operations"
echo "  argocd_app_sync_duration_seconds - sync duration histogram"
echo "  argocd_cluster_api_resources_total - managed resource count"
echo "  argocd_git_request_total         - git polling operations"

echo ""
echo "----------------------------------------------------------------------"
echo "* Port-forwarding to Grafana (background)"
echo "----------------------------------------------------------------------"
echo "Run to access Grafana: kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80"
echo "Default credentials: admin / prom-operator"
echo ""
echo "Import ArgoCD dashboard ID: 14584  (from grafana.com)"

echo ""
echo "----------------------------------------------------------------------"
echo "* Scrape ArgoCD metrics directly"
echo "----------------------------------------------------------------------"
kubectl port-forward svc/argocd-metrics -n argocd 8082:8082 &
METRICS_PID=$!
sleep 2
curl -s http://localhost:8082/metrics | grep "^argocd_app_info" | head -5 || true
kill $METRICS_PID 2>/dev/null || true

echo ""
echo "Monitoring stack deployed. ServiceMonitors configured for ArgoCD."
