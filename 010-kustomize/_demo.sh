#!/bin/bash

###
### Kustomize lab - deploy Kustomize apps via ArgoCD
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
echo "* Creating kustomize-guestbook application"
echo "----------------------------------------------------------------------"
argocd app create kustomize-guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path kustomize-guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace kustomize-guestbook \
  --sync-option CreateNamespace=true || true

argocd app sync kustomize-guestbook || true
argocd app wait kustomize-guestbook --health --timeout 120 || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Rendered manifests"
echo "----------------------------------------------------------------------"
argocd app manifests kustomize-guestbook 2>/dev/null | head -60 || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Resources deployed"
echo "----------------------------------------------------------------------"
kubectl get all -n kustomize-guestbook || true

kill $PF_PID 2>/dev/null || true
