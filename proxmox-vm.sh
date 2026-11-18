#!/usr/bin/env bash
#
# proxmox-vm.sh - Create a new Proxmox VM with SavaPage installed, in one command.
#
# Tested on Proxmox VE 9.2 with the Ubuntu 26.04 LTS (default) and Debian 13 cloud images.
#
# Run this on the Proxmox HOST (Node > Shell in the web UI), as root:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/syoong81/savapage-easy-install/main/proxmox-vm.sh)"
#
# It downloads an official Ubuntu LTS (or Debian) cloud image, verifies its checksum,
# creates a VM with cloud-init, and installs SavaPage on the VM's first boot with
# install-savapage.sh from this repository. It also adds a status screen to the VM's
# console (savapage-status.sh): what's running, the IP address and the web addresses.
#
# With no settings, it shows a menu (like community-scripts): use the defaults, or
# choose the OS, size, network, login and install options.
#
# Optional settings (put them in front of 'bash'; any of them skips the menu):
#   var_menu=1              Show the menu anyway (var_menu=0: never show it)
#   var_os=ubuntu           ubuntu (default, longest support) or debian
#   var_version=26.04       Ubuntu: 26.04 (default). Debian: 13 (default) or 12
#   var_vmid=120            VM ID (default: next free ID)
#   var_hostname=savapage   VM name and hostname
#   var_cpu=2               CPU cores
#   var_ram=2048            Memory in MB
#   var_disk=16             Disk size in GB
#   var_storage=local-lvm   Storage for the VM disk (default: local-lvm, or the first that fits)
#   var_bridge=vmbr0        Network bridge
#   var_user=admin          Login user for the VM (default: admin on Debian, ubuntu on Ubuntu)
#   var_password=...        Password for that user (default: a random one, shown at the end)
#   var_sshkey=/root/.ssh/id_ed25519.pub   Public key to allow for SSH logins (optional)
#
# Install options passed on to install-savapage.sh:
#   HTTPS_REDIRECT=0  CUPS_WEB=1  SKIP_FIREWALL=1
#   AUTO_UPDATES=0    UPDATE_TIME=03:00   (default: all updates every night at 03:00)
#
# Example:
#   var_ram=4096 CUPS_WEB=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/syoong81/savapage-easy-install/main/proxmox-vm.sh)"
#
set -euo pipefail

REPO_URL="https://github.com/syoong81/savapage-easy-install.git"

# Show the menu only when no settings were given on the command line.
SHOW_MENU=1
for v in var_os var_version var_vmid var_hostname var_cpu var_ram var_disk var_storage \
         var_bridge var_user var_password var_sshkey HTTPS_REDIRECT CUPS_WEB SKIP_FIREWALL \
         AUTO_UPDATES UPDATE_TIME; do
  [[ -n "${!v:-}" ]] && SHOW_MENU=0
done
case "${var_menu:-}" in 0) SHOW_MENU=0 ;; 1) SHOW_MENU=1 ;; esac

var_os="${var_os:-ubuntu}"
var_hostname="${var_hostname:-savapage}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-16}"
var_bridge="${var_bridge:-vmbr0}"
HTTPS_REDIRECT="${HTTPS_REDIRECT:-1}"
CUPS_WEB="${CUPS_WEB:-0}"
SKIP_FIREWALL="${SKIP_FIREWALL:-0}"
AUTO_UPDATES="${AUTO_UPDATES:-1}"
UPDATE_TIME="${UPDATE_TIME:-03:00}"

WAIT_MINUTES=30

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m[x] %s\033[0m\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
[[ $EUID -eq 0 ]] || die "Run this on the Proxmox host as root."
for cmd in qm pvesh pvesm; do
  command -v "$cmd" >/dev/null || die "'$cmd' not found. Run this on the Proxmox host (Node > Shell), not inside a VM."
done
command -v curl >/dev/null || die "curl is required."

# ---------------------------------------------------------------------------
# Settings menu (whiptail, like community-scripts)
# ---------------------------------------------------------------------------
wt() { whiptail --backtitle "savapage-easy-install" --title "SavaPage VM" "$@" 3>&1 1>&2 2>&3; }
cancelled() { clear; echo "Cancelled. Nothing was changed."; exit 0; }
pick_from() {  # pick_from "question" item... : a menu of items, or the only item
  local question=$1; shift
  if (( $# == 1 )); then echo "$1"; return 0; fi
  local items=() i
  for i in "$@"; do items+=("$i" ""); done
  wt --menu "$question" 16 60 6 "${items[@]}"
}

settings_menu() {
  local choice os default_user
  choice=$(wt --menu "Create a new Proxmox VM with SavaPage installed.\n\nDefault settings: Ubuntu 26.04 LTS, 2 cores, 2 GB RAM, 16 GB disk, DHCP on vmbr0, HTTPS redirect on, firewall on, all updates installed every night at 03:00, login user 'ubuntu' with a random password." 18 72 2 \
    default  "Use the default settings" \
    advanced "Choose the settings") || cancelled
  [[ "$choice" == advanced ]] || return 0

  os=$(wt --radiolist "Operating system (Space to select, Enter to continue)" 12 66 3 \
    ubuntu-26.04 "Ubuntu 26.04 LTS (longest support)" ON \
    debian-13    "Debian 13 (trixie, lighter)" OFF \
    debian-12    "Debian 12 (bookworm)" OFF) || cancelled
  var_os=${os%%-*}; var_version=${os#*-}

  var_vmid=$(wt --inputbox "VM ID" 8 60 "$(pvesh get /cluster/nextid)") || cancelled
  var_hostname=$(wt --inputbox "VM name (also its hostname)" 8 60 "$var_hostname") || cancelled
  var_cpu=$(wt --inputbox "CPU cores" 8 60 "$var_cpu") || cancelled
  var_ram=$(wt --inputbox "Memory in MB (SavaPage recommends at least 2048)" 8 60 "$var_ram") || cancelled
  var_disk=$(wt --inputbox "Disk size in GB" 8 60 "$var_disk") || cancelled
  # shellcheck disable=SC2046
  var_storage=$(pick_from "Storage for the VM disk" \
    $(pvesm status -content images 2>/dev/null | awk 'NR > 1 && $3 == "active" {print $1}')) || cancelled
  # shellcheck disable=SC2046
  var_bridge=$(pick_from "Network bridge" \
    $(ip -o link show type bridge | awk -F': ' '{print $2}' | sed 's/@.*//' | grep -v '^fwbr')) || cancelled

  default_user=admin; [[ "$var_os" == ubuntu ]] && default_user=ubuntu
  var_user=$(wt --inputbox "Login user for the VM" 8 60 "$default_user") || cancelled
  var_password=$(wt --passwordbox "Password for '$var_user'.\n\nLeave it empty for a random one, shown at the end." 11 60) || cancelled

  if wt --yesno "Send browsers on http://...:8631 to the secure HTTPS address?\n\n(Recommended.)" 10 64; then HTTPS_REDIRECT=1; else HTTPS_REDIRECT=0; fi
  if wt --defaultno --yesno "Open the CUPS web page (port 631) to your local network?\n\n(Off by default. Handy for adding printers.)" 10 64; then CUPS_WEB=1; else CUPS_WEB=0; fi
  if wt --yesno "Turn on the firewall (ufw) inside the VM?\n\n(Recommended.)" 10 64; then SKIP_FIREWALL=0; else SKIP_FIREWALL=1; fi
  if wt --yesno "Install all updates automatically every night?\n\nThe VM reboots afterwards only when an update needs it. (Recommended for a set-and-forget server.)" 11 66; then
    AUTO_UPDATES=1
    UPDATE_TIME=$(wt --inputbox "Time for the nightly updates (24-hour clock, e.g. 03:00)" 8 60 "$UPDATE_TIME") || cancelled
  else
    AUTO_UPDATES=0
  fi

  wt --yesno "Create the VM with these settings?\n
  OS        : $var_os $var_version
  VM ID     : $var_vmid
  Name      : $var_hostname
  CPU / RAM : $var_cpu cores / $var_ram MB
  Disk      : $var_disk GB on $var_storage
  Network   : $var_bridge (DHCP)
  Login     : $var_user ($([[ -n "$var_password" ]] && echo "your password" || echo "random password"))
  HTTPS redirect: $( ((HTTPS_REDIRECT)) && echo on || echo off ), CUPS web page: $( ((CUPS_WEB)) && echo on || echo off ), firewall: $( ((SKIP_FIREWALL)) && echo off || echo on )
  Updates   : $( ((AUTO_UPDATES)) && echo "every night at $UPDATE_TIME" || echo off )" 21 66 || cancelled
}

if (( SHOW_MENU )) && [[ -t 0 && -t 1 ]] && command -v whiptail >/dev/null; then
  settings_menu
fi

case "$var_os" in
  debian)
    var_version="${var_version:-13}"
    case "$var_version" in
      13) codename=trixie ;;
      12) codename=bookworm ;;
      *)  die "var_version=$var_version is not supported for Debian. Use 13 or 12." ;;
    esac
    IMAGE_FILE="debian-${var_version}-genericcloud-amd64.qcow2"
    IMAGE_BASE="https://cloud.debian.org/images/cloud/${codename}/latest"
    SUMS_FILE="SHA512SUMS"; SUM_CMD=sha512sum
    ;;
  ubuntu)
    var_version="${var_version:-26.04}"
    case "$var_version" in
      26.04) codename=resolute ;;
      *)     die "var_version=$var_version is not supported for Ubuntu. Use 26.04." ;;
    esac
    IMAGE_FILE="${codename}-server-cloudimg-amd64.img"
    IMAGE_BASE="https://cloud-images.ubuntu.com/${codename}/current"
    SUMS_FILE="SHA256SUMS"; SUM_CMD=sha256sum
    ;;
  *) die "var_os=$var_os is not supported. Use debian or ubuntu." ;;
esac

# Login user. Ubuntu's cloud image already has a group called 'admin', so cloud-init
# can't create a user with that name there. Use Ubuntu's usual 'ubuntu' instead.
if [[ "$var_os" == ubuntu ]]; then
  var_user="${var_user:-ubuntu}"
  [[ "$var_user" != admin ]] || die "var_user can't be 'admin' on Ubuntu: Ubuntu already has an 'admin' group. Leave var_user out to use 'ubuntu', or pick another name."
else
  var_user="${var_user:-admin}"
fi

[[ "$UPDATE_TIME" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]] || die "UPDATE_TIME='$UPDATE_TIME' is not a time like 03:00 (24-hour clock)."
[[ "$var_user" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || die "var_user='$var_user' is not a valid Linux user name."
[[ "$var_user" != savapage && "$var_user" != root ]] || die "var_user can't be '$var_user'. SavaPage needs 'savapage' for itself. Pick another name."
[[ "$var_hostname" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$ ]] || die "var_hostname='$var_hostname' is not a valid host name."
for n in var_cpu var_ram var_disk; do
  [[ "${!n}" =~ ^[0-9]+$ ]] || die "$n must be a number (got '${!n}')."
done
(( var_ram >= 1024 )) || die "var_ram must be at least 1024 MB. SavaPage recommends 2048."
(( var_ram >= 2048 )) || warn "SavaPage recommends at least 2048 MB RAM (var_ram=$var_ram)."
(( var_disk >= 8 )) || die "var_disk must be at least 8 GB."

ip link show "$var_bridge" >/dev/null 2>&1 || die "Network bridge '$var_bridge' not found. Set var_bridge=..."

if [[ -n "${var_sshkey:-}" ]]; then
  [[ -r "$var_sshkey" ]] || die "var_sshkey file '$var_sshkey' not found."
fi

# VM ID
if [[ -z "${var_vmid:-}" ]]; then
  var_vmid=$(pvesh get /cluster/nextid)
fi
[[ "$var_vmid" =~ ^[0-9]+$ ]] || die "var_vmid must be a number."
if qm status "$var_vmid" >/dev/null 2>&1 || pct status "$var_vmid" >/dev/null 2>&1; then
  die "ID $var_vmid is already in use. Set var_vmid=... to a free ID."
fi

# Storage for the VM disk
active_storages() { pvesm status -content "$1" 2>/dev/null | awk 'NR > 1 && $3 == "active" {print $1}'; }
if [[ -z "${var_storage:-}" ]]; then
  if active_storages images | grep -qx local-lvm; then
    var_storage=local-lvm
  else
    var_storage=$(active_storages images | head -n 1)
  fi
fi
[[ -n "$var_storage" ]] || die "No storage for VM disks found. Set var_storage=..."
active_storages images | grep -qx "$var_storage" || die "Storage '$var_storage' doesn't hold VM disks (or isn't active)."

# Storage for the cloud-init snippet. Use one that allows snippets; otherwise enable
# snippets on the default 'local' storage.
SNIP_STORAGE=$(active_storages snippets | head -n 1 || true)
if [[ -z "$SNIP_STORAGE" ]]; then
  local_content=$(pvesh get /storage/local --output-format json 2>/dev/null | sed -n 's/.*"content":"\([^"]*\)".*/\1/p')
  [[ -n "$local_content" ]] || die "No storage allows 'snippets'. Enable it: Datacenter > Storage > local > Edit > Content > Snippets."
  log "Allowing 'Snippets' on the 'local' storage (needed for the cloud-init setup)"
  pvesm set local --content "${local_content},snippets"
  SNIP_STORAGE=local
fi

if [[ -z "${var_password:-}" ]]; then
  var_password=$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-16)
  PASSWORD_GENERATED=1
else
  PASSWORD_GENERATED=0
fi

cat <<EOF

 Creating a SavaPage VM:
   VM ID     : $var_vmid
   Name      : $var_hostname
   OS        : $var_os $var_version (cloud image)
   CPU / RAM : $var_cpu cores / $var_ram MB
   Disk      : $var_disk GB on $var_storage
   Network   : $var_bridge (DHCP)
   Login     : $var_user
   Options   : HTTPS_REDIRECT=$HTTPS_REDIRECT CUPS_WEB=$CUPS_WEB SKIP_FIREWALL=$SKIP_FIREWALL
   Updates   : $( [[ "$AUTO_UPDATES" == 1 ]] && echo "all updates every night at $UPDATE_TIME" || echo off )
EOF

# ---------------------------------------------------------------------------
# 1. Download and verify the cloud image
# ---------------------------------------------------------------------------
WORK_DIR=$(mktemp -d /var/tmp/savapage-vm.XXXXXX)
trap 'rm -rf "$WORK_DIR"' EXIT

log "Downloading $IMAGE_FILE"
curl -fsSL -o "$WORK_DIR/$SUMS_FILE" "$IMAGE_BASE/$SUMS_FILE" || die "Could not download $IMAGE_BASE/$SUMS_FILE"
EXPECTED=$(awk -v f="$IMAGE_FILE" '{name = $2; sub(/^\*/, "", name)} name == f {print $1; exit}' "$WORK_DIR/$SUMS_FILE")
[[ -n "$EXPECTED" ]] || die "No checksum listed for $IMAGE_FILE."
curl -fL --progress-bar -o "$WORK_DIR/$IMAGE_FILE" "$IMAGE_BASE/$IMAGE_FILE" || die "Could not download $IMAGE_BASE/$IMAGE_FILE"
echo "$EXPECTED  $WORK_DIR/$IMAGE_FILE" | $SUM_CMD -c --status || die "Checksum mismatch for $IMAGE_FILE. Download deleted."
echo "Verified $IMAGE_FILE ($SUM_CMD)."

# ---------------------------------------------------------------------------
# 2. First-boot setup (cloud-init vendor data)
# ---------------------------------------------------------------------------
SNIPPET="savapage-${var_vmid}.yaml"
SNIPPET_PATH=$(pvesm path "$SNIP_STORAGE:snippets/$SNIPPET")
mkdir -p "$(dirname "$SNIPPET_PATH")"

HOME_DIR="/home/$var_user"
cat > "$SNIPPET_PATH" <<EOF
#cloud-config
# SavaPage first-boot setup, created by proxmox-vm.sh for VM $var_vmid.
# Proxmox needs this file to start the VM, so keep it.
ssh_pwauth: true
package_update: true
packages:
  - qemu-guest-agent
  - git
  - curl
write_files:
  - path: /usr/local/sbin/savapage-firstboot
    permissions: '0755'
    content: |
      #!/bin/bash
      # Clone savapage-easy-install and run the installer. Output: /var/log/savapage-install.log
      exec > /var/log/savapage-install.log 2>&1
      set -x
      rm -rf $HOME_DIR/savapage-easy-install
      git clone $REPO_URL $HOME_DIR/savapage-easy-install || { echo 90 > /var/log/savapage-install.exit; exit 1; }
      chown -R $var_user: $HOME_DIR/savapage-easy-install
      HTTPS_REDIRECT=$HTTPS_REDIRECT CUPS_WEB=$CUPS_WEB SKIP_FIREWALL=$SKIP_FIREWALL AUTO_UPDATES=$AUTO_UPDATES UPDATE_TIME=$UPDATE_TIME bash $HOME_DIR/savapage-easy-install/install-savapage.sh
      rc=\$?
      if [ "\$rc" -eq 0 ] && [ "$CUPS_WEB" = 1 ]; then usermod -aG lpadmin $var_user; fi
      # Status screen on the console: what's running, the IP and the web addresses.
      if [ "\$rc" -eq 0 ]; then bash $HOME_DIR/savapage-easy-install/savapage-status.sh --install; fi
      echo "\$rc" > /var/log/savapage-install.exit
runcmd:
  - [systemctl, start, qemu-guest-agent]
  - [/usr/local/sbin/savapage-firstboot]
EOF

# ---------------------------------------------------------------------------
# 3. Create the VM
# ---------------------------------------------------------------------------
# A normal screen (VGA) is the main console, like Home Assistant OS: it keeps showing
# the status screen when you come back to it. The serial port stays as a second
# console with copy and paste (Console > xterm.js).
log "Creating VM $var_vmid"
qm create "$var_vmid" --name "$var_hostname" --ostype l26 \
  --cores "$var_cpu" --memory "$var_ram" \
  --scsihw virtio-scsi-single --net0 "virtio,bridge=$var_bridge" \
  --agent enabled=1 --vga std --serial0 socket --onboot 1 \
  --description "SavaPage print server, created by savapage-easy-install (proxmox-vm.sh)."

log "Importing the disk to $var_storage"
qm set "$var_vmid" --scsi0 "$var_storage:0,import-from=$WORK_DIR/$IMAGE_FILE,discard=on,ssd=1" >/dev/null
qm resize "$var_vmid" scsi0 "${var_disk}G" >/dev/null
qm set "$var_vmid" --ide2 "$var_storage:cloudinit" --boot order=scsi0 >/dev/null

qm set "$var_vmid" --ciuser "$var_user" --cipassword "$var_password" --ipconfig0 ip=dhcp \
  --cicustom "vendor=$SNIP_STORAGE:snippets/$SNIPPET" >/dev/null
if [[ -n "${var_sshkey:-}" ]]; then
  qm set "$var_vmid" --sshkeys "$var_sshkey" >/dev/null
fi

log "Starting VM $var_vmid"
qm start "$var_vmid"

# ---------------------------------------------------------------------------
# 4. Wait for the first-boot install to finish
# ---------------------------------------------------------------------------
if (( PASSWORD_GENERATED )); then
  cat <<EOF

 VM login for $var_user: $var_password
 Save this password now. It is shown again at the end.
EOF
fi

log "Installing SavaPage inside the VM (about 5-15 minutes)"
echo "Watch it live: click VM $var_vmid > Console in the web UI."

guest_out() {  # print a guest command's output (needs the guest agent)
  qm guest exec "$var_vmid" --timeout 30 -- "$@" 2>/dev/null \
    | sed -n 's/.*"out-data" *: *"\(.*\)".*/\1/p' | sed 's/\\n/\n/g; s/\\t/\t/g; s/\\"/"/g'
}

deadline=$(( $(date +%s) + WAIT_MINUTES * 60 ))
rc=""
while (( $(date +%s) < deadline )); do
  if qm guest cmd "$var_vmid" ping >/dev/null 2>&1; then
    rc=$(guest_out cat /var/log/savapage-install.exit | tr -dc '0-9' || true)
    [[ -n "$rc" ]] && break
  fi
  printf '.'
  sleep 15
done
echo

if [[ -z "$rc" ]]; then
  die "The install didn't finish within $WAIT_MINUTES minutes. Check VM $var_vmid > Console, and /var/log/savapage-install.log inside the VM."
fi
if [[ "$rc" != 0 ]]; then
  warn "The SavaPage install inside the VM failed (exit code $rc). Last lines of /var/log/savapage-install.log:"
  guest_out tail -n 25 /var/log/savapage-install.log >&2 || true
  die "Fix the problem, then run inside the VM: sudo bash ~/savapage-easy-install/install-savapage.sh"
fi

VM_IP=$(qm guest cmd "$var_vmid" network-get-interfaces 2>/dev/null \
  | grep -oE '"ip-address" *: *"([0-9]{1,3}\.){3}[0-9]{1,3}"' | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' \
  | grep -v '^127\.' | head -n 1 || true)
VM_IP=${VM_IP:-VM-IP}

cat <<EOF

========================================================================
 SavaPage is installed in VM $var_vmid ($var_hostname)

 Admin web app : http://$VM_IP:8631/admin   (goes to HTTPS)
                 https://$VM_IP:8632/admin
 SavaPage login: admin / admin   <-- change this right away
                 (Options > Advanced > Reset internal admin password)

 VM login      : $var_user
EOF
if (( PASSWORD_GENERATED )); then
  echo " VM password   : $var_password   <-- save this now"
else
  echo " VM password   : (the one you set with var_password)"
fi
cat <<EOF
 SSH           : ssh $var_user@$VM_IP
 Console       : VM $var_vmid > Console in the Proxmox web UI
                 (shows the SavaPage status; run 'savapage-status' any time)
 Lost password : on the Proxmox host, run: qm guest passwd $var_vmid $var_user

 Scripts in the VM: ~/savapage-easy-install/ (for re-runs and uninstall)
 Next steps    : see INSTALL.md
========================================================================
EOF
