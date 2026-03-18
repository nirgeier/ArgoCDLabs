FROM ubuntu:24.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system tools needed by labs and node-pty compilation
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  gnupg \
  git \
  vim \
  less \
  grep \
  sed \
  gawk \
  tree \
  jq \
  wget \
  make \
  g++ \
  python3 \
  python3-pip \
  openssl \
  sudo \
  && rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN curl -fsSL "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/$(dpkg --print-architecture)/kubectl" \
    -o /usr/local/bin/kubectl \
  && chmod +x /usr/local/bin/kubectl

# Install Node.js 20 via NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ── Node.js app ───────────────────────────────────────────────────────────────
# Build context is the repo root (docker-compose: context: ..)
COPY docker/package.json ./
RUN npm install --omit=dev

COPY docker/server.js  ./
COPY docker/public/    ./public/

# ── Lab content ───────────────────────────────────────────────────────────────
# Copied to /app/labs/ – entrypoint.sh copies them to /home/student/labs/
COPY Labs/ ./labs/

# ── Pre-built mkdocs documentation (served at /docs/) ────────────────────────
# Run `mkdocs build` before `docker build` to generate mkdocs-site/
COPY mkdocs-site/ ./docs/

# ── Entrypoint ────────────────────────────────────────────────────────────────
COPY docker/entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh

LABEL org.opencontainers.image.description="Interactive ArgoCD Labs – learn GitOps and ArgoCD by solving challenges in a browser-based terminal"

EXPOSE 3000

ENV SHELL=/bin/bash

# ── Shell aliases ─────────────────────────────────────────────────────────────
RUN echo "alias ll='ls -lah'" >> /etc/profile.d/aliases.sh && \
  echo "alias la='ls -laF'"  >> /etc/profile.d/aliases.sh && \
  echo "alias l='ls -lAh'"   >> /etc/profile.d/aliases.sh

ENTRYPOINT ["/app/entrypoint.sh"]
