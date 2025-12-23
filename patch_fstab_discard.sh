#!/usr/bin/env bash
set -euo pipefail

FSTAB="/etc/fstab"
BACKUP="/etc/fstab.bak.$(date +%Y%m%d_%H%M%S)"

# "sda가 SSD인지"만 단순 판별 (원하면 nvme0n1로 바꿔도 됨)
DISK="sda"

need_opts_for_target() {
  # mountpoint별로 "반드시 포함돼야 하는 옵션" 정의
  # 출력은 콤마로 연결된 목록
  local mnt="$1"
  case "$mnt" in
    "/")     echo "discard" ;;
    "/DATA") echo "discard" ;;
    "/boot") echo "discard" ;;
    "/tmp")  echo "discard,noexec,nosuid" ;;
    *)       echo "" ;;
  esac
}

has_opt() {
  local opts="$1" opt="$2"
  # 콤마 구분 옵션에 opt가 포함되는지 정확히 체크
  [[ ",$opts," == *",$opt,"* ]]
}

add_opts() {
  local opts="$1" add_csv="$2"
  local new="$opts"
  IFS=',' read -ra add_arr <<< "$add_csv"
  for o in "${add_arr[@]}"; do
    [[ -z "$o" ]] && continue
    if ! has_opt "$new" "$o"; then
      new="${new},${o}"
    fi
  done
  # 앞에 콤마가 생겼으면 제거
  new="${new#,}"
  echo "$new"
}

echo "[0/5] check disk rota: /dev/${DISK}"
rota="$(lsblk -d -n -o ROTA "/dev/${DISK}" 2>/dev/null || true)"

if [[ -z "${rota}" ]]; then
  echo "ERROR: cannot read ROTA for /dev/${DISK}. Aborting."
  exit 2
fi

if [[ "${rota}" != "0" ]]; then
  echo "HDD detected (ROTA=${rota}). Skip fstab changes."
  exit 0
fi

echo "SSD detected (ROTA=0). Proceed."

echo "[1/5] backup: ${BACKUP}"
cp -a "${FSTAB}" "${BACKUP}"

tmp="$(mktemp)"

echo "[2/5] patching ${FSTAB} (exclude swap, apply mountpoint policy)..."

# fstab 라인별 처리:
# - 주석/빈줄 유지
# - swap fstype은 건드리지 않음
# - mnt가 /, /DATA, /boot, /tmp 인 경우 옵션 추가
while IFS= read -r line; do
  # 주석/빈줄 그대로
  if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line//[[:space:]]/}" ]]; then
    echo "$line" >> "$tmp"
    continue
  fi

  # 공백/탭 기준 파싱
  # shellcheck disable=SC2206
  parts=($line)

  # fstab 표준 6필드 기대
  src="${parts[0]:-}"
  mnt="${parts[1]:-}"
  fstype="${parts[2]:-}"
  opts="${parts[3]:-}"
  dump="${parts[4]:-0}"
  pass="${parts[5]:-0}"

  # swap 제외
  if [[ "$fstype" == "swap" ]]; then
    echo "$line" >> "$tmp"
    continue
  fi

  need="$(need_opts_for_target "$mnt")"
  if [[ -z "$need" ]]; then
    echo "$line" >> "$tmp"
    continue
  fi

  # /tmp는 discard,noexec,nosuid 강제 추가 (기존 옵션 보존 + 중복 방지)
  new_opts="$(add_opts "$opts" "$need")"

  # 재조립해서 출력 (fstab는 공백 구분이면 됨)
  echo -e "${src}\t${mnt}\t${fstype}\t${new_opts}\t${dump}\t${pass}" >> "$tmp"
done < "$FSTAB"

echo "[3/5] write patched fstab"
cp -a "$tmp" "$FSTAB"
rm -f "$tmp"

echo "[4/5] validate: mount -a"
if ! mount -a; then
  echo "ERROR: mount -a failed. Restoring backup..."
  cp -a "$BACKUP" "$FSTAB"
  mount -a || true
  exit 1
fi

echo "[5/5] done. Check applied options:"
echo "---- fstab targets ----"
grep -nE '^[^#].*\s(/|/DATA|/boot|/tmp)\s' "$FSTAB" || true
echo "---- mounted discard ----"
findmnt -no TARGET,OPTIONS | grep -E '^/( |$)|^/DATA( |$)|^/boot( |$)|^/tmp( |$)' -n || true
echo "Backup saved at: $BACKUP"
