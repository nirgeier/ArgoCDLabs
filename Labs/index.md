# ArgoCD Labs

## Lab Overview

Welcome to the hands-on ArgoCD labs! This comprehensive series of 26 labs guides you from basic setup through advanced topics like progressive delivery, ApplicationSets, secrets management, and GitOps best practices.

---

## Available Labs

### Beginner Track - Foundation

| Lab                                   | Topic            | Description                                                             |
| ------------------------------------- | ---------------- | ----------------------------------------------------------------------- |
| [000](000-setup/README.md)            | Setup            | Install kubectl, kind, ArgoCD CLI; create local cluster; install ArgoCD |
| [001](001-argocd-install/README.md)   | ArgoCD Install   | Deep dive into ArgoCD components, CRDs, and architecture                |
| [002](002-first-app/README.md)        | First App        | Create your first ArgoCD Application and observe sync                   |
| [003](003-git-repo-connect/README.md) | Git Repo Connect | Connect private Git repos via SSH and HTTPS tokens                      |
| [004](004-sync-policies/README.md)    | Sync Policies    | Manual sync, automated sync, SelfHeal, Prune, and sync windows          |
| [005](005-health-checks/README.md)    | Health Checks    | Built-in and custom health checks, health status states                 |

### Intermediate Track - Core Skills

| Lab                                   | Topic            | Description                                                          |
| ------------------------------------- | ---------------- | -------------------------------------------------------------------- |
| [006](006-rollback/README.md)         | Rollback         | Rollback to previous revision, history, diff, and undo               |
| [007](007-multi-cluster/README.md)    | Multi Cluster    | Register external clusters and deploy across multiple environments   |
| [008](008-app-of-apps/README.md)      | App of Apps      | Bootstrap a cluster from a single root ArgoCD Application            |
| [009](009-helm-integration/README.md) | Helm Integration | Deploy Helm charts with value overrides and post-renderers           |
| [010](010-kustomize/README.md)        | Kustomize        | Deploy Kustomize apps with base + overlays per environment           |
| [011](011-notifications/README.md)    | Notifications    | Slack/email alerts on sync events using notification templates       |
| [012](012-rbac/README.md)             | RBAC             | ArgoCD RBAC policies, roles, and project-level access control        |
| [013](013-sso/README.md)              | SSO              | Configure SSO with Dex, GitHub OAuth, and group-based RBAC           |
| [014](014-projects/README.md)         | Projects         | AppProjects with source/destination restrictions and resource limits |
| [015](015-waves-hooks/README.md)      | Waves & Hooks    | Sync phases, resource hooks, and wave-based ordering                 |

### Advanced Track - Expert Topics

| Lab                                        | Topic                 | Description                                                    |
| ------------------------------------------ | --------------------- | -------------------------------------------------------------- |
| [016](016-secrets-management/README.md)    | Secrets Management    | Sealed Secrets, External Secrets Operator, Vault integration   |
| [017](017-image-updater/README.md)         | Image Updater         | Automatic image tag updates with write-back strategies         |
| [018](018-ci-integration/README.md)        | CI Integration        | GitHub Actions + ArgoCD GitOps workflow end-to-end             |
| [019](019-monitoring/README.md)            | Monitoring            | Prometheus metrics, Grafana dashboards, and alert rules        |
| [020](020-disaster-recovery/README.md)     | Disaster Recovery     | Backup, restore ArgoCD state, and HA setup                     |
| [021](021-multi-tenancy/README.md)         | Multi Tenancy         | Namespace isolation, project boundaries, tenant onboarding     |
| [022](022-app-sets/README.md)              | App Sets              | ApplicationSets with List, Cluster, and Git generators         |
| [023](023-progressive-delivery/README.md)  | Progressive Delivery  | Argo Rollouts: Canary, Blue/Green, and traffic splitting       |
| [024](024-gitops-best-practices/README.md) | GitOps Best Practices | Repo structure, mono-repo vs multi-repo, environment promotion |
| [025](025-advanced-patterns/README.md)     | Advanced Patterns     | Config Management Plugins, API automation, drift remediation   |

---

## Learning Paths

### Beginner Path

Start here if you're new to ArgoCD and GitOps:

1. [Lab 000: Setup](000-setup/README.md)
2. [Lab 001: ArgoCD Install](001-argocd-install/README.md)
3. [Lab 002: First App](002-first-app/README.md)
4. [Lab 003: Git Repo Connect](003-git-repo-connect/README.md)
5. [Lab 004: Sync Policies](004-sync-policies/README.md)
6. [Lab 005: Health Checks](005-health-checks/README.md)

### Intermediate Path

For those comfortable with ArgoCD basics:

1. [Lab 006: Rollback](006-rollback/README.md)
2. [Lab 008: App of Apps](008-app-of-apps/README.md)
3. [Lab 009: Helm Integration](009-helm-integration/README.md)
4. [Lab 010: Kustomize](010-kustomize/README.md)
5. [Lab 012: RBAC](012-rbac/README.md)
6. [Lab 014: Projects](014-projects/README.md)
7. [Lab 015: Waves & Hooks](015-waves-hooks/README.md)

### Advanced Path

For experienced GitOps engineers:

1. [Lab 016: Secrets Management](016-secrets-management/README.md)
2. [Lab 017: Image Updater](017-image-updater/README.md)
3. [Lab 018: CI Integration](018-ci-integration/README.md)
4. [Lab 022: App Sets](022-app-sets/README.md)
5. [Lab 023: Progressive Delivery](023-progressive-delivery/README.md)
6. [Lab 024: GitOps Best Practices](024-gitops-best-practices/README.md)
7. [Lab 025: Advanced Patterns](025-advanced-patterns/README.md)

---

## Tips for Success

- **Take your time**: Don't rush through the labs - understanding beats speed
- **Read the diff**: ArgoCD's diff view shows exactly what changed - use it
- **Use the UI and CLI**: Practice both `argocd` CLI commands and the web UI
- **Break and fix**: Intentionally cause drift, then watch ArgoCD reconcile
- **Commit your work**: Use Git to track your manifests as they evolve
- **Check events**: `kubectl describe application -n argocd <name>` reveals a lot

## Get Started

Ready to begin? Start with [Lab 000: Setup](000-setup/README.md)!
