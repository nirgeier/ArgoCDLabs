---
# Rollback

* ArgoCD maintains a history of every sync operation, allowing you to roll back to any previous revision.
* Before rolling back, you should disable automated sync to prevent ArgoCD from immediately re-syncing.
* The rollback operation redeploys the manifests from a specific Git commit SHA.

## What will we learn?

- How to view application sync history
- How to diff between current state and a previous revision
- How to rollback to a specific revision
- Why automated sync must be disabled before rollback
- How to undo a rollback

---

## Prerequisites

- Complete [Lab 004](../004-sync-policies/README.md)
- The `guestbook` application has at least 2 sync operations in history

---

## 01. View Sync History

```sh
# List all past sync operations (revisions)
argocd app history guestbook

# Sample output:
# ID  DATE                           REVISION
# 0   2024-01-15 10:00:00 +0000 UTC  HEAD (abc1234)
# 1   2024-01-15 11:30:00 +0000 UTC  HEAD (def5678)
# 2   2024-01-15 14:45:00 +0000 UTC  HEAD (ghi9012)
```

---

## 02. Diff Against a Previous Revision

```sh
# Show what changed between current state and revision ID 1
argocd app diff guestbook --revision 1

# Compare two specific revisions (by Git commit SHA)
# argocd app diff guestbook --from-revision abc1234 --to-revision def5678
```

---

## 03. Disable Automated Sync Before Rollback

If automated sync is enabled, ArgoCD will immediately re-sync after rollback:

```sh
# Check current sync policy
argocd app get guestbook | grep "Sync Policy"

# Disable automated sync
argocd app set guestbook --sync-policy none

# Verify it is disabled
argocd app get guestbook | grep "Sync Policy"
# Should show: Sync Policy: <none>
```

---

## 04. Perform the Rollback

```sh
# View history to find the target revision ID
argocd app history guestbook

# Rollback to revision ID 1
argocd app rollback guestbook 1

# Wait for rollback to complete
argocd app wait guestbook --health --timeout 120

# Check the current state
argocd app get guestbook
```

---

## 05. Verify the Rollback

```sh
# Confirm the deployed resources match the old revision
kubectl get deployment guestbook-ui -n guestbook -o yaml | grep image

# Check the revision in argocd app get output
argocd app get guestbook
# The "Revision" field should now show the old commit SHA
```

---

## 06. Undo the Rollback (Sync to HEAD)

```sh
# Re-enable automated sync
argocd app set guestbook --sync-policy automated --self-heal

# Sync to latest HEAD
argocd app sync guestbook
argocd app wait guestbook --health --timeout 120
argocd app get guestbook
```

---

<img src="../assets/images/practice.png" alt="Practice" width="800"/>

## 07. Hands-on

1. View the sync history of the `guestbook` application:

   ??? success "Solution"

   ```sh
   argocd app history guestbook
   ```

2. Disable automated sync on the `guestbook` application then rollback to revision ID 0:

   ??? success "Solution"

   ```sh
   argocd app set guestbook --sync-policy none
   argocd app history guestbook
   argocd app rollback guestbook 0
   argocd app wait guestbook --health --timeout 120
   argocd app get guestbook
   ```

3. After rollback, sync back to HEAD and re-enable automated sync:

   ??? success "Solution"

   ```sh
   argocd app sync guestbook
   argocd app set guestbook --sync-policy automated --self-heal
   argocd app wait guestbook --health --timeout 120
   ```

---

## 08. Summary

- `argocd app history <app>` lists all past syncs with their revision IDs and Git commit SHAs
- Always disable automated sync (`--sync-policy none`) before rollback to prevent immediate re-sync
- Rollback deploys the exact manifests from a specific Git commit - it does not modify Git history
- `argocd app diff --revision <id>` lets you preview changes before committing to a rollback
- After rollback investigation, restore by syncing to HEAD and re-enabling the desired sync policy
