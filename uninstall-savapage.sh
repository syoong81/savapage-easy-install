#!/usr/bin/env bash
#
# uninstall-savapage.sh - Remove SavaPage installed by install-savapage.sh, then
# check that nothing is left behind, so the machine is ready for a clean reinstall.
#
# Usage:
#   sudo bash uninstall-savapage.sh
#
# Optional settings (environment variables):
#   ASSUME_YES=1             Don't ask for confirmation (needed with 'pct exec')
#   SKIP_BACKUP=1            Don't back up /opt/savapage/server/data first
#   RESTORE_CUPS=1           Restore /etc/cups/cupsd.conf from the installer's backup
#   REMOVE_FIREWALL_RULES=1  Remove the ufw rules for ports 8631, 8632, 9100 and 5353
#                            (the SSH rule and ufw itself are left alone)
#
# Example:
#   sudo ASSUME_YES=1 RESTORE_CUPS=1 bash uninstall-savapage.sh
#
set -euo pipefail

INSTALL_DIR="/opt/savapage"
SAVAPAGE_USER="savapage"
SAVAPAGE_PORTS="8631 8632 9100"
CUPSD_CONF=/etc/cups/cupsd.conf

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m[x] %s\033[0m\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
[[ $EUID -eq 0 ]] || die "Run this script as root: sudo bash $0"

# Only touch the account if it is SavaPage's service account, never a person's login.
SERVICE_ACCOUNT=0
if existing=$(getent passwd "$SAVAPAGE_USER"); then
  if [[ "$(cut -d: -f6 <<<"$existing")" == "$INSTALL_DIR" ]]; then
    SERVICE_ACCOUNT=1
  else
    warn "User '$SAVAPAGE_USER' exists but is not SavaPage's service account (home: $(cut -d: -f6 <<<"$existing")). It will not be touched."
  fi
fi

if [[ ! -d "$INSTALL_DIR" ]] && (( ! SERVICE_ACCOUNT )) && ! systemctl cat savapage.service >/dev/null 2>&1; then
  echo "SavaPage does not appear to be installed. Running the clean-up checks only."
  NOTHING_INSTALLED=1
else
  NOTHING_INSTALLED=0
fi

if (( ! NOTHING_INSTALLED )) && [[ "${ASSUME_YES:-0}" != "1" ]]; then
  cat <<EOF

This removes SavaPage and ALL of its data: users, print history, settings and
encryption keys in $INSTALL_DIR.
EOF
  [[ "${SKIP_BACKUP:-0}" == "1" ]] || echo "A backup of $INSTALL_DIR/server/data is saved in /root first."
  read -r -p "Type 'yes' to uninstall: " reply || reply=""
  [[ "$reply" == "yes" ]] || die "Cancelled. Nothing was changed."
fi

if (( ! NOTHING_INSTALLED )); then
  # -------------------------------------------------------------------------
  # 1. Back up the data folder (it holds the encryption keys)
  # -------------------------------------------------------------------------
  if [[ "${SKIP_BACKUP:-0}" != "1" && -d "$INSTALL_DIR/server/data" ]]; then
    log "Backing up $INSTALL_DIR/server/data"
    BACKUP="/root/savapage-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    (umask 077; tar -czf "$BACKUP" -C "$INSTALL_DIR/server" data)
    echo "Saved $BACKUP (readable by root only; it contains encryption.properties)."
  fi

  # -------------------------------------------------------------------------
  # 2. SavaPage's own uninstaller (service, CUPS notifier)
  # -------------------------------------------------------------------------
  if [[ -x "$INSTALL_DIR/uninstall" ]]; then
    log "Running SavaPage's uninstaller"
    (cd "$INSTALL_DIR" && echo yes | ./uninstall)
  else
    warn "$INSTALL_DIR/uninstall not found (partial install?). Removing the pieces by hand."
  fi

  # -------------------------------------------------------------------------
  # 3. Remove whatever the uninstaller leaves behind
  # -------------------------------------------------------------------------
  log "Removing leftovers"
  if systemctl cat savapage.service >/dev/null 2>&1; then
    systemctl disable --now savapage.service 2>/dev/null || true
  fi
  rm -f /lib/systemd/system/savapage.service /usr/lib/systemd/system/savapage.service \
        /etc/systemd/system/multi-user.target.wants/savapage.service
  rm -f /usr/lib/cups/notifier/savapage
  # SavaPage may add its own cups.service override. Remove it only if it is SavaPage's.
  if [[ -f /etc/systemd/system/cups.service ]] && grep -qi savapage /etc/systemd/system/cups.service; then
    rm -f /etc/systemd/system/cups.service
  fi
  systemctl daemon-reload

  rm -f /etc/pam.d/savapage
  cd /
  rm -rf "$INSTALL_DIR"

  if (( SERVICE_ACCOUNT )); then
    pkill -u "$SAVAPAGE_USER" 2>/dev/null || true
    sleep 1
    userdel "$SAVAPAGE_USER"
  fi
  if getent group "$SAVAPAGE_USER" >/dev/null && [[ -z "$(getent group "$SAVAPAGE_USER" | cut -d: -f4)" ]] \
     && ! getent passwd "$SAVAPAGE_USER" >/dev/null; then
    groupdel "$SAVAPAGE_USER"
  fi

  systemctl reset-failed cups.service 2>/dev/null || true
  systemctl restart cups.service 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# 4. Optional: undo the install script's system changes
# ---------------------------------------------------------------------------
if [[ "${RESTORE_CUPS:-0}" == "1" ]]; then
  if [[ -f "$CUPSD_CONF.savapage.bak" ]]; then
    log "Restoring the original CUPS configuration"
    cp "$CUPSD_CONF.savapage.bak" "$CUPSD_CONF"
    systemctl reset-failed cups.service 2>/dev/null || true
    systemctl restart cups.service
  else
    warn "No $CUPSD_CONF.savapage.bak found. CUPS configuration left as is."
  fi
fi

if [[ "${REMOVE_FIREWALL_RULES:-0}" == "1" ]]; then
  if command -v ufw >/dev/null; then
    log "Removing SavaPage's ufw rules (SSH rule kept)"
    for p in $SAVAPAGE_PORTS; do ufw delete allow "$p/tcp" >/dev/null 2>&1 || true; done
    ufw delete allow 5353/udp >/dev/null 2>&1 || true
  else
    warn "ufw is not installed. No firewall rules to remove."
  fi
fi

# ---------------------------------------------------------------------------
# 5. Clean-up checks: is the machine ready for a fresh install?
# ---------------------------------------------------------------------------
log "Checking that SavaPage is completely removed"
FAILED=0
check() {
  local description=$1; shift
  if "$@"; then
    printf '  \033[1;32m[PASS]\033[0m %s\n' "$description"
  else
    printf '  \033[1;31m[FAIL]\033[0m %s\n' "$description"
    FAILED=$((FAILED + 1))
  fi
}
no_unit()      { ! systemctl cat savapage.service >/dev/null 2>&1; }
no_unit_file() { [[ ! -e /lib/systemd/system/savapage.service && ! -e /usr/lib/systemd/system/savapage.service ]]; }
no_notifier()  { [[ ! -e /usr/lib/cups/notifier/savapage ]]; }
no_dir()       { [[ ! -e "$INSTALL_DIR" ]]; }
no_pam()       { [[ ! -e /etc/pam.d/savapage ]]; }
no_account()   {
  local home
  home=$(getent passwd "$SAVAPAGE_USER" | cut -d: -f6) || return 0
  [[ "$home" != "$INSTALL_DIR" ]]
}
no_processes() { ! pgrep -f "$INSTALL_DIR/" >/dev/null 2>&1; }
ports_free() {
  local p
  for p in $SAVAPAGE_PORTS; do
    ss -ltnH "sport = :$p" 2>/dev/null | grep -q . && return 1
  done
  return 0
}
cups_running() { systemctl is-active --quiet cups.service; }

check "savapage service removed"                   no_unit
check "savapage service file deleted"              no_unit_file
check "SavaPage CUPS notifier removed"             no_notifier
check "$INSTALL_DIR deleted"                       no_dir
check "/etc/pam.d/savapage deleted"                no_pam
check "'$SAVAPAGE_USER' service account removed"  no_account
check "no SavaPage processes running"              no_processes
check "ports ${SAVAPAGE_PORTS// /, } are free"     ports_free
check "CUPS still running (needed for reinstall)"  cups_running

echo
if (( FAILED )); then
  die "$FAILED check(s) failed. See the [FAIL] lines above before reinstalling."
fi

cat <<EOF
========================================================================
 SavaPage is removed. The machine is clean and ready for a reinstall:
   sudo bash install-savapage.sh
EOF
[[ -n "${BACKUP:-}" ]] && echo " Data backup: $BACKUP"
echo "========================================================================"
