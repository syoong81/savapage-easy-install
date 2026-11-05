#!/usr/bin/env bash
#
# install-savapage.sh - Install SavaPage on Debian / Ubuntu.
#
# Supported targets: Debian 12 and 13, Ubuntu 26.04, on bare metal, a VM or a
# Proxmox LXC container (unprivileged, nesting=1).
#
# The server is not tied to any network or subnet, so it keeps working after it
# is moved to another location.
#
# Usage:
#   sudo bash install-savapage.sh
#
# Optional settings (environment variables):
#   SAVAPAGE_VERSION=1.7.0-final Installer version (default: 1.7.0-final)
#   SKIP_FIREWALL=1              Do not configure ufw (you handle the firewall yourself)
#   HTTPS_REDIRECT=0             Don't redirect web pages on http://...:8631 to https://...:8632
#                                (default: 1 = redirect on; IPP printing is never redirected)
#   CUPS_WEB=1                   Open the CUPS web interface (port 631) to the local network
#                                (default: 0 = CUPS only reachable from the server itself)
#
set -euo pipefail

DOWNLOAD_BASE="https://download.savapage.org"
INSTALL_DIR="/opt/savapage"
SAVAPAGE_USER="savapage"
SAVAPAGE_VERSION="${SAVAPAGE_VERSION:-1.7.0-final}"
HTTPS_REDIRECT="${HTTPS_REDIRECT:-1}"
CUPS_WEB="${CUPS_WEB:-0}"

# Ports SavaPage needs (see manual, "Check Firewall Settings").
OPEN_TCP_PORTS="22 8631 8632 9100"   # SSH, HTTP, HTTPS, JetDirect/RAW printing
OPEN_UDP_PORTS="5353"                # mDNS for IPP Everywhere / AirPrint discovery

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m[x] %s\033[0m\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
[[ $EUID -eq 0 ]] || die "Run this script as root: sudo bash $0"

[[ -r /etc/os-release ]] || die "Cannot detect the operating system (/etc/os-release missing)."
. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
  *" debian "*|*" ubuntu "*) ;;
  *) die "This script supports Debian and Ubuntu only (found: ${PRETTY_NAME:-unknown})." ;;
esac
case "${ID:-}:${VERSION_ID:-}" in
  debian:12|debian:13|ubuntu:26.04) ;;
  *) warn "${PRETTY_NAME:-This OS} is not a supported version (Debian 12/13, Ubuntu 26.04). Continuing anyway." ;;
esac

[[ "$(uname -m)" == "x86_64" ]] || die "SavaPage installers are published for x86_64 (64-bit Intel/AMD) only."

command -v systemctl >/dev/null || die "systemd is required."

# The service account must be a dedicated one. Never take over a person's login account.
if existing=$(getent passwd "$SAVAPAGE_USER"); then
  existing_home=$(cut -d: -f6 <<<"$existing")
  if [[ "$existing_home" != "$INSTALL_DIR" ]]; then
    die "A user named '$SAVAPAGE_USER' already exists (home: $existing_home). SavaPage needs that name for its own
    service account, and this script will not modify an existing login account.
    Use a different name for your own account (e.g. create a new admin user, then remove or rename '$SAVAPAGE_USER'),
    or install on a fresh system where you chose another user name. Nothing has been changed."
  fi
fi

mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
(( mem_kb >= 1900000 )) || warn "SavaPage recommends at least 2 GB RAM (found $((mem_kb / 1024)) MB)."

# LXC containers (e.g. Proxmox CT) need an Avahi tweak, and ufw may not start in some.
IN_LXC=0
if [[ "$(systemd-detect-virt -c 2>/dev/null || true)" == lxc* ]]; then
  IN_LXC=1
  log "Running inside an LXC container"
  if systemctl list-units --state=failed --no-legend 2>/dev/null | grep -q .; then
    warn "Some systemd units have failed. On Proxmox, make sure the container has 'nesting=1' (Options > Features)."
  fi
fi

# ---------------------------------------------------------------------------
# 1. Packages
# ---------------------------------------------------------------------------
log "Installing required packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q

# Prefer Java 21 (Debian 13, Ubuntu 26.04), then 17 (Debian 12). Newer defaults
# such as Java 25 on Ubuntu 26.04 are not yet proven with SavaPage.
JAVA_PKG=default-jdk-headless
for v in 21 17; do
  if apt-cache show "openjdk-$v-jdk-headless" >/dev/null 2>&1; then
    JAVA_PKG="openjdk-$v-jdk-headless"
    break
  fi
done

apt-get install -y -q \
  "$JAVA_PKG" \
  cups cups-bsd cups-client \
  poppler-utils qpdf imagemagick librsvg2-bin \
  avahi-daemon avahi-utils libnss-mdns \
  binutils debianutils perl gzip \
  wget ca-certificates iproute2 sudo

# Make the chosen JDK the system default, in case another Java is installed too.
if [[ "$JAVA_PKG" == openjdk-* ]]; then
  java_bin=$(update-alternatives --list java 2>/dev/null | grep "java-${JAVA_PKG//[^0-9]/}-" | head -n 1 || true)
  if [[ -n "$java_bin" ]]; then
    update-alternatives --set java "$java_bin" >/dev/null
  fi
fi

java_major=$(java -version 2>&1 | awk -F'"' '/version/ {split($2, v, "."); print v[1]; exit}')
(( java_major >= 11 )) || die "SavaPage needs JDK 11 or newer (found Java $java_major)."
echo "Using Java $java_major."

# ImageMagick 7 (Debian 13+) replaces 'convert' with 'magick'. SavaPage calls 'convert'.
if ! command -v convert >/dev/null && command -v magick >/dev/null; then
  printf '#!/bin/sh\nexec magick "$@"\n' > /usr/local/bin/convert
  chmod 755 /usr/local/bin/convert
  echo "Added /usr/local/bin/convert wrapper for ImageMagick 7."
fi

# ---------------------------------------------------------------------------
# 2. System account
# ---------------------------------------------------------------------------
log "Creating the '$SAVAPAGE_USER' system account"
if ! id "$SAVAPAGE_USER" >/dev/null 2>&1; then
  useradd -r -s /bin/bash -d "$INSTALL_DIR" "$SAVAPAGE_USER"
fi
mkdir -p "$INSTALL_DIR"
chown "$SAVAPAGE_USER:$SAVAPAGE_USER" "$INSTALL_DIR"

# ---------------------------------------------------------------------------
# 3. CUPS: local only (SavaPage talks to it on localhost:631)
# ---------------------------------------------------------------------------
log "Configuring CUPS for local-only access"
CUPSD_CONF=/etc/cups/cupsd.conf
[[ -f "$CUPSD_CONF.savapage.bak" ]] || cp "$CUPSD_CONF" "$CUPSD_CONF.savapage.bak"

systemctl reset-failed cups.service cups.socket cups.path 2>/dev/null || true
systemctl enable --now cups.service
# Do not share or publish printers to the network, and keep the CUPS web/admin UI local.
cupsctl --no-share-printers --no-remote-admin --no-remote-any

# Bind CUPS to localhost only and turn browsing off.
sed -i -E \
  -e 's/^[[:space:]]*Port[[:space:]]+631[[:space:]]*$/Listen localhost:631/' \
  -e '/^[[:space:]]*Listen[[:space:]]+(\*|0\.0\.0\.0|\[::\]):631/d' \
  -e 's/^[[:space:]]*Browsing[[:space:]]+.*/Browsing Off/' \
  "$CUPSD_CONF"
grep -q '^Listen localhost:631' "$CUPSD_CONF" || sed -i '1i Listen localhost:631' "$CUPSD_CONF"
grep -q '^Browsing ' "$CUPSD_CONF" || echo 'Browsing Off' >> "$CUPSD_CONF"

# Job history settings recommended by SavaPage (avoids duplicate CUPS job IDs).
set_cups_directive() {
  if grep -qE "^[[:space:]]*$1[[:space:]]" "$CUPSD_CONF"; then
    sed -i -E "s/^[[:space:]]*$1[[:space:]].*/$1 $2/" "$CUPSD_CONF"
  else
    echo "$1 $2" >> "$CUPSD_CONF"
  fi
}
set_cups_directive MaxJobs 500
set_cups_directive PreserveJobHistory Yes
set_cups_directive PreserveJobFiles No

# Stop cups-browsed from importing remote printers.
if [[ -f /etc/cups/cups-browsed.conf ]]; then
  if grep -qE '^[[:space:]]*BrowseRemoteProtocols' /etc/cups/cups-browsed.conf; then
    sed -i -E 's/^[[:space:]]*BrowseRemoteProtocols.*/BrowseRemoteProtocols none/' /etc/cups/cups-browsed.conf
  else
    echo 'BrowseRemoteProtocols none' >> /etc/cups/cups-browsed.conf
  fi
  systemctl restart cups-browsed.service 2>/dev/null || true
fi

cupsd -t >/dev/null || die "cupsd.conf failed validation. Original saved as $CUPSD_CONF.savapage.bak"
systemctl reset-failed cups.service cups.socket cups.path 2>/dev/null || true
systemctl restart cups.service
systemctl start cups.socket cups.path 2>/dev/null || true

# Optional: CUPS web interface on the local network (off by default). CUPS itself
# limits it to the local subnet (Allow @LOCAL), and admin pages still need a login.
if [[ "$CUPS_WEB" == "1" ]]; then
  log "Opening the CUPS web interface to the local network (CUPS_WEB=1)"
  cupsctl --remote-admin
  # cupsctl makes cupsd restart; wait until it answers again.
  for _ in $(seq 1 15); do
    (exec 3<>/dev/tcp/127.0.0.1/631) 2>/dev/null && break
    sleep 1
  done
  if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != root ]]; then
    usermod -aG lpadmin "$SUDO_USER"
    echo "Added '$SUDO_USER' to the lpadmin group, so it can log in to the CUPS admin pages."
  fi
fi

# ---------------------------------------------------------------------------
# 4. Avahi (IPP Everywhere / AirPrint discovery on the local network)
# ---------------------------------------------------------------------------
log "Configuring Avahi"
AVAHI_CONF=/etc/avahi/avahi-daemon.conf
if [[ -f "$AVAHI_CONF" ]]; then
  # Advertise on all interfaces so discovery keeps working if the network
  # interface or subnet changes after a move.
  sed -i -E \
    -e 's/^#?[[:space:]]*use-ipv4=.*/use-ipv4=yes/' \
    -e 's/^#?[[:space:]]*use-ipv6=.*/use-ipv6=yes/' \
    -e 's/^[[:space:]]*allow-interfaces=/#allow-interfaces=/' \
    "$AVAHI_CONF"
  # In unprivileged containers avahi-daemon fails to start with its process limit set.
  if (( IN_LXC )); then
    sed -i -E 's/^[[:space:]]*rlimit-nproc=/#rlimit-nproc=/' "$AVAHI_CONF"
  fi
fi
systemctl enable avahi-daemon.service
systemctl restart avahi-daemon.service

# ---------------------------------------------------------------------------
# 5. Download and verify the installer
# ---------------------------------------------------------------------------
log "Downloading SavaPage"
SUMS_FILE=$(mktemp)
trap 'rm -f "$SUMS_FILE"' EXIT
wget -q -O "$SUMS_FILE" "$DOWNLOAD_BASE/sha512sums.txt" || die "Could not reach $DOWNLOAD_BASE"

INSTALLER="savapage-setup-${SAVAPAGE_VERSION}-linux-x64.bin"
EXPECTED_SHA=$(awk -v f="$INSTALLER" '$2 ~ ("(^|/)" f "$") {print $1; exit}' "$SUMS_FILE")
[[ -n "$EXPECTED_SHA" ]] || die "No checksum listed for $INSTALLER (check SAVAPAGE_VERSION)."

INSTALLER_PATH="$INSTALL_DIR/$INSTALLER"
if [[ ! -f "$INSTALLER_PATH" ]] || ! echo "$EXPECTED_SHA  $INSTALLER_PATH" | sha512sum -c --status; then
  rm -f "$INSTALL_DIR"/savapage-setup-*-linux-*.bin
  sudo -u "$SAVAPAGE_USER" wget -q --show-progress -O "$INSTALLER_PATH" "$DOWNLOAD_BASE/installer/$INSTALLER"
fi
echo "$EXPECTED_SHA  $INSTALLER_PATH" | sha512sum -c --status || { rm -f "$INSTALLER_PATH"; die "Checksum mismatch for $INSTALLER. Download deleted."; }
echo "Verified $INSTALLER (SHA-512)."

# ---------------------------------------------------------------------------
# 6. Run the installer
# ---------------------------------------------------------------------------
if [[ -d "$INSTALL_DIR/server" ]]; then
  warn "SavaPage is already installed in $INSTALL_DIR/server. Skipping the installer."
  warn "To upgrade, follow https://manual.savapage.org/ch-install-on-linux-upgrade.html"
else
  log "Running the SavaPage installer as '$SAVAPAGE_USER' (non-interactive)"
  sudo -u "$SAVAPAGE_USER" -H bash -c "cd '$INSTALL_DIR' && sh './$INSTALLER' -n"

  log "Running the root part of the installation"
  [[ -x "$INSTALL_DIR/MUST-RUN-AS-ROOT" ]] || die "$INSTALL_DIR/MUST-RUN-AS-ROOT not found. Check the installer output above."
  "$INSTALL_DIR/MUST-RUN-AS-ROOT"
fi

# ---------------------------------------------------------------------------
# 7. Redirect http://...:8631 web pages to HTTPS (on by default)
# ---------------------------------------------------------------------------
SERVER_PROPS="$INSTALL_DIR/server/data/server.properties"
[[ -f "$SERVER_PROPS" ]] || die "$SERVER_PROPS not found."
if [[ "$HTTPS_REDIRECT" == "1" ]]; then
  redirect_value=true
  log "Turning on the HTTP to HTTPS redirect for the web apps"
else
  redirect_value=false
  log "Turning off the HTTP to HTTPS redirect (HTTPS_REDIRECT=0)"
fi
if grep -qE '^[[:space:]]*server\.html\.redirect\.ssl[[:space:]]*=' "$SERVER_PROPS"; then
  current=$(grep -E '^[[:space:]]*server\.html\.redirect\.ssl[[:space:]]*=' "$SERVER_PROPS" | tail -n 1 | cut -d= -f2 | tr -d '[:space:]')
  sed -i -E "s/^[[:space:]]*server\.html\.redirect\.ssl[[:space:]]*=.*/server.html.redirect.ssl=$redirect_value/" "$SERVER_PROPS"
else
  current=false
  echo "server.html.redirect.ssl=$redirect_value" >> "$SERVER_PROPS"
fi
# Restart only when the setting actually changed.
if [[ "$current" != "$redirect_value" ]]; then
  systemctl restart savapage.service
fi

# ---------------------------------------------------------------------------
# 8. Firewall: open the SavaPage ports (from any network)
# ---------------------------------------------------------------------------
if [[ "$CUPS_WEB" == "1" ]]; then
  OPEN_TCP_PORTS="$OPEN_TCP_PORTS 631"
fi

configure_ufw() {
  ufw default deny incoming >/dev/null || return 1
  ufw default allow outgoing >/dev/null || return 1
  local p label
  for p in $OPEN_TCP_PORTS; do
    case "$p" in
      22)  label='SSH' ;;
      631) label='CUPS web interface' ;;
      *)   label='SavaPage' ;;
    esac
    ufw allow "$p/tcp" comment "$label" >/dev/null || return 1
  done
  for p in $OPEN_UDP_PORTS; do
    ufw allow "$p/udp" comment 'mDNS' >/dev/null || return 1
  done
  # CUPS (631) stays closed unless CUPS_WEB=1. Close it again if it was opened before.
  # SavaPage's local SSL port (8633) is never opened.
  if [[ "$CUPS_WEB" != "1" ]]; then
    ufw delete allow 631/tcp >/dev/null 2>&1 || true
  fi
  ufw --force enable >/dev/null || return 1
  ufw status | grep -q '^Status: active'
}

if [[ "${SKIP_FIREWALL:-0}" == "1" ]]; then
  warn "SKIP_FIREWALL=1: not touching the firewall. Open TCP $OPEN_TCP_PORTS and UDP $OPEN_UDP_PORTS yourself."
else
  log "Configuring the firewall (ufw): opening the SavaPage ports"
  if systemctl is-active --quiet firewalld 2>/dev/null; then
    die "firewalld is active. Rerun with SKIP_FIREWALL=1 and configure firewalld yourself."
  fi
  apt-get install -y -q ufw

  if configure_ufw; then
    ufw status verbose
  elif (( IN_LXC )); then
    # Some container setups can't run a firewall. Carry on without one.
    ufw --force disable >/dev/null 2>&1 || true
    warn "ufw could not start in this container, so the firewall is off. Use the Proxmox firewall"
    warn "for this container instead: allow TCP $OPEN_TCP_PORTS and UDP $OPEN_UDP_PORTS (see INSTALL.md)."
  else
    die "Could not set up the ufw firewall. Rerun with SKIP_FIREWALL=1 to skip it."
  fi
fi

# ---------------------------------------------------------------------------
# 9. Check the service
# ---------------------------------------------------------------------------
log "Waiting for SavaPage to start"
for _ in $(seq 1 60); do
  if (exec 3<>/dev/tcp/127.0.0.1/8631) 2>/dev/null; then started=1; break; fi
  sleep 2
done
if [[ "${started:-0}" == "1" ]]; then
  echo "SavaPage is listening on port 8631."
else
  warn "SavaPage did not answer on port 8631 yet. Check: systemctl status savapage"
fi

HOST_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "src") {print $(i + 1); exit}}')
HOST_IP=${HOST_IP:-SERVER-IP}
HOSTNAME_LOCAL="$(hostname -s).local"
cat <<EOF

========================================================================
 SavaPage $SAVAPAGE_VERSION is installed

 Admin web app : https://$HOST_IP:8632/admin
                 https://$HOSTNAME_LOCAL:8632/admin
 Login         : admin / admin   <-- change this right away
                 (Options > Advanced > Reset internal admin password)

 User web app  : https://$HOST_IP:8632/user
 AirPrint/IPP  : ipps://$HOST_IP:8632/printers/airprint

 HTTP redirect : $( [[ "$redirect_value" == true ]] && echo "on (http://$HOST_IP:8631 goes to HTTPS)" || echo "off" )
 CUPS web page : $( [[ "$CUPS_WEB" == 1 ]] && echo "on (http://$HOST_IP:631, local network only)" || echo "off (local only; CUPS_WEB=1 opens it)" )

 Your browser will warn about the self-signed certificate. That is
 expected; accept it to continue.

 The IP address above is today's. After moving the server, use the
 new IP or $HOSTNAME_LOCAL instead.

 Next steps    : see INSTALL.md.
========================================================================
EOF
