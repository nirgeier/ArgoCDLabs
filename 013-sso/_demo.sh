#!/bin/bash

set -euo pipefail

###
### SSO lab - inspect Dex server and SSO configuration
###

ROOT_FOLDER=$(git rev-parse --show-toplevel)
source "$ROOT_FOLDER/_utils/common.sh"
source $ROOT_FOLDER/_utils/common.sh 2>/dev/null || true

echo "----------------------------------------------------------------------"
echo "* Dex server pod status"
echo "----------------------------------------------------------------------"
kubectl get pods -n argocd | grep dex

echo ""
echo "----------------------------------------------------------------------"
echo "* Dex server logs"
echo "----------------------------------------------------------------------"
kubectl logs -n argocd deploy/argocd-dex-server --tail=20 || true

echo ""
echo "----------------------------------------------------------------------"
echo "* argocd-cm SSO configuration"
echo "----------------------------------------------------------------------"
kubectl get cm argocd-cm -n argocd -o yaml | grep -A 20 "dex.config" || echo "No dex.config found"

echo ""
echo "----------------------------------------------------------------------"
echo "* argocd-secret keys (not values)"
echo "----------------------------------------------------------------------"
kubectl get secret argocd-secret -n argocd \
  -o jsonpath='{.data}' | python3 -c \
  "import sys,json; [print(k) for k in json.load(sys.stdin).keys()]" || true
