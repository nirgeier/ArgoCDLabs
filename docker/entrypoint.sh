#!/bin/bash
# =============================================================================
# ArgoCD Labs – Container Entrypoint
#
# 1. Creates the 'student' user with sudo access
# 2. Copies lab content fresh into /home/student/labs/
# 3. Writes helper .bashrc / .bash_profile for the user shell
# 4. Starts the Node.js web-terminal server
# =============================================================================
set -eu

BASE=/home/student/labs
CONTENT=/app/labs

# ── 1. Create student user ────────────────────────────────────────────────────
if ! id -u student >/dev/null 2>&1; then
  useradd -m -s /bin/bash student
fi
echo "student:student" | chpasswd

# Passwordless sudo
echo "student ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/student
chmod 0440 /etc/sudoers.d/student

# ── 2. Copy fresh lab content ─────────────────────────────────────────────────
mkdir -p "$BASE"
rm -rf "$BASE"
cp -rp "$CONTENT" "$BASE"
chmod -R a+rX "$BASE"

# ── 3. Write .bashrc ──────────────────────────────────────────────────────────
mkdir -p /home/student
cat > /home/student/.bashrc <<'BASHRC'
# Custom prompt
export PS1='\[\033[01;36m\]student\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

export HOME=/home/student
export LABS=/home/student/labs

# Aliases
alias ll='ls -lah'
alias la='ls -laF'
alias l='ls -lAh'
alias k='kubectl'
alias kgp='kubectl get pods'
alias kga='kubectl get all'

# Show welcome message on first interactive login
if [ -z "${ARGOCD_LABS_WELCOMED:-}" ]; then
  export ARGOCD_LABS_WELCOMED=1
  echo ""
  echo "  Welcome to ArgoCD Labs!"
  echo "  ────────────────────────────────────────────────────────"
  echo "  Labs directory : \$LABS"
  echo ""
  echo "  Available labs:"
  if [ -d "\$LABS" ]; then
    for d in "\$LABS"/*/; do
      lab=\$(basename "\$d")
      echo "    - \$lab"
    done
  fi
  echo ""
  echo "  Start with lab 000-setup:"
  echo "    cd \$LABS/000-setup && cat README.md"
  echo ""
  echo "  kubectl is available – try: kubectl version --client"
  echo ""
fi
BASHRC

# .bash_profile sources .bashrc so login shells work correctly
cat > /home/student/.bash_profile <<'PROFILE'
[ -f ~/.bashrc ] && source ~/.bashrc
cd /home/student/labs
PROFILE

# ── 4. Fix ownership ──────────────────────────────────────────────────────────
chown -R student:student /home/student

# ── 5. Start web server ───────────────────────────────────────────────────────
exec node /app/server.js
