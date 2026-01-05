#!/usr/bin/env bash
set -euo pipefail

# 반드시 root
[[ "${EUID:-$(id -u)}" -eq 0 ]] || exit 1

echo "[STAGE2] run make_ifcfg.sh"

# 1. 현재 스크립트가 위치한 디렉토리를 변수에 담습니다.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 2. 변수를 사용하여 실행합니다. (이것만 있으면 됩니다)
bash "${SCRIPT_DIR}/make_ifcfg.sh"

# (기존의 bash /root/rocky-automation/make_ifcfg.sh 부분은 삭제하거나 주석 처리하세요)

echo "[STAGE2] cleanup systemd service"

# 3. 서비스 비활성화 및 파일 삭제
systemctl disable rocky-automation-stage2.service || true
rm -f /etc/systemd/system/rocky-automation-stage2.service
systemctl daemon-reload

echo "[STAGE2] done"