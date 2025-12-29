#!/usr/bin/env bash
set -euo pipefail

# 반드시 root
[[ "${EUID:-$(id -u)}" -eq 0 ]] || exit 1

echo "[STAGE2] run make_ifcfg.sh"

bash /root/rocky-automation/make_ifcfg.sh

echo "[STAGE2] cleanup systemd service"

systemctl disable rocky-automation-stage2.service || true
rm -f /etc/systemd/system/rocky-automation-stage2.service
systemctl daemon-reload

echo "[STAGE2] done"
