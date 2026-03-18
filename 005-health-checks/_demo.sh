#!/bin/bash

###
### Health Checks lab - inspect and test ArgoCD health states
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
echo "* Application health status"
echo "----------------------------------------------------------------------"
argocd app get guestbook || echo "guestbook not found - run Lab 002 first"

echo ""
echo "----------------------------------------------------------------------"
echo "* Resource-level health"
echo "----------------------------------------------------------------------"
argocd app resources guestbook || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Forcing Degraded state (invalid image)"
echo "----------------------------------------------------------------------"
kubectl set image deployment/guestbook-ui \
  guestbook-ui=nginx:does-not-exist -n guestbook || true
sleep 15
argocd app get guestbook || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Restoring via sync"
echo "----------------------------------------------------------------------"
argocd app sync guestbook --force || true
argocd app wait guestbook --health --timeout 120 || true
argocd app get guestbook || true

kill $PF_PID 2>/dev/null || true
