#!/bin/bash

set -euo pipefail

###
### Projects lab - create and configure AppProjects
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
echo "* Existing projects"
echo "----------------------------------------------------------------------"
argocd proj list

echo ""
echo "----------------------------------------------------------------------"
echo "* Creating team-alpha project"
echo "----------------------------------------------------------------------"
argocd proj create team-alpha \
  --description "Team Alpha project" \
  --src "https://github.com/argoproj/*" \
  --dest "https://kubernetes.default.svc,team-alpha" || true

echo ""
echo "----------------------------------------------------------------------"
echo "* team-alpha project details"
echo "----------------------------------------------------------------------"
argocd proj get team-alpha || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Testing forbidden destination (should fail)"
echo "----------------------------------------------------------------------"
argocd app create forbidden-test \
  --project team-alpha \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace kube-system 2>&1 || echo "Expected failure: destination not permitted"

kill $PF_PID 2>/dev/null || true
