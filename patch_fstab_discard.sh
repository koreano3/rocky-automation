#!/usr/bin/env bash
set -euo pipefail

FSTAB="/etc/fstab"
BACKUP="/etc/fstab.bak.$(date +%Y%m%d_%H%M%S)"

echo "[1/6] backup: $BACKUP"
cp -a "$FSTAB" "$BACKUP"

# SSD/회전 여부를 blkid/lsblk로 판별하기 위한 준비
# rota=0 -> SSD/NVMe, rota=1 -> HDD
is_ssd_for_source() {
  local src="$1"

  # UUID=, LABEL= 같은 경우 실제 디바이스로 변환 시도
  if [[ "$src" =~ ^UUID= ]]; then
    local uuid="${src#UUID=}"
    src="$(blkid -U "$uuid" 2>/dev/null || true)"
  elif [[ "$src" =~ ^LABEL= ]]; then
    local label="${src#LABEL=}"
    src="$(blkid -L "$label" 2>/dev/null || true)"
  fi

  # src가 비었거나 파일(예: tmpfs)류면 SSD 판별 불가 -> false
  [[ -n "$src" ]] || return 1
  [[ "$src" == "tmpfs" || "$src" == "devtmpfs" ]] && return 1

  # LVM(/dev/mapper/xxx)면 하위 PV 디스크의 rota 중 하나라도 0이면 SSD로 간주(현업에서 흔히 이렇게 처리)
  # 일반 파티션이면 그 디스크의 rota 확인
  local rota
  rota="$(lsblk -no ROTA "$src" 2>/dev/null | head -n1 || true)"
  if [[ "$rota" == "0" ]]; then
    return 0
  fi

  # /dev/mapper인 경우 하위 물리 디스크 rota 재확인
  if [[ "$src" == /dev/mapper/* ]]; then
    # 하위 트리를 타고 rota 값들 중 0이 있으면 SSD
    if lsblk -no ROTA "$src" 2>/dev/null | grep -q '^0$'; then
      return 0
    fi
  fi

  return 1
}

echo "[2/6] patching fstab (exclude swap, add discard only for SSD-backed entries)..."

tmp="$(mktemp)"
awk -v OFS="\t" '
  BEGIN { }
  /^[[:space:]]*#/ { print; next }     # comment
  /^[[:space:]]*$/ { print; next }     # blank
  {
    # 기본 fstab: src mnt fstype opts dump pass
    # 공백/탭 혼용이라 일단 통째로 잡고, 뒤에서 split 처리
    line=$0
    print line
  }
' "$FSTAB" > "$tmp"

# awk에서 시스템 호출로 SSD 판단하기가 번거로워서,
# 라인 단위로 bash가 읽어 SSD면 옵션을 수정하는 방식
out="$(mktemp)"
while IFS= read -r line; do
  # 주석/빈줄 그대로
  if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line//[[:space:]]/}" ]]; then
    echo "$line" >> "$out"
    continue
  fi

  # 필드 파싱 (fstab는 최소 6필드가 보통)
  # shellcheck disable=SC2206
  parts=($line)
  src="${parts[0]:-}"
  mnt="${parts[1]:-}"
  fstype="${parts[2]:-}"
  opts="${parts[3]:-}"

  # swap 제외 (fstype=swap 또는 mountpoint=swap 등 다양한 케이스 방어)
  if [[ "$fstype" == "swap" || "$mnt" == "swap" || "$src" == "swap" ]]; then
    echo "$line" >> "$out"
    continue
  fi

  # system 파티션만 대상으로 하려면, 보통 /, /boot, /var, /home 등 "실제 마운트"만 처리
  # (원하면 여기서 mnt 조건을 더 빡세게 줄 수 있음)

  # 이미 discard 있으면 건너뜀
  if [[ "$opts" == *discard* ]]; then
    echo "$line" >> "$out"
    continue
  fi

  # SSD인 경우에만 discard 추가
  if is_ssd_for_source "$src"; then
    new_opts="$opts,discard"
    # opts가 "defaults" 같은 형태면 그대로 뒤에 discard 붙임
    parts[3]="$new_opts"
    echo "${parts[*]}" >> "$out"
  else
    echo "$line" >> "$out"
  fi
done < "$FSTAB"

echo "[3/6] writing patched fstab"
cp -a "$out" "$FSTAB"
rm -f "$tmp" "$out"

echo "[4/6] validate: mount -a"
if ! mount -a; then
  echo "ERROR: mount -a failed. Restoring backup..."
  cp -a "$BACKUP" "$FSTAB"
  mount -a || true
  exit 1
fi

echo "[5/6] OK. current discard-applied mounts:"
mount | grep -E " on /| discard" || true

echo "[6/6] done."
echo "Backup saved at: $BACKUP"
