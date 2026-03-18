---
# Helm Integration

* ArgoCD natively supports deploying Helm charts as Applications.
* You can override values inline, reference multiple value files, and use post-renderers for additional customization.
* ArgoCD tracks the Helm chart version in Git, not just the rendered manifests.

## What will we learn?

- How to create an ArgoCD Application from a Helm chart
- How to override Helm values in the Application spec
- How to reference multiple value files per environment
- How to use a Helm post-renderer
- How ArgoCD and Helm lifecycle interact

---

## Prerequisites

- Complete [Lab 003](../003-git-repo-connect/README.md)

---

## 01. Deploy a Helm Chart via ArgoCD CLI

```sh
# Deploy the nginx Helm chart from Bitnami
argocd app create nginx-helm \
  --repo https://charts.bitnami.com/bitnami \
  --helm-chart nginx \
  --revision 15.0.0 \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace nginx-helm \
  --helm-set replicaCount=2 \
  --helm-set service.type=ClusterIP \
  --sync-option CreateNamespace=true

argocd app sync nginx-helm
argocd app wait nginx-helm --health --timeout 180
```

---

## 02. Helm Chart Application via YAML

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-helm-yaml
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.bitnami.com/bitnami
    chart: nginx
    targetRevision: 15.0.0
    helm:
      releaseName: nginx-helm-yaml
      values: |
        replicaCount: 2
        service:
          type: ClusterIP
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
  destination:
    server: https://kubernetes.default.svc
    namespace: nginx-helm-yaml
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

---

## 03. Multiple Value Files

Reference environment-specific value files from a Git repository:

```yaml
spec:
  source:
    repoURL: https://github.com/your-org/helm-values.git
    targetRevision: HEAD
    path: charts/nginx
    helm:
      releaseName: nginx
      valueFiles:
        - values.yaml # Base values
        - values-production.yaml # Production overrides
```

---

## 04. Inline Value Overrides

Mix `valueFiles` with inline `values` overrides:

```sh
argocd app set nginx-helm \
  --helm-set replicaCount=3 \
  --helm-set-string image.tag=latest

# Show rendered Helm templates without applying
argocd app manifests nginx-helm
```

---

## 05. Inspect Rendered Manifests

```sh
# Show what ArgoCD will deploy (rendered Helm templates)
argocd app manifests nginx-helm

# Show diff between rendered and live
argocd app diff nginx-helm

# List Helm release info
kubectl get secret -n nginx-helm -l "owner=helm"
```

---

## 06. Helm Post-Renderer

A post-renderer is a binary that transforms Helm output before applying to the cluster. In ArgoCD, this is typically done via Kustomize (Lab 010) layered on top of a Helm chart.

```yaml
spec:
  source:
    repoURL: https://github.com/your-org/apps.git
    path: nginx-with-kustomize
    helm:
      releaseName: nginx
    # Kustomize post-renderer is enabled by having a kustomization.yaml
    # in the same path alongside the Helm chart
```

---

<img src="../assets/images/practice.png" alt="Practice" width="800"/>

## 07. Hands-on

1. Create an ArgoCD Application using the Bitnami nginx Helm chart with `replicaCount=2`:

   ??? success "Solution"

   ```sh
   argocd app create nginx-helm \
     --repo https://charts.bitnami.com/bitnami \
     --helm-chart nginx \
     --revision 15.0.0 \
     --dest-server https://kubernetes.default.svc \
     --dest-namespace nginx-helm \
     --helm-set replicaCount=2 \
     --helm-set service.type=ClusterIP \
     --sync-option CreateNamespace=true
   argocd app sync nginx-helm
   argocd app wait nginx-helm --health --timeout 180
   ```

2. Update the `replicaCount` to 3 using `argocd app set --helm-set` and verify the deployment scales:

   ??? success "Solution"

   ```sh
   argocd app set nginx-helm --helm-set replicaCount=3
   argocd app sync nginx-helm
   kubectl get deployment -n nginx-helm
   # Should show 3/3 replicas
   ```

3. Print the rendered Helm manifests for the `nginx-helm` application:

   ??? success "Solution"

   ```sh
   argocd app manifests nginx-helm
   ```

---

## 08. Summary

- ArgoCD treats Helm charts as a source type - specify `chart` and `targetRevision` instead of `path`
- `helm.values` in the Application spec allows inline value overrides without modifying the chart
- `helm.valueFiles` references value files inside a Git repository - ideal for per-environment customization
- `argocd app manifests <name>` shows the rendered Kubernetes manifests ArgoCD would apply
- ArgoCD does not use `helm install` directly - it renders the templates and applies them with `kubectl apply`
