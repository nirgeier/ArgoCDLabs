---

# Advanced Patterns

* Config Management Plugins (CMP) extend ArgoCD to support any templating tool not natively supported.
* The ArgoCD API and `argocd` CLI enable automation: programmatic app creation, sync triggering, and status polling.
* Resource hooks and sync waves give fine-grained control over deployment ordering and lifecycle events.

## What will we learn?

- How to write and register a Config Management Plugin
- How to automate ArgoCD with the REST API and CLI
- How to use PreSync/PostSync hooks for database migrations and smoke tests
- How to use sync waves for ordered multi-component deployments
- How to detect and remediate drift programmatically

---

## Prerequisites

- Complete all previous labs
- Familiarity with Kubernetes RBAC and Helm

---

## 01. Config Management Plugin (CMP)

Add support for a custom templating engine (e.g., jsonnet):

```sh
# Register plugin in argocd-cm
kubectl patch configmap argocd-cm -n argocd --patch '
data:
  configManagementPlugins: |
    - name: jsonnet
      generate:
        command: ["sh", "-c"]
        args: ["jsonnet . -J vendor 2>&1"]
' 2>/dev/null || echo "(showing config only – requires running ArgoCD)"

# Use the plugin in an Application
kubectl apply -f - <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: jsonnet-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps
    targetRevision: HEAD
    path: jsonnet-guestbook
    plugin:
      name: jsonnet
  destination:
    server: https://kubernetes.default.svc
    namespace: jsonnet-app
YAML
```

---

## 02. ArgoCD REST API Automation

```sh
# Authenticate and get a token
ARGOCD_SERVER="localhost:8080"
TOKEN=$(argocd account generate-token 2>/dev/null || \
  curl -sk https://${ARGOCD_SERVER}/api/v1/session \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"secret"}' | jq -r .token)

# List all applications via API
curl -sk https://${ARGOCD_SERVER}/api/v1/applications \
  -H "Authorization: Bearer ${TOKEN}" | jq '.items[].metadata.name' 2>/dev/null || \
  echo "(requires running ArgoCD with port-forward)"

# Trigger sync via API
curl -sk -X POST https://${ARGOCD_SERVER}/api/v1/applications/guestbook/sync \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"revision":"HEAD"}' 2>/dev/null || true
```

---

## 03. Resource Hooks

```sh
# PreSync hook: run database migration before deployment
kubectl apply -f - <<'YAML'
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
          command: ["python", "manage.py", "migrate", "--noinput"]
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: db-secret
                  key: url
      restartPolicy: Never
  backoffLimit: 3
YAML

# PostSync hook: run smoke tests after deployment
kubectl apply -f - <<'YAML'
apiVersion: batch/v1
kind: Job
metadata:
  name: smoke-test
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
        - name: test
          image: curlimages/curl:latest
          command: ["sh", "-c", "curl -f http://my-app/healthz || exit 1"]
      restartPolicy: Never
YAML
```

---

## 04. Sync Waves for Ordered Deployment

```sh
# Wave 0: CRDs and namespaces (must exist first)
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: my-app
  annotations:
    argocd.argoproj.io/sync-wave: "0"
YAML

# Wave 1: Database
# Wave 2: Backend
# Wave 3: Frontend
# Wave 4: Ingress

# Resources deploy in wave order, each wave waits for the previous to be Healthy
```

---

## 05. Drift Detection and Remediation

```sh
# List all out-of-sync applications
argocd app list -o wide 2>/dev/null | grep -v "Synced" || \
  echo "argocd CLI not available"

# Force sync all OutOfSync apps (use with caution!)
argocd app list -o json 2>/dev/null | \
  jq -r '.[] | select(.status.sync.status=="OutOfSync") | .metadata.name' | \
  while read app; do
    echo "Syncing drifted app: ${app}"
    argocd app sync "${app}" --prune 2>/dev/null || true
  done

# Enable aggressive self-heal (ensures Git always wins)
argocd app set my-app \
  --self-heal \
  --sync-policy automated \
  --auto-prune 2>/dev/null || echo "(showing command – app not configured)"
```

---

## 06. Notification Triggers for Drift Alerts

```sh
# Add a notification trigger for OutOfSync state
kubectl patch configmap argocd-notifications-cm -n argocd --patch '
data:
  trigger.on-out-of-sync: |
    - when: app.status.sync.status == "OutOfSync"
      send: [slack-message]
  template.slack-message: |
    message: |
      Application {{.app.metadata.name}} is OutOfSync!
      Repo: {{.app.spec.source.repoURL}}
      Run: argocd app sync {{.app.metadata.name}}
' 2>/dev/null || echo "(showing config – requires argocd-notifications installed)"
```

---

## Hands-on Tasks

1. Register a simple Config Management Plugin that runs `envsubst` on YAML files
2. Write a shell script that uses the ArgoCD API to list all OutOfSync applications and sync them
3. Add a `PreSync` hook Job that prints "Migration complete" to simulate a DB migration
4. Apply sync wave annotations to a multi-component app (DB → Backend → Frontend → Ingress)
5. Enable SelfHeal on an application, manually change a replica count, and observe ArgoCD revert it

---

## 08. Summary

- Config Management Plugins (CMP) let ArgoCD render manifests with any tool - jsonnet, cdk8s, envsubst, or custom scripts
- The ArgoCD REST API enables programmatic automation: create apps, trigger syncs, and query status without the CLI
- **Resource hooks** (`PreSync`, `PostSync`, `SyncFail`) run Jobs at specific lifecycle points - perfect for migrations and smoke tests
- **Sync waves** (`argocd.argoproj.io/sync-wave`) ensure resources deploy in dependency order within a single sync operation
- `selfHeal: true` + `prune: true` make Git truly authoritative - any manual change or deleted resource is automatically corrected
