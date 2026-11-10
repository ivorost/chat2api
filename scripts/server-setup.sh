#!/usr/bin/env bash
# One-time setup for an Ubuntu (26.04 LTS) server that receives deployments
# from .github/workflows/deploy.yml.
#
# Usage (as root on the server):
#   DEPLOY_USER=deploy bash server-setup.sh "ssh-ed25519 AAAA... github-actions"
set -euo pipefail

DEPLOY_USER="${DEPLOY_USER:-deploy}"
PUBKEY="${1:-}"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl ufw

# Latest Docker Engine from Docker's official apt repository.
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
. /etc/os-release
cat > /etc/apt/sources.list.d/docker.sources <<SRC
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
SRC
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

if ! id "$DEPLOY_USER" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "$DEPLOY_USER"
fi
usermod -aG docker "$DEPLOY_USER"

if [ -n "$PUBKEY" ]; then
  home=$(getent passwd "$DEPLOY_USER" | cut -d: -f6)
  install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$home/.ssh"
  grep -qxF "$PUBKEY" "$home/.ssh/authorized_keys" 2>/dev/null || echo "$PUBKEY" >> "$home/.ssh/authorized_keys"
  chown "$DEPLOY_USER:$DEPLOY_USER" "$home/.ssh/authorized_keys"
  chmod 600 "$home/.ssh/authorized_keys"
fi

install -d -o "$DEPLOY_USER" -g "$DEPLOY_USER" /opt/chat2api /opt/chat2api/data
[ -f /opt/chat2api/.env ] || install -m 600 -o "$DEPLOY_USER" -g "$DEPLOY_USER" /dev/null /opt/chat2api/.env

ufw allow OpenSSH
ufw allow 80/tcp
ufw --force enable

echo "Done. Put app settings (AUTHORIZATION=..., PROXY_URL=..., etc.) in /opt/chat2api/.env"
