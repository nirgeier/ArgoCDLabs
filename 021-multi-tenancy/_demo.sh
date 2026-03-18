#!/bin/bash

###
### Multi-Tenancy lab - namespace isolation and project boundaries
###

set -euo pipefail

ROOT_FOLDER=$(git rev-parse --show-toplevel)
source $ROOT_FOLDER/_utils/common.sh 2>/dev/null || true

echo "----------------------------------------------------------------------"
echo "* Multi-Tenancy in ArgoCD"
echo "----------------------------------------------------------------------"

if ! command -v kubectl &>/dev/null; then
  echo ">>> kubectl not found – showing concepts only"
  echo "DONE: Multi-Tenancy lab concepts reviewed"
  exit 0
fi

echo ""
echo "----------------------------------------------------------------------"
echo "* Step 1: Create tenant namespaces"
echo "----------------------------------------------------------------------"
NAMESPACES=("team-alpha" "team-beta" "team-gamma")

for ns in "${NAMESPACES[@]}"; do
  echo ">>> Creating namespace: ${ns}"
  kubectl create namespace "${ns}" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
  kubectl label namespace "${ns}" tenant="${ns}" --overwrite 2>/dev/null || true
done

echo ""
echo "----------------------------------------------------------------------"
echo "* Step 2: Define ArgoCD AppProject per tenant"
echo "----------------------------------------------------------------------"
echo ">>> Creating AppProject for team-alpha..."

cat <<'YAML'
# AppProject restricts what team-alpha can deploy and where
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-alpha
  namespace: argocd
spec:
  description: "Team Alpha project - restricted to their namespace"
  sourceRepos:
    - "https://github.com/team-alpha/*"
  destinations:
    - namespace: team-alpha
      server: https://kubernetes.default.svc
  clusterResourceWhitelist: []    # No cluster-level resources
  namespaceResourceWhitelist:
    - group: "apps"
      kind: Deployment
    - group: ""
      kind: Service
    - group: ""
      kind: ConfigMap
YAML

echo ""
echo "----------------------------------------------------------------------"
echo "* Step 3: RBAC for tenant isolation"
echo "----------------------------------------------------------------------"
echo ">>> ArgoCD RBAC policy for team-alpha..."

cat <<'POLICY'
# argocd-rbac-cm ConfigMap
p, role:team-alpha, applications, get, team-alpha/*, allow
p, role:team-alpha, applications, create, team-alpha/*, allow
p, role:team-alpha, applications, update, team-alpha/*, allow
p, role:team-alpha, applications, delete, team-alpha/*, allow
p, role:team-alpha, applications, sync, team-alpha/*, allow

g, team-alpha-devs, role:team-alpha
POLICY

echo ""
echo "----------------------------------------------------------------------"
echo "* Step 4: Verify namespace isolation"
echo "----------------------------------------------------------------------"
for ns in "${NAMESPACES[@]}"; do
  echo ">>> Namespace ${ns} labels:"
  kubectl get namespace "${ns}" --show-labels 2>/dev/null | grep -v "^NAME" || true
done

echo ""
echo "DONE: Multi-Tenancy lab completed"
