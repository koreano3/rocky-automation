#!/usr/bin/env bash
set -euo pipefail

# ===== 설정 =====
DIR="/etc/sysconfig/network-scripts"
IF0="eth0"
IF1="eth1"

require_root() {
  if [[ $EUID -ne 0 ]]; then
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
  local prefix="$3"
  local gw="$4"      # 빈 값 허용
  local dns1="$5"    # 빈 값 허용
  local dns2="$6"    # 빈 값 허용
  local path="${DIR}/ifcfg-${dev}"

  local uuid
  uuid=$(cat /proc/sys/kernel/random/uuid)

  cat > "$path" <<EOF
TYPE=Ethernet
BOOTPROTO=none
DEFROUTE=$( [[ -n "$gw" ]] && echo "yes" || echo "no" )
NAME=${dev}
DEVICE=${dev}
ONBOOT=yes
UUID=${uuid}
IPADDR=${ip}
PREFIX=${prefix}
EOF

  if [[ -n "$gw" ]]; then
    echo "GATEWAY=${gw}" >> "$path"
  fi
  if [[ -n "$dns1" ]]; then
    echo "DNS1=${dns1}" >> "$path"
  fi
  if [[ -n "$dns2" ]]; then
    echo "DNS2=${dns2}" >> "$path"
  fi

  echo "생성됨: $path"
}

main() {
  require_root
  mkdir -p "$DIR"

  echo "[${IF0}] 설정 입력"
  IP0=$(ask "IPADDR (예: 192.168.10.10)")
  PFX0=$(ask "PREFIX (예: 24)")
  GW0=$(ask "GATEWAY (없으면 엔터)")
  DNS10=$(ask "DNS1 (없으면 엔터)")
  DNS20=$(ask "DNS2 (없으면 엔터)")

  echo
  echo "[${IF1}] 설정 입력"
  IP1=$(ask "IPADDR (예: 10.0.0.10)")
  PFX1=$(ask "PREFIX (예: 24)")
  # 보통 eth1은 게이트웨이 비우고(DEFROUTE=no) 내부망만 두는 경우 많음
  GW1=$(ask "GATEWAY (보통 비움, 없으면 엔터)")
  DNS11=$(ask "DNS1 (없으면 엔터)")
  DNS21=$(ask "DNS2 (없으면 엔터)")

  write_ifcfg "$IF0" "$IP0" "$PFX0" "$GW0" "$DNS10" "$DNS20"
  write_ifcfg "$IF1" "$IP1" "$PFX1" "$GW1" "$DNS11" "$DNS21"

  echo
  echo "적용 방법(둘 중 하나 선택):"
  echo "1) nmcli로 반영: nmcli connection reload && nmcli device reapply ${IF0} && nmcli device reapply ${IF1}"
  echo "2) 재시작: systemctl restart NetworkManager"
}

main "$@"
