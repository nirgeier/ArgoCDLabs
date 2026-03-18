#!/bin/bash

###
### Secrets Management lab - Sealed Secrets demo
###

ROOT_FOLDER=$(git rev-parse --show-toplevel)
source $ROOT_FOLDER/_utils/common.sh 2>/dev/null || true

echo "----------------------------------------------------------------------"
echo "* Installing Sealed Secrets controller"
echo "----------------------------------------------------------------------"
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/latest/download/controller.yaml || true

echo ""
echo "* Waiting for Sealed Secrets controller..."
kubectl wait --for=condition=Ready pods \
  -l name=sealed-secrets-controller \
  -n kube-system --timeout=120s || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Sealed Secrets controller pod"
echo "----------------------------------------------------------------------"
kubectl get pods -n kube-system | grep sealed-secrets || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Creating and sealing a test secret"
echo "----------------------------------------------------------------------"
if command -v kubeseal &>/dev/null; then
  kubectl create secret generic demo-secret \
    --from-literal=password=hello-world \
    --dry-run=client -o yaml | \
    kubeseal --format yaml > /tmp/demo-sealed.yaml
  echo "Sealed secret created at /tmp/demo-sealed.yaml:"
  cat /tmp/demo-sealed.yaml
  kubectl apply -f /tmp/demo-sealed.yaml || true
  sleep 5
  echo ""
  echo "Decrypted value:"
  kubectl get secret demo-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d && echo || true
else
  echo "kubeseal not installed. Install with: brew install kubeseal"
fi
