---

# Progressive Delivery

* Argo Rollouts extends Kubernetes Deployments with advanced release strategies: Canary, Blue/Green, and Analysis-based promotion.
* Traffic is shifted gradually - a percentage goes to the new version while the rest stays on stable.
* Automated analysis can query Prometheus metrics to decide whether to promote or abort a rollout.

## What will we learn?

- How to install Argo Rollouts
- How to configure a Canary rollout with weighted traffic steps
- How to configure a Blue/Green rollout with preview service
- How to use AnalysisTemplates for automated promotion

---

## Prerequisites

- Complete [Lab 002](../002-first-app/README.md)
- A cluster with Argo Rollouts installed (see step 01)

---

## 01. Install Argo Rollouts

```sh
kubectl create namespace argo-rollouts

kubectl apply -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

kubectl rollout status deploy/argo-rollouts -n argo-rollouts --timeout=90s

# Install the kubectl plugin (Linux/macOS)
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts-linux-amd64
sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts

kubectl argo rollouts version
```

---

## 02. Canary Rollout

```sh
kubectl apply -f - <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: guestbook-rollout
  namespace: default
spec:
  replicas: 5
  selector:
    matchLabels:
      app: guestbook
  template:
    metadata:
      labels:
        app: guestbook
    spec:
      containers:
        - name: guestbook
          image: gcr.io/heptio-images/ks-guestbook-demo:0.1
          ports:
            - containerPort: 80
  strategy:
    canary:
      canaryService: guestbook-canary
      stableService: guestbook-stable
      steps:
        - setWeight: 20        # 20% to canary
        - pause: {duration: 30s}
        - setWeight: 40
        - pause: {duration: 30s}
        - setWeight: 80
        - pause: {}             # Manual gate before 100%
YAML

# Create the two services
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: guestbook-stable
spec:
  selector:
    app: guestbook
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: guestbook-canary
spec:
  selector:
    app: guestbook
  ports:
    - port: 80
      targetPort: 80
YAML
```

---

## 03. Trigger and Watch a Canary Rollout

```sh
# Watch the rollout
kubectl argo rollouts get rollout guestbook-rollout --watch &

# Trigger a new rollout by updating the image
kubectl argo rollouts set image guestbook-rollout \
  guestbook=gcr.io/heptio-images/ks-guestbook-demo:0.2

# After the pause step – manually promote to continue
kubectl argo rollouts promote guestbook-rollout

# If something goes wrong – abort and roll back
# kubectl argo rollouts abort guestbook-rollout
# kubectl argo rollouts undo guestbook-rollout
```

---

## 04. Blue/Green Rollout

```sh
kubectl apply -f - <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: guestbook-bluegreen
spec:
  replicas: 3
  selector:
    matchLabels:
      app: guestbook-bg
  template:
    metadata:
      labels:
        app: guestbook-bg
    spec:
      containers:
        - name: guestbook
          image: gcr.io/heptio-images/ks-guestbook-demo:0.1
  strategy:
    blueGreen:
      activeService: guestbook-active      # Live traffic
      previewService: guestbook-preview    # Staging/QA traffic
      autoPromotionEnabled: false          # Require manual gate
      scaleDownDelaySeconds: 60            # Keep blue around for 60s after promotion
YAML
```

---

## 05. AnalysisTemplate for Automated Promotion

```sh
kubectl apply -f - <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  args:
    - name: service-name
  metrics:
    - name: success-rate
      interval: 30s
      successCondition: result[0] >= 0.95    # Require 95% success rate
      failureLimit: 3
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            sum(rate(http_requests_total{
              service="{{args.service-name}}",
              status!~"5.."}[5m]))
            /
            sum(rate(http_requests_total{
              service="{{args.service-name}}"}[5m]))
YAML
```

---

## Hands-on Tasks

1. Install Argo Rollouts and the `kubectl-argo-rollouts` plugin
2. Create a Canary rollout for the guestbook app with 20% → 40% → 80% → 100% steps
3. Trigger a new rollout by updating the container image, watch the traffic shift
4. Manually promote the rollout through each pause step
5. Trigger a rollout and then abort it - verify traffic reverts to the stable version

---

## 08. Summary

- Argo Rollouts replaces the standard `Deployment` with a `Rollout` resource that adds Canary and Blue/Green strategies
- **Canary** shifts a percentage of traffic to the new version incrementally, with optional pause steps for manual gates
- **Blue/Green** runs two full replica sets simultaneously; active receives live traffic, preview receives test traffic
- `AnalysisTemplates` query Prometheus (or Datadog, New Relic, etc.) to auto-promote or auto-abort based on real metrics
- `kubectl argo rollouts promote` and `abort` give operators manual control at any pause step
