---
# CI/CD Integration with ArgoCD

* ArgoCD handles the CD (continuous delivery) portion of the CI/CD pipeline.
* The CI pipeline builds and pushes the image; it then updates the image tag in Git; ArgoCD detects the change and syncs.
* This clean separation ensures all deployments are GitOps-driven and auditable.

## What will we learn?

- The full GitOps CI/CD workflow end-to-end
- How GitHub Actions integrates with ArgoCD
- How to update the image tag in Git from a CI pipeline
- How to trigger ArgoCD sync from CI
- The "push image, update Git, ArgoCD syncs" pattern

---

## Prerequisites

- Complete [Lab 004](../004-sync-policies/README.md)
- A GitHub repository and Actions enabled

---

## 01. GitOps CI/CD Flow

```text
GitOps Pipeline:

Developer pushes code
        │
        ▼
CI Pipeline (GitHub Actions)
  1. Build Docker image
  2. Run tests
  3. Push image to registry (e.g., ghcr.io/org/app:sha-abc123)
  4. Update image tag in Git (manifests repo or values file)
        │
        ▼
ArgoCD detects Git change (polling or webhook)
  5. Detects OutOfSync state
  6. Syncs to new desired state
  7. Rolls out new image version
        │
        ▼
PostSync notification → Slack/email
```

---

## 02. GitHub Actions Workflow for CI

```yaml
# .github/workflows/ci.yml
name: Build and Push

on:
  push:
    branches: [main]
    paths:
      - "src/**"

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: ghcr.io/${{ github.repository_owner }}/my-app:${{ github.sha }}
```

---

## 03. Update Image Tag in Git from CI

After pushing the image, the CI pipeline updates the image tag in the manifests repository:

```yaml
# .github/workflows/update-manifests.yml
- name: Update image tag in manifests repo
  env:
    GIT_TOKEN: ${{ secrets.MANIFESTS_REPO_TOKEN }}
  run: |
    git clone https://x-access-token:${GIT_TOKEN}@github.com/your-org/manifests.git
    cd manifests

    # Update the image tag (using yq or sed)
    yq e ".spec.template.spec.containers[0].image = \"ghcr.io/your-org/my-app:${{ github.sha }}\"" \
      -i apps/my-app/deployment.yaml

    git config user.email "ci@github.com"
    git config user.name "GitHub Actions"
    git add .
    git commit -m "chore: update my-app image to ${{ github.sha }}"
    git push
```

---

## 04. Trigger ArgoCD Sync from CI (Optional)

If you want an immediate sync instead of waiting for ArgoCD's polling interval:

```yaml
- name: Sync ArgoCD Application
  env:
    ARGOCD_SERVER: argocd.your-domain.com
    ARGOCD_AUTH_TOKEN: ${{ secrets.ARGOCD_AUTH_TOKEN }}
  run: |
    # Install ArgoCD CLI
    curl -sSL -o argocd \
      https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    chmod +x argocd

    # Sync the application
    ./argocd app sync my-app \
      --server "$ARGOCD_SERVER" \
      --auth-token "$ARGOCD_AUTH_TOKEN" \
      --insecure

    # Wait for healthy
    ./argocd app wait my-app \
      --server "$ARGOCD_SERVER" \
      --auth-token "$ARGOCD_AUTH_TOKEN" \
      --health --timeout 120 \
      --insecure
```

---

## 05. ArgoCD API Token for CI

```sh
# Create a dedicated ArgoCD account for CI
kubectl patch cm argocd-cm -n argocd --type merge -p '{
  "data": {
    "accounts.ci-bot": "apiKey"
  }
}' || true

# Generate an API token for the CI bot
argocd account generate-token --account ci-bot

# Grant the CI bot permissions (in argocd-rbac-cm)
# p, ci-bot, applications, sync, */*, allow
# p, ci-bot, applications, get, */*, allow
```

---

## 06. Webhook for Instant Sync

Configure a GitHub webhook to notify ArgoCD immediately on push (instead of polling):

```sh
# Get the ArgoCD webhook URL
# https://<argocd-server>/api/webhook

# In GitHub repository settings:
# Payload URL: https://argocd.your-domain.com/api/webhook
# Content type: application/json
# Secret: (generate a random secret)
# Events: Just the push event

# Configure the webhook secret in ArgoCD
kubectl patch secret argocd-secret -n argocd \
  --type merge -p '{
    "stringData": {
      "webhook.github.secret": "your-webhook-secret"
    }
  }' || true
```

---

<img src="../assets/images/practice.png" alt="Practice" width="800"/>

## 07. Hands-on

1. Create an ArgoCD API key for a `ci-bot` account and verify it can list applications:

   ??? success "Solution"

   ```sh
   # Add ci-bot account to argocd-cm
   kubectl patch cm argocd-cm -n argocd --type merge -p '{
     "data": {"accounts.ci-bot": "apiKey"}
   }' || true
   # Add permissions
   kubectl patch cm argocd-rbac-cm -n argocd --type merge -p '{
     "data": {
       "policy.csv": "p, ci-bot, applications, sync, */*, allow\np, ci-bot, applications, get, */*, allow\n"
     }
   }' || true
   # Generate token
   CI_TOKEN=$(argocd account generate-token --account ci-bot 2>/dev/null || echo "NOT_GENERATED")
   echo "CI Bot token: $CI_TOKEN"
   ```

2. Write a shell script that simulates the "update image tag in manifests" step by patching a Deployment's image in a local YAML file:

   ??? success "Solution"

   ```sh
   NEW_TAG="sha-$(date +%s)"
   echo "Simulating CI image tag update to: $NEW_TAG"
   # In a real scenario you would use yq or sed on your manifests repo
   kubectl set image deployment/guestbook-ui \
     guestbook-ui=gcr.io/heptio-images/ks-guestbook-demo:0.2 \
     -n guestbook || true
   argocd app diff guestbook || true
   ```

---

## 08. Summary

- In GitOps, CI builds and pushes the image; it never deploys directly - it updates Git and ArgoCD deploys
- Separating the application repo from the manifests repo ("two-repo pattern") prevents CI credentials from having cluster access
- ArgoCD API tokens enable CI pipelines to trigger syncs or check application status programmatically
- Webhooks eliminate polling latency - ArgoCD is notified immediately when Git changes
- The `ci-bot` pattern grants CI minimal permissions: only `sync` and `get` on applications
