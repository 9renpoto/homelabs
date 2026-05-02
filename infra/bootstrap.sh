#!/usr/bin/env bash
set -euo pipefail

: "${DOCKER_GROUP:=docker}"
: "${DOCKER_SOCKETPATH:=/var/run/docker.sock}"
: "${DOCKER_DAEMON_CONFIG:=/etc/docker/daemon.json}"

die() {
  echo "❌ $*" >&2
  exit 1
}

info() {
  echo "ℹ️  $*"
}

success() {
  echo "✓ $*"
}

info "WSL2 Docker + NVIDIA bootstrap starting..."

if [[ $EUID -ne 0 ]]; then
  die "This script must be run as root (use: sudo $0)"
fi

info "Creating docker group..."
if ! getent group "$DOCKER_GROUP" &>/dev/null; then
  groupadd "$DOCKER_GROUP"
  success "Docker group created"
else
  success "Docker group already exists"
fi

info "Configuring Docker daemon for NVIDIA runtime..."
mkdir -p "$(dirname "$DOCKER_DAEMON_CONFIG")"
cat > "$DOCKER_DAEMON_CONFIG" <<'EOF'
{
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  },
  "default-runtime": "nvidia"
}
EOF
success "Docker daemon configured at $DOCKER_DAEMON_CONFIG"

info "Enabling docker.service in systemd..."
systemctl daemon-reload
systemctl enable docker || true
systemctl start docker || true
success "docker.service enabled"

info "Waiting for Docker socket..."
timeout=10
while [[ ! -S "$DOCKER_SOCKETPATH" && $timeout -gt 0 ]]; do
  sleep 1
  ((timeout--))
done
if [[ -S "$DOCKER_SOCKETPATH" ]]; then
  success "Docker socket available at $DOCKER_SOCKETPATH"
else
  die "Docker socket not available after 10 seconds"
fi

info "Testing docker command..."
if docker ps >/dev/null 2>&1; then
  success "docker ps works"
else
  die "docker ps failed"
fi

info "Verifying NVIDIA runtime..."
if docker info 2>/dev/null | grep -q -i nvidia; then
  success "NVIDIA runtime detected in docker info"
else
  info "⚠️  NVIDIA runtime not yet detected in docker info (may still work)"
fi

info "Testing GPU visibility in Docker..."
if docker run --rm --gpus all nvidia/cuda:12.4.1-runtime-ubuntu24.04 nvidia-smi >/dev/null 2>&1; then
  success "GPU is visible inside Docker container"
else
  die "GPU not visible inside Docker container; check NVIDIA CUDA setup"
fi

success "✅ WSL2 Docker + NVIDIA bootstrap complete"
