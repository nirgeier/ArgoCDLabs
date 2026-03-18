---
# Secrets Management

* The golden rule of GitOps: never store plaintext secrets in Git.
* ArgoCD integrates with several secrets management solutions: Sealed Secrets, External Secrets Operator (ESO), and HashiCorp Vault.
* Each approach has trade-offs between simplicity, security, and operational overhead.

## What will we learn?

- Why plaintext secrets in Git are dangerous
- How Sealed Secrets encrypts secrets for safe Git storage
- How External Secrets Operator syncs secrets from external stores
- How to integrate with HashiCorp Vault

---

## Prerequisites

- Complete [Lab 002](../002-first-app/README.md)

---

## 01. The Secrets Problem in GitOps

```text
WRONG approach (never do this):
├── apps/
│   └── myapp/
│       ├── deployment.yaml
│       └── secret.yaml  ← base64 encoded ≠ encrypted!

CORRECT approaches:
1. Sealed Secrets:    Encrypt secret in Git, decrypt in cluster
2. External Secrets:  Store secret externally, sync to cluster
3. Vault Agent:       Inject secrets at runtime from Vault
```

---

## 02. Sealed Secrets

Sealed Secrets uses asymmetric encryption. The `kubeseal` CLI encrypts using the cluster's public key; only the in-cluster controller can decrypt.

```sh
# Install Sealed Secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/latest/download/controller.yaml

# Wait for the controller
kubectl wait --for=condition=Ready pods -l name=sealed-secrets-controller \
  -n kube-system --timeout=120s || true

# Install kubeseal CLI
brew install kubeseal 2>/dev/null || \
  curl -sSL https://github.com/bitnami-labs/sealed-secrets/releases/latest/download/kubeseal-linux-amd64 \
    -o kubeseal && chmod +x kubeseal && sudo mv kubeseal /usr/local/bin/ 2>/dev/null || true

# Create a regular secret
kubectl create secret generic my-db-password \
  --from-literal=password=super-secret \
  --dry-run=client \
  -o yaml > /tmp/my-secret.yaml

# Seal it (encrypt for the cluster)
kubeseal --format yaml < /tmp/my-secret.yaml > /tmp/my-sealed-secret.yaml

# View the sealed secret (safe to commit to Git)
cat /tmp/my-sealed-secret.yaml

# Apply the sealed secret to the cluster
kubectl apply -f /tmp/my-sealed-secret.yaml

# The controller decrypts it into a regular Secret
kubectl get secret my-db-password -o jsonpath='{.data.password}' | base64 -d && echo
```

---

## 03. External Secrets Operator

ESO pulls secrets from AWS SSM, AWS Secrets Manager, GCP Secret Manager, Azure Key Vault, etc.

```sh
# Install External Secrets Operator via Helm
helm repo add external-secrets https://charts.external-secrets.io 2>/dev/null || true
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace || true

# Example ExternalSecret manifest (using a fake backend for demo):
cat <<'EOF' | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-app-secret
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: my-secret-store
    kind: SecretStore
  target:
    name: my-app-secret    # The Kubernetes Secret to create
    creationPolicy: Owner
  data:
    - secretKey: db-password
      remoteRef:
        key: /prod/myapp/db-password  # Path in the external secret store
EOF
```

---

## 04. Vault Integration

```sh
# For a demo, run Vault in dev mode
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vault
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vault
  template:
    metadata:
      labels:
        app: vault
    spec:
      containers:
        - name: vault
          image: hashicorp/vault:1.15
          env:
            - name: VAULT_DEV_ROOT_TOKEN_ID
              value: root
            - name: VAULT_DEV_LISTEN_ADDRESS
              value: 0.0.0.0:8200
          ports:
            - containerPort: 8200
---
apiVersion: v1
kind: Service
metadata:
  name: vault
  namespace: default
spec:
  selector:
    app: vault
  ports:
    - port: 8200
      targetPort: 8200
EOF

# Write a secret to Vault
kubectl exec deploy/vault -- vault kv put secret/myapp/config \
  db_password=vault-stored-secret || true
```

---

<img src="../assets/images/practice.png" alt="Practice" width="800"/>

## 05. Hands-on

1. Install the Sealed Secrets controller and verify it is running:

   ??? success "Solution"

   ```sh
   kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/latest/download/controller.yaml
   kubectl wait --for=condition=Ready pods \
     -l name=sealed-secrets-controller \
     -n kube-system --timeout=120s || true
   kubectl get pods -n kube-system | grep sealed-secrets
   ```

2. Create a Kubernetes Secret, seal it with `kubeseal`, and apply the SealedSecret to the cluster. Verify the decrypted Secret is created:

   ??? success "Solution"

   ```sh
   kubectl create secret generic lab-secret \
     --from-literal=api-key=my-super-secret-key \
     --dry-run=client -o yaml | \
     kubeseal --format yaml > /tmp/lab-sealed-secret.yaml
   cat /tmp/lab-sealed-secret.yaml
   kubectl apply -f /tmp/lab-sealed-secret.yaml
   sleep 5
   kubectl get secret lab-secret -o jsonpath='{.data.api-key}' | base64 -d && echo
   ```

3. Delete the SealedSecret and verify that the Kubernetes Secret is also cleaned up:

   ??? success "Solution"

   ```sh
   kubectl delete -f /tmp/lab-sealed-secret.yaml
   kubectl get secret lab-secret || echo "Secret was cleaned up"
   ```

---

## 06. Summary

- Base64 in Kubernetes Secrets is NOT encryption - never commit them to Git unencrypted
- Sealed Secrets asymmetrically encrypts secrets with the cluster's public key - safe to store in Git
- External Secrets Operator decouples secret storage from Kubernetes - secrets live in AWS SSM, Vault, etc.
- ArgoCD does not natively manage secrets - use one of the above patterns as a layer below ArgoCD
- Rotate the Sealed Secrets controller's key periodically and re-seal all secrets to maintain security hygiene
