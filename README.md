<!-- header start -->

<a href="https://stackoverflow.com/users/1755598/codewizard"><img src="https://stackoverflow.com/users/flair/1755598.png" width="208" height="58" alt="profile for CodeWizard at Stack Overflow, Q&amp;A for professional and enthusiast programmers" title="profile for CodeWizard at Stack Overflow, Q&amp;A for professional and enthusiast programmers"></a>&emsp;&emsp;[![Linkedin Badge](https://img.shields.io/badge/-nirgeier-blue?style=flat&logo=Linkedin&logoColor=white&link=https://www.linkedin.com/in/nirgeier/)](https://www.linkedin.com/in/nirgeier/)&emsp;[![Gmail Badge](https://img.shields.io/badge/-nirgeier@gmail.com-fcc624?style=flat&logo=Gmail&logoColor=red&link=mailto:nirgeier@gmail.com)](mailto:nirgeier@gmail.com)&emsp;[![Outlook Badge](https://img.shields.io/badge/-nirg@codewizard.co.il-fcc624?style=flat&logo=microsoftoutlook&logoColor=blue&link=mailto:nirg@codewizard.co.il)](mailto:nirg@codewizard.co.il)

<!-- header end -->

---

# ArgoCD Hands-on Repository

- A collection of Hands-on labs for ArgoCD and GitOps.
- Each lab builds on the previous one, guiding you from basic setup to advanced GitOps patterns.
- Learn ArgoCD by doing - every lab includes real `kubectl` and `argocd` CLI commands.

---

## [🚀 Interactive Labs & Documentation](https://nirgeier.github.io/ArgoCDLabs/)

---

## Labs

<!-- Labs list start -->

| Lab                                             | Topic                 | Description                                             |
| ----------------------------------------------- | --------------------- | ------------------------------------------------------- |
| [000](Labs/000-setup/README.md)                 | Setup                 | Install kubectl, kind, argocd CLI and configure access  |
| [001](Labs/001-argocd-install/README.md)        | ArgoCD Install        | Deploy ArgoCD to Kubernetes, expose UI, first login     |
| [002](Labs/002-first-app/README.md)             | First App             | Create an Application manifest, sync from Git           |
| [003](Labs/003-git-repo-connect/README.md)      | Git Repo Connect      | Connect private repos via SSH key or HTTPS token        |
| [004](Labs/004-sync-policies/README.md)         | Sync Policies         | Manual vs automated sync, prune, self-heal              |
| [005](Labs/005-health-checks/README.md)         | Health Checks         | Built-in health logic, custom Lua health checks         |
| [006](Labs/006-rollback/README.md)              | Rollback              | View sync history, roll back to a previous revision     |
| [007](Labs/007-multi-cluster/README.md)         | Multi-Cluster         | Register external clusters, deploy across clusters      |
| [008](Labs/008-app-of-apps/README.md)           | App of Apps           | Pattern for managing many apps from a single root app   |
| [009](Labs/009-helm-integration/README.md)      | Helm Integration      | Deploy Helm charts, override values, multi-env values   |
| [010](Labs/010-kustomize/README.md)             | Kustomize             | Base + overlay structure, patches, image tags           |
| [011](Labs/011-notifications/README.md)         | Notifications         | Templates, triggers, Slack/email subscriptions          |
| [012](Labs/012-rbac/README.md)                  | RBAC                  | Policy syntax, roles, groups, project-scoped access     |
| [013](Labs/013-sso/README.md)                   | SSO                   | Dex integration, OIDC, GitHub/LDAP connectors           |
| [014](Labs/014-projects/README.md)              | Projects              | AppProjects, source/destination restrictions, quotas    |
| [015](Labs/015-waves-hooks/README.md)           | Waves & Hooks         | Sync phases, PreSync/PostSync/SyncFail hooks, waves     |
| [016](Labs/016-secrets-management/README.md)    | Secrets Management    | Sealed Secrets, External Secrets Operator, Vault        |
| [017](Labs/017-image-updater/README.md)         | Image Updater         | Auto-update image tags in Git on new registry push      |
| [018](Labs/018-ci-integration/README.md)        | CI Integration        | Full GitOps pipeline: CI writes back to GitOps repo     |
| [019](Labs/019-monitoring/README.md)            | Monitoring            | Prometheus metrics, Grafana dashboards, alerts          |
| [020](Labs/020-disaster-recovery/README.md)     | Disaster Recovery     | Backup/restore apps, HA setup, cluster failover         |
| [021](Labs/021-multi-tenancy/README.md)         | Multi-Tenancy         | AppProjects, namespace quotas, RBAC policies            |
| [022](Labs/022-app-sets/README.md)              | ApplicationSets       | List, Cluster, Git, Matrix generators                   |
| [023](Labs/023-progressive-delivery/README.md)  | Progressive Delivery  | Argo Rollouts, canary steps, blue/green, analysis       |
| [024](Labs/024-gitops-best-practices/README.md) | GitOps Best Practices | Mono vs multi-repo, Kustomize overlays, image promotion |
| [025](Labs/025-advanced-patterns/README.md)     | Advanced Patterns     | CMP, REST API automation, sync waves, hooks             |

<!-- Labs list ends -->
