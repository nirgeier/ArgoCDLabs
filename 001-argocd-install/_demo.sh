#!/bin/bash

set -euo pipefail

###
### ArgoCD Install lab - explore ArgoCD components and CRDs
###

ROOT_FOLDER=$(git rev-parse --show-toplevel)
source "$ROOT_FOLDER/_utils/common.sh"
source $ROOT_FOLDER/_utils/common.sh 2>/dev/null || true

echo "----------------------------------------------------------------------"
echo "* ArgoCD pods in the argocd namespace"
echo "----------------------------------------------------------------------"
kubectl get pods -n argocd

echo ""
echo "----------------------------------------------------------------------"
echo "* ArgoCD services"
echo "----------------------------------------------------------------------"
kubectl get svc -n argocd

echo ""
echo "----------------------------------------------------------------------"
echo "* ArgoCD CRDs"
echo "----------------------------------------------------------------------"
kubectl get crd | grep argoproj.io || true

echo ""
echo "----------------------------------------------------------------------"
echo "* argocd-cm ConfigMap"
echo "----------------------------------------------------------------------"
kubectl get cm argocd-cm -n argocd -o yaml || true

echo ""
echo "----------------------------------------------------------------------"
echo "* argocd-rbac-cm ConfigMap"
echo "----------------------------------------------------------------------"
kubectl get cm argocd-rbac-cm -n argocd -o yaml || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Application controller StatefulSet"
echo "----------------------------------------------------------------------"
kubectl describe statefulset argocd-application-controller -n argocd || true
