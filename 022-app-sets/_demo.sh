#!/bin/bash

###
### ApplicationSets lab - List, Cluster, and Git generators
###

set -euo pipefail

ROOT_FOLDER=$(git rev-parse --show-toplevel)
source $ROOT_FOLDER/_utils/common.sh 2>/dev/null || true

echo "----------------------------------------------------------------------"
echo "* ArgoCD ApplicationSets"
echo "----------------------------------------------------------------------"

echo ""
echo "----------------------------------------------------------------------"
echo "* Step 1: List Generator example"
echo "----------------------------------------------------------------------"
echo ">>> ApplicationSet with List generator – deploy to multiple environments:"

cat <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: guestbook-appset
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - cluster: dev
            url: https://kubernetes.default.svc
            namespace: guestbook-dev
          - cluster: staging
            url: https://kubernetes.default.svc
            namespace: guestbook-staging
          - cluster: prod
            url: https://kubernetes.default.svc
            namespace: guestbook-prod
  template:
    metadata:
      name: "guestbook-{{cluster}}"
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps
        targetRevision: HEAD
        path: guestbook
      destination:
        server: "{{url}}"
        namespace: "{{namespace}}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
YAML

echo ""
echo "----------------------------------------------------------------------"
echo "* Step 2: Git Generator example"
echo "----------------------------------------------------------------------"
echo ">>> ApplicationSet with Git generator – auto-discover apps from repo:"

cat <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: git-generator-appset
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/argoproj/argocd-example-apps
        revision: HEAD
        directories:
          - path: "apps/*"
  template:
    metadata:
      name: "{{path.basename}}"
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps
        targetRevision: HEAD
        path: "{{path}}"
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{path.basename}}"
      syncPolicy:
        syncOptions:
          - CreateNamespace=true
YAML

echo ""
echo "----------------------------------------------------------------------"
echo "* Step 3: Apply ApplicationSet to cluster (dry run)"
echo "----------------------------------------------------------------------"
if kubectl get namespace argocd >/dev/null 2>&1; then
  echo ">>> ArgoCD namespace found – creating ApplicationSet (dry run)..."
  cat <<'YAML' | kubectl apply --dry-run=client -f - 2>/dev/null || echo "(skipped - CRD may not be installed)"
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: demo-appset
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - env: demo
            namespace: demo-app
  template:
    metadata:
      name: "demo-{{env}}"
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps
        targetRevision: HEAD
        path: guestbook
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{namespace}}"
YAML
else
  echo ">>> ArgoCD not installed – showing ApplicationSet manifest only (above)"
fi

echo ""
echo "DONE: ApplicationSets lab completed"
