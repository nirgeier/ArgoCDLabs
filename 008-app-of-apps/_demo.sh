#!/bin/bash

###
### App-of-Apps lab - create root app that manages child apps
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
echo "* Creating root application"
echo "----------------------------------------------------------------------"
argocd app create root-app \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path apps \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace argocd \
  --sync-policy automated \
  --auto-prune \
  --self-heal || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Syncing root application"
echo "----------------------------------------------------------------------"
argocd app sync root-app || true
sleep 15

echo ""
echo "----------------------------------------------------------------------"
echo "* All applications (root + children)"
echo "----------------------------------------------------------------------"
argocd app list

kill $PF_PID 2>/dev/null || true
