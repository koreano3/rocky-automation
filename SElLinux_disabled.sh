#!/usr/bin/env bash
set -euo pipefail

CFG2="/etc/sysconfig/selinux"

backup_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    cp -a "$f" "${f}.bak.$(date +%Y%m%d_%H%M%S)"
  fi
}

patch_cfg() {
  local f="$1"
  [[ -f "$f" ]] || return 0

  # SELINUX= 줄이 있으면 disabled로 교체, 없으면 추가
  if grep -qE '^\s*SELINUX=' "$f"; then
    sed -ri 's/^\s*SELINUX=.*/SELINUX=disabled/' "$f"
  else
    echo "SELINUX=disabled" >> "$f"
  fi
}

echo "[1/4] Checking current SELinux state..."
if command -v getenforce >/dev/null 2>&1; then
  echo "Current: $(getenforce)"
else
  echo "getenforce not found (continuing)."
fi

echo "[2/4] Backing up config files..."

backup_file "$CFG2"

echo "[3/4] Setting SELINUX=disabled in config..."

patch_cfg "$CFG2"

echo "[4/4] Set current session to permissive (if possible)..."
if command -v setenforce >/dev/null 2>&1; then
  # Enforcing일 때만 permissive로 내림
  if getenforce 2>/dev/null | grep -qi enforcing; then
    setenforce 0 || true
  fi
  echo "Now: $(getenforce 2>/dev/null || echo 'unknown')"
fi

echo
echo "DONE."
echo "- Config updated to SELINUX=disabled."
echo "- To fully disable SELinux, reboot is required:"
echo "  reboot"
echo "- After reboot, confirm with:"
echo "  getenforce   # should be 'Disabled'"
