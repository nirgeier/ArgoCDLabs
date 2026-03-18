---
# Sync Phases, Waves, and Hooks

* ArgoCD sync operations proceed through three phases: PreSync, Sync, and PostSync.
* Within each phase, resources are ordered by their `argocd.argoproj.io/sync-wave` annotation.
* Hooks are resources (Jobs, Pods, etc.) that run only during sync operations, not as permanent workloads.

## What will we learn?

- The three sync phases and when each runs
- How sync waves order resource application within a phase
- How to create PreSync, Sync, and PostSync hooks
- How to use sync-wave annotations to control ordering

---

## Prerequisites

- Complete [Lab 002](../002-first-app/README.md)

---

## 01. Sync Phases

```text
ArgoCD Sync Timeline:
┌─────────────────────────────────────────────────────┐
│  1. PreSync Phase                                    │
│     - Run PreSync hooks (e.g., database migrations) │
│     - Wait for all PreSync hooks to complete        │
├─────────────────────────────────────────────────────┤
│  2. Sync Phase                                       │
│     - Apply all non-hook resources                  │
│     - Resources with lower wave number go first     │
├─────────────────────────────────────────────────────┤
│  3. PostSync Phase                                   │
│     - Run PostSync hooks (e.g., smoke tests)        │
│     - SyncFail hooks run if sync fails              │
└─────────────────────────────────────────────────────┘
```

---

## 02. Hook Annotations

```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync # Phase
    argocd.argoproj.io/hook-delete-policy: HookSucceeded # Cleanup
```

Hook types:

- `PreSync` - runs before the sync begins
- `Sync` - runs during the sync phase (alongside normal resources)
- `PostSync` - runs after all resources are synced and healthy
- `SyncFail` - runs only if the sync fails

Hook delete policies:

- `HookSucceeded` - delete the hook after it succeeds
- `HookFailed` - delete the hook after it fails
- `BeforeHookCreation` - delete the previous hook before creating a new one

---

## 03. PreSync Hook Example: Database Migration

```sh
cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
  namespace: guestbook
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
        - name: migrate
          image: alpine:3.18
          command: ["/bin/sh", "-c"]
          args:
            - |
              echo "Running database migration..."
              sleep 5
              echo "Migration complete!"
      restartPolicy: Never
  backoffLimit: 2
EOF
```

---

## 04. PostSync Hook Example: Smoke Test

```sh
cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: smoke-test
  namespace: guestbook
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
        - name: test
          image: curlimages/curl:8.0.0
          command: ["/bin/sh", "-c"]
          args:
            - |
              echo "Running smoke test..."
              # curl -f http://guestbook-ui.guestbook.svc.cluster.local
              echo "Smoke test passed!"
      restartPolicy: Never
  backoffLimit: 3
EOF
```

---

## 05. Sync Waves

Waves control the order within each sync phase. Lower wave numbers are applied first:

```sh
cat <<'EOF' | kubectl apply -f -
# Wave 1: Create the namespace
apiVersion: v1
kind: Namespace
metadata:
  name: wave-demo
  annotations:
    argocd.argoproj.io/sync-wave: "1"
---
# Wave 2: Create ConfigMaps and Secrets
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: wave-demo
  annotations:
    argocd.argoproj.io/sync-wave: "2"
data:
  key: value
---
# Wave 3: Deploy the application
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wave-demo-app
  namespace: wave-demo
  annotations:
    argocd.argoproj.io/sync-wave: "3"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wave-demo
  template:
    metadata:
      labels:
        app: wave-demo
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
EOF
```

---

<img src="../assets/images/practice.png" alt="Practice" width="800"/>

## 06. Hands-on

1. Create a PreSync hook Job that prints "Pre-sync complete" and verify it runs before the main deployment:

   ??? success "Solution"

   ```sh
   cat <<'EOF' | kubectl apply -f -
   apiVersion: batch/v1
   kind: Job
   metadata:
     name: presync-demo
     namespace: guestbook
     annotations:
       argocd.argoproj.io/hook: PreSync
       argocd.argoproj.io/hook-delete-policy: HookSucceeded
   spec:
     template:
       spec:
         containers:
           - name: demo
             image: alpine:3.18
             command: [sh, -c, "echo Pre-sync hook running! && sleep 3"]
         restartPolicy: Never
   EOF
   # Trigger a sync to see the hook run
   argocd app sync guestbook
   kubectl get jobs -n guestbook
   ```

2. Add `sync-wave` annotations to two ConfigMaps so that ConfigMap A (wave 1) is applied before ConfigMap B (wave 2):

   ??? success "Solution"

   ```sh
   kubectl apply -f - <<'EOF'
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: wave-first
     namespace: guestbook
     annotations:
       argocd.argoproj.io/sync-wave: "1"
   data:
     order: first
   ---
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: wave-second
     namespace: guestbook
     annotations:
       argocd.argoproj.io/sync-wave: "2"
   data:
     order: second
   EOF
   ```

---

## 07. Summary

- Sync phases execute in strict order: PreSync → Sync → PostSync → SyncFail (on failure)
- Hooks are standard Kubernetes resources (Jobs, Pods) with `argocd.argoproj.io/hook` annotations
- `hook-delete-policy: HookSucceeded` keeps failed hooks for debugging while cleaning up successful ones
- Sync waves (`argocd.argoproj.io/sync-wave`) are integers - ArgoCD waits for all resources in wave N to be healthy before starting wave N+1
- Hooks are never part of the steady-state - they only exist during sync operations
