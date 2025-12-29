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
    ip -o link show | awk -F': ' '{print $2}' \
      | grep -vE '^(lo|docker0|virbr0|vboxnet|br-|tun|tap)' \
      | head -n 2
  )
  [[ "${#ifs[@]}" -ge 2 ]] || { echo "ERROR: need 2 interfaces"; exit 1; }
  echo "${ifs[0]} ${ifs[1]}"
}

remove_key() {
  local file="$1" key="$2"
  sed -ri "/^\s*${key}\s*=/d" "$file"
}

set_kv() {
  local file="$1" key="$2" value="$3"
  if grep -qE "^\s*${key}\s*=" "$file"; then
    sed -ri "s|^\s*${key}\s*=.*|${key}=${value}|" "$file"
  else
    echo "${key}=${value}" >> "$file"
  fi
}

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

  remove_key "$dst" UUID
  sed -ri '/^\s*$/d' "$dst"

  set_kv "$dst" NAME "\"${eth}\""
  set_kv "$dst" DEVICE "\"${eth}\""
  set_kv "$dst" TYPE "Ethernet"
  set_kv "$dst" ONBOOT "yes"
  set_kv "$dst" BOOTPROTO "dhcp"
}

patch_grub() {
  [[ -f "$GRUB_DEF" ]] || { echo "ERROR: $GRUB_DEF not found"; exit 1; }

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

  echo "[1/5] Detect interfaces"
  read -r IF0 IF1 <<<"$(detect_two_ifaces)"
  echo " - detected: $IF0 , $IF1"

  echo "[2/5] Locate existing ifcfg files (both required)"
  SRC0="$(find_ifcfg_for_iface "$IF0")"
  SRC1="$(find_ifcfg_for_iface "$IF1")"
  if [[ -z "$SRC0" || -z "$SRC1" ]]; then
    echo "ERROR: both ifcfg files must exist."
    echo " - missing for: $([[ -z "$SRC0" ]] && echo "$IF0") $([[ -z "$SRC1" ]] && echo "$IF1")"
    exit 1
  fi

  echo "[3/5] Move ifcfg -> eth0 / eth1 and patch values"
  normalize_ifcfg "$SRC0" eth0
  normalize_ifcfg "$SRC1" eth1

  echo "[4/5] Patch grub cmdline"
  patch_grub

  echo "[5/5] Regenerate grub.cfg => $GRUB_CFG"
  grub2-mkconfig -o "$GRUB_CFG" >/dev/null

  echo "DONE."
  echo "- eth0/eth1 naming effective AFTER reboot"
}

main "$@"
