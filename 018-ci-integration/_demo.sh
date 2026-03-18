#!/bin/bash

###
### CI Integration lab - connect CI pipelines to ArgoCD for GitOps deployments
###

set -euo pipefail

ROOT_FOLDER=$(git rev-parse --show-toplevel)
source $ROOT_FOLDER/_utils/common.sh 2>/dev/null || true

kubectl port-forward svc/argocd-server -n argocd 8080:443 &
PF_PID=$!
sleep 3

ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
argocd login localhost:8080 --username admin --password "$ARGOCD_PASS" --insecure || true

echo "----------------------------------------------------------------------"
echo "* Creating a CI service account for automated deployments"
echo "----------------------------------------------------------------------"
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argocd-ci-bot
  namespace: argocd
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: argocd-ci-bot-role
  namespace: argocd
rules:
  - apiGroups: [argoproj.io]
    resources: [applications]
    verbs: [get, list, patch, update]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: argocd-ci-bot-rolebinding
  namespace: argocd
subjects:
  - kind: ServiceAccount
    name: argocd-ci-bot
    namespace: argocd
roleRef:
  kind: Role
  name: argocd-ci-bot-role
  apiGroup: rbac.authorization.k8s.io
EOF

echo ""
echo "----------------------------------------------------------------------"
echo "* Creating an ArgoCD local user for CI (argocd-params configmap)"
echo "----------------------------------------------------------------------"
kubectl -n argocd patch configmap argocd-cm \
  --patch '{"data":{"accounts.ci-bot":"apiKey"}}' || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Generating an API token for the ci-bot user"
echo "----------------------------------------------------------------------"
CI_TOKEN=$(argocd account generate-token --account ci-bot 2>/dev/null) || true
if [ -n "${CI_TOKEN:-}" ]; then
  echo "CI token generated (first 20 chars): ${CI_TOKEN:0:20}..."
  echo "Store this token as a CI secret (e.g., ARGOCD_AUTH_TOKEN)"
else
  echo "Could not generate token - ci-bot account may not be configured yet"
fi

echo ""
echo "----------------------------------------------------------------------"
echo "* Demonstrating a typical CI sync command"
echo "----------------------------------------------------------------------"
echo "In CI pipelines, after pushing an image, trigger ArgoCD sync with:"
echo ""
echo "  argocd app sync my-app \\"
echo "    --server argocd.example.com \\"
echo "    --auth-token \$ARGOCD_AUTH_TOKEN \\"
echo "    --insecure \\"
echo "    --revision \$GIT_SHA"
echo ""
echo "  argocd app wait my-app \\"
echo "    --server argocd.example.com \\"
echo "    --auth-token \$ARGOCD_AUTH_TOKEN \\"
echo "    --health --timeout 300"

echo ""
echo "----------------------------------------------------------------------"
echo "* Current ArgoCD accounts"
echo "----------------------------------------------------------------------"
argocd account list || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Creating a demo app to simulate CI-triggered sync"
echo "----------------------------------------------------------------------"
argocd app create ci-demo \
  --repo https://github.com/argoproj/argocd-example-apps \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace ci-demo \
  --sync-option CreateNamespace=true \
  --upsert || true

argocd app sync ci-demo --timeout 60 || true
argocd app wait ci-demo --health --timeout 90 || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Application health after CI-triggered sync"
echo "----------------------------------------------------------------------"
argocd app get ci-demo || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Cleanup"
echo "----------------------------------------------------------------------"
argocd app delete ci-demo --yes 2>/dev/null || true
kill $PF_PID 2>/dev/null || true
