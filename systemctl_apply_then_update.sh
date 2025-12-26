#!/usr/bin/env bash
set -euo pipefail

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo "ERROR: run as root"; exit 1; }
}

unit_exists() {
  systemctl show -p LoadState --value "$1" 2>/dev/null | grep -qx 'loaded'
}

enable_units=(
  "NetworkManager.service"
  "sshd.service"
  "crond.service"
  "irqbalance.service"
)

disable_units=(
  "NetworkManager-dispatcher.service"
  "NetworkManager-wait-online.service"
  "atd.service"
  "auditd.service"
  "chronyd.service"
  "cockpit.socket"
#  "dbus-org.fedoraproject.FirewallD1.service"
#  "dbus-org.freedesktop.nm-dispatcher.service"
#  "dbus-org.freedesktop.timedate1.service"
  "dm-event.socket"
  "firewalld.service"
  "import-state.service"
  "kdump.service"
  "libstoragemgmt.service"
  "loadmodules.service"
  "lvm2-lvmpolld.socket"
  "lvm2-monitor.service"
  "mcelog.service"
  "mdmonitor.service"
  "microcode.service"
  "nis-domainname.service"
  "selinux-autorelabel-mark.service"
  "smartd.service"
  "sssd-kcm.socket"
  "sssd.service"
  "systemd-pstore.service"
  "timedatex.service"
  "tuned.service"
  "nvmefc-boot-connections.service"
  "vdo.service"
)

main() {
  require_root

  echo "== systemctl_apply (boot-time only) =="

  echo "[Enable]"
  for u in "${enable_units[@]}"; do
    if unit_exists "$u"; then
      systemctl enable "$u" 2>/dev/null || true
      echo "  enabled: $u"
    else
      echo "  skip (not found): $u"
    fi
  done

  echo
  echo "[Disable]"
  for u in "${disable_units[@]}"; do
    if unit_exists "$u"; then
      systemctl disable "$u" 2>/dev/null || true
      echo "  disabled: $u"
    else
      echo "  skip (not found): $u"
    fi
  done

  echo
  echo "== Verify (only targets) =="
  for u in "${enable_units[@]}"; do
    printf "  %-40s : %s\n" "$u" "$(systemctl is-enabled "$u" 2>/dev/null || echo not-found)"
  done
  for u in "${disable_units[@]}"; do
    printf "  %-40s : %s\n" "$u" "$(systemctl is-enabled "$u" 2>/dev/null || echo not-found)"
  done

  echo
  echo "== yum -y update =="
  yum -y update

  echo
  echo "DONE. (Reboot to apply start/stop changes)"
}

main "$@"
