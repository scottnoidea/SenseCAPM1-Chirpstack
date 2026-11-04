#!/usr/bin/env bash
# Install systemd unit for the Semtech UDP packet forwarder on SenseCAP M1.
# Works on Raspberry Pi OS Bookworm and Trixie.
#
# Usage:
#   cd ~/SenseCAPM1-Chirpstack
#   ./scripts/install-lora-service.sh
#   ./scripts/install-lora-service.sh --config /etc/sensecap-m1/global_conf.json
#   ./scripts/install-lora-service.sh --user myuser --config /etc/sensecap-m1/global_conf.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PF_DIR="${REPO_ROOT}/packet_forwarder"
SERVICE_NAME="lora_pkt_fwd.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"

RUN_USER="${SUDO_USER:-${USER}}"
CONFIG_FILE="/etc/sensecap-m1/global_conf.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)
      RUN_USER="${2:?--user requires a username}"
      shift 2
      ;;
    --config)
      CONFIG_FILE="${2:?--config requires a filename}"
      shift 2
      ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Please run with sudo: sudo $0 $*"
  exit 1
fi

if ! id "$RUN_USER" &>/dev/null; then
  echo "User '$RUN_USER' does not exist." >&2
  exit 1
fi

if [[ "$CONFIG_FILE" = /* ]]; then
  CONFIG_PATH="$CONFIG_FILE"
else
  CONFIG_PATH="${PF_DIR}/${CONFIG_FILE}"
fi
# systemd treats whitespace and % specially; reject unsupported install paths.
if [[ "$PF_DIR$CONFIG_PATH" =~ [[:space:]%] ]]; then
  echo "Install paths must not contain whitespace or %." >&2
  exit 1
fi
if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Config not found: $CONFIG_PATH" >&2
  exit 1
fi

if [[ ! -x "${PF_DIR}/lora_pkt_fwd" ]]; then
  chmod +x "${PF_DIR}/lora_pkt_fwd" "${PF_DIR}/reset_lgw.sh" "${PF_DIR}/spectral_scan" 2>/dev/null || true
fi

# Groups needed for SPI + GPIO character device access on modern RPi OS
for grp in gpio spi dialout; do
  if getent group "$grp" >/dev/null 2>&1; then
    usermod -aG "$grp" "$RUN_USER" || true
  fi
done

HOME_DIR="$(getent passwd "$RUN_USER" | cut -d: -f6)"

cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=SenseCAP M1 SX1302/SX1303 Semtech UDP Packet Forwarder
Documentation=https://github.com/hereismeaw/SenseCAPM1-Chirpstack
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${RUN_USER}
WorkingDirectory=${PF_DIR}
ExecStartPre=${PF_DIR}/reset_lgw.sh start
ExecStart=${PF_DIR}/lora_pkt_fwd -c ${CONFIG_PATH}
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal
SyslogIdentifier=lora_pkt_fwd

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

echo
echo "Installed and started ${SERVICE_NAME}"
echo "  User:    ${RUN_USER} (home: ${HOME_DIR})"
echo "  Config:  ${CONFIG_PATH}"
echo "  Status:  sudo systemctl status ${SERVICE_NAME}"
echo "  Logs:    journalctl -u ${SERVICE_NAME} -f"
echo
echo "If this is the first time adding ${RUN_USER} to gpio/spi groups, log out and back in (or reboot)."
