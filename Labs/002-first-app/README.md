---
# Your First ArgoCD Application

* In this lab we create an ArgoCD `Application` resource that points to a Git repository containing a simple nginx deployment.
* We observe how ArgoCD syncs the desired state from Git into the cluster.
* We access the deployed application and verify it is running.

## What will we learn?

- The structure of an ArgoCD `Application` manifest
- How to create an Application using the CLI and via YAML
- How to observe the sync process in the UI and CLI
- How to access a deployed workload

---

## Prerequisites

- Complete [Lab 000](../000-setup/README.md) to have ArgoCD running
- Port-forward active: `kubectl port-forward svc/argocd-server -n argocd 8080:443 &`
- Logged in: `argocd login localhost:8080 --username admin --insecure`

---

## 01. Understanding the Application CRD

An ArgoCD `Application` has two key sections:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default # Which AppProject this belongs to

  source: # WHERE to get the manifests
    repoURL: https://github.com/argoproj/argocd-example-apps
    targetRevision: HEAD
    path: guestbook

  destination: # WHERE to deploy them
    server: https://kubernetes.default.svc
    namespace: guestbook

  syncPolicy: # HOW to sync
    syncOptions:
      - CreateNamespace=true
```

---

## 02. Create Your First Application via CLI

```sh
# Create the application
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace guestbook \
  --sync-option CreateNamespace=true

# List applications
argocd app list

# Get application status
argocd app get guestbook
```

---

## 03. Create an Application via YAML Manifest

```sh
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-demo
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: nginx
  destination:
    server: https://kubernetes.default.svc
    namespace: nginx-demo
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
EOF
```

---

## 04. Trigger a Sync

By default, ArgoCD does not automatically sync. Let's trigger it manually:

```sh
# Sync the application
argocd app sync guestbook

# Watch the sync progress
argocd app wait guestbook --health --timeout 120

# Check application status after sync
argocd app get guestbook
```

Expected output:

```
Name:               argocd/guestbook
Project:            default
Server:             https://kubernetes.default.svc
Namespace:          guestbook
URL:                https://localhost:8080/applications/guestbook
Repo:               https://github.com/argoproj/argocd-example-apps.git
Target:             HEAD
Path:               guestbook
SyncWindow:         Sync Allowed
Sync Policy:        <none>
Sync Status:        Synced to HEAD
Health Status:      Healthy
```

---

## 05. Observe the Deployed Resources

```sh
# List all resources in the target namespace
kubectl get all -n guestbook

# View pods
kubectl get pods -n guestbook

# View service
kubectl get svc -n guestbook

# Port-forward to access the guestbook app
kubectl port-forward svc/guestbook-ui 9090:80 -n guestbook &
# Open http://localhost:9090
```

---

## 06. View Application Diff

```sh
# Show the diff between desired (Git) and actual (cluster) state
argocd app diff guestbook

# If already synced, no diff is expected
```

---

<img src="../assets/images/practice.png" alt="Practice" width="800"/>

## 07. Hands-on

1. Create an ArgoCD Application pointing to `https://github.com/argoproj/argocd-example-apps.git`, path `guestbook`, in namespace `guestbook`:

   ??? success "Solution"

   ```sh
   argocd app create guestbook \
     --repo https://github.com/argoproj/argocd-example-apps.git \
     --path guestbook \
     --dest-server https://kubernetes.default.svc \
     --dest-namespace guestbook \
     --sync-option CreateNamespace=true
   argocd app list
   ```

2. Sync the application and wait until health is `Healthy`:

   ??? success "Solution"

   ```sh
   argocd app sync guestbook
   argocd app wait guestbook --health --timeout 120
   argocd app get guestbook
   ```

3. Verify the pods and service are running in the `guestbook` namespace:

   ??? success "Solution"

   ```sh
   kubectl get pods -n guestbook
   kubectl get svc -n guestbook
   ```

4. Delete a pod in the `guestbook` namespace and observe that Kubernetes (not ArgoCD) restores it automatically:

   ??? success "Solution"

   ```sh
   POD=$(kubectl get pods -n guestbook -o jsonpath='{.items[0].metadata.name}')
   kubectl delete pod "$POD" -n guestbook
   # Kubernetes ReplicaSet controller recreates it
   kubectl get pods -n guestbook -w
   ```

---

## 08. Summary

- An ArgoCD `Application` defines a `source` (Git repo + path) and a `destination` (cluster + namespace)
- Without `syncPolicy.automated`, ArgoCD only shows drift - it does not auto-fix it
- `argocd app sync <name>` triggers an immediate sync from Git to the cluster
- `argocd app wait <name> --health` blocks until the application reaches the Healthy state
- ArgoCD does not replace the Kubernetes controller - pods are still managed by Deployments/ReplicaSets
