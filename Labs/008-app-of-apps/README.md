---
# App-of-Apps Pattern

* The App-of-Apps pattern uses a single ArgoCD Application to manage many child Applications.
* A root application points to a Git directory containing other Application manifests.
* This enables bootstrapping an entire cluster from a single `argocd app sync root-app` command.

## What will we learn?

- The App-of-Apps design pattern and when to use it
- How to create a root application that generates child applications
- How to structure a Git repository for App-of-Apps
- How to bootstrap a cluster with a single command

---

## Prerequisites

- Complete [Lab 002](../002-first-app/README.md)

---

## 01. The Pattern Explained

```text
Git repository structure for App-of-Apps:

apps/
├── root-app.yaml          # The single ArgoCD Application you deploy first
└── apps/
    ├── guestbook.yaml     # Child Application for guestbook
    ├── nginx.yaml         # Child Application for nginx
    └── monitoring.yaml    # Child Application for monitoring stack
```

The root application watches the `apps/` directory. When you add a new YAML file there (push to Git), ArgoCD creates the child Application automatically.

---

## 02. Create the App-of-Apps Structure Locally

For this lab we simulate the pattern using the public `argocd-example-apps` repo which has an `apps` directory:

```sh
# We'll create our own local structure using a temporary directory
# In real scenarios, this would be a Git repo

# Create the app-of-apps manifests
mkdir -p /tmp/argocd-app-of-apps/apps

# Create child app 1: guestbook
cat <<'EOF' > /tmp/argocd-app-of-apps/apps/guestbook.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook-child
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: guestbook-aoa
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
    syncOptions:
      - CreateNamespace=true
EOF

# Create child app 2: nginx
cat <<'EOF' > /tmp/argocd-app-of-apps/apps/nginx.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-child
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: nginx
  destination:
    server: https://kubernetes.default.svc
    namespace: nginx-aoa
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
    syncOptions:
      - CreateNamespace=true
EOF
```

---

## 03. Understanding Finalizers

The `resources-finalizer.argocd.argoproj.io` finalizer ensures child resources are cleaned up when an Application is deleted:

```yaml
metadata:
  finalizers:
    - resources-finalizer.argocd.argoproj.io # Cascade delete
```

Without this finalizer, deleting the Application in ArgoCD leaves all Kubernetes resources behind.

---

## 04. Create the Root Application

```sh
# The root app points to the argocd-example-apps "apps" directory
# which contains Application manifests
argocd app create root-app \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path apps \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace argocd \
  --sync-policy automated \
  --auto-prune \
  --self-heal

# List all applications - child apps should appear
argocd app list

# Sync the root app
argocd app sync root-app
```

---

## 05. Verify Child Applications

```sh
# After syncing, child apps should be created automatically
argocd app list

# Check status of a specific child app
argocd app get guestbook-child 2>/dev/null || argocd app list

# View the parent-child hierarchy in the ArgoCD UI
# Navigate to: https://localhost:8080
```

---

## 06. Delete an Application from the Tree

```sh
# To remove a child app: delete its YAML from the Git repo
# ArgoCD will then delete the Application resource (and its Kubernetes resources if cascade=true)

# Force delete for testing
argocd app delete guestbook-child --cascade || true
```

---

<img src="../assets/images/practice.png" alt="Practice" width="800"/>

## 07. Hands-on

1. Create a root ArgoCD Application pointing to the `apps` path of `argocd-example-apps` and list all generated child apps:

   ??? success "Solution"

   ```sh
   argocd app create root-app \
     --repo https://github.com/argoproj/argocd-example-apps.git \
     --path apps \
     --dest-server https://kubernetes.default.svc \
     --dest-namespace argocd \
     --sync-policy automated \
     --auto-prune \
     --self-heal
   argocd app sync root-app
   sleep 10
   argocd app list
   ```

2. Verify that the child applications automatically create their namespaces and deploy their workloads:

   ??? success "Solution"

   ```sh
   kubectl get namespaces | grep -E "guestbook|nginx|helm"
   argocd app list
   # All child apps should eventually show Synced and Healthy
   ```

3. Explain what the `resources-finalizer.argocd.argoproj.io` finalizer does and when you would omit it:

   ??? success "Solution"

   ```sh
   # The finalizer causes a cascade delete - when the Application is removed,
   # all its Kubernetes resources are also deleted.
   # You would OMIT it if you want to remove the ArgoCD Application without
   # deleting the actual workloads (e.g., when migrating ArgoCD instances).
   kubectl get application guestbook-child -n argocd -o yaml | grep finalizer || true
   ```

---

## 08. Summary

- The App-of-Apps pattern treats Application manifests as first-class GitOps objects
- A single root app bootstraps an entire cluster - add a YAML to Git, ArgoCD creates the app
- `resources-finalizer.argocd.argoproj.io` enables cascade delete of Kubernetes resources when the Application is removed
- Child apps inherit the sync policy independently - each can have different sync strategies
- For large clusters, consider ApplicationSets (Lab 022) as a more scalable alternative to App-of-Apps
