#!/usr/bin/env bash
#
# proxmox-lxc.sh - Create a new Proxmox LXC container with SavaPage installed, in one command.
#
# Run this on the Proxmox HOST (Node > Shell in the web UI), as root:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/syoong81/savapage-easy-install/main/proxmox-lxc.sh)"
#
# It downloads the official Debian (or Ubuntu) container template with pveam, creates an
# unprivileged container with nesting turned on, installs SavaPage inside it with
# install-savapage.sh from this repository, and adds the console status screen
# (savapage-status.sh).
#
# Console login, like the community-scripts containers:
#   - No var_password (default): the Proxmox console opens a root shell with the
#     SavaPage status screen, every time ('shell' console mode). The root password
#     is empty, so SSH needs a key (var_sshkey).
#   - var_password=...: the console asks for that password.
#
# Optional settings (put them in front of 'bash'):
#   var_os=debian           debian (default) or ubuntu
#   var_version=13          Debian: 13 (default) or 12. Ubuntu: 26.04 (default)
#   var_ctid=120            Container ID (default: next free ID)
#   var_hostname=savapage   Container name and hostname
#   var_cpu=2               CPU cores
#   var_ram=2048            Memory in MB
#   var_swap=512            Swap in MB
#   var_disk=8              Disk size in GB
#   var_storage=local-lvm   Storage for the container (default: local-lvm, or the first that fits)
#   var_bridge=vmbr0        Network bridge
#   var_password=...        Root password (default: none, with automatic console login)
#   var_sshkey=/root/.ssh/id_ed25519.pub   Public key to allow for SSH logins as root (optional)
#
# Install options passed on to install-savapage.sh:
#   HTTPS_REDIRECT=0  CUPS_WEB=1  SKIP_FIREWALL=1
#
# Example:
#   var_ram=4096 CUPS_WEB=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/syoong81/savapage-easy-install/main/proxmox-lxc.sh)"
#
set -euo pipefail

REPO_URL="https://github.com/syoong81/savapage-easy-install.git"
REPO_DIR="/root/savapage-easy-install"

var_os="${var_os:-debian}"
var_hostname="${var_hostname:-savapage}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_swap="${var_swap:-512}"
var_disk="${var_disk:-8}"
var_bridge="${var_bridge:-vmbr0}"
var_password="${var_password:-}"
HTTPS_REDIRECT="${HTTPS_REDIRECT:-1}"
CUPS_WEB="${CUPS_WEB:-0}"
SKIP_FIREWALL="${SKIP_FIREWALL:-0}"

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m[x] %s\033[0m\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
[[ $EUID -eq 0 ]] || die "Run this on the Proxmox host as root."
for cmd in pct pveam pvesh pvesm; do
  command -v "$cmd" >/dev/null || die "'$cmd' not found. Run this on the Proxmox host (Node > Shell), not inside a container."
done

case "$var_os" in
  debian)
    var_version="${var_version:-13}"
    [[ "$var_version" == 13 || "$var_version" == 12 ]] || die "var_version=$var_version is not supported for Debian. Use 13 or 12."
    ;;
  ubuntu)
    var_version="${var_version:-26.04}"
    [[ "$var_version" == 26.04 ]] || die "var_version=$var_version is not supported for Ubuntu. Use 26.04."
    ;;
  *) die "var_os=$var_os is not supported. Use debian or ubuntu." ;;
esac
TEMPLATE_PREFIX="${var_os}-${var_version}-standard"

[[ "$var_hostname" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$ ]] || die "var_hostname='$var_hostname' is not a valid host name."
for n in var_cpu var_ram var_swap var_disk; do
  [[ "${!n}" =~ ^[0-9]+$ ]] || die "$n must be a number (got '${!n}')."
done
(( var_ram >= 1024 )) || die "var_ram must be at least 1024 MB. SavaPage recommends 2048."
(( var_ram >= 2048 )) || warn "SavaPage recommends at least 2048 MB RAM (var_ram=$var_ram)."
(( var_disk >= 4 )) || die "var_disk must be at least 4 GB."

ip link show "$var_bridge" >/dev/null 2>&1 || die "Network bridge '$var_bridge' not found. Set var_bridge=..."

if [[ -n "${var_sshkey:-}" ]]; then
  [[ -r "$var_sshkey" ]] || die "var_sshkey file '$var_sshkey' not found."
fi
if [[ -n "$var_password" ]] && (( ${#var_password} < 5 )); then
  die "var_password must be at least 5 characters (Proxmox's minimum)."
fi

# Container ID
if [[ -z "${var_ctid:-}" ]]; then
  var_ctid=$(pvesh get /cluster/nextid)
fi
[[ "$var_ctid" =~ ^[0-9]+$ ]] || die "var_ctid must be a number."
if pct status "$var_ctid" >/dev/null 2>&1 || qm status "$var_ctid" >/dev/null 2>&1; then
  die "ID $var_ctid is already in use. Set var_ctid=... to a free ID."
fi

# Storages: one for the container's disk, one for templates.
active_storages() { pvesm status -content "$1" 2>/dev/null | awk 'NR > 1 && $3 == "active" {print $1}'; }
if [[ -z "${var_storage:-}" ]]; then
  if active_storages rootdir | grep -qx local-lvm; then
    var_storage=local-lvm
  else
    var_storage=$(active_storages rootdir | head -n 1)
  fi
fi
[[ -n "$var_storage" ]] || die "No storage for containers found. Set var_storage=..."
active_storages rootdir | grep -qx "$var_storage" || die "Storage '$var_storage' doesn't hold containers (or isn't active)."

if active_storages vztmpl | grep -qx local; then
  TEMPLATE_STORAGE=local
else
  TEMPLATE_STORAGE=$(active_storages vztmpl | head -n 1)
fi
[[ -n "$TEMPLATE_STORAGE" ]] || die "No storage holds container templates. Enable 'Container template' on a storage (Datacenter > Storage)."

if [[ -n "$var_password" ]]; then LOGIN_TEXT="root, with your var_password"; else LOGIN_TEXT="root, automatic on the console"; fi
cat <<EOF

 Creating a SavaPage container:
   Container : $var_ctid
   Name      : $var_hostname
   OS        : $var_os $var_version (Proxmox template), unprivileged, nesting on
   CPU / RAM : $var_cpu cores / $var_ram MB (+ $var_swap MB swap)
   Disk      : $var_disk GB on $var_storage
   Network   : $var_bridge (DHCP)
   Login     : $LOGIN_TEXT
   Options   : HTTPS_REDIRECT=$HTTPS_REDIRECT CUPS_WEB=$CUPS_WEB SKIP_FIREWALL=$SKIP_FIREWALL
EOF

# ---------------------------------------------------------------------------
# 1. Container template (pveam checks the template's checksum)
# ---------------------------------------------------------------------------
log "Finding the latest $TEMPLATE_PREFIX template"
pveam update >/dev/null || warn "Could not refresh the template list. Using the one Proxmox already has."
TEMPLATE=$(pveam available --section system | awk '{print $2}' \
  | grep -E "^${TEMPLATE_PREFIX}_.*_amd64\.tar\.(zst|xz|gz)$" | sort -V | tail -n 1 || true)
[[ -n "$TEMPLATE" ]] || die "No $TEMPLATE_PREFIX template is available from Proxmox."

if pveam list "$TEMPLATE_STORAGE" | awk '{print $1}' | grep -qx "$TEMPLATE_STORAGE:vztmpl/$TEMPLATE"; then
  echo "Using $TEMPLATE (already downloaded)."
else
  log "Downloading $TEMPLATE"
  pveam download "$TEMPLATE_STORAGE" "$TEMPLATE" || die "Could not download $TEMPLATE."
fi

# ---------------------------------------------------------------------------
# 2. Create and start the container
# ---------------------------------------------------------------------------
log "Creating container $var_ctid"
create_args=(
  --hostname "$var_hostname" --cores "$var_cpu" --memory "$var_ram" --swap "$var_swap"
  --rootfs "$var_storage:$var_disk"
  --net0 "name=eth0,bridge=$var_bridge,ip=dhcp"
  --unprivileged 1 --features nesting=1 --onboot 1
  --description "SavaPage print server, created by savapage-easy-install (proxmox-lxc.sh)."
)
if [[ -n "$var_password" ]]; then
  create_args+=(--password "$var_password")
else
  # 'shell' console mode from the start: Proxmox keeps the first console session
  # running (dtach), so a console opened during the install would otherwise stay a
  # login console.
  create_args+=(--cmode shell)
fi
[[ -n "${var_sshkey:-}" ]] && create_args+=(--ssh-public-keys "$var_sshkey")
pct create "$var_ctid" "$TEMPLATE_STORAGE:vztmpl/$TEMPLATE" "${create_args[@]}" >/dev/null

log "Starting container $var_ctid"
pct start "$var_ctid"

# Run a command inside the container, with a locale that exists there.
in_ct() { pct exec "$var_ctid" -- env LANG=C.UTF-8 LC_ALL=C.UTF-8 DEBIAN_FRONTEND=noninteractive "$@"; }

printf 'Waiting for the network'
for _ in $(seq 1 60); do
  if in_ct sh -c 'ip -4 route show default | grep -q . && getent hosts github.com >/dev/null' 2>/dev/null; then
    net_ok=1; break
  fi
  printf '.'; sleep 2
done
echo
[[ "${net_ok:-0}" == 1 ]] || die "Container $var_ctid has no network after 2 minutes. Check the bridge '$var_bridge' and DHCP."

# ---------------------------------------------------------------------------
# 3. Install SavaPage inside the container
# ---------------------------------------------------------------------------
log "Installing SavaPage inside the container (about 5-15 minutes)"
in_ct bash -c "apt-get update -qq && apt-get install -y -qq git ca-certificates >/dev/null" \
  || die "Could not install git in the container."
in_ct bash -c "rm -rf $REPO_DIR && git clone -q $REPO_URL $REPO_DIR" \
  || die "Could not download the scripts from $REPO_URL."
in_ct env HTTPS_REDIRECT="$HTTPS_REDIRECT" CUPS_WEB="$CUPS_WEB" SKIP_FIREWALL="$SKIP_FIREWALL" \
  bash "$REPO_DIR/install-savapage.sh" \
  || die "The SavaPage install failed. Fix the problem, then in the container's console run: bash $REPO_DIR/install-savapage.sh"

log "Adding the console status screen"
in_ct bash "$REPO_DIR/savapage-status.sh" --install

# ---------------------------------------------------------------------------
# 4. Console login
# ---------------------------------------------------------------------------
# Without a password, log in as root automatically on the Proxmox console. Adapted
# from community-scripts' customize() (https://github.com/community-scripts/core,
# MIT): container-getty@ is the Proxmox web console (tty), console-getty is
# 'pct console'. --noissue: the status screen shows after login instead.
if [[ -z "$var_password" ]]; then
  log "Turning on automatic root login on the Proxmox console"
  in_ct bash -s <<'EOS'
set -e
passwd -d root >/dev/null
opts='--autologin root --noissue --keep-baud'
if [ -f /usr/lib/systemd/system/container-getty@.service ] || [ -f /lib/systemd/system/container-getty@.service ]; then
  mkdir -p /etc/systemd/system/container-getty@.service.d
  cat > /etc/systemd/system/container-getty@.service.d/autologin.conf <<EOF
# Added by savapage-easy-install (proxmox-lxc.sh): log in as root automatically.
[Service]
Environment=TERM=linux
ExecStart=
ExecStart=-/sbin/agetty $opts - 115200,38400,9600 linux
EOF
fi
if [ -f /usr/lib/systemd/system/console-getty.service ] || [ -f /lib/systemd/system/console-getty.service ]; then
  # On systemd 258+, LXC's own drop-in makes agetty open the console itself. Keep that.
  port='-'; stdio=''
  if grep -qs '^StandardInput=null' /run/systemd/system/console-getty.service.d/override.conf; then
    port='console'; stdio='StandardInput=null
StandardOutput=null'
  fi
  mkdir -p /etc/systemd/system/console-getty.service.d
  cat > /etc/systemd/system/console-getty.service.d/autologin.conf <<EOF
# Added by savapage-easy-install (proxmox-lxc.sh): log in as root automatically.
[Service]
Environment=TERM=linux
ExecStart=
ExecStart=-/sbin/agetty $opts 115200,38400,9600 $port linux
$stdio
EOF
fi
systemctl daemon-reload
systemctl restart 'container-getty@*.service' 2>/dev/null || true
systemctl try-restart console-getty.service 2>/dev/null || true

# The Proxmox web console uses 'shell' mode (set at creation): when it opens, it
# starts a fresh root shell. Show the status screen there, so the console always
# shows it, even after a refresh or 'clear'. Replaces an older copy of this block.
sed -i '/^# >>> savapage-console/,/^# <<< savapage-console/d' /root/.bashrc
cat >> /root/.bashrc <<'EOF'
# >>> savapage-console (proxmox-lxc.sh): show the SavaPage status when the Proxmox console opens
if [[ $- == *i* ]] && ! shopt -q login_shell && [ -z "${SSH_CONNECTION:-}${SAVAPAGE_STATUS_SHOWN:-}" ] && [ -x /usr/local/bin/savapage-status ]; then
  export SAVAPAGE_STATUS_SHOWN=1
  # The console starts with an empty environment.
  export HOME="${HOME:-/root}" USER="${USER:-root}" LOGNAME="${LOGNAME:-root}"
  export LANG="${LANG:-C.UTF-8}" TERM="${TERM:-linux}"
  cd "$HOME"
  printf '\033[3J\033[H\033[2J'
  /usr/local/bin/savapage-status
  # In this console, 'clear' and Ctrl+L show the status screen again.
  clear() { command clear "$@"; /usr/local/bin/savapage-status; }
  bind -x '"\C-l": clear' 2>/dev/null
  # Proxmox keeps this shell running between visits (dtach) and reattaches it when
  # Console opens again, which resizes the terminal (WINCH). Redraw the status then.
  trap 'command clear; /usr/local/bin/savapage-status; printf "%s" "${PS1@P}"' WINCH
fi
# <<< savapage-console
EOF
EOS
fi

# ---------------------------------------------------------------------------
# 5. Summary
# ---------------------------------------------------------------------------
CT_IP=$(in_ct sh -c "ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i < NF; i++) if (\$i == \"src\") {print \$(i + 1); exit}}'" || true)
CT_IP=${CT_IP:-CT-IP}

cat <<EOF

========================================================================
 SavaPage is installed in container $var_ctid ($var_hostname)

 Admin web app : http://$CT_IP:8631/admin   (goes to HTTPS)
                 https://$CT_IP:8632/admin
 SavaPage login: admin / admin   <-- change this right away
                 (Options > Advanced > Reset internal admin password)

EOF
if [[ -z "$var_password" ]]; then
  cat <<EOF
 Console       : container $var_ctid > Console opens a root shell and shows
                 the SavaPage status, every time you open it. No password.
EOF
else
  cat <<EOF
 Console       : container $var_ctid > Console, log in as root with your var_password.
                 It shows the SavaPage status. Press Enter if it's blank.
EOF
fi
cat <<EOF
 Status        : run 'savapage-status' in the container
 Scripts       : $REPO_DIR (for re-runs and uninstall)
 Next steps    : see INSTALL.md
========================================================================
EOF

# Kernel messages ([UFW BLOCK] lines) can only be kept off the console from the host.
if (( $(sysctl -n kernel.printk 2>/dev/null | awk '{print $1}') > 3 )); then
  cat <<EOF

 Tip: if firewall messages ([UFW BLOCK] ...) ever fill the container's console,
 run this once on this Proxmox host:
   echo 'kernel.printk = 3 4 1 3' > /etc/sysctl.d/10-console.conf && sysctl -p /etc/sysctl.d/10-console.conf
EOF
fi
