---
# Monitoring ArgoCD

* ArgoCD exposes Prometheus metrics from the `argocd-server`, `argocd-application-controller`, and `argocd-repo-server`.
* Grafana dashboards provide visual insight into sync counts, health status, and repo performance.
* Alerting rules can notify your team when applications go out of sync or become degraded.

## What will we learn?

- Which Prometheus metrics ArgoCD exposes
- How to scrape ArgoCD metrics with Prometheus
- How to import the community ArgoCD Grafana dashboard
- Key metrics to watch and alert on

---

## Prerequisites

- Complete [Lab 002](../002-first-app/README.md)

---

## 01. ArgoCD Prometheus Metrics

ArgoCD exposes metrics on three endpoints:

| Component                     | Port | Path     |
| ----------------------------- | ---- | -------- |
| argocd-server                 | 8083 | /metrics |
| argocd-application-controller | 8082 | /metrics |
| argocd-repo-server            | 8084 | /metrics |

```sh
# Port-forward the metrics endpoint
kubectl port-forward svc/argocd-server -n argocd 8083:8083 &
sleep 2
curl http://localhost:8083/metrics | grep "^argocd_" | head -20
```

---

## 02. Key Metrics

```text
# Application metrics
argocd_app_info{name,namespace,project,health_status,sync_status,repo,dest_server,dest_namespace}
argocd_app_sync_total{name,namespace,phase}
argocd_app_health_status{name,namespace,health_status}
argocd_app_k8s_request_total{name,namespace,response_code,verb}

# Repository metrics
argocd_git_request_total{repo,request_type}
argocd_git_request_duration_seconds{repo,request_type}

# Cluster metrics
argocd_cluster_info{name,server}
argocd_cluster_api_resource_objects{name}
argocd_cluster_api_resources{name}
```

---

## 03. Deploy Prometheus and Grafana

```sh
# Add Prometheus Community Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update || true

# Install kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
helm install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  --set grafana.adminPassword=admin123 \
  --wait --timeout 10m || true

# Verify
kubectl get pods -n monitoring
```

---

## 04. Configure Prometheus to Scrape ArgoCD

```sh
# Create a ServiceMonitor for ArgoCD metrics
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
      interval: 30s
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
      interval: 30s
EOF
```

---

## 05. Import ArgoCD Grafana Dashboard

```sh
# Port-forward Grafana
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80 &
sleep 3
# Open http://localhost:3000
# Default credentials: admin / admin123

# The community ArgoCD dashboard ID is: 14584
# In Grafana: Dashboards → Import → Enter ID 14584 → Load
```

---

## 06. Alert Rules

```sh
cat <<'EOF' | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: argocd-alerts
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
spec:
  groups:
    - name: argocd.rules
      rules:
        - alert: ArgoCDAppOutOfSync
          expr: argocd_app_info{sync_status="OutOfSync"} == 1
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "ArgoCD application {{ $labels.name }} is OutOfSync"
            description: "Application {{ $labels.name }} has been OutOfSync for more than 5 minutes."

        - alert: ArgoCDAppDegraded
          expr: argocd_app_info{health_status="Degraded"} == 1
          for: 2m
          labels:
            severity: critical
          annotations:
            summary: "ArgoCD application {{ $labels.name }} is Degraded"
            description: "Application {{ $labels.name }} health is Degraded."

        - alert: ArgoCDSyncFailed
          expr: increase(argocd_app_sync_total{phase="Error"}[5m]) > 0
          labels:
            severity: warning
          annotations:
            summary: "ArgoCD sync failed for {{ $labels.name }}"
EOF
```

---

<img src="../assets/images/practice.png" alt="Practice" width="800"/>

## 07. Hands-on

1. Port-forward the ArgoCD metrics endpoint and list all `argocd_app_info` metrics:

   ??? success "Solution"

   ```sh
   kubectl port-forward svc/argocd-metrics -n argocd 8082:8082 &
   sleep 2
   curl -s http://localhost:8082/metrics | grep "^argocd_app_info" | head -10
   kill %1 2>/dev/null || true
   ```

2. Install `kube-prometheus-stack` and verify Prometheus and Grafana are running:

   ??? success "Solution"

   ```sh
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
   helm repo update || true
   helm install kube-prometheus-stack \
     prometheus-community/kube-prometheus-stack \
     -n monitoring --create-namespace \
     --set grafana.adminPassword=admin123 || true
   kubectl get pods -n monitoring
   ```

3. Create a `PrometheusRule` that fires an alert when any ArgoCD application is `OutOfSync` for more than 5 minutes:

   ??? success "Solution"

   ```sh
   cat <<'EOF' | kubectl apply -f -
   apiVersion: monitoring.coreos.com/v1
   kind: PrometheusRule
   metadata:
     name: argocd-outofsync-alert
     namespace: monitoring
     labels:
       release: kube-prometheus-stack
   spec:
     groups:
       - name: argocd.rules
         rules:
           - alert: ArgoCDAppOutOfSync
             expr: argocd_app_info{sync_status="OutOfSync"} == 1
             for: 5m
             labels:
               severity: warning
             annotations:
               summary: "App {{ $labels.name }} is OutOfSync"
   EOF
   kubectl get prometheusrule -n monitoring
   ```

---

## 08. Summary

- ArgoCD exposes Prometheus metrics on ports 8082 (app-controller), 8083 (server), and 8084 (repo-server)
- `argocd_app_info` is the most useful metric - it contains health status, sync status, and labels for every app
- ServiceMonitors configure Prometheus to scrape ArgoCD endpoints automatically
- The community Grafana dashboard ID `14584` provides a comprehensive ArgoCD overview
- Alert on `OutOfSync` (>5min) and `Degraded` health to catch issues before users notice them
