#!/bin/bash

###
### Rollback lab - view history and perform rollback
###

ROOT_FOLDER=$(git rev-parse --show-toplevel)
source $ROOT_FOLDER/_utils/common.sh 2>/dev/null || true

kubectl port-forward svc/argocd-server -n argocd 8080:443 &
PF_PID=$!
sleep 3

ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
argocd login localhost:8080 --username admin --password "$ARGOCD_PASS" --insecure || true

echo "----------------------------------------------------------------------"
echo "* Application sync history"
echo "----------------------------------------------------------------------"
argocd app history guestbook || echo "Run Lab 002 first"

echo ""
echo "----------------------------------------------------------------------"
echo "* Disabling automated sync before rollback"
echo "----------------------------------------------------------------------"
argocd app set guestbook --sync-policy none || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Rolling back to revision 0"
echo "----------------------------------------------------------------------"
argocd app rollback guestbook 0 || true
argocd app wait guestbook --health --timeout 120 || true
argocd app get guestbook || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Syncing back to HEAD"
echo "----------------------------------------------------------------------"
argocd app sync guestbook || true
argocd app set guestbook --sync-policy automated --self-heal || true

kill $PF_PID 2>/dev/null || true
