#!/bin/bash

set -euo pipefail

###
### First App lab - create and sync an ArgoCD Application
###

ROOT_FOLDER=$(git rev-parse --show-toplevel)
source "$ROOT_FOLDER/_utils/common.sh"
source $ROOT_FOLDER/_utils/common.sh 2>/dev/null || true

echo "----------------------------------------------------------------------"
echo "* Starting port-forward to ArgoCD server"
echo "----------------------------------------------------------------------"
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
PF_PID=$!
sleep 3

echo ""
echo "----------------------------------------------------------------------"
echo "* Logging into ArgoCD"
echo "----------------------------------------------------------------------"
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
argocd login localhost:8080 --username admin --password "$ARGOCD_PASS" --insecure || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Creating guestbook application"
echo "----------------------------------------------------------------------"
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace guestbook \
  --sync-option CreateNamespace=true || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Syncing guestbook application"
echo "----------------------------------------------------------------------"
argocd app sync guestbook || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Waiting for application to be Healthy"
echo "----------------------------------------------------------------------"
argocd app wait guestbook --health --timeout 120 || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Application status"
echo "----------------------------------------------------------------------"
argocd app get guestbook || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Resources deployed in guestbook namespace"
echo "----------------------------------------------------------------------"
kubectl get all -n guestbook || true

# Cleanup port-forward
kill $PF_PID 2>/dev/null || true
