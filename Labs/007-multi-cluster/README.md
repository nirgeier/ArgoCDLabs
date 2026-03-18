---
# Multi-Cluster Deployments

* ArgoCD can deploy applications to multiple Kubernetes clusters from a single control plane.
* External clusters are registered using their kubeconfig credentials.
* You can target clusters by name, URL, or labels for flexible multi-environment deployments.

## What will we learn?

- How to register an external cluster with ArgoCD
- How to deploy applications to multiple clusters
- How to use cluster labels for targeting
- How cluster credentials are stored

---

## Prerequisites

- Complete [Lab 002](../002-first-app/README.md)
- `kind` installed to create a second cluster

---

## 01. Create a Second Cluster

```sh
# Create a second kind cluster to act as a "remote" cluster
kind create cluster --name argocd-workload --wait 60s

# Verify both clusters exist
kind get clusters
# argocd-labs
# argocd-workload

# Verify kubectl contexts
kubectl config get-contexts
```

---

## 02. Register the External Cluster

```sh
# ArgoCD uses the current kubeconfig context to register clusters
# Switch to the ArgoCD management cluster context first
kubectl config use-context kind-argocd-labs

# Ensure you're logged into ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
sleep 3
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
argocd login localhost:8080 --username admin --password "$ARGOCD_PASS" --insecure

# Register the workload cluster
argocd cluster add kind-argocd-workload --name workload-cluster

# List registered clusters
argocd cluster list
```

---

## 03. How Cluster Credentials Are Stored

```sh
# Cluster credentials are stored as Secrets in the argocd namespace
kubectl get secrets -n argocd -l "argocd.argoproj.io/secret-type=cluster"

# Inspect the cluster secret
kubectl get secret -n argocd \
  -l "argocd.argoproj.io/secret-type=cluster" \
  -o jsonpath='{.items[0].data.server}' | base64 -d && echo
```

---

## 04. Deploy an App to the Remote Cluster

```sh
# Create an application targeting the workload cluster
argocd app create guestbook-remote \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-name workload-cluster \
  --dest-namespace guestbook \
  --sync-option CreateNamespace=true

# Sync it
argocd app sync guestbook-remote

# Verify the deployment in the workload cluster
kubectl get pods -n guestbook --context kind-argocd-workload
```

---

## 05. Deploy to Multiple Clusters with Labels

Cluster labels allow you to target groups of clusters:

```sh
# Add labels to clusters
argocd cluster set https://kubernetes.default.svc \
  --label env=management

# Get the workload cluster server URL
WORKLOAD_URL=$(argocd cluster list -o json | python3 -c \
  "import sys,json; [print(c['server']) for c in json.load(sys.stdin) if c['name']=='workload-cluster']")

argocd cluster set "$WORKLOAD_URL" --label env=staging

# List clusters with labels
argocd cluster list
```

---

## 06. Remove a Cluster

```sh
# Remove the workload cluster from ArgoCD
argocd cluster rm https://$(kubectl config view \
  --context kind-argocd-workload \
  -o jsonpath='{.clusters[0].cluster.server}') || true

# Or by cluster name
argocd cluster rm workload-cluster --yes || true

# Clean up the kind cluster
kind delete cluster --name argocd-workload || true
```

---

<img src="../assets/images/practice.png" alt="Practice" width="800"/>

## 07. Hands-on

1. Create a second kind cluster named `argocd-workload` and register it with ArgoCD:

   ??? success "Solution"

   ```sh
   kind create cluster --name argocd-workload --wait 60s
   kubectl config use-context kind-argocd-labs
   argocd cluster add kind-argocd-workload --name workload-cluster
   argocd cluster list
   ```

2. Deploy the `guestbook` application to the `workload-cluster` and verify the pods are running there:

   ??? success "Solution"

   ```sh
   argocd app create guestbook-remote \
     --repo https://github.com/argoproj/argocd-example-apps.git \
     --path guestbook \
     --dest-name workload-cluster \
     --dest-namespace guestbook \
     --sync-option CreateNamespace=true
   argocd app sync guestbook-remote
   argocd app wait guestbook-remote --health --timeout 120
   kubectl get pods -n guestbook --context kind-argocd-workload
   ```

3. Label the workload cluster with `env=staging` and verify the label appears in `argocd cluster list`:

   ??? success "Solution"

   ```sh
   WORKLOAD_SERVER=$(argocd cluster list -o json | \
     python3 -c "import sys,json; [print(c['server']) for c in json.load(sys.stdin) if c['name']=='workload-cluster']")
   argocd cluster set "$WORKLOAD_SERVER" --label env=staging
   argocd cluster list
   ```

---

## 08. Summary

- ArgoCD registers external clusters using kubeconfig credentials stored as Kubernetes Secrets
- The `argocd cluster add <context>` command creates a ServiceAccount in the target cluster with the necessary permissions
- Use `--dest-name` (cluster name) or `--dest-server` (cluster URL) to target applications to specific clusters
- Cluster labels enable flexible targeting strategies - useful with ApplicationSets (Lab 022)
- ArgoCD's management cluster is always available as `https://kubernetes.default.svc`
