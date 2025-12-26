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
  fix_var_tmp_symlink.sh
  install_base_pkgs.sh
  iptables_clear.sh
  #make_ifcfg.sh
  patch_fstab_discard.sh
  SELinux_disabled.sh
  set_eth_ifcfg_and_grub.sh
  systemctl_apply_then_update.sh
)

for s in "${scripts[@]}"; do
  echo
  echo "=============================="
  echo " RUN: $s"
  echo "=============================="

  if [[ -x "./$s" ]]; then
    "./$s"
  else
    echo "ERROR: $s not found or not executable"
    exit 1
  fi
done

echo
echo "ALL SCRIPTS COMPLETED SUCCESSFULLY"
echo ">> Reboot is recommended to fully apply changes."
