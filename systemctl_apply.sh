#!/usr/bin/env bash
set -euo pipefail

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo "ERROR: run as root"; exit 1; }
}

disable_units=(
  "NetworkManager-dispatcher.service"
  "NetworkManager-wait-online.service"
  "atd.service"
  "auditd.service"
  "chronyd.service"
  "cockpit.socket"
  "dbus-org.fedoraproject.FirewallD1.service"
  "dbus-org.freedesktop.nm-dispatcher.service"
  "dbus-org.freedesktop.timedate1.service"
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
  "vdo.service"
)

enable_units=(
  "NetworkManager.service"
  "sshd.service"
  "crond.service"
  "irqbalance.service"
)

apply_disable_now=true   # true면 즉시 stop도 시도 (ntsysv에서 바로 끄는 효과)
apply_enable_now=true    # true면 즉시 start도 시도

main() {
  require_root

  echo "== Enable =="
  for u in "${enable_units[@]}"; do
    if systemctl show -p LoadState --value "$u" 2>/dev/null | grep -qx 'loaded'; then
      if $apply_enable_now; then
        systemctl enable --now "$u"
      else
        systemctl enable "$u"
      fi
      echo "  enabled: $u"
    else
      echo "  skip (not found): $u"
    fi
  done

  echo
  echo "== Disable =="
  for u in "${disable_units[@]}"; do
    if systemctl show -p LoadState --value "$u" 2>/dev/null | grep -qx 'loaded'; then
      if $apply_disable_now; then
        systemctl disable --now "$u" 2>/dev/null || systemctl disable "$u" || true
      else
        systemctl disable "$u" || true
      fi
      echo "  disabled: $u"
    else
      echo "  skip (not found): $u"
    fi
  done

  echo
  echo "== Verify (enabled) =="
  systemctl list-unit-files --type=service --state=enabled --no-legend | awk '{print "  " $1}'
  systemctl list-unit-files --type=socket  --state=enabled --no-legend | awk '{print "  " $1}'
}

main "$@"
