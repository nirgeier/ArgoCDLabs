#!/bin/bash

set -euo pipefail

###
### Git Repo Connect lab - connect repos and verify connectivity
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
echo "* Adding public example-apps repo"
echo "----------------------------------------------------------------------"
argocd repo add https://github.com/argoproj/argocd-example-apps.git || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Adding Bitnami Helm repo"
echo "----------------------------------------------------------------------"
argocd repo add https://charts.bitnami.com/bitnami \
  --type helm \
  --name bitnami || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Listing all repositories"
echo "----------------------------------------------------------------------"
argocd repo list

echo ""
echo "----------------------------------------------------------------------"
echo "* Repo secrets in argocd namespace"
echo "----------------------------------------------------------------------"
kubectl get secrets -n argocd \
  -l "argocd.argoproj.io/secret-type=repository" || true

kill $PF_PID 2>/dev/null || true
