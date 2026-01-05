#!/usr/bin/env bash
set -euo pipefail

# 반드시 root
[[ "${EUID:-$(id -u)}" -eq 0 ]] || exit 1

# [수정 포인트] 현재 run_stage2.sh가 있는 폴더 위치를 자동으로 변수에 저장합니다.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[STAGE2] run make_ifcfg.sh"

# [수정 포인트] 절대 경로 대신 변수를 사용하여 같은 폴더 내의 파일을 실행합니다.
bash "${SCRIPT_DIR}/make_ifcfg.sh"

echo "[STAGE2] cleanup systemd service"

systemctl disable rocky-automation-stage2.service || true
rm -f /etc/systemd/system/rocky-automation-stage2.service
systemctl daemon-reload

echo "[STAGE2] done"