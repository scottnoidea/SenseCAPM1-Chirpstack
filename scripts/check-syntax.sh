#!/usr/bin/env bash
# Local + CI syntax checks for SenseCAPM1-Chirpstack scripts and key configs.
#
# Usage (from repo root or any cwd):
#   ./scripts/check-syntax.sh
#
# Exit codes:
#   0  all checks passed
#   1  one or more checks failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

failures=0
checks=0

pass() {
  checks=$((checks + 1))
  printf '%s✓%s %s\n' "$GREEN" "$RESET" "$1"
}

fail() {
  checks=$((checks + 1))
  failures=$((failures + 1))
  printf '%s✗%s %s\n' "$RED" "$RESET" "$1"
}

info() {
  printf '%s•%s %s\n' "$YELLOW" "$RESET" "$1"
}

section() {
  printf '\n%s%s%s\n' "$BOLD" "$1" "$RESET"
}

# ---------------------------------------------------------------------------
# Discover shell scripts (tracked + untracked under repo, skip .git)
# ---------------------------------------------------------------------------
mapfile -t SHELL_SCRIPTS < <(
  find "$REPO_ROOT" \
    -path '*/.git/*' -prune -o \
    -type f -name '*.sh' -print \
    | LC_ALL=C sort
)

if [[ ${#SHELL_SCRIPTS[@]} -eq 0 ]]; then
  fail "No .sh scripts found"
  exit 1
fi

section "Shell scripts (${#SHELL_SCRIPTS[@]})"

for script in "${SHELL_SCRIPTS[@]}"; do
  rel="${script#"$REPO_ROOT"/}"

  # CRLF guard — breaks shebang/execution on Linux / Raspberry Pi
  if grep -q $'\r' "$script" 2>/dev/null; then
    fail "$rel — contains CRLF line endings (use LF)"
    continue
  fi

  # Choose parser from shebang (default bash for *.sh)
  shell="bash"
  if head -n1 "$script" | grep -Eq '^#!.*\b(dash|sh)\b'; then
    shell="sh"
  elif head -n1 "$script" | grep -Eq '^#!.*\bbash\b'; then
    shell="bash"
  fi

  if ! command -v "$shell" >/dev/null 2>&1; then
    fail "$rel — interpreter '$shell' not available"
    continue
  fi

  if "$shell" -n "$script" 2>/tmp/sensecap-syntax.err; then
    pass "$rel — $shell -n"
  else
    fail "$rel — $shell -n"
    sed 's/^/    /' /tmp/sensecap-syntax.err || true
  fi
done

# ---------------------------------------------------------------------------
# ShellCheck (optional but installed in CI)
# ---------------------------------------------------------------------------
section "ShellCheck"

if command -v shellcheck >/dev/null 2>&1; then
  for script in "${SHELL_SCRIPTS[@]}"; do
    rel="${script#"$REPO_ROOT"/}"
    sc_shell="bash"
    if head -n1 "$script" | grep -Eq '^#!.*\b(dash|sh)\b'; then
      sc_shell="sh"
    fi

    # SC1091: not following sourced files (none expected)
    # SC2312: pipeline/command substitution exit status (noisy for simple scripts)
    if shellcheck -x -s "$sc_shell" \
      -e SC1091 \
      "$script" 2>/tmp/sensecap-shellcheck.err; then
      pass "$rel — shellcheck (-s $sc_shell)"
    else
      fail "$rel — shellcheck (-s $sc_shell)"
      sed 's/^/    /' /tmp/sensecap-shellcheck.err || true
    fi
  done
else
  info "shellcheck not installed — skip (CI installs it)"
fi

# ---------------------------------------------------------------------------
# Python syntax (optional tools in packet_forwarder)
# ---------------------------------------------------------------------------
section "Python"

mapfile -t PY_SCRIPTS < <(
  find "$REPO_ROOT" \
    -path '*/.git/*' -prune -o \
    -type f -name '*.py' -print \
    | LC_ALL=C sort
)

if [[ ${#PY_SCRIPTS[@]} -eq 0 ]]; then
  info "No Python files found"
else
  if command -v python3 >/dev/null 2>&1; then
    PY=python3
  elif command -v python >/dev/null 2>&1; then
    PY=python
  else
    PY=""
  fi

  if [[ -n "$PY" ]]; then
    for py in "${PY_SCRIPTS[@]}"; do
      rel="${py#"$REPO_ROOT"/}"
      if "$PY" -m py_compile "$py" 2>/tmp/sensecap-py.err; then
        pass "$rel — $PY -m py_compile"
      else
        fail "$rel — $PY -m py_compile"
        sed 's/^/    /' /tmp/sensecap-py.err || true
      fi
    done
  else
    info "python not installed — skip"
  fi
fi

# ---------------------------------------------------------------------------
# Docker Compose file
# ---------------------------------------------------------------------------
section "Docker Compose"

COMPOSE_FILE="$REPO_ROOT/chirpstack-docker/docker-compose.yml"
if [[ -f "$COMPOSE_FILE" ]]; then
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    if (
      cd "$REPO_ROOT/chirpstack-docker"
      docker compose -f docker-compose.yml config --quiet
    ) 2>/tmp/sensecap-compose.err; then
      pass "chirpstack-docker/docker-compose.yml — docker compose config"
    else
      fail "chirpstack-docker/docker-compose.yml — docker compose config"
      sed 's/^/    /' /tmp/sensecap-compose.err || true
    fi
  elif command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
    # Fallback: YAML parse only (structure, not full Compose semantics)
    PY_BIN="$(command -v python3 || command -v python)"
    if "$PY_BIN" - <<'PY' "$COMPOSE_FILE" 2>/tmp/sensecap-compose.err
import sys
path = sys.argv[1]
try:
    import yaml  # type: ignore
except ImportError:
    # Minimal structural check without PyYAML: require top-level "services:"
    text = open(path, encoding="utf-8").read()
    if "services:" not in text:
        raise SystemExit("missing top-level services: key")
    sys.exit(0)
data = yaml.safe_load(open(path, encoding="utf-8"))
if not isinstance(data, dict) or "services" not in data:
    raise SystemExit("compose file must define services")
PY
    then
      pass "chirpstack-docker/docker-compose.yml — YAML/structure check"
    else
      fail "chirpstack-docker/docker-compose.yml — YAML/structure check"
      sed 's/^/    /' /tmp/sensecap-compose.err || true
    fi
  else
    info "docker/python not available — skip compose check"
  fi
else
  fail "chirpstack-docker/docker-compose.yml missing"
fi

# ---------------------------------------------------------------------------
# systemd unit (basic sanity)
# ---------------------------------------------------------------------------
section "systemd unit"

UNIT="$REPO_ROOT/systemd/lora_pkt_fwd.service"
if [[ -f "$UNIT" ]]; then
  rel="systemd/lora_pkt_fwd.service"
  if grep -q $'\r' "$UNIT" 2>/dev/null; then
    fail "$rel — contains CRLF line endings"
  elif ! grep -q '^\[Unit\]' "$UNIT"; then
    fail "$rel — missing [Unit] section"
  elif ! grep -q '^\[Service\]' "$UNIT"; then
    fail "$rel — missing [Service] section"
  elif ! grep -q '^\[Install\]' "$UNIT"; then
    fail "$rel — missing [Install] section"
  else
    pass "$rel — basic section layout"
  fi
else
  info "no systemd unit template found"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
section "Summary"
if [[ "$failures" -eq 0 ]]; then
  printf '%sAll %s check(s) passed.%s\n' "$GREEN" "$checks" "$RESET"
  exit 0
fi

printf '%s%d failure(s) in %s check(s).%s\n' "$RED" "$failures" "$checks" "$RESET"
exit 1
