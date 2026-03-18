#!/bin/bash

###
### Helm Integration lab - deploy Helm charts via ArgoCD
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
echo "* Creating nginx Helm application"
echo "----------------------------------------------------------------------"
argocd app create nginx-helm \
  --repo https://charts.bitnami.com/bitnami \
  --helm-chart nginx \
  --revision 15.0.0 \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace nginx-helm \
  --helm-set replicaCount=1 \
  --helm-set service.type=ClusterIP \
  --sync-option CreateNamespace=true || true

argocd app sync nginx-helm || true
argocd app wait nginx-helm --health --timeout 180 || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Application status"
echo "----------------------------------------------------------------------"
argocd app get nginx-helm || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Rendered manifests (first 50 lines)"
echo "----------------------------------------------------------------------"
argocd app manifests nginx-helm 2>/dev/null | head -50 || true

kill $PF_PID 2>/dev/null || true
