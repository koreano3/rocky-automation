# #!/usr/bin/env bash
# set -euo pipefail

# require_root() {
#   [[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo "ERROR: run as root"; exit 1; }
# }

# disable_units=(
#   "NetworkManager-dispatcher.service"
#   "NetworkManager-wait-online.service"
#   "atd.service"
#   "auditd.service"
#   "chronyd.service"
#   "cockpit.socket"
# #  "dbus-org.fedoraproject.FirewallD1.service"
# #  "dbus-org.freedesktop.nm-dispatcher.service"
# #  "dbus-org.freedesktop.timedate1.service"
#   "dm-event.socket"
#   "firewalld.service"
#   "import-state.service"
#   "kdump.service"
#   "libstoragemgmt.service"
#   "loadmodules.service"
#   "lvm2-lvmpolld.socket"
#   "lvm2-monitor.service"
#   "mcelog.service"
#   "mdmonitor.service"
#   "microcode.service"
#   "nis-domainname.service"
#   "selinux-autorelabel-mark.service"
#   "smartd.service"
#   "sssd-kcm.socket"
#   "sssd.service"
#   "systemd-pstore.service"
#   "timedatex.service"
#   "tuned.service"
#   "nvmefc-boot-connections.service"
#   "vdo.service"
# )

# enable_units=(
#   "NetworkManager.service"
#   "sshd.service"
#   "crond.service"
#   "irqbalance.service"
# )

# apply_disable_now=false   # true면 즉시 stop도 시도 (ntsysv에서 바로 끄는 효과)
# apply_enable_now=false    # true면 즉시 start도 시도
# # NOTE: enable/disable only affects next boot (no immediate start/stop)

# main() {
#   require_root
#   ecjp


# echo "== Enable =="
# for u in "${enable_units[@]}"; do
#   if systemctl show -p LoadState --value "$u" 2>/dev/null | grep -qx 'loaded'; then
#     # --now를 쓰지 않기로 했으니 enable만 수행 (재부팅 시 적용)
#     systemctl enable "$u" 2>/dev/null || true
#     echo "  enabled: $u"
#   else
#     echo "  skip (not found): $u"
#   fi
# done


#   echo
# echo "== Disable =="
# for u in "${disable_units[@]}"; do
#   if systemctl show -p LoadState --value "$u" 2>/dev/null | grep -qx 'loaded'; then
#     # --now를 쓰지 않기로 했으니 disable만 수행 (재부팅 시 적용)
#     systemctl disable "$u" 2>/dev/null || true
#     echo "  disabled: $u"
#   else
#     echo "  skip (not found): $u"
#   fi
# done

#   echo "== Verify (targets) =="
# for u in "${enable_units[@]}"; do
#   printf "  %-35s : %s\n" "$u" "$(systemctl is-enabled "$u" 2>/dev/null || echo not-found)"
# done
# for u in "${disable_units[@]}"; do
#   printf "  %-35s : %s\n" "$u" "$(systemctl is-enabled "$u" 2>/dev/null || echo not-found)"
# done

# }

# main "$@"
