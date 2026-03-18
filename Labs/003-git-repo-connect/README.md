---
# Connecting Git Repositories

* ArgoCD needs credentials to access private Git repositories and Helm chart registries.
* You can connect repos via SSH keys, HTTPS tokens, or TLS certificates.
* Once connected, ArgoCD stores repo credentials as Kubernetes Secrets in the `argocd` namespace.

## What will we learn?

- How to connect a private Git repo using an SSH key
- How to connect a private Git repo using an HTTPS token
- How to connect a Helm chart repository
- How to verify repo connectivity from CLI and UI
- How repo credentials are stored in Kubernetes

---

## Prerequisites

- Complete [Lab 002](../002-first-app/README.md)
- A GitHub/GitLab account with a private repository (or use a public one for testing)

---

## 01. Connect a Private Repo via HTTPS Token

```sh
# Add a private GitHub repo using a personal access token
argocd repo add https://github.com/your-org/private-repo.git \
  --username your-github-username \
  --password ghp_YourPersonalAccessToken

# List connected repos
argocd repo list

# Check connectivity
argocd repo get https://github.com/your-org/private-repo.git
```

---

## 02. Connect a Private Repo via SSH Key

```sh
# Generate an SSH key pair (skip if you already have one)
ssh-keygen -t ed25519 -C "argocd@labs" -f ~/.ssh/argocd_ed25519 -N ""

# Print the public key - add this to your Git provider's Deploy Keys
cat ~/.ssh/argocd_ed25519.pub

# Add the repo using the private key
argocd repo add git@github.com:your-org/private-repo.git \
  --ssh-private-key-path ~/.ssh/argocd_ed25519

# Verify
argocd repo list
```

---

## 03. Connect a Helm Repository

```sh
# Add a public Helm repository (Bitnami)
argocd repo add https://charts.bitnami.com/bitnami \
  --type helm \
  --name bitnami

# Add a private Helm OCI registry
argocd repo add oci://registry.example.com/helm-charts \
  --type helm \
  --name private-oci \
  --username myuser \
  --password mypassword

# List all repos including Helm repos
argocd repo list
```

---

## 04. How Credentials Are Stored

ArgoCD stores repo credentials as Kubernetes Secrets with specific labels:

```sh
# View repo secrets
kubectl get secrets -n argocd -l "argocd.argoproj.io/secret-type=repository"

# Inspect a repo secret (base64 encoded values)
kubectl get secret -n argocd -l "argocd.argoproj.io/secret-type=repository" \
  -o yaml

# The secret type label values:
# repository       -> individual repo credentials
# repo-creds       -> credential template (applies to URL prefix)
# cluster          -> cluster connection credentials
```

---

## 05. Repository Templates (Credential Templates)

Instead of adding credentials per-repo, you can set a credential template for an entire GitHub org:

```sh
# Add credentials for all repos under github.com/your-org
argocd repocreds add https://github.com/your-org/ \
  --username your-github-username \
  --password ghp_YourPersonalAccessToken

# Now any repo under https://github.com/your-org/ will use these creds
argocd repocreds list
```

---

## 06. Test Connectivity

```sh
# Force a refresh of a specific repo
argocd repo get https://github.com/argoproj/argocd-example-apps.git

# Check status in argocd app list
argocd app list

# If a repo is unreachable, the app will show ComparisonError
# Check logs of repo-server for details
kubectl logs -n argocd deploy/argocd-repo-server --tail=50
```

---

<img src="../assets/images/practice.png" alt="Practice" width="800"/>

## 07. Hands-on

1. Add the public `argocd-example-apps` repository via HTTPS and verify its status is `Successful`:

   ??? success "Solution"

   ```sh
   argocd repo add https://github.com/argoproj/argocd-example-apps.git
   argocd repo list
   # ConnectionState should show: Successful
   ```

2. Add the Bitnami Helm repository and list all repositories including their type:

   ??? success "Solution"

   ```sh
   argocd repo add https://charts.bitnami.com/bitnami \
     --type helm \
     --name bitnami
   argocd repo list
   # Should show TYPE=helm for the Bitnami entry
   ```

3. Inspect the Kubernetes Secret that ArgoCD created for the connected repository:

   ??? success "Solution"

   ```sh
   kubectl get secrets -n argocd \
     -l "argocd.argoproj.io/secret-type=repository" \
     -o yaml
   # Note: values are base64 encoded
   ```

4. Remove the Bitnami repo and verify it no longer appears in the list:

   ??? success "Solution"

   ```sh
   argocd repo rm https://charts.bitnami.com/bitnami
   argocd repo list
   # Bitnami entry should be gone
   ```

---

## 08. Summary

- ArgoCD supports three authentication methods for Git repos: SSH keys, HTTPS tokens, and TLS certificates
- Credential templates (`repocreds`) let you apply one credential to all repos under a URL prefix
- Helm repositories are added with `--type helm` and support both HTTP-based and OCI registries
- All repo credentials are stored as Kubernetes Secrets with label `argocd.argoproj.io/secret-type=repository`
- Use `kubectl logs deploy/argocd-repo-server` to diagnose repository connection issues
