#!/bin/bash

###
### Advanced Patterns lab - Config Management Plugins, API automation, drift remediation
###

set -euo pipefail

ROOT_FOLDER=$(git rev-parse --show-toplevel)
source $ROOT_FOLDER/_utils/common.sh 2>/dev/null || true

echo "----------------------------------------------------------------------"
echo "* Advanced ArgoCD Patterns"
echo "----------------------------------------------------------------------"

echo ""
echo "----------------------------------------------------------------------"
echo "* Step 1: Config Management Plugin (CMP) example"
echo "----------------------------------------------------------------------"
echo ">>> CMP allows custom templating engines (e.g., jsonnet, cdk8s):"

cat <<'YAML'
# argocd-cm ConfigMap - register custom plugin
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  configManagementPlugins: |
    - name: my-jsonnet-plugin
      generate:
        command: ["sh", "-c"]
        args: ["jsonnet . -J vendor"]
YAML

echo ""
echo "----------------------------------------------------------------------"
echo "* Step 2: ArgoCD API automation with curl"
echo "----------------------------------------------------------------------"
echo ">>> Get ArgoCD token via API:"

cat <<'BASH'
# Login via API
ARGOCD_TOKEN=$(curl -s https://argocd.example.com/api/v1/session \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"secret"}' | jq -r .token)

# Create application via API
curl -s https://argocd.example.com/api/v1/applications \
  -H "Authorization: Bearer $ARGOCD_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "metadata": {"name": "my-api-app"},
    "spec": {
      "project": "default",
      "source": {
        "repoURL": "https://github.com/org/repo",
        "targetRevision": "HEAD",
        "path": "manifests"
      },
      "destination": {
        "server": "https://kubernetes.default.svc",
        "namespace": "my-namespace"
      }
    }
  }'
BASH

echo ""
echo "----------------------------------------------------------------------"
echo "* Step 3: Drift detection and automated remediation"
echo "----------------------------------------------------------------------"
echo ">>> SelfHeal + Prune policy for strict drift remediation:"

cat <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: strict-app
  namespace: argocd
spec:
  syncPolicy:
    automated:
      prune: true          # Remove resources deleted from Git
      selfHeal: true       # Revert manual changes automatically
      allowEmpty: false    # Never sync empty state
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
    syncOptions:
      - Validate=true
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
YAML

echo ""
echo "----------------------------------------------------------------------"
echo "* Step 4: Resource hooks for complex deployments"
echo "----------------------------------------------------------------------"
echo ">>> PreSync hook to run database migration before app deploys:"

cat <<'YAML'
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migrate
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
        - name: migrate
          image: my-app:latest
          command: ["python", "manage.py", "migrate"]
      restartPolicy: Never
YAML

echo ""
echo "----------------------------------------------------------------------"
echo "* Step 5: Verify ArgoCD health"
echo "----------------------------------------------------------------------"
if kubectl get namespace argocd >/dev/null 2>&1; then
  echo ">>> ArgoCD component status:"
  kubectl get pods -n argocd 2>/dev/null || true
  echo ""
  echo ">>> ArgoCD version:"
  argocd version --client 2>/dev/null || kubectl get deploy argocd-server -n argocd -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true
else
  echo ">>> ArgoCD not installed in cluster"
fi

echo ""
echo "DONE: Advanced Patterns lab completed"
