#!/bin/bash

set -euo pipefail

###
### Multi-Cluster lab - register and deploy to a second cluster
###

ROOT_FOLDER=$(git rev-parse --show-toplevel)
source "$ROOT_FOLDER/_utils/common.sh"
source $ROOT_FOLDER/_utils/common.sh 2>/dev/null || true

echo "----------------------------------------------------------------------"
echo "* Creating second kind cluster: argocd-workload"
echo "----------------------------------------------------------------------"
kind delete cluster --name argocd-workload 2>/dev/null || true
kind create cluster --name argocd-workload --wait 60s

echo ""
echo "----------------------------------------------------------------------"
echo "* Switching back to argocd-labs context"
echo "----------------------------------------------------------------------"
kubectl config use-context kind-argocd-labs

kubectl port-forward svc/argocd-server -n argocd 8080:443 &
PF_PID=$!
sleep 3

ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
argocd login localhost:8080 --username admin --password "$ARGOCD_PASS" --insecure || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Registering workload cluster"
echo "----------------------------------------------------------------------"
argocd cluster add kind-argocd-workload --name workload-cluster --yes || true
argocd cluster list

echo ""
echo "----------------------------------------------------------------------"
echo "* Deploying guestbook to workload cluster"
echo "----------------------------------------------------------------------"
argocd app create guestbook-remote \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-name workload-cluster \
  --dest-namespace guestbook \
  --sync-option CreateNamespace=true || true
argocd app sync guestbook-remote || true
argocd app wait guestbook-remote --health --timeout 120 || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Pods in workload cluster"
echo "----------------------------------------------------------------------"
kubectl get pods -n guestbook --context kind-argocd-workload || true

kill $PF_PID 2>/dev/null || true
