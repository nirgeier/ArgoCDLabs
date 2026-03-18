---
# ArgoCD Components Deep Dive

* ArgoCD is composed of several microservices, each with a distinct responsibility.
* Understanding the components helps you troubleshoot issues and tune the installation.
* ArgoCD uses Custom Resource Definitions (CRDs) to represent Applications, AppProjects, and ApplicationSets.

## What will we learn?

- The role of each ArgoCD component: server, repo-server, application-controller, dex, redis
- How to verify all pods are healthy and ready
- What ArgoCD CRDs are installed and what they represent
- How to inspect the ArgoCD namespace for resources

---

## Prerequisites

- Complete [Lab 000](../000-setup/README.md) to have a running ArgoCD installation

---

## 01. ArgoCD Architecture Overview

ArgoCD consists of these core components:

```text
argocd namespace
├── argocd-server                  # API server + Web UI (gRPC + REST)
├── argocd-repo-server             # Clones repos, generates manifests
├── argocd-application-controller  # Reconciliation loop (desired vs actual)
├── argocd-dex-server              # SSO / OIDC identity provider bridge
├── argocd-redis                   # In-memory cache for repo-server/app-controller
└── argocd-notifications-controller # Sends alerts (Slack, email, etc.)
```

---

## 02. Component Roles

| Component                                                                   | Role                                                                                                                                                |
| --------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| :material-web:{ style="color: #FFD700" } `argocd-server`                    | API server - serves the web UI over HTTPS, exposes the gRPC API (used by the `argocd` CLI), handles authentication and authorization                |
| :material-source-repository:{ style="color: #FFD700" } `argocd-repo-server` | Repository server - clones Git repositories, runs Helm/Kustomize/other config management tools, caches rendered manifests in Redis                  |
| :material-sync:{ style="color: #FFD700" } `argocd-application-controller`   | Reconciliation engine - continuously compares desired state (Git) with actual state (cluster), reports sync/health status, triggers automatic syncs |
| :material-shield-account:{ style="color: #FFD700" } `argocd-dex-server`     | Identity provider bridge - supports GitHub, GitLab, LDAP, OIDC, bridges external identity to ArgoCD's internal user model                           |
| :material-database:{ style="color: #FFD700" } `argocd-redis`                | Shared cache - caches repository data from `argocd-repo-server`, reduces repeated Git clones and manifest generation                                |

---

## 03. Verify All Pods Running

```sh
# Check all pods in the argocd namespace
kubectl get pods -n argocd

# Watch pods in real time
kubectl get pods -n argocd -w

# Detailed pod information
kubectl describe pods -n argocd

# Check resource usage
kubectl top pods -n argocd 2>/dev/null || echo "metrics-server not installed"
```

---

## 04. Explore ArgoCD CRDs

ArgoCD installs three CRDs into the cluster:

```sh
# List all ArgoCD CRDs
kubectl get crd | grep argoproj.io

# Describe the Application CRD
kubectl explain application --api-version argoproj.io/v1alpha1

# Describe the AppProject CRD
kubectl explain appproject --api-version argoproj.io/v1alpha1

# Describe the ApplicationSet CRD
kubectl explain applicationset --api-version argoproj.io/v1alpha1
```

The three CRDs:

- `applications.argoproj.io` - represents a deployed application (source + destination)
- `appprojects.argoproj.io` - represents a logical grouping with access controls
- `applicationsets.argoproj.io` - represents a template that generates multiple Applications

---

## 05. Inspect Services and ConfigMaps

```sh
# List all services
kubectl get svc -n argocd

# List all ConfigMaps
kubectl get cm -n argocd

# Inspect the main ArgoCD config
kubectl describe cm argocd-cm -n argocd

# Inspect RBAC config
kubectl describe cm argocd-rbac-cm -n argocd

# List secrets (do not print values)
kubectl get secrets -n argocd
```

---

## 06. ArgoCD Server Version Info

```sh
# Check ArgoCD server version (requires port-forward to be active)
argocd version

# Check via kubectl
kubectl -n argocd exec deploy/argocd-server -- argocd version --server-side-only 2>/dev/null || true

# Get server info
argocd info 2>/dev/null || true
```

---

<img src="../assets/images/practice.png" alt="Practice" width="800"/>

## 07. Hands-on

1. List all pods in the `argocd` namespace and confirm every pod is `1/1 Running`:

   ??? success "Solution"

   ```sh
   kubectl get pods -n argocd
   # All pods should show STATUS=Running and READY=1/1
   ```

2. Describe the `argocd-application-controller` StatefulSet and find its replica count and image version:

   ??? success "Solution"

   ```sh
   kubectl describe statefulset argocd-application-controller -n argocd
   # Look for: Replicas and Image fields
   kubectl get statefulset argocd-application-controller -n argocd \
     -o jsonpath='{.spec.template.spec.containers[0].image}'
   ```

3. List all three ArgoCD CRDs and print the full name of each:

   ??? success "Solution"

   ```sh
   kubectl get crd | grep argoproj.io
   # Expected:
   # applicationsets.argoproj.io
   # applications.argoproj.io
   # appprojects.argoproj.io
   ```

4. Inspect the `argocd-cm` ConfigMap and identify where you would set the `admin.enabled` flag:

   ??? success "Solution"

   ```sh
   kubectl get cm argocd-cm -n argocd -o yaml
   # The admin.enabled key can be added under data:
   # data:
   #   admin.enabled: "true"
   ```

---

## 08. Summary

- ArgoCD is composed of six microservices: `server`, `repo-server`, `application-controller`, `dex-server`, `redis`, and `notifications-controller`
- The `application-controller` is the reconciliation engine - it compares Git state with cluster state on every sync interval
- Three CRDs define the ArgoCD API: `Application`, `AppProject`, and `ApplicationSet`
- Configuration is stored in ConfigMaps (`argocd-cm`, `argocd-rbac-cm`) in the `argocd` namespace
- Use `kubectl describe` and `kubectl get -o yaml` to inspect any ArgoCD resource in detail
