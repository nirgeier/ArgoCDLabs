---

# Notifications

* ArgoCD Notifications sends alerts when application events occur (sync success, failure, health degraded).
* Notifications support multiple channels: Slack, email, PagerDuty, OpsGenie, Webhook, and more.
* You define `templates` (message format) and `triggers` (when to send) in a ConfigMap.

## What will we learn?

- How ArgoCD Notifications works (templates + triggers + subscriptions)
- How to configure Slack notifications
- How to configure email notifications
- How to subscribe an application to a notification trigger

---

## Prerequisites

- Complete [Lab 002](../002-first-app/README.md)
- A Slack workspace with an incoming webhook URL (or use the mock below)

---

## 01. ArgoCD Notifications Architecture

```text
Notification flow:
1. Application event occurs (sync, health change, etc.)
2. notification-controller evaluates triggers
3. If trigger condition is met → render template
4. Send message via configured service (Slack, email, etc.)

Key ConfigMaps:
- argocd-notifications-cm      → templates + triggers
- argocd-notifications-secret  → service credentials (tokens, passwords)
```

---

## 02. Configure a Slack Notification Service

```sh
# Store the Slack webhook token in the notifications secret
kubectl patch secret argocd-notifications-secret -n argocd \
  --type merge -p '{
    "stringData": {
      "slack-token": "xoxb-YOUR-SLACK-BOT-TOKEN"
    }
  }' || true

# Configure the Slack service in the notifications ConfigMap
kubectl patch cm argocd-notifications-cm -n argocd --type merge -p '{
  "data": {
    "service.slack": "|\n  token: $slack-token\n  username: ArgoCD\n  icon: https://argoproj.github.io/argo-cd/assets/logo.png\n"
  }
}' || true
```

---

## 03. Create Notification Templates

Templates define the message content using Go templating:

```sh
kubectl patch cm argocd-notifications-cm -n argocd --type merge -p '
{
  "data": {
    "template.app-sync-succeeded": "|\n  message: |\n    Application {{.app.metadata.name}} sync succeeded!\n    Revision: {{.app.status.sync.revision}}\n    Environment: {{.app.metadata.namespace}}\n  slack:\n    attachments: |\n      [{\n        \"title\": \"{{.app.metadata.name}}\",\n        \"title_link\": \"{{.context.argocdUrl}}/applications/{{.app.metadata.name}}\",\n        \"color\": \"good\",\n        \"fields\": [{\n          \"title\": \"Sync Status\",\n          \"value\": \"Synced\",\n          \"short\": true\n        }]\n      }]\n",
    "template.app-sync-failed": "|\n  message: |\n    :x: Application {{.app.metadata.name}} sync FAILED!\n    Message: {{.app.status.operationState.message}}\n"
  }
}'
```

---

## 04. Create Notification Triggers

Triggers define when a notification is sent:

```sh
kubectl patch cm argocd-notifications-cm -n argocd --type merge -p '
{
  "data": {
    "trigger.on-sync-succeeded": "|\n  - when: app.status.operationState.phase in [\"Succeeded\"]\n    send: [app-sync-succeeded]\n",
    "trigger.on-sync-failed": "|\n  - when: app.status.operationState.phase in [\"Error\", \"Failed\"]\n    send: [app-sync-failed]\n",
    "trigger.on-health-degraded": "|\n  - when: app.status.health.status == \"Degraded\"\n    send: [app-sync-failed]\n"
  }
}'
```

---

## 05. Subscribe an Application to Notifications

```sh
# Subscribe the guestbook app to receive notifications on Slack
argocd app set guestbook \
  --annotations "notifications.argoproj.io/subscribe.on-sync-succeeded.slack=general"

# Or via kubectl annotation
kubectl annotate application guestbook -n argocd \
  "notifications.argoproj.io/subscribe.on-sync-failed.slack=alerts" \
  --overwrite

# Trigger a sync to test
argocd app sync guestbook
```

---

## 06. Email Notifications

```sh
# Configure email service
kubectl patch secret argocd-notifications-secret -n argocd \
  --type merge -p '{
    "stringData": {
      "email-username": "argocd@yourdomain.com",
      "email-password": "your-smtp-password"
    }
  }' || true

kubectl patch cm argocd-notifications-cm -n argocd --type merge -p '{
  "data": {
    "service.email.gmail": "|\n  username: $email-username\n  password: $email-password\n  host: smtp.gmail.com\n  port: 465\n  from: $email-username\n"
  }
}' || true
```

---

<img src="../assets/images/practice.png" alt="Practice" width="800"/>

## 07. Hands-on

1. Verify the `argocd-notifications-controller` pod is running:

   ??? success "Solution"

   ```sh
   kubectl get pods -n argocd | grep notifications
   # argocd-notifications-controller-xxx   1/1   Running
   ```

2. View the current contents of `argocd-notifications-cm` to see any pre-configured templates and triggers:

   ??? success "Solution"

   ```sh
   kubectl get cm argocd-notifications-cm -n argocd -o yaml
   ```

3. Annotate the `guestbook` application to subscribe to the `on-sync-succeeded` trigger (even without a working Slack token, the annotation will be set):

   ??? success "Solution"

   ```sh
   kubectl annotate application guestbook -n argocd \
     "notifications.argoproj.io/subscribe.on-sync-succeeded.slack=general" \
     --overwrite
   kubectl get application guestbook -n argocd -o jsonpath='{.metadata.annotations}' | python3 -m json.tool
   ```

---

## 08. Summary

- ArgoCD Notifications uses a template + trigger + subscription model to send alerts
- Templates define message content using Go templates with access to the Application object
- Triggers define conditions using CEL expressions evaluated against the Application state
- Subscribe applications to triggers via annotations: `notifications.argoproj.io/subscribe.<trigger>.<service>=<target>`
- Credentials for notification services are stored in `argocd-notifications-secret`, never in the ConfigMap
