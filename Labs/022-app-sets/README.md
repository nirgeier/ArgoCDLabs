---

# ApplicationSets

* ApplicationSets automate the creation of ArgoCD Applications using generators - templating apps from lists, cluster registries, or Git directory structures.
* A single ApplicationSet can deploy to dozens of environments or clusters without duplicating Application manifests.
* The ApplicationSet controller runs as a separate deployment alongside ArgoCD.

## What will we learn?

- How the List, Cluster, and Git directory generators work
- How to template Application manifests with `{{variables}}`
- How to deploy to multiple environments from one ApplicationSet
- How to auto-discover apps from a Git repository structure

---

## Prerequisites

- Complete [Lab 007](../007-multi-cluster/README.md) (Multi-Cluster)

---

## 01. List Generator

Deploy the same app to multiple environments defined inline:

```sh
kubectl apply -f - <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: guestbook-environments
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - env: dev
            namespace: guestbook-dev
            replicas: "1"
          - env: staging
            namespace: guestbook-staging
            replicas: "2"
          - env: prod
            namespace: guestbook-prod
            replicas: "3"
  template:
    metadata:
      name: "guestbook-{{env}}"
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps
        targetRevision: HEAD
        path: guestbook
        helm:
          parameters:
            - name: replicaCount
              value: "{{replicas}}"
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{namespace}}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
YAML
```

---

## 02. Cluster Generator

Automatically target all registered clusters (or by label):

```sh
kubectl apply -f - <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: monitoring-all-clusters
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            tier: production         # Only production clusters
  template:
    metadata:
      name: "monitoring-{{name}}"   # {{name}} = cluster name
    spec:
      project: default
      source:
        repoURL: https://github.com/prometheus-community/helm-charts
        chart: kube-prometheus-stack
        targetRevision: "~55.0"
        helm:
          releaseName: monitoring
      destination:
        server: "{{server}}"         # {{server}} = cluster API URL
        namespace: monitoring
      syncPolicy:
        syncOptions:
          - CreateNamespace=true
YAML
```

---

## 03. Git Directory Generator

Auto-discover applications from repository folder structure:

```sh
kubectl apply -f - <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: apps-from-git
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/argoproj/argocd-example-apps
        revision: HEAD
        directories:
          - path: "apps/*/overlays/dev"   # Discover kustomize overlays
          - path: "charts/*"              # Discover helm charts
          - path: "legacy"
            exclude: true                 # Exclude legacy directory
  template:
    metadata:
      name: "{{path.basename}}"
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps
        targetRevision: HEAD
        path: "{{path}}"
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{path.basename}}"
      syncPolicy:
        syncOptions:
          - CreateNamespace=true
YAML
```

---

## 04. Matrix Generator

Combine generators to create a matrix of environments × clusters:

```sh
kubectl apply -f - <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: matrix-appset
  namespace: argocd
spec:
  generators:
    - matrix:
        generators:
          - list:
              elements:
                - app: frontend
                - app: backend
                - app: worker
          - list:
              elements:
                - env: staging
                - env: prod
  template:
    metadata:
      name: "{{app}}-{{env}}"
    spec:
      project: default
      source:
        repoURL: https://github.com/org/apps
        targetRevision: HEAD
        path: "{{app}}/overlays/{{env}}"
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{app}}-{{env}}"
YAML
```

---

## 05. Verify ApplicationSet

```sh
# List ApplicationSets
kubectl get applicationsets -n argocd

# List all generated Applications
argocd app list | grep "guestbook-"

# Check ApplicationSet status
kubectl describe applicationset guestbook-environments -n argocd
```

---

## Hands-on Tasks

1. Create a List generator ApplicationSet deploying the guestbook app to `dev`, `staging`, and `prod` namespaces
2. Verify three Applications are automatically created, one per environment
3. Add a new element (`- env: qa`) to the list and observe the new Application being created
4. Remove the `qa` element and verify the Application is pruned (if `template.syncPolicy.automated.prune: true`)
5. Create a Git directory generator that auto-discovers all subdirectories in a repo

---

## 08. Summary

- ApplicationSets generate multiple ArgoCD Applications from a single template, eliminating copy-paste manifests
- The **List generator** creates apps from an inline list of parameters - ideal for fixed environment sets
- The **Cluster generator** targets all (or labeled) registered clusters automatically
- The **Git directory generator** auto-discovers apps from repository folder structure
- The **Matrix generator** combines two generators to produce a Cartesian product (e.g., apps × environments)
