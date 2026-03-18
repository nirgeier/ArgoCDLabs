#!/bin/bash

###
### Notifications lab - inspect notification controller and config
###

ROOT_FOLDER=$(git rev-parse --show-toplevel)
source $ROOT_FOLDER/_utils/common.sh 2>/dev/null || true

echo "----------------------------------------------------------------------"
echo "* Notifications controller pod"
echo "----------------------------------------------------------------------"
kubectl get pods -n argocd | grep notifications || true

echo ""
echo "----------------------------------------------------------------------"
echo "* argocd-notifications-cm contents"
echo "----------------------------------------------------------------------"
kubectl get cm argocd-notifications-cm -n argocd -o yaml || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Annotating guestbook app for notifications"
echo "----------------------------------------------------------------------"
kubectl annotate application guestbook -n argocd \
  "notifications.argoproj.io/subscribe.on-sync-succeeded.slack=general" \
  --overwrite 2>/dev/null || echo "guestbook app not found"

echo ""
echo "----------------------------------------------------------------------"
echo "* Notifications controller logs (last 20 lines)"
echo "----------------------------------------------------------------------"
kubectl logs -n argocd deploy/argocd-notifications-controller --tail=20 || true
