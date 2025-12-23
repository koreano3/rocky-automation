#!/usr/bin/env bash
set -euo pipefail

FSTAB="/etc/fstab"
BACKUP="/etc/fstab.bak.$(date +%Y%m%d_%H%M%S)"

need_opts_for_target() {
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

  # 혹시 opts가 비어있어서 앞에 콤마가 붙으면 제거
  new="${new#,}"
  echo "$new"
}

echo "[1/5] backup: ${BACKUP}"
cp -a "${FSTAB}" "${BACKUP}"

tmp="$(mktemp)"

echo "[2/5] patching ${FSTAB} (exclude swap, apply discard policy)..."

while IFS= read -r line; do
  # 주석/빈줄 유지
  if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line//[[:space:]]/}" ]]; then
    echo "$line" >> "$tmp"
    continue
  fi

  # 공백/탭 기준 파싱
  # shellcheck disable=SC2206
  parts=($line)

  src="${parts[0]:-}"
  mnt="${parts[1]:-}"
  fstype="${parts[2]:-}"
  opts="${parts[3]:-defaults}"
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

  new_opts="$(add_opts "$opts" "$need")"

  # 원래 dump/pass 값 그대로 유지
  echo -e "${src}\t${mnt}\t${fstype}\t${new_opts}\t${dump}\t${pass}" >> "$tmp"
done < "$FSTAB"

echo "[3/5] writing patched fstab"
cp -a "$tmp" "$FSTAB"
rm -f "$tmp"

echo "[4/5] validate: mount -a"
if ! mount -a; then
  echo "ERROR: mount -a failed. Restoring backup..."
  cp -a "$BACKUP" "$FSTAB"
  mount -a || true
  exit 1
fi

echo "[5/5] done. Applied lines:"
grep -nE '^[^#].*\s(/|/DATA|/boot|/tmp)\s' "$FSTAB" || true
echo "Backup saved at: $BACKUP"
