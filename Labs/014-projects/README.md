---
# ArgoCD Projects

* AppProjects are logical groupings of applications that enforce access controls and resource limits.
* Projects restrict which Git repositories, destination clusters/namespaces, and cluster resources applications can use.
* The `default` project allows everything; custom projects enforce the principle of least privilege.

## What will we learn?

- How AppProjects work and why they're important for multi-tenancy
- How to restrict source repositories and destination namespaces
- How to use cluster resource whitelists and blacklists
- How to assign applications to projects

---

## Prerequisites

- Complete [Lab 012](../012-rbac/README.md)

---

## 01. The Default Project

```sh
# Inspect the default project
argocd proj get default

# The default project allows:
# - Any source repository
# - Any destination cluster/namespace
# - Any cluster-scoped resource
```

---

## 02. Create a Custom AppProject

```sh
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-alpha
  namespace: argocd
spec:
  description: "Team Alpha - restricted to their own repos and namespaces"

  # Allowed source repositories
  sourceRepos:
    - 'https://github.com/team-alpha/*'
    - 'https://charts.bitnami.com/bitnami'

  # Allowed destination clusters and namespaces
  destinations:
    - server: https://kubernetes.default.svc
      namespace: team-alpha-staging
    - server: https://kubernetes.default.svc
      namespace: team-alpha-production

  # Allowed cluster-scoped resources (empty = namespace-scoped only)
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace

  # Blocked namespace-scoped resources
  namespaceResourceBlacklist:
    - group: ''
      kind: ResourceQuota
    - group: ''
      kind: LimitRange

  # Sync windows
  syncWindows:
    - kind: deny
      schedule: '0 22 * * *'
      duration: 8h
      applications:
        - '*'

  # Project-level roles (covered in Lab 012)
  roles:
    - name: developer
      description: Team Alpha developers
      policies:
        - p, proj:team-alpha:developer, applications, get, team-alpha/*, allow
        - p, proj:team-alpha:developer, applications, sync, team-alpha/*, allow
      groups:
        - team-alpha-devs
EOF
```

---

## 03. Assign an Application to a Project

```sh
# Create an application in the team-alpha project
argocd app create alpha-app \
  --project team-alpha \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace team-alpha-staging \
  --sync-option CreateNamespace=true || true

# Try to deploy to a forbidden namespace (should fail)
argocd app create alpha-bad-app \
  --project team-alpha \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace kube-system || true
# Expected: error about destination not permitted
```

---

## 04. Cluster Resource Whitelist vs Blacklist

```sh
# Allow only specific cluster-scoped resources (whitelist wins over blacklist)
# Whitelist: ONLY these can be deployed as cluster-scoped resources
# Blacklist: these are DENIED in namespace-scoped resources

# Example: allow Namespaces but deny PodSecurityPolicies
argocd proj allow-cluster-resource team-alpha '' Namespace
argocd proj deny-namespace-resource team-alpha '' ResourceQuota

# List project details
argocd proj get team-alpha
```

---

## 05. Orphan Resources Detection

```sh
# Enable orphan resources tracking for the project
argocd proj set team-alpha --orphaned-resources

# Now ArgoCD will warn if there are resources in team-alpha namespaces
# that don't belong to any Application in the project
argocd proj get team-alpha
```

---

<img src="../assets/images/practice.png" alt="Practice" width="800"/>

## 06. Hands-on

1. Create a project called `team-alpha` that restricts sources to `github.com/argoproj/*` repos and destinations to the `team-alpha` namespace:

   ??? success "Solution"

   ```sh
   argocd proj create team-alpha \
     --description "Team Alpha project" \
     --src "https://github.com/argoproj/*" \
     --dest "https://kubernetes.default.svc,team-alpha"
   argocd proj get team-alpha
   ```

2. Try to create an Application in `team-alpha` project that deploys to a forbidden namespace and observe the error:

   ??? success "Solution"

   ```sh
   argocd app create forbidden-app \
     --project team-alpha \
     --repo https://github.com/argoproj/argocd-example-apps.git \
     --path guestbook \
     --dest-server https://kubernetes.default.svc \
     --dest-namespace kube-system || true
   # Expected: application destination server ... is not permitted in project 'team-alpha'
   ```

3. List all projects and display their source and destination restrictions:

   ??? success "Solution"

   ```sh
   argocd proj list
   argocd proj get team-alpha
   ```

---

## 07. Summary

- AppProjects enforce least-privilege: specify exactly which repos, clusters, and namespaces are allowed
- `clusterResourceWhitelist` controls which cluster-scoped resources (like Namespaces, CRDs) can be deployed
- `namespaceResourceBlacklist` prevents specific namespace-scoped resources (like ResourceQuotas) from being deployed
- A project's sync windows override individual Application sync windows - project-level controls take priority
- Orphaned resource tracking warns when cluster resources exist in a project's namespaces without an owning Application
