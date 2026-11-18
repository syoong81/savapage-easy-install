#!/usr/bin/env bash
#
# savapage-status.sh - A status screen for the SavaPage server's console, similar to
# the Home Assistant OS console: what is running, the IP address, the version and
# the web addresses. It is shown above the login prompt, and again after logging in.
#
# Usage:
#   savapage-status             Show the status (any user)
#   sudo bash savapage-status.sh --install   Set up the console screen
#   sudo bash savapage-status.sh --remove    Remove it again
#
# --install copies this script to /usr/local/bin/savapage-status and adds:
#   /etc/systemd/system/savapage-status.{service,timer}  refreshes the screen every minute
#   /etc/issue.d/50-savapage.issue                      the text above the login prompt
#   /etc/profile.d/zz-savapage-status.sh                 shows the status after logging in
#
set -uo pipefail

BIN=/usr/local/bin/savapage-status
UNIT_DIR=/etc/systemd/system
ISSUE_FILE=/etc/issue.d/50-savapage.issue
PROFILE_FILE=/etc/profile.d/zz-savapage-status.sh
INSTALL_DIR=/opt/savapage

# ---------------------------------------------------------------------------
# Collect the status
# ---------------------------------------------------------------------------
state() {  # "running" or the unit's state
  local s
  s=$(systemctl is-active "$1" 2>/dev/null) || true
  case "$s" in
    active) echo running ;;
    "")     echo "not installed" ;;
    *)      echo "$s" ;;
  esac
}

collect() {
  IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "src") {print $(i + 1); exit}}')
  IP=${IP:-no network}
  NAME="$(hostname -s).local"

  VERSION=$(ls "$INSTALL_DIR"/server/lib/savapage-server-*.war 2>/dev/null | head -n 1 | sed 's/.*savapage-server-\(.*\)\.war$/\1/')
  VERSION=${VERSION:-unknown}

  OS_NAME="Linux"
  if [[ -r /etc/os-release ]]; then
    OS_NAME=$(. /etc/os-release; echo "${NAME:-Linux} ${VERSION_ID:-}")
  fi

  SP_STATE=$(state savapage.service)
  CUPS_STATE=$(state cups.service)

  if grep -qs '^ENABLED=yes' /etc/ufw/ufw.conf; then FIREWALL=on; else FIREWALL=off; fi

  if /usr/sbin/cupsctl 2>/dev/null | grep -q '^_remote_admin=1'; then
    CUPS_WEB="on (http://$IP:631)"
  else
    CUPS_WEB="off"
  fi
}

# The screen as plain text. It holds nothing that changes every minute, so the
# login prompt is only redrawn when something real changes.
render() {
  cat <<EOF

 SavaPage Print Server $VERSION
 $OS_NAME
 ----------------------------------------------------------------
 SavaPage      : $(printf '%-20s' "$SP_STATE") CUPS     : $CUPS_STATE
 Firewall      : $(printf '%-20s' "$FIREWALL") Name     : $NAME
 IP address    : $IP

 Admin web app : https://$IP:8632/admin
 User web app  : https://$IP:8632/user
 Printer (IPP) : ipp://$IP:8631/printers/airprint
 CUPS web page : $CUPS_WEB
 ----------------------------------------------------------------

EOF
}

show() {
  collect
  local uptime_text
  uptime_text=$(uptime -p 2>/dev/null | sed 's/^up //')
  if [[ -t 1 ]]; then
    # Color the states on a terminal: green for running/on, yellow otherwise.
    render | sed -E \
      -e 's/(: )(running|on)( |$)/\1\x1b[1;32m\2\x1b[0m\3/g' \
      -e 's/(: )(failed|inactive|activating|deactivating|not installed|off|no network)( |$)/\1\x1b[1;33m\2\x1b[0m\3/g' \
      -e 's/^( SavaPage Print Server .*)$/\x1b[1m\1\x1b[0m/' | sed '$d'
  else
    render | sed '$d'
  fi
  echo " Up $uptime_text. Logs: journalctl -u savapage, /opt/savapage/server/logs/"
  echo
}

# Write the login-prompt text, and redraw the prompt only if it changed.
update_issue() {
  collect
  mkdir -p "$(dirname "$ISSUE_FILE")"
  local new
  new=$(render | sed 's/\\/\\\\/g')   # agetty treats backslashes as escapes
  if [[ ! -f "$ISSUE_FILE" ]] || [[ "$(cat "$ISSUE_FILE")" != "$new" ]]; then
    printf '%s\n' "$new" > "$ISSUE_FILE"
    /sbin/agetty --reload 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Install / remove
# ---------------------------------------------------------------------------
need_root() { [[ $EUID -eq 0 ]] || { echo "Run this as root: sudo bash $0 $1" >&2; exit 1; }; }

install_screen() {
  need_root --install
  install -m 0755 "$0" "$BIN"

  cat > "$UNIT_DIR/savapage-status.service" <<EOF
[Unit]
Description=Update the SavaPage status on the console login screen
After=network-online.target savapage.service

[Service]
Type=oneshot
ExecStart=$BIN --update-issue
EOF

  cat > "$UNIT_DIR/savapage-status.timer" <<'EOF'
[Unit]
Description=Refresh the SavaPage console status every minute

[Timer]
OnBootSec=15s
OnUnitActiveSec=1min
AccuracySec=5s

[Install]
WantedBy=timers.target
EOF

  cat > "$PROFILE_FILE" <<EOF
# Show the SavaPage status after logging in (added by savapage-status.sh).
case "\$-" in
  *i*) [ -x $BIN ] && $BIN ;;
esac
EOF
  chmod 0644 "$PROFILE_FILE"

  systemctl daemon-reload
  systemctl enable --now savapage-status.timer >/dev/null 2>&1
  update_issue
  echo "SavaPage console status screen installed. Show it any time with: savapage-status"
}

remove_screen() {
  need_root --remove
  systemctl disable --now savapage-status.timer >/dev/null 2>&1 || true
  rm -f "$UNIT_DIR/savapage-status.service" "$UNIT_DIR/savapage-status.timer" \
        "$ISSUE_FILE" "$PROFILE_FILE" "$BIN"
  rmdir /etc/issue.d 2>/dev/null || true
  systemctl daemon-reload
  /sbin/agetty --reload 2>/dev/null || true
  echo "SavaPage console status screen removed."
}

case "${1:-}" in
  --install)      install_screen ;;
  --remove)       remove_screen ;;
  --update-issue) need_root --update-issue; update_issue ;;
  ""|--show)      show ;;
  *) echo "Usage: savapage-status [--install | --remove]" >&2; exit 2 ;;
esac
