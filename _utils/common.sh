#!/bin/bash

##########################################
### Colors
##########################################

# Load the colors palette
source <(curl -s https://raw.githubusercontent.com/nirgeier/labs-assets/refs/heads/main/assets/scripts/colors.sh) 2>/dev/null || true

##########################################
### Global functions
##########################################

# Get the root folder
ROOT_FOLDER=$(git rev-parse --show-toplevel)

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Print a section header
section() {
    echo ""
    echo "────────────────────────────────────────────────────────"
    echo "  $1"
    echo "────────────────────────────────────────────────────────"
}

# Wait for ArgoCD app to be synced and healthy
wait_for_app() {
    local app="$1"
    local timeout="${2:-120}"
    echo ">>> Waiting for ArgoCD app '${app}' to sync..."
    argocd app wait "${app}" \
        --sync \
        --health \
        --timeout "${timeout}" 2>/dev/null || true
}

# Wait for a kubernetes deployment to be ready
wait_for_deployment() {
    local name="$1"
    local namespace="${2:-default}"
    echo ">>> Waiting for deployment '${name}' in namespace '${namespace}'..."
    kubectl rollout status deployment/"${name}" \
        -n "${namespace}" \
        --timeout=120s 2>/dev/null || true
}
