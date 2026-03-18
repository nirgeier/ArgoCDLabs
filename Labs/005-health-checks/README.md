---
# Health Checks

* ArgoCD evaluates the health of every Kubernetes resource it manages.
* Built-in health checks cover Deployments, Services, Ingresses, StatefulSets, and more.
* Custom health checks written in Lua let you define health logic for any CRD.

## What will we learn?

- ArgoCD's built-in health check logic for common resource types
- The five health status states and what they mean
- How to write a custom Lua health check for a CRD
- How to inspect health status via CLI and UI

---

## Prerequisites

- Complete [Lab 002](../002-first-app/README.md)

---

## 01. Health Status States

ArgoCD reports one of five health statuses for every resource:

| Status        | Meaning                                                       |
| ------------- | ------------------------------------------------------------- |
| `Healthy`     | Resource is fully running and meeting its desired state       |
| `Progressing` | Resource is being updated or is starting up                   |
| `Degraded`    | Resource has failed or is in a broken state                   |
| `Suspended`   | Resource is intentionally paused (e.g., CronJob, scaled to 0) |
| `Missing`     | Resource exists in Git but not in the cluster                 |
| `Unknown`     | ArgoCD cannot determine health (no health check defined)      |

---

## 02. Built-in Health Checks

ArgoCD ships with built-in health checks for these resource types:

```sh
# Check health of the guestbook application
argocd app get guestbook

# View resource-level health
argocd app resources guestbook

# Get detailed health information
kubectl get application guestbook -n argocd -o jsonpath='{.status.health}' | python3 -m json.tool
```

**Deployment health logic** (built-in):

- `Healthy` if: `availableReplicas == desiredReplicas` and no rollout in progress
- `Progressing` if: rollout is in progress
- `Degraded` if: replicas have been unavailable for too long

**Pod health logic** (built-in):

- `Healthy` if: all containers are `Ready`
- `Degraded` if: any container is in `CrashLoopBackOff` or `Error`

---

## 03. Observe Health Changes

```sh
# Force a degraded state: set an invalid image
kubectl set image deployment/guestbook-ui \
  guestbook-ui=nginx:invalid-tag-that-does-not-exist \
  -n guestbook

# Watch ArgoCD detect the Degraded state
argocd app get guestbook
kubectl get pods -n guestbook

# Restore the correct image (from Git - trigger a sync)
argocd app sync guestbook --force
argocd app wait guestbook --health --timeout 120
```

---

## 04. Custom Health Checks in Lua

For custom CRDs, you can define health logic in Lua inside `argocd-cm`:

```sh
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-cm
    app.kubernetes.io/part-of: argocd
data:
  # Custom health check for a hypothetical "DatabaseCluster" CRD
  resource.customizations.health.example.com_DatabaseCluster: |
    hs = {}
    if obj.status ~= nil then
      if obj.status.phase == "Running" then
        hs.status = "Healthy"
        hs.message = "Database cluster is running"
        return hs
      end
      if obj.status.phase == "Pending" then
        hs.status = "Progressing"
        hs.message = "Database cluster is starting"
        return hs
      end
      if obj.status.phase == "Failed" then
        hs.status = "Degraded"
        hs.message = obj.status.message or "Database cluster failed"
        return hs
      end
    end
    hs.status = "Unknown"
    hs.message = "No status available"
    return hs
EOF
```

---

## 05. Health Check for Common Kubernetes Resources

```sh
# Inspect the health of each individual resource in an app
argocd app resources guestbook --output wide

# Filter by health status
argocd app resources guestbook | grep -v Healthy || true

# View application events
kubectl get events -n guestbook --sort-by='.lastTimestamp' | tail -20
```

---

<img src="../assets/images/practice.png" alt="Practice" width="800"/>

## 06. Hands-on

1. Get the health status of all resources in the `guestbook` application and identify the overall health:

   ??? success "Solution"

   ```sh
   argocd app get guestbook
   argocd app resources guestbook
   # Health Status line shows: Healthy / Progressing / Degraded
   ```

2. Force a `Degraded` state by setting an invalid image, observe the status, then restore with a sync:

   ??? success "Solution"

   ```sh
   kubectl set image deployment/guestbook-ui \
     guestbook-ui=nginx:does-not-exist -n guestbook
   sleep 30
   argocd app get guestbook
   # Should show Degraded
   argocd app sync guestbook --force
   argocd app wait guestbook --health --timeout 120
   ```

3. Write a simple custom Lua health check in `argocd-cm` for a CRD with a `status.ready` boolean field:

   ??? success "Solution"

   ```sh
   kubectl patch cm argocd-cm -n argocd --type merge -p '{
     "data": {
       "resource.customizations.health.mygroup.io_MyResource": "hs = {}\nif obj.status ~= nil and obj.status.ready == true then\n  hs.status = \"Healthy\"\n  hs.message = \"Resource is ready\"\nelse\n  hs.status = \"Progressing\"\n  hs.message = \"Waiting for resource to be ready\"\nend\nreturn hs\n"
     }
   }'
   ```

---

## 07. Summary

- ArgoCD evaluates health at the resource level - the app-level health is the worst of all resource healths
- The five states are: `Healthy`, `Progressing`, `Degraded`, `Suspended`, and `Unknown`
- Built-in health checks cover Deployments, DaemonSets, StatefulSets, Pods, Services, Ingresses, and more
- Custom Lua health checks are configured in `argocd-cm` under `resource.customizations.health.<group_kind>`
- A `Progressing` state has a timeout - if it stays Progressing too long, it transitions to `Degraded`
