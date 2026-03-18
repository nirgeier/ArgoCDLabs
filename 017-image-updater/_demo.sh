#!/bin/bash

###
### Image Updater lab - install and configure ArgoCD Image Updater
###

ROOT_FOLDER=$(git rev-parse --show-toplevel)
source $ROOT_FOLDER/_utils/common.sh 2>/dev/null || true

echo "----------------------------------------------------------------------"
echo "* Installing ArgoCD Image Updater"
echo "----------------------------------------------------------------------"
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml || true

echo ""
echo "* Waiting for Image Updater pod..."
kubectl wait --for=condition=Ready pods \
  -l app.kubernetes.io/name=argocd-image-updater \
  -n argocd --timeout=120s || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Image Updater pod status"
echo "----------------------------------------------------------------------"
kubectl get pods -n argocd | grep image-updater || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Annotating guestbook application"
echo "----------------------------------------------------------------------"
kubectl annotate application guestbook -n argocd \
  "argocd-image-updater.argoproj.io/image-list=ks=gcr.io/heptio-images/ks-guestbook-demo" \
  "argocd-image-updater.argoproj.io/ks.update-strategy=latest" \
  "argocd-image-updater.argoproj.io/write-back-method=argocd" \
  --overwrite 2>/dev/null || echo "guestbook app not found"

echo ""
echo "----------------------------------------------------------------------"
echo "* Image Updater logs"
echo "----------------------------------------------------------------------"
kubectl logs -n argocd deploy/argocd-image-updater --tail=30 || true
