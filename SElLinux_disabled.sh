#!/usr/bin/env bash
set -euo pipefail

CFG="/etc/sysconfig/selinux"

backup_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    cp -a "$f" "${f}.bak.$(date +%Y%m%d_%H%M%S)"
  fi
}

patch_cfg() {
  local f="$1"
  [[ -f "$f" ]] || return 0

  # SELINUX= 줄이 있으면 disabled로 교체 (없으면 아무 것도 안 함)
  if grep -qE '^\s*SELINUX=' "$f"; then
    sed -ri 's/^\s*SELINUX=.*/SELINUX=disabled/' "$f"
  fi
}

echo "[1/3] Checking current SELinux state..."
if command -v getenforce >/dev/null 2>&1; then
  echo "Current: $(getenforce)"
else
  echo "getenforce not found (continuing)."
fi

echo "[2/3] Backing up config file..."
backup_file "$CFG"

echo "[3/3] Setting SELINUX=disabled in config..."
patch_cfg "$CFG"

echo
echo "DONE."
echo "- Config updated: SELINUX=disabled"
echo "- Current SELinux runtime state NOT changed"
echo "- Apply fully after reboot (later)"
