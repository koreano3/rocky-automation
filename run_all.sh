#!/usr/bin/env bash
set -euo pipefail

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || {
    echo "ERROR: run as root"
    exit 1
  }
}

require_root

scripts=(
  patch_fstab_discard.sh
  SELinux_disabled.sh
  fix_var_tmp_symlink.sh
  iptables_clear.sh
  set_eth_ifcfg_and_grub.sh
  install_base_pkgs.sh
  systemctl_apply_then_update.sh
  make_ifcfg.sh
)

for s in "${scripts[@]}"; do
  echo
  echo "=============================="
  echo " RUN: $s"
  echo "=============================="

  if [[ -f "$s" ]]; then
    bash "$s"
  else
    echo "ERROR: $s not found"
    exit 1
  fi
done


echo
echo "ALL SCRIPTS COMPLETED SUCCESSFULLY"
echo ">> Reboot is recommended to fully apply changes."
