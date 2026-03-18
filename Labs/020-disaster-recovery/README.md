---

# Disaster Recovery

* ArgoCD state (Applications, AppProjects, repository credentials) is stored as Kubernetes resources that can be exported and re-imported.
* Because Git is the source of truth, a fresh ArgoCD install can re-sync all workloads automatically.
* High Availability (HA) mode protects against control-plane failures.

## What will we learn?

- How to back up ArgoCD Application and AppProject resources
- How to restore ArgoCD state to a new cluster
- How to configure ArgoCD in High Availability mode
- Best practices for RTO/RPO in a GitOps workflow

---

## Prerequisites

- Complete [Lab 002](../002-first-app/README.md)

---

## 01. What State Does ArgoCD Hold?

| Resource type                | Where stored                 | Recoverable from Git?       |
| ---------------------------- | ---------------------------- | --------------------------- |
| Application CRs              | argocd namespace             | Yes (re-apply from Git)     |
| AppProject CRs               | argocd namespace             | Yes (re-apply from Git)     |
| Repository credentials       | argocd namespace (Secrets)   | Partially (re-enter tokens) |
| Cluster credentials          | argocd namespace (Secrets)   | Partially (re-add clusters) |
| ArgoCD config (argocd-cm)    | argocd namespace (ConfigMap) | Yes (store in Git)          |
| RBAC policy (argocd-rbac-cm) | argocd namespace (ConfigMap) | Yes (store in Git)          |

---

## 02. Backup ArgoCD Resources

```sh
# Create a backup directory
mkdir -p ~/argocd-backup

# Export all Application CRs
kubectl get applications -n argocd -o yaml > ~/argocd-backup/applications.yaml

# Export all AppProject CRs
kubectl get appprojects -n argocd -o yaml > ~/argocd-backup/appprojects.yaml

# Export repository secrets
kubectl get secret -n argocd \
  -l "argocd.argoproj.io/secret-type=repository" \
  -o yaml > ~/argocd-backup/repo-secrets.yaml

# Export cluster secrets
kubectl get secret -n argocd \
  -l "argocd.argoproj.io/secret-type=cluster" \
  -o yaml > ~/argocd-backup/cluster-secrets.yaml

# Export ArgoCD config maps
kubectl get configmap argocd-cm argocd-rbac-cm -n argocd \
  -o yaml > ~/argocd-backup/configmaps.yaml

ls ~/argocd-backup/
```

---

## 03. Restore to a New Cluster

```sh
# 1. Install ArgoCD on the new cluster
kubectl create namespace argocd
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 2. Wait for ArgoCD to be ready
kubectl rollout status deploy/argocd-server -n argocd --timeout=120s

# 3. Restore config and credentials first
kubectl apply -f ~/argocd-backup/configmaps.yaml
kubectl apply -f ~/argocd-backup/repo-secrets.yaml
kubectl apply -f ~/argocd-backup/cluster-secrets.yaml

# 4. Restore AppProjects before Applications (dependency)
kubectl apply -f ~/argocd-backup/appprojects.yaml

# 5. Restore Applications – ArgoCD will begin syncing from Git immediately
kubectl apply -f ~/argocd-backup/applications.yaml

# 6. Watch sync status
argocd app list
```

---

## 04. ArgoCD High Availability

```sh
# Install ArgoCD in HA mode
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/ha/install.yaml

# HA changes vs standard:
# - argocd-server: 2 replicas
# - argocd-repo-server: 2 replicas
# - argocd-application-controller: StatefulSet with sharding
# - Redis HA: sentinel mode (3 nodes)
```

Verify HA pods are running:

```sh
kubectl get pods -n argocd -o wide
# Expect multiple replicas of server and repo-server
```

---

## 05. Store ArgoCD Config in Git

The most resilient approach is to keep ArgoCD configuration in Git itself:

```sh
# Directory structure for GitOps-managed ArgoCD
argocd-bootstrap/
├── argocd-install/
│   └── kustomization.yaml    # ArgoCD install + overlays
├── projects/
│   ├── team-alpha.yaml
│   └── team-beta.yaml
├── apps/
│   ├── infra/
│   └── workloads/
└── rbac/
    └── argocd-rbac-cm.yaml
```

Use an App-of-Apps (Lab 008) to bootstrap the entire ArgoCD setup from Git.

---

## Hands-on Tasks

1. Export all ArgoCD Application and AppProject resources to a local backup directory
2. Delete one Application and restore it from the backup
3. Verify the restored Application re-syncs from Git automatically
4. Review the HA install manifest and identify how replicas are configured
5. Design a Git repository structure that stores all ArgoCD config (projects, RBAC, apps)

---

## 08. Summary

- ArgoCD state is stored as Kubernetes resources (Applications, AppProjects, Secrets) that can be exported with `kubectl get -o yaml`
- Restoration is as simple as `kubectl apply` on the backed-up YAMLs to a fresh cluster
- Git is the ultimate source of truth - a new ArgoCD install re-syncs all workloads automatically
- HA mode runs multiple replicas of `argocd-server` and `argocd-repo-server` plus Redis sentinel
- Store ArgoCD configuration (projects, RBAC, app definitions) in Git and manage it with an App-of-Apps
