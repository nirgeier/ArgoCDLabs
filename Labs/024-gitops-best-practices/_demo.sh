#!/bin/bash

###
### GitOps Best Practices lab - repo structure, promotion strategies
###

set -euo pipefail

ROOT_FOLDER=$(git rev-parse --show-toplevel)
source "$ROOT_FOLDER/_utils/common.sh"
source $ROOT_FOLDER/_utils/common.sh 2>/dev/null || true

echo "----------------------------------------------------------------------"
echo "* GitOps Best Practices"
echo "----------------------------------------------------------------------"

echo ""
echo "----------------------------------------------------------------------"
echo "* Step 1: Recommended mono-repo structure"
echo "----------------------------------------------------------------------"
cat <<'TREE'
my-gitops-repo/
├── apps/                     # ArgoCD Application manifests
│   ├── dev/
│   │   ├── app-a.yaml
│   │   └── app-b.yaml
│   ├── staging/
│   │   ├── app-a.yaml
│   │   └── app-b.yaml
│   └── prod/
│       ├── app-a.yaml
│       └── app-b.yaml
├── infra/                    # Infrastructure charts
│   ├── cert-manager/
│   ├── ingress-nginx/
│   └── monitoring/
└── services/                 # Application source manifests
    ├── app-a/
    │   ├── base/
    │   │   ├── deployment.yaml
    │   │   └── service.yaml
    │   └── overlays/
    │       ├── dev/
    │       ├── staging/
    │       └── prod/
    └── app-b/
TREE

echo ""
echo "----------------------------------------------------------------------"
echo "* Step 2: Environment promotion workflow"
echo "----------------------------------------------------------------------"
echo ">>> Promotion via image tag update (CI writes back to Git):"

cat <<'YAML'
# GitHub Actions promotion step
- name: Update image tag in dev
  run: |
    cd gitops-repo
    yq e ".spec.source.helm.values |= sub(\"tag: .*\", \"tag: ${{ github.sha }}\")" \
      -i apps/dev/my-app.yaml
    git commit -am "promote my-app:${{ github.sha }} to dev"
    git push
YAML

echo ""
echo "----------------------------------------------------------------------"
echo "* Step 3: Branch strategy best practices"
echo "----------------------------------------------------------------------"
echo ">>> Recommended Git branching for GitOps:"
echo "    main          - Production environment"
echo "    staging       - Staging environment (auto-promote from dev)"
echo "    dev           - Development environment (auto-promote from CI)"
echo ""
echo ">>> ArgoCD watches different branches per environment:"

cat <<'YAML'
# Production App watches 'main' branch
spec:
  source:
    repoURL: https://github.com/org/gitops-repo
    targetRevision: main
    path: apps/prod

# Dev App watches 'dev' branch
spec:
  source:
    repoURL: https://github.com/org/gitops-repo
    targetRevision: dev
    path: apps/dev
YAML

echo ""
echo "----------------------------------------------------------------------"
echo "* Step 4: Drift detection and remediation"
echo "----------------------------------------------------------------------"
if command -v argocd &>/dev/null; then
  echo ">>> Checking for drifted applications..."
  argocd app list --output wide 2>/dev/null | grep -v "Synced" || echo "(no drifted apps or argocd not connected)"
else
  echo ">>> argocd CLI not available – in practice run:"
  echo "    argocd app list --output wide | grep -v Synced"
fi

echo ""
echo "----------------------------------------------------------------------"
echo "* Step 5: Secret management strategy"
echo "----------------------------------------------------------------------"
echo ">>> Options for GitOps-compatible secrets:"
echo "    1. Sealed Secrets    - encrypt secrets into Git"
echo "    2. External Secrets  - reference secrets from Vault/AWS/GCP"
echo "    3. SOPS              - encrypt secret files before committing"
echo "    4. ArgoCD Vault      - Vault plugin for ArgoCD"

echo ""
echo "DONE: GitOps Best Practices lab completed"
