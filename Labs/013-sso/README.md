---
# Single Sign-On (SSO)

* ArgoCD uses Dex as an embedded OIDC provider to support SSO with GitHub, GitLab, LDAP, and other identity providers.
* Once SSO is configured, users log in with their organization credentials instead of a local ArgoCD password.
* Group memberships from the identity provider map to ArgoCD RBAC roles.

## What will we learn?

- How ArgoCD's Dex integration works
- How to configure GitHub OAuth for SSO
- How the SSO login flow works
- How to map GitHub org teams to ArgoCD roles

---

## Prerequisites

- Complete [Lab 012](../012-rbac/README.md)
- A GitHub account and OAuth App (for the GitHub SSO section)

---

## 01. How Dex Works with ArgoCD

```text
SSO Login Flow:
1. User clicks "Login via GitHub" in ArgoCD UI
2. ArgoCD redirects to Dex
3. Dex redirects to GitHub OAuth
4. User authenticates with GitHub
5. GitHub returns auth code to Dex
6. Dex exchanges code for user info (name, email, groups/orgs)
7. Dex issues an OIDC token to ArgoCD
8. ArgoCD maps the token's groups to RBAC roles
```

---

## 02. Create a GitHub OAuth App

In GitHub:

1. Go to Settings → Developer settings → OAuth Apps → New OAuth App
2. Set:
   - Application name: `ArgoCD Labs`
   - Homepage URL: `https://localhost:8080`
   - Authorization callback URL: `https://localhost:8080/api/dex/callback`
3. Save the `Client ID` and `Client Secret`

---

## 03. Configure Dex for GitHub SSO

```sh
# Store the GitHub OAuth secret
kubectl patch secret argocd-secret -n argocd \
  --type merge -p '{
    "stringData": {
      "dex.github.clientSecret": "YOUR_GITHUB_CLIENT_SECRET"
    }
  }' || true

# Configure argocd-cm with Dex config
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-cm
    app.kubernetes.io/part-of: argocd
data:
  url: https://localhost:8080
  dex.config: |
    connectors:
      - type: github
        id: github
        name: GitHub
        config:
          clientID: YOUR_GITHUB_CLIENT_ID
          clientSecret: $dex.github.clientSecret
          redirectURI: https://localhost:8080/api/dex/callback
          orgs:
            - name: your-github-org
              teams:
                - developers
                - devops
                - admins
EOF
```

---

## 04. Map GitHub Teams to ArgoCD Roles

```sh
# After Dex is configured, update RBAC to map teams
kubectl patch cm argocd-rbac-cm -n argocd --type merge -p '{
  "data": {
    "policy.csv": "g, your-github-org:admins, role:admin\ng, your-github-org:devops, role:devops\ng, your-github-org:developers, role:developer\n",
    "policy.default": "role:readonly"
  }
}' || true
```

---

## 05. Verify Dex Configuration

```sh
# Check Dex server is running
kubectl get pods -n argocd | grep dex

# View Dex server logs
kubectl logs -n argocd deploy/argocd-dex-server --tail=30

# Verify argocd-cm has the dex config
kubectl get cm argocd-cm -n argocd -o jsonpath='{.data.dex\.config}'

# Test the OIDC discovery endpoint (requires port-forward)
curl -k https://localhost:8080/api/dex/.well-known/openid-configuration 2>/dev/null | python3 -m json.tool || true
```

---

## 06. OIDC Direct Integration (Without Dex)

You can bypass Dex and configure an external OIDC provider directly:

```yaml
# In argocd-cm:
data:
  oidc.config: |
    name: Okta
    issuer: https://your-org.okta.com
    clientID: YOUR_CLIENT_ID
    clientSecret: $oidc.okta.clientSecret
    requestedScopes:
      - openid
      - profile
      - email
      - groups
    requestedIDTokenClaims:
      groups:
        essential: true
```

---

<img src="../assets/images/practice.png" alt="Practice" width="800"/>

## 07. Hands-on

1. Verify the `argocd-dex-server` pod is running and check its logs:

   ??? success "Solution"

   ```sh
   kubectl get pods -n argocd | grep dex
   kubectl logs -n argocd deploy/argocd-dex-server --tail=20
   ```

2. Inspect the current `argocd-cm` ConfigMap for any existing SSO configuration:

   ??? success "Solution"

   ```sh
   kubectl get cm argocd-cm -n argocd -o yaml
   # Look for dex.config or oidc.config keys
   ```

3. Configure the `argocd-cm` with a skeleton GitHub Dex connector (using placeholder values) and restart the Dex server:

   ??? success "Solution"

   ```sh
   kubectl patch cm argocd-cm -n argocd --type merge -p '{
     "data": {
       "url": "https://localhost:8080",
       "dex.config": "connectors:\n  - type: github\n    id: github\n    name: GitHub\n    config:\n      clientID: PLACEHOLDER\n      clientSecret: $dex.github.clientSecret\n      redirectURI: https://localhost:8080/api/dex/callback\n"
     }
   }' || true
   kubectl rollout restart deploy/argocd-dex-server -n argocd || true
   kubectl rollout status deploy/argocd-dex-server -n argocd --timeout=60s || true
   ```

---

## 08. Summary

- ArgoCD's embedded Dex server bridges external identity providers (GitHub, OIDC, LDAP) to ArgoCD's auth system
- GitHub OAuth uses organization team memberships as group claims for RBAC mapping
- All OAuth secrets are stored in `argocd-secret` and referenced with `$secret-key` syntax in `argocd-cm`
- Direct OIDC integration (`oidc.config`) bypasses Dex - useful when you already have a corporate IdP
- After any Dex configuration change, restart the `argocd-dex-server` deployment to pick up the new config
