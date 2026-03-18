#!/bin/bash

set -euo pipefail

###
### Waves and Hooks lab - demonstrate sync phases and wave ordering
###

ROOT_FOLDER=$(git rev-parse --show-toplevel)
source "$ROOT_FOLDER/_utils/common.sh"
source $ROOT_FOLDER/_utils/common.sh 2>/dev/null || true

kubectl port-forward svc/argocd-server -n argocd 8080:443 &
PF_PID=$!
sleep 3

ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
argocd login localhost:8080 --username admin --password "$ARGOCD_PASS" --insecure || true

echo "----------------------------------------------------------------------"
echo "* Creating PreSync hook"
echo "----------------------------------------------------------------------"
cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: presync-demo
  namespace: guestbook
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
spec:
  template:
    spec:
      containers:
        - name: demo
          image: alpine:3.18
          command: [sh, -c, "echo 'PreSync hook running!' && sleep 2 && echo 'PreSync done!'"]
      restartPolicy: Never
EOF

echo ""
echo "----------------------------------------------------------------------"
echo "* Triggering sync to run the hook"
echo "----------------------------------------------------------------------"
argocd app sync guestbook || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Jobs in guestbook namespace (hook jobs)"
echo "----------------------------------------------------------------------"
kubectl get jobs -n guestbook || true

echo ""
echo "----------------------------------------------------------------------"
echo "* Hook job logs"
echo "----------------------------------------------------------------------"
kubectl logs job/presync-demo -n guestbook 2>/dev/null || true

kill $PF_PID 2>/dev/null || true
