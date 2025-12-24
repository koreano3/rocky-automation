#!/usr/bin/env bash
set -euo pipefail

TARGET="/var/tmp"
LINK="/tmp"

echo "[1/6] Stop chronyd service (if running)..."
if systemctl is-active --quiet chronyd; then
  systemctl stop chronyd
else
  echo "chronyd already stopped or not running."
fi

echo "[2/6] Check existing /var/tmp..."

# 이미 심볼릭 링크면 종료
if [[ -L "$TARGET" ]]; then
  echo "/var/tmp is already a symlink -> $(readlink -f $TARGET)"
  exit 0
fi

# 디렉터리면 백업 후 제거
if [[ -d "$TARGET" ]]; then
  BACKUP="/var/tmp.bak.$(date +%Y%m%d_%H%M%S)"
  echo "[3/6] Backup existing /var/tmp to $BACKUP"
  mv "$TARGET" "$BACKUP"
fi

echo "[4/6] Create symlink: /var/tmp -> /tmp"
ln -s "$LINK" "$TARGET"

echo "[5/6] Verify result"
ls -ld /var/tmp

echo "[6/6] Done."
echo "- chronyd stopped"
echo "- /var/tmp now points to /tmp"
