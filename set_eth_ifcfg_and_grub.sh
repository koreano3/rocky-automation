#!/usr/bin/env bash
set -euo pipefail

NS_DIR="/etc/sysconfig/network-scripts"
GRUB_DEF="/etc/default/grub"

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo "ERROR: run as root"; exit 1; }
}

is_uefi() { [[ -d /sys/firmware/efi ]]; }

detect_grub_cfg() {
  # UEFI면 이쪽이 실제 부팅에 쓰이는 grub.cfg
  if is_uefi; then
    if [[ -f /boot/efi/EFI/rocky/grub.cfg ]]; then
      echo "/boot/efi/EFI/rocky/grub.cfg"; return
    elif [[ -f /boot/efi/EFI/redhat/grub.cfg ]]; then
      echo "/boot/efi/EFI/redhat/grub.cfg"; return
    fi
    # 혹시 디렉터리는 있는데 파일이 없으면(특이 케이스) grub2-mkconfig 경로로 rocky를 우선
    if [[ -d /boot/efi/EFI/rocky ]]; then
      echo "/boot/efi/EFI/rocky/grub.cfg"; return
    elif [[ -d /boot/efi/EFI/redhat ]]; then
      echo "/boot/efi/EFI/redhat/grub.cfg"; return
    fi
  fi
  echo "/boot/grub2/grub.cfg"
}

detect_two_ifaces() {
  # lo + 가상 NIC들 제외 (VM에서도 안정)
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

  # UUID 제거
  remove_key "$dst" UUID
  # 빈 줄 제거(깔끔)
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

  # 중복 없이 2개 옵션 추가
  if ! grep -qE '^\s*GRUB_CMDLINE_LINUX=.*net\.ifnames=0' "$GRUB_DEF"; then
    sed -ri 's|^(GRUB_CMDLINE_LINUX="[^"]*)"$|\1 net.ifnames=0"|' "$GRUB_DEF"
  fi
  if ! grep -qE '^\s*GRUB_CMDLINE_LINUX=.*biosdevname=0' "$GRUB_DEF"; then
    sed -ri 's|^(GRUB_CMDLINE_LINUX="[^"]*)"$|\1 biosdevname=0"|' "$GRUB_DEF"
  fi
}

main() {
  require_root

  local GRUB_CFG
  GRUB_CFG="$(detect_grub_cfg)"

  echo "[0] Boot mode: $(is_uefi && echo UEFI || echo BIOS)"
  echo "    grub target: $GRUB_CFG"

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

  # 백업 (grub + ifcfg)
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  cp -a "$GRUB_DEF" "${GRUB_DEF}.bak.${ts}"

  [[ -f "$GRUB_CFG" ]] && cp -a "$GRUB_CFG" "${GRUB_CFG}.bak.${ts}" || true
  cp -a "$SRC0" "${SRC0}.bak.${ts}"
  cp -a "$SRC1" "${SRC1}.bak.${ts}"

  echo "[3/5] Move ifcfg -> eth0 / eth1 and patch values"
  normalize_ifcfg "$SRC0" eth0
  normalize_ifcfg "$SRC1" eth1

  echo "[4/5] Patch grub cmdline"
  patch_grub

  echo "[5/5] Regenerate grub.cfg"
  if ! grub2-mkconfig -o "$GRUB_CFG" >/dev/null; then
    echo "ERROR: grub2-mkconfig failed. Rolling back grub..."
    cp -a "${GRUB_DEF}.bak.${ts}" "$GRUB_DEF"
    exit 1
  fi

  echo "DONE."
  echo "- eth0/eth1 naming effective AFTER reboot"
  echo "- backups:"
  echo "  ${GRUB_DEF}.bak.${ts}"
  echo "  ${GRUB_CFG}.bak.${ts} (if existed)"
  echo "  ${SRC0}.bak.${ts}"
  echo "  ${SRC1}.bak.${ts}"
}

main "$@"
