#!/bin/bash
# =============================================================================
# ArgoCD Labs – Build Script
#
# 1. Builds mkdocs-site (if mkdocs.yml exists)
# 2. Registers binfmt for multi-platform builds
# 3. Creates (or reuses) a buildx builder
# 4. Runs docker buildx bake to build and push multi-platform images
# =============================================================================
set -eu

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║   ArgoCD Labs – Build                                    ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ── 1. Build MkDocs site ──────────────────────────────────────────────────────
if [ -f "${REPO_ROOT}/mkdocs.yml" ]; then
  echo ">>> Building MkDocs site..."
  cd "${REPO_ROOT}"
  # Use project venv if available, otherwise fall back to system mkdocs
  MKDOCS_CMD="mkdocs"
  for vdir in .venv venv; do
    if [ -x "${REPO_ROOT}/${vdir}/bin/mkdocs" ]; then
      MKDOCS_CMD="${REPO_ROOT}/${vdir}/bin/mkdocs"
      break
    fi
  done
  "$MKDOCS_CMD" build --config-file mkdocs.yml
  echo ">>> MkDocs site built at ${REPO_ROOT}/mkdocs-site"
else
  echo ">>> mkdocs.yml not found – skipping MkDocs build"
fi

# ── 2. Register binfmt for multi-platform builds ──────────────────────────────
echo ""
echo ">>> Registering binfmt (multi-platform support)..."
docker run --privileged --rm tonistiigi/binfmt --install all

# ── 3. Create (or reuse) buildx builder ───────────────────────────────────────
echo ""
echo ">>> Setting up buildx builder..."
if ! docker buildx inspect argocd-labs-builder >/dev/null 2>&1; then
  docker buildx create --name argocd-labs-builder --use --bootstrap
else
  docker buildx use argocd-labs-builder
fi

# ── 4. Build and push via docker buildx bake ─────────────────────────────────
# Run from docker/ so that context: .. in the compose file resolves to the repo root.
echo ""
echo ">>> Running docker buildx bake..."
cd "${REPO_ROOT}/docker"
docker buildx bake \
  --allow=fs.read=.. \
  -f docker-compose.yml \
  --push \
  argocd-labs

echo ""
echo ">>> Build complete!"
echo ""
