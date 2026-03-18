---

# GitOps Best Practices

* GitOps is effective only when the repository structure, branching strategy, and promotion workflow are designed intentionally.
* Keeping Git as the single source of truth requires discipline: no `kubectl apply` by hand, no out-of-band secrets.
* A well-structured GitOps repository scales from one team to dozens without becoming a maintenance burden.

## What will we learn?

- Mono-repo vs multi-repo strategies and when to use each
- Recommended folder structures for Kustomize and Helm GitOps repos
- Environment promotion workflows (image tag update, PR-based promotion)
- Secrets management options compatible with GitOps
- Common anti-patterns to avoid

---

## Prerequisites

- Complete [Lab 010](../010-kustomize/README.md) (Kustomize)
- Complete [Lab 009](../009-helm-integration/README.md) (Helm)

---

## 01. Mono-repo vs Multi-repo

| Strategy       | Pros                       | Cons                                    |
| -------------- | -------------------------- | --------------------------------------- |
| **Mono-repo**  | Atomic changes, single PR  | RBAC harder, large repos slow           |
| **Multi-repo** | Clear ownership, fine RBAC | Cross-service changes need multiple PRs |
| **Hybrid**     | Config repo + app repos    | Best of both worlds                     |

**Recommended**: Separate "config repo" (GitOps manifests) from "app repos" (source code).

---

## 02. Recommended Repository Structure

```text
gitops-config-repo/
├── bootstrap/              # ArgoCD App-of-Apps root
│   └── root-app.yaml
├── infra/                  # Cluster-wide infrastructure
│   ├── cert-manager/
│   ├── ingress-nginx/
│   └── monitoring/
├── apps/                   # Application deployments
│   ├── frontend/
│   │   ├── base/
│   │   │   ├── deployment.yaml
│   │   │   └── kustomization.yaml
│   │   └── overlays/
│   │       ├── dev/
│   │       │   ├── kustomization.yaml   ← image: frontend:dev-abc123
│   │       ├── staging/
│   │       └── prod/
│   └── backend/
│       └── ...
└── projects/               # AppProject CRs
    ├── team-alpha.yaml
    └── team-beta.yaml
```

---

## 03. Image Tag Promotion Workflow

CI/CD writes back to the GitOps repo when a new image is built:

```sh
# In your CI pipeline (GitHub Actions example):
# 1. Build and push image
docker build -t registry.io/org/frontend:${GIT_SHA} .
docker push registry.io/org/frontend:${GIT_SHA}

# 2. Update the dev overlay image tag in the GitOps repo
git clone https://github.com/org/gitops-config-repo
cd gitops-config-repo

# Use kustomize edit to update the image
kustomize edit set image \
  registry.io/org/frontend=registry.io/org/frontend:${GIT_SHA} \
  --kustomizationfile apps/frontend/overlays/dev/kustomization.yaml

# 3. Commit and push - ArgoCD auto-syncs dev
git commit -am "promote frontend:${GIT_SHA} to dev"
git push

# 4. After dev validation, open PR to promote to staging/prod
```

---

## 04. Branch Strategy

```sh
# Recommended: environment branches map to ArgoCD targets
git branch --list
# main      → production (protected, requires PR + approval)
# staging   → staging environment
# dev       → development (auto-merge from CI)
```

ArgoCD Application targets per environment:

```yaml
# dev Application watches 'dev' branch
spec:
  source:
    targetRevision: dev
    path: apps/frontend/overlays/dev
  syncPolicy:
    automated:
      selfHeal: true
      prune: true

# prod Application watches 'main' branch (manual sync recommended)
spec:
  source:
    targetRevision: main
    path: apps/frontend/overlays/prod
  syncPolicy: {}   # No automated sync in prod
```

---

## 05. Secrets Management

Never commit plaintext secrets to Git. Choose one:

| Option                          | How it works                                        | Complexity |
| ------------------------------- | --------------------------------------------------- | ---------- |
| **Sealed Secrets**              | Encrypt with cluster public key, commit ciphertext  | Low        |
| **External Secrets Operator**   | Reference AWS/GCP/Vault secrets by name             | Medium     |
| **SOPS + age/GPG**              | Encrypt files before commit, decrypt at deploy time | Medium     |
| **Vault + ArgoCD Vault Plugin** | Inject secrets from Vault at sync time              | High       |

```sh
# Sealed Secrets quick example
kubeseal --format yaml < secret.yaml > sealed-secret.yaml
git add sealed-secret.yaml   # Safe to commit
```

---

## 06. Anti-Patterns to Avoid

```text
❌ kubectl apply by hand on production      → Use ArgoCD sync only
❌ Storing plaintext secrets in Git         → Use Sealed Secrets or ESO
❌ One giant repository with no structure   → Use the folder hierarchy above
❌ Disabling selfHeal in production         → Enable with caution + alerts
❌ Auto-sync + prune in prod without review → Use manual sync gates for prod
❌ Different app versions per env in one file → Use overlays / values files
```

---

## Hands-on Tasks

1. Create a Kustomize-based GitOps repo with `base/` and three overlays (`dev`, `staging`, `prod`)
2. Write a shell script that updates the image tag in the dev overlay and commits the change
3. Create ArgoCD Applications pointing to each overlay with appropriate sync policies
4. Install Sealed Secrets and encrypt a Kubernetes Secret - commit the sealed version
5. Document your team's Git branching strategy and which ArgoCD sync policy maps to each branch

---

## 08. Summary

- Separate the GitOps config repo from application source repos - this gives clean RBAC and promotion boundaries
- Use Kustomize overlays or Helm values files per environment rather than duplicating full manifests
- CI writes image tags back to Git; ArgoCD detects the commit and deploys - no `kubectl` in CI pipelines
- Production sync should be **manual** (or require PR approval) to prevent accidental auto-deploys
- Never commit plaintext secrets - use Sealed Secrets, External Secrets Operator, or SOPS
