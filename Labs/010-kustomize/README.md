---
# Kustomize

* Kustomize allows you to customize Kubernetes YAML without templates or a separate DSL.
* ArgoCD has native Kustomize support - just point to a directory containing a `kustomization.yaml`.
* The base + overlays pattern lets you define common resources once and customize per environment.

## What will we learn?

- The base + overlay Kustomize structure
- How ArgoCD detects and renders Kustomize automatically
- Environment-specific customizations (namespaces, images, replica counts)
- Kustomize image overrides and patches

---

## Prerequisites

- Complete [Lab 002](../002-first-app/README.md)

---

## 01. Understanding Kustomize Structure

```text
kustomize-app/
├── base/
│   ├── kustomization.yaml    # References all base resources
│   ├── deployment.yaml       # Base Deployment
│   └── service.yaml          # Base Service
└── overlays/
    ├── staging/
    │   ├── kustomization.yaml # Extends base, applies staging changes
    │   └── replica-patch.yaml # Staging: 1 replica
    └── production/
        ├── kustomization.yaml # Extends base, applies production changes
        └── replica-patch.yaml # Production: 3 replicas
```

---

## 02. ArgoCD Application with Kustomize

ArgoCD detects Kustomize automatically when a `kustomization.yaml` is present:

```sh
# Deploy the kustomize-guestbook example
argocd app create kustomize-guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path kustomize-guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace kustomize-guestbook \
  --sync-option CreateNamespace=true

argocd app sync kustomize-guestbook
argocd app wait kustomize-guestbook --health --timeout 120
```

---

## 03. Create a Base + Overlay Structure

```sh
# Create a local kustomize structure for this lab
mkdir -p /tmp/kustomize-lab/base
mkdir -p /tmp/kustomize-lab/overlays/staging
mkdir -p /tmp/kustomize-lab/overlays/production

# Base deployment
cat <<'EOF' > /tmp/kustomize-lab/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
EOF

# Base kustomization
cat <<'EOF' > /tmp/kustomize-lab/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
EOF

# Staging overlay
cat <<'EOF' > /tmp/kustomize-lab/overlays/staging/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: nginx-staging
resources:
  - ../../base
patches:
  - patch: |-
      - op: replace
        path: /spec/replicas
        value: 1
    target:
      kind: Deployment
      name: nginx
images:
  - name: nginx
    newTag: "1.25-alpine"
EOF

# Production overlay
cat <<'EOF' > /tmp/kustomize-lab/overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: nginx-production
resources:
  - ../../base
patches:
  - patch: |-
      - op: replace
        path: /spec/replicas
        value: 3
    target:
      kind: Deployment
      name: nginx
images:
  - name: nginx
    newTag: "1.25"
EOF
```

---

## 04. Kustomize Image Overrides via ArgoCD

```sh
# Override image tags at the ArgoCD Application level
argocd app set kustomize-guestbook \
  --kustomize-image gcr.io/heptio-images/ks-guestbook-demo:0.2

# Or in YAML:
# spec:
#   source:
#     kustomize:
#       images:
#         - gcr.io/heptio-images/ks-guestbook-demo:0.2
```

---

## 05. Render Kustomize Output

```sh
# Show rendered manifests
argocd app manifests kustomize-guestbook

# Use kubectl to render locally
kubectl kustomize /tmp/kustomize-lab/overlays/staging 2>/dev/null || true
```

---

<img src="../assets/images/practice.png" alt="Practice" width="800"/>

## 06. Hands-on

1. Create an ArgoCD Application using the `kustomize-guestbook` path from `argocd-example-apps`:

   ??? success "Solution"

   ```sh
   argocd app create kustomize-guestbook \
     --repo https://github.com/argoproj/argocd-example-apps.git \
     --path kustomize-guestbook \
     --dest-server https://kubernetes.default.svc \
     --dest-namespace kustomize-guestbook \
     --sync-option CreateNamespace=true
   argocd app sync kustomize-guestbook
   argocd app wait kustomize-guestbook --health --timeout 120
   ```

2. Override the image tag for the `kustomize-guestbook` app using `argocd app set --kustomize-image`:

   ??? success "Solution"

   ```sh
   argocd app set kustomize-guestbook \
     --kustomize-image gcr.io/heptio-images/ks-guestbook-demo:0.2
   argocd app sync kustomize-guestbook
   argocd app manifests kustomize-guestbook | grep image
   ```

3. Show the rendered manifests for the `kustomize-guestbook` application:

   ??? success "Solution"

   ```sh
   argocd app manifests kustomize-guestbook
   ```

---

## 07. Summary

- ArgoCD detects Kustomize automatically when `kustomization.yaml` exists in the source path
- The base + overlays pattern separates common configuration from environment-specific customizations
- Image overrides via `kustomize.images` or `--kustomize-image` update image tags without modifying Git
- Kustomize patches (strategic merge or JSON6902) allow precise field-level overrides
- `argocd app manifests` renders the final output before applying - use it to verify before syncing
