#!/usr/bin/env bash
set -euo pipefail

NS_DIR="/etc/sysconfig/network-scripts"
GRUB_DEF="/etc/default/grub"
GRUB_CFG="/boot/grub2/grub.cfg"

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo "run as root"; exit 1; }
}

detect_two_ifaces() {
  mapfile -t ifs < <(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$' | head -n 2)
  [[ "${#ifs[@]}" -ge 2 ]] || { echo "need 2 interfaces"; exit 1; }
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

find_ifcfg_for_iface() {
  local iface="$1"
  [[ -f "${NS_DIR}/ifcfg-${iface}" ]] && { echo "${NS_DIR}/ifcfg-${iface}"; return; }
  grep -rlE "^\s*(DEVICE|NAME)\s*=\s*\"?${iface}\"?\s*$" \
    "$NS_DIR"/ifcfg-* 2>/dev/null | head -n 1 || true
}

normalize_ifcfg() {
  local src="$1" eth="$2"
  local dst="${NS_DIR}/ifcfg-${eth}"

  mkdir -p "$NS_DIR"

  if [[ -n "$src" && "$src" != "$dst" ]]; then
    mv -f "$src" "$dst"
  elif [[ -z "$src" ]]; then
    : > "$dst"
  fi

  set_kv "$dst" NAME "\"${eth}\""
  set_kv "$dst" DEVICE "\"${eth}\""
  set_kv "$dst" TYPE "Ethernet"
  set_kv "$dst" ONBOOT "yes"
  set_kv "$dst" BOOTPROTO "dhcp"
}

apply_nmcli_now() {
  local dev="$1"

  # 기존 연결 찾기
  local con
  con="$(nmcli -t -f NAME,DEVICE connection show | awk -F: -v d="$dev" '$2==d{print $1; exit}')"

  if [[ -n "$con" ]]; then
    nmcli connection reload
    nmcli device reapply "$dev" || nmcli connection up "$con"
  fi
}

patch_grub() {
  if grep -qE '^\s*GRUB_CMDLINE_LINUX=' "$GRUB_DEF"; then
    sed -ri 's|^(GRUB_CMDLINE_LINUX="[^"]*)"$|\1 net.ifnames=0 biosdevname=0"|' "$GRUB_DEF"
  else
    echo 'GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0"' >> "$GRUB_DEF"
  fi
}

main() {
  require_root

  echo "[1/6] Detect interfaces"
  read -r IF0 IF1 <<<"$(detect_two_ifaces)"
  echo " - $IF0 , $IF1"

  echo "[2/6] Prepare ifcfg-eth0/eth1"
  SRC0="$(find_ifcfg_for_iface "$IF0")"
  SRC1="$(find_ifcfg_for_iface "$IF1")"
  normalize_ifcfg "$SRC0" eth0
  normalize_ifcfg "$SRC1" eth1

  echo "[3/6] Apply NetworkManager now (pre-reboot)"
  apply_nmcli_now "$IF0"
  apply_nmcli_now "$IF1"

  echo "[4/6] Patch grub cmdline"
  patch_grub

  echo "[5/6] Regenerate grub.cfg"
  grub2-mkconfig -o "$GRUB_CFG" >/dev/null

  echo "[6/6] Done"
  echo "INFO:"
  echo "- Network config applied immediately (IP/DHCP)"
  echo "- Interface names (eth0/eth1) take effect AFTER reboot"
}

main "$@"
