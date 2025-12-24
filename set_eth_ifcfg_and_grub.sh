#!/usr/bin/env bash
set -euo pipefail

NS_DIR="/etc/sysconfig/network-scripts"
GRUB_DEF="/etc/default/grub"
GRUB_CFG="/boot/grub2/grub.cfg"

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo "ERROR: run as root"; exit 1; }
}

detect_two_ifaces() {
  mapfile -t ifs < <(
    ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$' | head -n 2
  )
  [[ "${#ifs[@]}" -ge 2 ]] || { echo "ERROR: need 2 interfaces"; exit 1; }
  echo "${ifs[0]} ${ifs[1]}"
}

set_kv() {
  local file="$1" key="$2" value="$3"
  if grep -qE "^\s*${key}\s*=" "$file"; then
    sed -ri "s|^\s*${key}\s*=.*|${key}=${value}|" "$file"
  else
    echo "${key}=${value}" >> "$file"
  fi
}

# 반드시 실제 파일만 허용
find_ifcfg_for_iface() {
  local iface="$1"
  local f="${NS_DIR}/ifcfg-${iface}"
  [[ -f "$f" ]] && echo "$f" || echo ""
}

normalize_ifcfg() {
  local src="$1" eth="$2"
  local dst="${NS_DIR}/ifcfg-${eth}"

  [[ -n "$src" ]] || { echo "ERROR: source ifcfg missing for $eth"; exit 1; }

  if [[ "$src" != "$dst" ]]; then
    mv -f "$src" "$dst"
  fi

  # 요구사항에 맞게 값 강제 수정
  set_kv "$dst" NAME "\"${eth}\""
  set_kv "$dst" DEVICE "\"${eth}\""
  set_kv "$dst" TYPE "Ethernet"
  set_kv "$dst" ONBOOT "yes"
  set_kv "$dst" BOOTPROTO "dhcp"
}

apply_nmcli_now() {
  local dev="$1"
  local con
  con="$(nmcli -t -f NAME,DEVICE connection show | awk -F: -v d="$dev" '$2==d{print $1; exit}')"

  if [[ -n "$con" ]]; then
    nmcli connection reload
    nmcli device reapply "$dev" || nmcli connection up "$con"
  fi
}

patch_grub() {
  if ! grep -qE '^\s*GRUB_CMDLINE_LINUX=' "$GRUB_DEF"; then
    echo 'GRUB_CMDLINE_LINUX=""' >> "$GRUB_DEF"
  fi

  if ! grep -qE '^\s*GRUB_CMDLINE_LINUX=.*net\.ifnames=0' "$GRUB_DEF"; then
    sed -ri 's|^(GRUB_CMDLINE_LINUX="[^"]*)"$|\1 net.ifnames=0"|' "$GRUB_DEF"
  fi
  if ! grep -qE '^\s*GRUB_CMDLINE_LINUX=.*biosdevname=0' "$GRUB_DEF"; then
    sed -ri 's|^(GRUB_CMDLINE_LINUX="[^"]*)"$|\1 biosdevname=0"|' "$GRUB_DEF"
  fi
}

main() {
  require_root

  echo "[1/6] Detect interfaces"
  read -r IF0 IF1 <<<"$(detect_two_ifaces)"
  echo " - detected: $IF0 , $IF1"

  echo "[2/6] Locate existing ifcfg files (both required)"
  SRC0="$(find_ifcfg_for_iface "$IF0")"
  SRC1="$(find_ifcfg_for_iface "$IF1")"

  if [[ -z "$SRC0" || -z "$SRC1" ]]; then
    echo "ERROR: both ifcfg files must exist."
    echo " - missing for: $([[ -z "$SRC0" ]] && echo "$IF0") $([[ -z "$SRC1" ]] && echo "$IF1")"
    exit 1
  fi

  echo "[3/6] Move ifcfg -> eth0 / eth1 and patch values"
  normalize_ifcfg "$SRC0" eth0
  normalize_ifcfg "$SRC1" eth1

  echo "[4/6] Apply NetworkManager now (pre-reboot)"
  apply_nmcli_now "$IF0"
  apply_nmcli_now "$IF1"

  echo "[5/6] Patch grub cmdline"
  patch_grub

  echo "[6/6] Regenerate grub.cfg"
  grub2-mkconfig -o "$GRUB_CFG" >/dev/null

  echo "DONE."
  echo "- Both interfaces renamed via mv (no new files created)"
  echo "- eth0/eth1 naming effective AFTER reboot"
}

main "$@"
