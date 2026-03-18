#!/bin/bash

###
### Disaster Recovery lab - backup and restore ArgoCD state
###

set -euo pipefail

ROOT_FOLDER=$(git rev-parse --show-toplevel)
source "$ROOT_FOLDER/_utils/common.sh"
source $ROOT_FOLDER/_utils/common.sh 2>/dev/null || true

echo "----------------------------------------------------------------------"
echo "* ArgoCD Disaster Recovery - Backup & Restore"
echo "----------------------------------------------------------------------"

# Check prerequisites
if ! command -v argocd &>/dev/null; then
  echo ">>> argocd CLI not found – install with: curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
  echo ">>> Showing backup concepts instead..."
fi

if ! command -v kubectl &>/dev/null; then
  echo ">>> kubectl not found – skipping cluster commands"
  echo "DONE: Disaster Recovery lab concepts reviewed"
  exit 0
fi

echo ""
echo "----------------------------------------------------------------------"
echo "* Step 1: Export ArgoCD application manifests (backup)"
echo "----------------------------------------------------------------------"
echo ">>> Export all ArgoCD Application CRs to backup directory..."
mkdir -p /tmp/argocd-backup

# Export applications if ArgoCD is available
if kubectl get namespace argocd >/dev/null 2>&1; then
  kubectl get applications -n argocd -o yaml > /tmp/argocd-backup/applications.yaml 2>/dev/null || echo "(no applications found)"
  kubectl get appprojects -n argocd -o yaml > /tmp/argocd-backup/appprojects.yaml 2>/dev/null || echo "(no projects found)"
  kubectl get secret -n argocd -l "argocd.argoproj.io/secret-type=repository" -o yaml > /tmp/argocd-backup/repositories.yaml 2>/dev/null || echo "(no repo secrets found)"
  echo ">>> Backed up to /tmp/argocd-backup/"
  ls /tmp/argocd-backup/
else
  echo ">>> ArgoCD namespace not found – creating example backup files..."
  cat > /tmp/argocd-backup/applications.yaml <<'YAML'
# Example Application backup
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/repo
    targetRevision: HEAD
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: default
YAML
  echo ">>> Created example backup at /tmp/argocd-backup/applications.yaml"
fi

echo ""
echo "----------------------------------------------------------------------"
echo "* Step 2: Restore procedure (dry run)"
echo "----------------------------------------------------------------------"
echo ">>> Restore command: kubectl apply -f /tmp/argocd-backup/"
echo ">>> In a real disaster scenario:"
echo "    1. Install fresh ArgoCD cluster"
echo "    2. Apply backed-up Application CRs"
echo "    3. ArgoCD will re-sync all apps from Git"
echo "    4. No data loss – Git is the source of truth"

echo ""
echo "----------------------------------------------------------------------"
echo "* Step 3: High Availability setup concepts"
echo "----------------------------------------------------------------------"
echo ">>> ArgoCD HA components:"
echo "    - argocd-server:          Run 2+ replicas"
echo "    - argocd-repo-server:     Run 2+ replicas"
echo "    - argocd-application-controller: StatefulSet (1 per shard)"
echo "    - Redis HA:               Use redis-ha chart"

cat /tmp/argocd-backup/applications.yaml
echo ""
echo "DONE: Disaster Recovery lab completed"
