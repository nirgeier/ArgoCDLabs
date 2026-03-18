#!/bin/bash

###
### Progressive Delivery lab - Argo Rollouts: Canary, Blue/Green
###

set -euo pipefail

ROOT_FOLDER=$(git rev-parse --show-toplevel)
source $ROOT_FOLDER/_utils/common.sh 2>/dev/null || true

echo "----------------------------------------------------------------------"
echo "* Progressive Delivery with Argo Rollouts"
echo "----------------------------------------------------------------------"

echo ""
echo "----------------------------------------------------------------------"
echo "* Step 1: Install Argo Rollouts controller (concept)"
echo "----------------------------------------------------------------------"
echo ">>> Install command:"
echo "    kubectl create namespace argo-rollouts"
echo "    kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml"

echo ""
echo "----------------------------------------------------------------------"
echo "* Step 2: Canary Rollout example"
echo "----------------------------------------------------------------------"
echo ">>> Rollout with 20% canary steps:"

cat <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-app-rollout
spec:
  replicas: 5
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: my-app
          image: my-app:v1
          ports:
            - containerPort: 8080
  strategy:
    canary:
      steps:
        - setWeight: 20       # Send 20% traffic to canary
        - pause: {duration: 30s}
        - setWeight: 40
        - pause: {duration: 30s}
        - setWeight: 60
        - pause: {duration: 30s}
        - setWeight: 80
        - pause: {}           # Wait for manual promotion
      canaryService: my-app-canary
      stableService: my-app-stable
YAML

echo ""
echo "----------------------------------------------------------------------"
echo "* Step 3: Blue/Green Rollout example"
echo "----------------------------------------------------------------------"

cat <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-app-bluegreen
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app-bg
  template:
    metadata:
      labels:
        app: my-app-bg
    spec:
      containers:
        - name: my-app
          image: my-app:v2
  strategy:
    blueGreen:
      activeService: my-app-active
      previewService: my-app-preview
      autoPromotionEnabled: false   # Require manual promotion
      scaleDownDelaySeconds: 30
YAML

echo ""
echo "----------------------------------------------------------------------"
echo "* Step 4: Rollout kubectl plugin commands"
echo "----------------------------------------------------------------------"
echo ">>> Key commands after installing kubectl-argo-rollouts plugin:"
echo "    kubectl argo rollouts list rollouts"
echo "    kubectl argo rollouts get rollout my-app-rollout --watch"
echo "    kubectl argo rollouts promote my-app-rollout"
echo "    kubectl argo rollouts abort my-app-rollout"
echo "    kubectl argo rollouts undo my-app-rollout"

# Check if Argo Rollouts is installed
if kubectl get namespace argo-rollouts >/dev/null 2>&1; then
  echo ""
  echo ">>> Argo Rollouts found in cluster:"
  kubectl get pods -n argo-rollouts 2>/dev/null || true
fi

echo ""
echo "DONE: Progressive Delivery lab completed"
