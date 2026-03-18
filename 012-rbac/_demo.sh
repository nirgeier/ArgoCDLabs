#!/bin/bash

###
### RBAC lab - inspect and configure ArgoCD RBAC
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
echo "* Current RBAC ConfigMap"
echo "----------------------------------------------------------------------"
kubectl get cm argocd-rbac-cm -n argocd -o yaml

echo ""
echo "----------------------------------------------------------------------"
echo "* ArgoCD accounts"
echo "----------------------------------------------------------------------"
argocd account list || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Adding developer role policy"
echo "----------------------------------------------------------------------"
kubectl patch cm argocd-rbac-cm -n argocd --type merge -p '{
  "data": {
    "policy.csv": "p, role:developer, applications, get, default/*, allow\np, role:developer, applications, sync, default/*, allow\n",
    "policy.default": "role:readonly"
  }
}' || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Updated RBAC policy"
echo "----------------------------------------------------------------------"
kubectl get cm argocd-rbac-cm -n argocd -o jsonpath='{.data.policy\.csv}' && echo

kill $PF_PID 2>/dev/null || true
