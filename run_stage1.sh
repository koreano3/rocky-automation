#!/usr/bin/env bash
set -euo pipefail

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || {
    echo "ERROR: run as root"
    exit 1
  }
}

require_root

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICE_NAME="rocky-automation-stage2.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"

scripts_stage1=(
  patch_fstab_discard.sh
  SELinux_disabled.sh
  fix_var_tmp_symlink.sh
  iptables_clear.sh
  set_eth_ifcfg_and_grub.sh
  install_base_pkgs.sh
  systemctl_apply_then_update.sh
)

run_script() {
  local s="$1"
  echo
  echo "=============================="
  echo " RUN: $s"
  echo "=============================="

  if [[ -f "${BASE_DIR}/${s}" ]]; then
    bash "${BASE_DIR}/${s}"
  else
    echo "ERROR: ${BASE_DIR}/${s} not found"
    exit 1
  fi
}

echo "===== STAGE1 START ====="

# 1️⃣ stage1 스크립트 실행
for s in "${scripts_stage1[@]}"; do
  run_script "$s"
done

# 2️⃣ stage2 스크립트 존재 확인
if [[ ! -f "${BASE_DIR}/run_stage2.sh" ]]; then
  echo "ERROR: ${BASE_DIR}/run_stage2.sh not found"
  exit 1
fi

# 3️⃣ systemd stage2 서비스 생성 (수정된 버전)
cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=Rocky automation stage2 (post-reboot)
After=network.target NetworkManager.service
Wants=NetworkManager.service

[Service]
Type=oneshot
# [중요] 스크립트가 실행될 기본 위치를 지정합니다.
WorkingDirectory=${BASE_DIR}
ExecStart=/usr/bin/env bash ${BASE_DIR}/run_stage2.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl disable rocky-automation-stage2.service
rm -f /etc/systemd/system/rocky-automation-stage2.service
systemctl daemon-reload

echo
echo "STAGE1 완료"
echo "→ 5초 후 재부팅"
echo "→ 다음 부팅에서 run_stage2.sh 자동 실행"
sleep 5
reboot
`
