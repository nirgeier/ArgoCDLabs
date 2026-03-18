#!/bin/bash

set -euo pipefail

###
### Sync Policies lab - demonstrate manual, auto, selfheal, prune
###

ROOT_FOLDER=$(git rev-parse --show-toplevel)
source "$ROOT_FOLDER/_utils/common.sh"
source $ROOT_FOLDER/_utils/common.sh 2>/dev/null || true

kubectl port-forward svc/argocd-server -n argocd 8080:443 &
PF_PID=$!
sleep 3

ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
argocd login localhost:8080 --username admin --password "$ARGOCD_PASS" --insecure || true

echo "----------------------------------------------------------------------"
echo "* Current guestbook sync status"
echo "----------------------------------------------------------------------"
argocd app get guestbook 2>/dev/null || echo "guestbook app not found - run Lab 002 first"

echo ""
echo "----------------------------------------------------------------------"
echo "* Enabling automated sync with selfHeal and prune"
echo "----------------------------------------------------------------------"
argocd app set guestbook --sync-policy automated --self-heal --auto-prune || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Performing a dry-run sync"
echo "----------------------------------------------------------------------"
argocd app sync guestbook --dry-run || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Creating an orphan ConfigMap then pruning it"
echo "----------------------------------------------------------------------"
kubectl create configmap orphan-test -n guestbook --from-literal=key=value || true
kubectl get cm -n guestbook
echo "Syncing with prune..."
argocd app sync guestbook --prune || true
kubectl get cm -n guestbook

kill $PF_PID 2>/dev/null || true
