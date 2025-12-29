#!/usr/bin/env bash
set -euo pipefail

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo "ERROR: run as root"; exit 1; }
}

main() {
  require_root

  echo "== Install base packages =="

  # epel
  yum -y install epel-release

  # base tools
  yum -y install \
    whois \
    net-tools \
    lrzsz \
    screen \
    bind-utils \
    sysstat \
    lsof \
    rsyslog

  # ntsysv (Rocky 8에서는 없을 수도 있음)
  if yum -y install ntsysv 2>/dev/null; then
    echo "ntsysv installed"
  else
    echo "ntsysv not available (Rocky8 normal)"
  fi

  echo
  echo "== Enable core services (ntsysv equivalent) =="

  systemctl enable NetworkManager.service
  systemctl enable crond.service
  systemctl enable irqbalance.service
  systemctl enable sshd.service

  echo
  echo "DONE: install_base_pkgs.sh"
}

main "$@"
