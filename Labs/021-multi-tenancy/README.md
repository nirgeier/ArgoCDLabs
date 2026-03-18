---

# Multi-Tenancy

* ArgoCD AppProjects provide the primary isolation boundary - restricting source repos, destination clusters, and resource kinds per tenant.
* RBAC policies control which users and groups can access which applications and projects.
* Namespace isolation and resource quotas enforce hard limits at the Kubernetes level.

## What will we learn?

- How to create AppProjects that restrict tenant access
- How to define per-tenant RBAC policies
- How to isolate tenant namespaces with resource quotas
- Best practices for onboarding new tenants

---

## Prerequisites

- Complete [Lab 012](../012-rbac/README.md) (RBAC)
- Complete [Lab 014](../014-projects/README.md) (Projects)

---

## 01. Tenant Architecture

```text
ArgoCD multi-tenancy model:
┌─────────────────────────────────────────────────┐
│ ArgoCD                                           │
│  ├── AppProject: team-alpha                      │
│  │    ├── sourceRepos: github.com/team-alpha/*   │
│  │    ├── destinations: namespace team-alpha     │
│  │    └── resourceWhitelist: Deployment, Service │
│  ├── AppProject: team-beta                       │
│  │    ├── sourceRepos: github.com/team-beta/*    │
│  │    ├── destinations: namespace team-beta      │
│  │    └── resourceWhitelist: Deployment, Service │
│  └── AppProject: platform (admins only)          │
└─────────────────────────────────────────────────┘
```

---

## 02. Create Tenant Namespaces

```sh
# Create namespaces for each tenant
for team in alpha beta gamma; do
  kubectl create namespace "team-${team}" --dry-run=client -o yaml | kubectl apply -f -
  kubectl label namespace "team-${team}" \
    tenant="team-${team}" \
    argocd.argoproj.io/managed-by=argocd \
    --overwrite
done

# Apply resource quotas per namespace
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-quota
  namespace: team-alpha
spec:
  hard:
    pods: "20"
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
YAML
```

---

## 03. AppProject per Tenant

```sh
kubectl apply -f - <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-alpha
  namespace: argocd
spec:
  description: "Team Alpha – restricted to their namespace and repos"
  sourceRepos:
    - "https://github.com/team-alpha/*"
    - "https://github.com/org/shared-charts"
  destinations:
    - namespace: team-alpha
      server: https://kubernetes.default.svc
  clusterResourceWhitelist: []    # No cluster-level access
  namespaceResourceWhitelist:
    - group: "apps"
      kind: Deployment
    - group: "apps"
      kind: StatefulSet
    - group: ""
      kind: Service
    - group: ""
      kind: ConfigMap
    - group: ""
      kind: Secret
  roles:
    - name: developer
      description: "Team Alpha developer"
      policies:
        - p, proj:team-alpha:developer, applications, *, team-alpha/*, allow
      groups:
        - team-alpha-developers
YAML
```

---

## 04. RBAC for Tenants

```sh
# Update argocd-rbac-cm with tenant policies
kubectl patch configmap argocd-rbac-cm -n argocd --patch '
data:
  policy.csv: |
    # Team Alpha – full access to their project
    p, role:team-alpha-dev, applications, get,    team-alpha/*, allow
    p, role:team-alpha-dev, applications, create, team-alpha/*, allow
    p, role:team-alpha-dev, applications, update, team-alpha/*, allow
    p, role:team-alpha-dev, applications, sync,   team-alpha/*, allow
    p, role:team-alpha-dev, applications, delete, team-alpha/*, deny

    # Team Beta
    p, role:team-beta-dev, applications, *, team-beta/*, allow

    # Group bindings (with SSO from Lab 013)
    g, team-alpha-sso-group, role:team-alpha-dev
    g, team-beta-sso-group,  role:team-beta-dev
  policy.default: role:readonly
' 2>/dev/null || echo "(patch requires running ArgoCD – showing config only)"
```

---

## 05. Verify Isolation

```sh
# Confirm a team-alpha application cannot target team-beta namespace
argocd app create alpha-test \
  --project team-alpha \
  --repo https://github.com/argoproj/argocd-example-apps \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace team-beta  # This should be REJECTED by AppProject rules
# Expected: "application destination {https://kubernetes.default.svc team-beta} is not permitted"
```

---

## Hands-on Tasks

1. Create three tenant namespaces (`team-alpha`, `team-beta`, `team-gamma`) with resource quotas
2. Create an AppProject for `team-alpha` restricting source repos and destination namespace
3. Define RBAC policies granting `team-alpha` developers sync/get access only to their project
4. Verify that `team-alpha` cannot deploy to `team-beta` namespace
5. Design an onboarding script that creates namespace + AppProject + RBAC for a new tenant

---

## 08. Summary

- AppProjects are the primary isolation mechanism - they restrict source repos, destination namespaces, and allowed resource kinds per tenant
- RBAC policies in `argocd-rbac-cm` bind SSO groups (or local users) to project-scoped roles
- Namespace resource quotas enforce hard CPU/memory limits independent of ArgoCD
- The `clusterResourceWhitelist: []` setting prevents tenants from creating cluster-scoped resources like ClusterRoles
- Use the App-of-Apps pattern (Lab 008) to bootstrap new tenant projects from a Git-managed onboarding repo
