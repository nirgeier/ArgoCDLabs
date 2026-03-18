---
# Sync Policies

* ArgoCD's sync policy controls how and when the cluster state is reconciled with Git.
* Manual sync requires explicit user action; automated sync reconciles continuously.
* SelfHeal and Prune are powerful options that keep your cluster clean and drift-free.

## What will we learn?

- The difference between manual and automated sync
- How to enable SelfHeal to automatically fix drift
- How to enable Prune to remove resources deleted from Git
- How sync windows work to block syncs at certain times
- How to perform a dry-run sync and a force sync

---

## Prerequisites

- Complete [Lab 002](../002-first-app/README.md)
- The `guestbook` application is deployed and Healthy

---

## 01. Manual Sync

Without a `syncPolicy`, ArgoCD shows drift but does nothing automatically.

```sh
# Trigger a manual sync
argocd app sync guestbook

# Sync only specific resources
argocd app sync guestbook \
  --resource apps:Deployment:guestbook-ui

# Sync and show the diff first
argocd app diff guestbook
argocd app sync guestbook
```

---

## 02. Automated Sync

Enable automated sync so ArgoCD reconciles whenever Git changes:

```sh
# Enable automated sync via CLI
argocd app set guestbook --sync-policy automated

# Or via YAML manifest
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: guestbook
  syncPolicy:
    automated: {}         # Enable automated sync
    syncOptions:
      - CreateNamespace=true
EOF
```

---

## 03. SelfHeal

SelfHeal makes ArgoCD re-sync automatically when someone manually changes the cluster:

```sh
# Enable SelfHeal
argocd app set guestbook \
  --sync-policy automated \
  --self-heal

# Or in YAML:
# syncPolicy:
#   automated:
#     selfHeal: true

# Test it: manually scale the deployment
kubectl scale deployment guestbook-ui -n guestbook --replicas=3
# ArgoCD will detect the drift and revert to replicas=1 (from Git) within ~3 minutes
kubectl get deployment guestbook-ui -n guestbook -w
```

---

## 04. Prune

Prune removes Kubernetes resources that exist in the cluster but no longer exist in Git:

```sh
# Enable Prune
argocd app set guestbook \
  --sync-policy automated \
  --auto-prune

# Or in YAML:
# syncPolicy:
#   automated:
#     prune: true

# Test it: add a resource manually to the namespace
kubectl create configmap orphan-config -n guestbook --from-literal=key=value
# Without prune, argocd app get guestbook would show it as OutOfSync but leave it
# With prune enabled, next sync will delete it
argocd app sync guestbook --prune
kubectl get configmap -n guestbook  # orphan-config should be gone
```

---

## 05. Sync Windows

Sync windows block automated syncs during specified time windows (e.g., production freeze):

```sh
# Add a deny sync window (no syncs on weekends)
argocd proj windows add default \
  --kind deny \
  --schedule "0 0 * * 6,0" \
  --duration 48h \
  --applications "*"

# Add an allow sync window (only sync during business hours)
argocd proj windows add default \
  --kind allow \
  --schedule "0 9 * * 1-5" \
  --duration 8h \
  --applications "*"

# List windows
argocd proj windows list default
```

---

## 06. Dry Run Sync

A dry run shows what would change without actually applying it:

```sh
# Dry run sync (server-side dry run)
argocd app sync guestbook --dry-run

# Force sync (ignore diff - useful after conflicts)
argocd app sync guestbook --force
```

---

<img src="../assets/images/practice.png" alt="Practice" width="800"/>

## 07. Hands-on

1. Enable automated sync with SelfHeal and Prune on the `guestbook` app, then manually scale the deployment to 3 replicas and watch ArgoCD revert it:

   ??? success "Solution"

   ```sh
   argocd app set guestbook --sync-policy automated --self-heal --auto-prune
   kubectl scale deployment guestbook-ui -n guestbook --replicas=3
   # Wait ~3 minutes and watch the replicas go back to 1
   kubectl get deployment guestbook-ui -n guestbook -w
   ```

2. Create an orphan ConfigMap in the `guestbook` namespace and verify that a manual sync with `--prune` removes it:

   ??? success "Solution"

   ```sh
   kubectl create configmap orphan -n guestbook --from-literal=test=true
   kubectl get cm -n guestbook
   argocd app sync guestbook --prune
   kubectl get cm -n guestbook  # orphan should be gone
   ```

3. Perform a dry-run sync and observe the output without applying any changes:

   ??? success "Solution"

   ```sh
   argocd app sync guestbook --dry-run
   # Output shows what would be applied - no actual changes made
   ```

---

## 08. Summary

- Manual sync gives full control; automated sync enables true GitOps continuous delivery
- `selfHeal: true` detects and corrects any out-of-band changes to the cluster within ~3 minutes
- `prune: true` deletes resources removed from Git; without it, deleted-from-Git resources become orphans
- Sync windows are defined at the AppProject level and can allow or deny syncs on a cron schedule
- Always test risky syncs with `--dry-run` before applying to production
