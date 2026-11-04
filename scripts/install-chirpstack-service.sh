#!/usr/bin/env bash
# Install and start systemd supervision of the local Docker Compose stack.
# Usage: sudo ./scripts/install-chirpstack-service.sh
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK_DIR="$REPO_ROOT/chirpstack-docker"
if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo to install the systemd unit." >&2
  exit 1
fi
if [[ "$STACK_DIR" =~ [[:space:]%\&\|] ]]; then
  echo "Install path must not contain whitespace, %, & or |." >&2
  exit 1
fi
cd "$STACK_DIR"
# Fails before modifying systemd if configure.sh has not been run.
/usr/bin/docker compose config --quiet
sed "s|@STACK_DIR@|$STACK_DIR|g" "$REPO_ROOT/systemd/chirpstack-compose.service" \
  > /etc/systemd/system/chirpstack-compose.service
systemctl daemon-reload
systemctl enable chirpstack-compose.service
systemctl restart chirpstack-compose.service
