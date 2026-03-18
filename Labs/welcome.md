<!-- header start -->
<div markdown class="center">
# ArgoCD Labs

</div>

---

!!! success "Getting Started Tip"
Choose the preferred way to run the labs. If you encounter any issues, please contact your instructor.

<div class="grid cards" markdown style="text-align: center;border-radius: 20px;">

- ![](assets/images/kind-logo.png)

  ```bash
  cd 000-setup && bash _demo.sh
  ```

- [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://console.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https://github.com/nirgeier/ArgoCDLabs)

</div>

## Intro

- This tutorial teaches ArgoCD through hands-on labs designed as practical exercises.
- Each lab is packaged in its own folder and includes the files, manifests, and assets required to complete the lab.
- Every lab folder includes a `README` that describes the lab's objectives, tasks, and how to verify the solution.
- The ArgoCD Labs are a series of GitOps exercises designed to teach players ArgoCD skills and features.
- The inspiration for this project is to provide practical learning experiences for GitOps and continuous delivery.

## Pre-Requirements

- This tutorial will test your `Kubernetes`, `ArgoCD`, and `GitOps` skills.
- You should be familiar with the following topics:
  - Basic Linux commands and shell scripting
  - Kubernetes core concepts (`pods`, `deployments`, `services`)
  - Basic knowledge of YAML
  - Basic Git knowledge
- For advanced Labs:
  - `Kubernetes` networking and RBAC
  - `Helm` and `Kustomize` basics

## Usage

- There are several ways to run the ArgoCD Labs.
- Choose the method that works best for you.
  - Local cluster with `kind` or `k3d` (Recommended)
  - Using Google Cloud Shell
  - Any existing Kubernetes cluster

=== "Local kind cluster (Recommended)"

    The easiest way to get started locally:

    ```bash
    # Install kind
    brew install kind  # macOS
    # or
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64 && chmod +x ./kind

    # Run the setup lab
    cd Labs/000-setup
    bash _demo.sh
    ```

    **Prerequisites:**

    - Docker installed and running
    - `kubectl` installed
    - `kind` or `k3d` installed
    - `argocd` CLI installed

=== "Google Cloud Shell"

    - Google Cloud Shell provides a free, browser-based environment with Kubernetes tools pre-installed.
    - Click on the `Open in Google Cloud Shell` button below:

      [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://console.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https://github.com/nirgeier/ArgoCDLabs)

    - The repository will automatically be cloned into a free Cloud instance.
    - Use **<kbd>CTRL</kbd>** + click to open it in a new window.
    - Follow the instructions in the README of each lab.

---

!!! warning "" - Ensure you have the necessary permissions to create Kubernetes clusters and namespaces. - Enjoy, and don't forget to star the project on GitHub!

## Preface

### What is ArgoCD?

- `ArgoCD` is a declarative, GitOps continuous delivery tool for Kubernetes.
- It follows the GitOps pattern of using Git repositories as the source of truth for defining the desired application state.
- ArgoCD automates the deployment of the desired application states in the specified target environments.
- Application deployments can track updates to branches, tags, or specific versions of manifests in Git.

### How ArgoCD Works

- ArgoCD continuously monitors running applications and compares the current state against the desired state in Git.
- When a difference (drift) is detected, ArgoCD can automatically or manually sync the application back to the desired state.
- ArgoCD supports multiple config management tools: plain YAML, Helm, Kustomize, Jsonnet, and more.

### GitOps Principles

1. **Declarative**: The entire system is described declaratively.
2. **Versioned and Immutable**: The desired state is stored in Git with history.
3. **Pulled Automatically**: Software agents pull the desired state from Git.
4. **Continuously Reconciled**: Software agents observe actual vs desired state and reconcile.
