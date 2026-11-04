#!/usr/bin/env bash
# Configure a local AU915 FSB2 deployment without editing radio calibration.
# Usage: sudo ./scripts/configure.sh [--gateway-id 16_HEX_DIGITS]
# Existing /etc/sensecap-m1/global_conf.json and .env values survive reruns.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo to write /etc/sensecap-m1 and prepare SQLite storage." >&2
  exit 1
fi
python3 "$REPO_ROOT/scripts/configure.py" "$REPO_ROOT" "$@"
