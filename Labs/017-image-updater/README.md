---

# ArgoCD Image Updater

* ArgoCD Image Updater automatically updates container image tags in ArgoCD Applications when new images are pushed to a registry.
* It supports write-back strategies: updating the Git repo directly or updating ArgoCD Application parameters.
* Update constraints let you control which image tags are eligible (semver, regex, digest, etc.).

## What will we learn?

- How ArgoCD Image Updater works
- How to install and configure Image Updater
- How to annotate an Application for automatic image updates
- The two write-back strategies: `git` and `argocd`
- How to use update constraints to filter eligible image tags

---

## Prerequisites

- Complete [Lab 002](../002-first-app/README.md)

---

## 01. How Image Updater Works

```text
Image Updater Flow:
1. Polls the container registry periodically (default: 2 minutes)
2. Checks for new tags matching the constraints
3. If a new tag is found, updates the Application:
   - Strategy "argocd": patches the ArgoCD Application parameter
   - Strategy "git":    commits the new tag to the Git repository
4. ArgoCD detects the change and syncs
```

---

## 02. Install ArgoCD Image Updater

```sh
# Install from the official manifest
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml

# Verify the installation
kubectl get pods -n argocd | grep image-updater

# View the Image Updater config
kubectl get cm argocd-image-updater-config -n argocd -o yaml
```

---

## 03. Write-Back Strategy: argocd (in-memory)

The `argocd` strategy patches the Application's Helm/Kustomize parameters in ArgoCD's memory (not Git):

```sh
# Annotate the nginx-helm application (from Lab 009)
kubectl annotate application nginx-helm -n argocd \
  "argocd-image-updater.argoproj.io/image-list=nginx=docker.io/library/nginx" \
  "argocd-image-updater.argoproj.io/nginx.update-strategy=semver" \
  "argocd-image-updater.argoproj.io/nginx.allow-tags=regexp:^1\.[0-9]+-alpine$" \
  "argocd-image-updater.argoproj.io/write-back-method=argocd" \
  --overwrite || true
```

---

## 04. Write-Back Strategy: git

The `git` strategy commits the new image tag back to the Git repository:

```sh
# Requires write access to the Git repo
# The Image Updater will commit a file like .argocd-source-<appname>.yaml

kubectl annotate application guestbook -n argocd \
  "argocd-image-updater.argoproj.io/image-list=ks-guestbook=gcr.io/heptio-images/ks-guestbook-demo" \
  "argocd-image-updater.argoproj.io/ks-guestbook.update-strategy=latest" \
  "argocd-image-updater.argoproj.io/write-back-method=git" \
  "argocd-image-updater.argoproj.io/git-branch=main" \
  --overwrite || true
```

---

## 05. Update Constraints

```sh
# Semver: only update to newer semver versions
# argocd-image-updater.argoproj.io/myapp.update-strategy=semver
# argocd-image-updater.argoproj.io/myapp.allow-tags=regexp:^v[0-9]+\.[0-9]+\.[0-9]+$

# Latest: always use the most recently pushed tag
# argocd-image-updater.argoproj.io/myapp.update-strategy=latest

# Digest: always use the latest digest (even if tag doesn't change)
# argocd-image-updater.argoproj.io/myapp.update-strategy=digest

# Regex filter on tags
# argocd-image-updater.argoproj.io/myapp.allow-tags=regexp:^prod-[0-9]{8}$
```

---

## 06. Monitor Image Updater

```sh
# View Image Updater logs
kubectl logs -n argocd deploy/argocd-image-updater --tail=50

# Check the config
kubectl get cm argocd-image-updater-config -n argocd -o yaml

# View what Image Updater has detected
kubectl logs -n argocd deploy/argocd-image-updater 2>&1 | grep "updating image" || true
```

---

<img src="../assets/images/practice.png" alt="Practice" width="800"/>

## 07. Hands-on

1. Install ArgoCD Image Updater and verify the pod is running:

   ??? success "Solution"

   ```sh
   kubectl apply -n argocd \
     -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml
   kubectl wait --for=condition=Ready pods \
     -l app.kubernetes.io/name=argocd-image-updater \
     -n argocd --timeout=120s || true
   kubectl get pods -n argocd | grep image-updater
   ```

2. Annotate the `guestbook` application to use Image Updater with the `latest` update strategy for the `ks-guestbook-demo` image:

   ??? success "Solution"

   ```sh
   kubectl annotate application guestbook -n argocd \
     "argocd-image-updater.argoproj.io/image-list=ks-guestbook=gcr.io/heptio-images/ks-guestbook-demo" \
     "argocd-image-updater.argoproj.io/ks-guestbook.update-strategy=latest" \
     "argocd-image-updater.argoproj.io/write-back-method=argocd" \
     --overwrite
   kubectl get application guestbook -n argocd \
     -o jsonpath='{.metadata.annotations}' | python3 -m json.tool
   ```

3. Check the Image Updater logs to see if it detected any images:

   ??? success "Solution"

   ```sh
   kubectl logs -n argocd deploy/argocd-image-updater --tail=30
   ```

---

## 08. Summary

- ArgoCD Image Updater polls container registries and updates Application image parameters automatically
- The `argocd` write-back strategy updates in memory (no Git commit); the `git` strategy commits changes to Git
- Update strategies: `semver` (respects semantic versioning), `latest` (newest push), `digest` (content hash)
- Use `allow-tags` with a regex to restrict which image tags are eligible for updates
- Image Updater requires registry credentials in the `argocd-image-updater-secret` for private registries
