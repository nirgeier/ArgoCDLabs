---

# RBAC

* ArgoCD has its own RBAC system built on top of Casbin, independent of Kubernetes RBAC.
* Policies control what users and groups can do: create apps, sync apps, delete apps, manage projects, etc.
* RBAC is configured in the `argocd-rbac-cm` ConfigMap.

## What will we learn?

- ArgoCD RBAC policy syntax
- Built-in roles: `role:readonly` and `role:admin`
- How to create custom roles
- Project-level RBAC restrictions
- How to verify RBAC with the CLI

---

## Prerequisites

- Complete [Lab 002](../002-first-app/README.md)

---

## 01. RBAC Policy Syntax

ArgoCD RBAC policies follow this format:

```
p, <subject>, <resource>, <action>, <object>, <effect>
```

- `subject`: user, group, or role
- `resource`: `applications`, `clusters`, `repositories`, `projects`, etc.
- `action`: `get`, `create`, `update`, `delete`, `sync`, `override`, `action`
- `object`: `<project>/<app-name>` or `*`
- `effect`: `allow` or `deny`

---

## 02. Built-in Roles

```sh
# View the default RBAC configuration
kubectl get cm argocd-rbac-cm -n argocd -o yaml

# Built-in roles:
# role:readonly  - can view everything, cannot modify
# role:admin     - full access to everything
```

---

## 03. Create Custom Roles

```sh
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-rbac-cm
    app.kubernetes.io/part-of: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    # Developer role: can sync apps in the 'default' project but cannot delete
    p, role:developer, applications, get, default/*, allow
    p, role:developer, applications, sync, default/*, allow
    p, role:developer, applications, create, default/*, allow
    p, role:developer, applications, update, default/*, allow

    # DevOps role: full access except cluster management
    p, role:devops, applications, *, */*, allow
    p, role:devops, repositories, get, *, allow
    p, role:devops, repositories, create, *, allow

    # Assign roles to users
    g, alice, role:developer
    g, bob, role:devops
    g, charlie, role:admin

    # Assign roles to SSO groups
    g, github-org:developers, role:developer
    g, github-org:devops, role:devops
EOF
```

---

## 04. Project-Level RBAC

AppProjects can define their own roles that restrict access within the project:

```sh
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-alpha
  namespace: argocd
spec:
  description: Team Alpha project
  sourceRepos:
    - 'https://github.com/team-alpha/*'
  destinations:
    - namespace: team-alpha-*
      server: https://kubernetes.default.svc
  roles:
    - name: team-alpha-developer
      description: Read-only access for Team Alpha
      policies:
        - p, proj:team-alpha:team-alpha-developer, applications, get, team-alpha/*, allow
        - p, proj:team-alpha:team-alpha-developer, applications, sync, team-alpha/*, allow
      groups:
        - github-org:team-alpha-developers
EOF
```

---

## 05. Verify RBAC

```sh
# Test what a user/role can do
argocd admin settings rbac validate --policy-file /tmp/policy.csv || true

# Check the effective permissions for a user
# (requires ArgoCD 2.7+)
argocd auth can-i sync applications '*' --as alice 2>/dev/null || true

# View current RBAC config
kubectl get cm argocd-rbac-cm -n argocd -o jsonpath='{.data.policy\.csv}'
```

---

<img src="../assets/images/practice.png" alt="Practice" width="800"/>

## 06. Hands-on

1. View the current RBAC configuration in `argocd-rbac-cm`:

   ??? success "Solution"

   ```sh
   kubectl get cm argocd-rbac-cm -n argocd -o yaml
   # Look for policy.csv and policy.default
   ```

2. Create a `role:developer` that can only `get` and `sync` applications in the `default` project:

   ??? success "Solution"

   ```sh
   kubectl patch cm argocd-rbac-cm -n argocd --type merge -p '{
     "data": {
       "policy.csv": "p, role:developer, applications, get, default/*, allow\np, role:developer, applications, sync, default/*, allow\n",
       "policy.default": "role:readonly"
     }
   }'
   kubectl get cm argocd-rbac-cm -n argocd -o jsonpath='{.data.policy\.csv}'
   ```

3. List all ArgoCD accounts and their permissions:

   ??? success "Solution"

   ```sh
   argocd account list 2>/dev/null || true
   argocd account get admin 2>/dev/null || true
   ```

---

## 07. Summary

- ArgoCD RBAC uses Casbin policies: `p, subject, resource, action, object, effect`
- The default role (`policy.default`) applies to all authenticated users without an explicit role
- Built-in roles are `role:readonly` (view only) and `role:admin` (full control)
- Project-level roles (`proj:<project>:<role>`) restrict access within a specific AppProject
- Group bindings (`g, <group>, <role>`) work with SSO groups from Dex, LDAP, or OIDC providers
