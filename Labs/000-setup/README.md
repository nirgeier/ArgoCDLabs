---
# Environment Setup

* In this lab we install all the tools needed to run the remaining ArgoCD labs locally.
* We create a local Kubernetes cluster using `kind` and install ArgoCD into it.
* By the end of this lab you will have a fully functional ArgoCD instance accessible at `https://localhost:8080`.

## What will we learn?

- How to install `kubectl`, `kind`, and the `argocd` CLI
- How to create a local Kubernetes cluster with kind
- How to install ArgoCD via `kubectl apply`
- How to access the ArgoCD UI with port-forwarding
- How to retrieve the initial admin password

---

## Prerequisites

- Docker installed and running
- Internet access to pull images and install tools
- macOS, Linux, or Windows with WSL2

---

## 01. Install kubectl

`kubectl` is the Kubernetes command-line tool used to interact with any cluster.

```sh
# macOS (Homebrew)
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Verify
kubectl version --client
```

---

## 02. Install kind

`kind` (Kubernetes IN Docker) runs Kubernetes clusters as Docker containers - ideal for local development.

```sh
# macOS (Homebrew)
brew install kind

# Linux
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Verify
kind version
```

---

## 03. Install ArgoCD CLI

The `argocd` CLI lets you manage applications, repos, and clusters from the terminal.

```sh
# macOS (Homebrew)
brew install argocd

# Linux
curl -sSL -o argocd-linux-amd64 \
  https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd-linux-amd64
sudo mv argocd-linux-amd64 /usr/local/bin/argocd

# Verify
argocd version --client
```

---

## 04. Create a Local Kubernetes Cluster

We use kind to spin up a single-node cluster named `argocd-labs`.

```sh
# Create cluster
kind create cluster --name argocd-labs

# Verify the cluster is running
kubectl cluster-info --context kind-argocd-labs
kubectl get nodes
```

Expected output:

```
NAME                        STATUS   ROLES           AGE   VERSION
argocd-labs-control-plane   Ready    control-plane   30s   v1.29.x
```

---

## 05. Install ArgoCD

ArgoCD is installed into its own namespace using the official install manifest.

```sh
# Create the argocd namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for all pods to be Ready
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Verify all pods are running
kubectl get pods -n argocd
```

Expected pods:

```
argocd-application-controller-0      1/1   Running
argocd-dex-server-xxx                1/1   Running
argocd-notifications-controller-xxx  1/1   Running
argocd-redis-xxx                     1/1   Running
argocd-repo-server-xxx               1/1   Running
argocd-server-xxx                    1/1   Running
```

---

## 06. Access the ArgoCD UI

Port-forward the ArgoCD server to access it locally:

```sh
# Port-forward in the background
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# The UI is now available at: https://localhost:8080
# (accept the self-signed certificate warning)
```

---

## 07. Get Initial Admin Password

ArgoCD generates a random initial password stored in a Kubernetes Secret.

```sh
# Get the initial admin password
argocd admin initial-password -n argocd

# Or directly via kubectl
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Login with the CLI
argocd login localhost:8080 \
  --username admin \
  --password $(kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d) \
  --insecure

# Change the password (recommended)
argocd account update-password
```

---

<img src="../assets/images/practice.png" alt="Practice" width="800"/>

## 08. Hands-on

1. Create a kind cluster named `argocd-labs` and verify the node is Ready:

   ??? success "Solution"

   ```sh
   kind create cluster --name argocd-labs
   kubectl get nodes --context kind-argocd-labs
   ```

2. Install ArgoCD and wait until all pods in the `argocd` namespace are Running:

   ??? success "Solution"

   ```sh
   kubectl create namespace argocd
   kubectl apply -n argocd \
     -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
   kubectl get pods -n argocd
   ```

3. Port-forward the ArgoCD server and log in with the CLI using the initial admin password:

   ??? success "Solution"

   ```sh
   kubectl port-forward svc/argocd-server -n argocd 8080:443 &
   ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
     -o jsonpath="{.data.password}" | base64 -d)
   argocd login localhost:8080 --username admin --password "$ARGOCD_PASS" --insecure
   argocd version
   ```

4. List all ArgoCD CRDs installed in the cluster:

   ??? success "Solution"

   ```sh
   kubectl get crd | grep argoproj
   # Expected output includes:
   # applications.argoproj.io
   # applicationsets.argoproj.io
   # appprojects.argoproj.io
   ```

---

## 09. Summary

- `kind` creates lightweight Kubernetes clusters inside Docker containers - perfect for local ArgoCD labs
- ArgoCD installs into its own `argocd` namespace from the official install manifest
- The `argocd-server` pod serves both the web UI and the gRPC API for the CLI
- The initial admin password is stored in the `argocd-initial-admin-secret` Kubernetes Secret
- Always change the initial admin password after first login
