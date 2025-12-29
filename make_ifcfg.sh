#!/usr/bin/env bash
set -euo pipefail

# ===== 설정 =====
DIR="/etc/sysconfig/network-scripts"
IF0="eth0"
IF1="eth1"

require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "root로 실행해야 함 (sudo 사용)."
    exit 1
  fi
}

ask() {
  local prompt="$1"
  local var
  read -r -p "$prompt: " var
  echo "$var"
}

write_ifcfg() {
  local dev="$1"
  local ip="$2"
  local netmask="$3"
  local gw="$4"
  local dns1="$5"
  local dns2="$6"
  local path="${DIR}/ifcfg-${dev}"

  # heredoc에 빈 줄 절대 넣지 않기!
  cat > "$path" <<EOF
TYPE=Ethernet
BOOTPROTO=none
DEFROUTE=$( [[ -n "$gw" ]] && echo "yes" || echo "no" )
NAME=${dev}
DEVICE=${dev}
ONBOOT=yes
IPADDR=${ip}
NETMASK=${netmask}
EOF

  [[ -n "$gw"   ]] && echo "GATEWAY=${gw}" >> "$path"
  [[ -n "$dns1" ]] && echo "DNS1=${dns1}" >> "$path"
  [[ -n "$dns2" ]] && echo "DNS2=${dns2}" >> "$path"

  echo "생성됨: $path"
}

main() {
  require_root
  mkdir -p "$DIR"

  echo "[${IF0}] 설정 입력"
  IP0=$(ask "IPADDR (예: 192.168.10.10)")
  MASK0=$(ask "NETMASK (예: 255.255.255.0)")
  GW0=$(ask "GATEWAY (없으면 엔터)")
  DNS10=$(ask "DNS1 (없으면 엔터)")
  DNS20=$(ask "DNS2 (없으면 엔터)")

  echo
  echo "[${IF1}] 설정 입력"
  IP1=$(ask "IPADDR (예: 10.0.0.10)")
  MASK1=$(ask "NETMASK (예: 255.255.255.0)")
  GW1=$(ask "GATEWAY (보통 비움, 없으면 엔터)")
  DNS11=$(ask "DNS1 (없으면 엔터)")
  DNS21=$(ask "DNS2 (없으면 엔터)")

  write_ifcfg "$IF0" "$IP0" "$MASK0" "$GW0" "$DNS10" "$DNS20"
  write_ifcfg "$IF1" "$IP1" "$MASK1" "$GW1" "$DNS11" "$DNS21"

  echo
  echo "done. reboot recommended to apply network settings."
}

main "$@"
