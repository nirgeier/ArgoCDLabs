#!/bin/bash

###
### Setup lab - create a kind cluster and install ArgoCD
###

# Get the root folder of our demo folder
ROOT_FOLDER=$(git rev-parse --show-toplevel)

# Load the common script
source $ROOT_FOLDER/_utils/common.sh 2>/dev/null || true

CLUSTER_NAME="argocd-labs"

echo "----------------------------------------------------------------------"
echo "* Creating kind cluster: ${CLUSTER_NAME}"
echo "----------------------------------------------------------------------"

# Check if kind is installed
if ! command -v kind &>/dev/null; then
  echo "kind not found. Please install kind first: https://kind.sigs.k8s.io/"
  exit 1
fi

# Delete existing cluster if present
kind delete cluster --name "${CLUSTER_NAME}" 2>/dev/null || true

# Create the cluster
kind create cluster --name "${CLUSTER_NAME}" --wait 60s

echo ""
echo "----------------------------------------------------------------------"
echo "* Verifying cluster nodes"
echo "----------------------------------------------------------------------"
kubectl get nodes --context "kind-${CLUSTER_NAME}"

echo ""
echo "----------------------------------------------------------------------"
echo "* Installing ArgoCD"
echo "----------------------------------------------------------------------"

kubectl create namespace argocd || true

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo ""
echo "* Waiting for ArgoCD pods to be ready (up to 5 minutes)..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s || true

echo ""
echo "----------------------------------------------------------------------"
echo "* ArgoCD pods status"
echo "----------------------------------------------------------------------"
kubectl get pods -n argocd

echo ""
echo "----------------------------------------------------------------------"
echo "* ArgoCD CRDs"
echo "----------------------------------------------------------------------"
kubectl get crd | grep argoproj || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Initial admin password"
echo "----------------------------------------------------------------------"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d && echo || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Setup complete!"
echo "* Run: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "* Then open: https://localhost:8080"
echo "----------------------------------------------------------------------"
