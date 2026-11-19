# Install guide

## Quickest: a new Proxmox VM with one command

If you use Proxmox, this one command creates a new VM with SavaPage already installed. Run it in the **Proxmox host shell**: click your **node** in the web UI, then **Shell**.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/syoong81/savapage-easy-install/main/proxmox-vm.sh)"
```

**It opens a menu,** like the community-scripts: choose **Use the default settings**, or **Choose the settings** to pick the operating system (**Ubuntu 26.04 LTS**, the default, Debian 13 or Debian 12), the VM ID, name, CPU, memory, disk, storage, network bridge, login user and password, and the install options. It shows everything once more before it creates the VM. Esc cancels without changing anything.

**Using the menu:**

| Key | Does |
|---|---|
| **↑ / ↓** | Move between choices |
| **Space** | Select an option in a list with `( )` circles, such as the operating system |
| **Enter** | Accept the screen and go to the next one. A box with a value already filled in keeps that value. |
| **Tab** | Move between the text box and the **Ok / Cancel** (or **Yes / No**) buttons |
| **Esc** | Cancel. Nothing is created. |

To change a filled-in value, delete it with **Backspace** and type the new one. The password box shows nothing while you type, which is normal. Not sure which operating system to pick? See [Ubuntu or Debian?](#ubuntu-or-debian) below.

With the default settings, it:

1. **Downloads the official Ubuntu 26.04 LTS cloud image** and checks its SHA-256 checksum. Ubuntu LTS is the default because it's supported the longest; see [Ubuntu or Debian?](#ubuntu-or-debian).
2. **Creates the VM:** next free ID, 2 cores, 2 GB RAM, 16 GB disk, DHCP on `vmbr0`, starts with the host.
3. **Installs SavaPage on the VM's first boot** with this repo's installer.
4. **Adds a status screen to the VM's console**, like the Home Assistant OS console: whether SavaPage and CUPS are running, the firewall, the IP address, the version and the web addresses. It refreshes every minute, so it follows the server to a new network.
5. **Prints the VM's IP, the admin address and the VM login** when it's done, after about 3–15 minutes.

**Save the VM password.** If you left the password empty in the menu, or didn't set `var_password`, the script makes a random one and shows it twice: before the wait and at the end. If you lose it, see [Logging in to the VM](#logging-in-to-the-vm).

Then continue at [step 4: Log in and change the password](#4-log-in-and-change-the-password). Inside the VM, the scripts are in `~/savapage-easy-install/`, for re-runs and uninstalling.

### Logging in to the VM

For maintenance, log in to the VM as **`ubuntu`** (on a Debian VM: **`admin`**), or the user you chose in the menu or with `var_user`. Use **Console** or `ssh ubuntu@VM-IP`. That user can use `sudo` without typing a password again, so give it a strong password. On a Debian VM, use `admin` instead of `ubuntu` in the commands below.

There are three different logins. Don't mix them up:

| Login | User | Password |
|---|---|---|
| **The VM** (console, SSH) | `ubuntu` (Debian: `admin`) | The random one `proxmox-vm.sh` printed, or your `var_password` |
| **SavaPage's web admin** (`https://VM-IP:8632/admin`) | `admin` | `admin` until you change it (step 4). Separate from the VM's login. |
| `savapage` | — | **Can't log in.** It's SavaPage's own service account, with no password. Leave it that way. |

**Set or reset the VM password.** In the **Proxmox host shell** (node → **Shell**), replace `118` with your VM ID:

```bash
qm guest passwd 118 ubuntu
```

It asks for the new password twice. This works without knowing the old password, through the guest agent.

**Change it from inside the VM,** when you're logged in:

```bash
passwd
```

**Updates install themselves every night at 03:00** (see [Automatic updates](#automatic-updates)). To install them right now, logged in:

```bash
sudo apt update && sudo apt full-upgrade -y
```

<a id="ubuntu-or-debian"></a>**Ubuntu or Debian?** Both run SavaPage the same way and get automatic security updates. **Debian** is lighter (about 100 MB less RAM and 1 GB less disk) and very stable, with about 5 years of updates. **Ubuntu LTS** is a little heavier but supported longer: 5 years, or 10 with Ubuntu Pro (free for personal use). Choose Ubuntu if you want to leave the server alone for as long as possible.

**Settings without the menu.** Put them in front of `bash`. Any setting skips the menu (add `var_menu=1` to show it anyway). For example:

```bash
var_ram=4096 CUPS_WEB=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/syoong81/savapage-easy-install/main/proxmox-vm.sh)"
```

| Setting | Default | What it changes |
|---|---|---|
| `var_os` | `ubuntu` | `ubuntu` or `debian` |
| `var_version` | `26.04` (Debian: `13`) | Ubuntu `26.04`; Debian `13` or `12` |
| `var_vmid` | next free ID | VM ID |
| `var_hostname` | `savapage` | VM name and hostname |
| `var_cpu` / `var_ram` / `var_disk` | `2` / `2048` / `16` | Cores, RAM in MB, disk in GB |
| `var_storage` | `local-lvm`, or the first that fits | Storage for the VM disk |
| `var_bridge` | `vmbr0` | Network bridge |
| `var_user` | `ubuntu` (Debian: `admin`) | The VM login user (not `savapage`; not `admin` on Ubuntu, which already has an `admin` group) |
| `var_password` | random | The VM login password |
| `var_sshkey` | none | A public key file to allow for SSH |
| `HTTPS_REDIRECT`, `CUPS_WEB`, `SKIP_FIREWALL` | | Passed on to the installer. See [Install options](#install-options). |

**Good to know:**

- **Console** in the web UI shows the VM's screen, with the status screen and the login prompt, like the Home Assistant OS console. It doesn't support copy and paste. For that, use **Console ▾ → xterm.js**, the VM's serial console, and press **Enter** to show the login prompt.
- The **status screen** shows above the login prompt and again after you log in. While you're logged in on the console, the screen is your session, so the status screen doesn't come back on its own. **Type `exit` to log out and return to the status screen.** Show it any time with `savapage-status`. To remove it: `sudo bash ~/savapage-easy-install/savapage-status.sh --remove`. To add it to a machine you installed by hand: `sudo bash ~/savapage-easy-install/savapage-status.sh --install`.
- SSH logins with the VM password are allowed: `ssh ubuntu@VM-IP`.
- The VM's first-boot settings are saved as a Proxmox *snippet*, e.g. `/var/lib/vz/snippets/savapage-122.yaml`. Proxmox needs that file to start the VM, so keep it. It contains no passwords. If no storage allows snippets, the script turns them on for `local`.
- To remove the VM later: **VM → More → Remove**. Then delete its snippet file.

---

## Quickest: a new Proxmox LXC container with one command

This creates a new **LXC container** with SavaPage already installed. A container uses less memory than a VM. Run it in the **Proxmox host shell**:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/syoong81/savapage-easy-install/main/proxmox-lxc.sh)"
```

**It opens the same kind of menu** (same keys as above): **Use the default settings**, or **Choose the settings** (operating system, container ID, name, CPU, memory, swap, disk, storage, network bridge, root password and install options). Leave the root password empty for the passwordless console with the status screen.

With the default settings, it:

1. **Downloads the official Debian 13 container template** with Proxmox's own template tool (`pveam`), which checks the template's checksum.
2. **Creates the container:** next free ID, unprivileged, **nesting** turned on, 2 cores, 2 GB RAM, 8 GB disk, DHCP on `vmbr0`, starts with the host.
3. **Installs SavaPage** inside it with this repo's installer. You see the install as it runs.
4. **Adds the status screen.** If you didn't set a password, the Proxmox **Console** opens straight to a root shell showing the SavaPage status, every time you open it, like the Home Assistant OS console.
5. **Prints the container's IP and the admin address** when it's done.

Then continue at [step 4: Log in and change the password](#4-log-in-and-change-the-password). Inside the container, the scripts are in `/root/savapage-easy-install/`.

**Settings without the menu.** Put them in front of `bash`, e.g. `var_ram=4096 bash -c "$(curl …)"`. Any setting skips the menu:

| Setting | Default | What it changes |
|---|---|---|
| `var_os` | `debian` | `debian` or `ubuntu` |
| `var_version` | `13` | Debian `13` or `12`; Ubuntu `26.04` |
| `var_ctid` | next free ID | Container ID |
| `var_hostname` | `savapage` | Container name and hostname |
| `var_cpu` / `var_ram` / `var_swap` / `var_disk` | `2` / `2048` / `512` / `8` | Cores, RAM and swap in MB, disk in GB |
| `var_storage` | `local-lvm`, or the first that fits | Storage for the container |
| `var_bridge` | `vmbr0` | Network bridge |
| `var_password` | none | Root password. **Without one, the console opens without a password.** |
| `var_sshkey` | none | A public key file to allow for SSH as root |
| `HTTPS_REDIRECT`, `CUPS_WEB`, `SKIP_FIREWALL` | | Passed on to the installer. See [Install options](#install-options). |

### Logging in to the container

| Login | User | Password |
|---|---|---|
| **Proxmox console**, no `var_password` | `root` | None: it opens a root shell with the status screen |
| **Proxmox console**, with `var_password` | `root` | Your `var_password` |
| **SSH** | `root` | Only with a key (`var_sshkey`). Root password logins over SSH are off, Debian's default. |
| **SavaPage's web admin** | `admin` | `admin` until you change it (step 4) |
| `savapage` | — | **Can't log in.** It's SavaPage's own service account. |

**How the passwordless console works.** The container's console is set to Proxmox's **shell** mode (*Options → Console mode*). Each time you open or refresh **Console**, Proxmox starts a new root shell inside the container, and it shows the status screen first. That's why the status is always there, even after `clear`. Only people who can already log in to Proxmox can open that console. `pct console CTID` on the host logs root in automatically as well.

**To require a password on the console** later:

1. In the console, set a root password: `passwd`.
2. Turn off automatic login, in the console:

   ```bash
   rm /etc/systemd/system/container-getty@.service.d/autologin.conf /etc/systemd/system/console-getty.service.d/autologin.conf && systemctl daemon-reload
   ```

3. In the **Proxmox host shell**, switch the console back to a login prompt, then restart the container:

   ```bash
   pct set CTID --cmode tty
   ```

The status screen then shows after you log in. **Forgot the root password?** In the Proxmox host shell, run `pct enter CTID`, then `passwd`, then `exit`.

**Good to know:**

- Switching to **Summary** and back to **Console** reconnects you to the same shell, so you see what you left there. **Type `exit` to start a fresh console with the status screen.** `clear` (or Ctrl+L) also shows the status screen again.
- Show the status any time with `savapage-status`. With a password (`var_password`), the console is a normal login prompt. If it's blank when you come back to it, press **Enter**. The status screen shows after you log in.
- An unprivileged container can't keep kernel messages off its console. If `[UFW BLOCK]` lines ever fill it, run this once in the **Proxmox host shell**:

  ```bash
  echo 'kernel.printk = 3 4 1 3' > /etc/sysctl.d/10-console.conf && sysctl -p /etc/sysctl.d/10-console.conf
  ```

- To remove the container later: **Container → More → Remove**.

The rest of this guide is for installing **by hand**, on any VM, physical machine or LXC container.

---

## Install by hand

One guide for both ways to run SavaPage:

- **VM or physical machine:** a Proxmox VM, VirtualBox, Hyper-V, or an old PC/server.
- **Proxmox LXC container:** lighter than a VM. Use it when your printers are on the network. A printer that plugs in by **USB** is easier with a VM.

> Read the [Disclaimer](README.md#disclaimer) first. By running the scripts, you accept it.
>
> The setup steps follow the [SavaPage User Manual](https://manual.savapage.org/) by Rijk Ravestein ([CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)). For anything not covered here, see the manual.

### How commands are shown

Where the two differ, commands come in pairs:

- **VM / physical machine:** you're logged in as your own user, so commands start with `sudo`.
- **LXC container:** you're typing in the container's **Console** in the Proxmox web UI, logged in as `root`. **Leave out `sudo`.**

Type or paste each command and press **Enter**. When you type a password, **nothing appears on screen**. That's normal.

## Contents

1. [Prepare the machine](#1-prepare-the-machine)
2. [Get the scripts](#2-get-the-scripts)
3. [Run the installer](#3-run-the-installer)
4. [Log in and change the password](#4-log-in-and-change-the-password)
5. [Back up the encryption key](#5-back-up-the-encryption-key)
6. [Firewall](#6-firewall)
7. [Set up SavaPage](#7-set-up-savapage)
8. [Print to SavaPage from devices](#8-print-to-savapage-from-devices)

Reference: [One-command Proxmox VM](#quickest-a-new-proxmox-vm-with-one-command) · [Install options](#install-options) · [Automatic updates](#automatic-updates) · [CUPS web page](#cups-web-page) · [HTTPS redirect](#https-redirect) · [Updating the scripts](#updating-the-scripts) · [What the script changes](#what-the-script-changes) · [Moving the server](#moving-the-server-to-another-location) · [Everyday commands](#everyday-commands) · [Security](#security) · [Troubleshooting](#troubleshooting) · [Uninstall](#uninstall)

---

## 1. Prepare the machine

### VM or physical machine

| Item | Details |
|---|---|
| Hardware | 64-bit Intel/AMD (x86_64), **2+ CPU cores, 2+ GB RAM, 16 GB disk**. *Raspberry Pi / ARM is not supported.* |
| Operating system | **Debian 12, Debian 13 or Ubuntu 26.04 LTS**. A fresh install is best. |
| Your user account | Any user that can run `sudo`. **Don't name it `savapage`.** SavaPage needs that name for its own account, and the script stops if it's taken. |
| Network | Internet access during the install. |

**Open a terminal** on the machine. Use one of these:

- **Proxmox VM:** click the VM → **Console** and log in.
- **Physical machine:** log in at its screen. If it has a desktop, press **Ctrl + Alt + T**.
- **SSH from your Windows PC:** see [Alternative: SSH in and paste the script](#alternative-ssh-in-and-paste-the-script).

**For a USB printer on a Proxmox VM:** add it under **VM → Hardware → Add → USB Device**.

### Proxmox LXC container

**a. Download the template.** In the Proxmox web UI, click your storage (usually **`local`**). Go to **CT Templates → Templates**, search for **`debian-13-standard`**, and click **Download**. (`debian-12-standard` also works.)

**b. Create the container.** Click **Create CT** (top right) and fill in:

| Tab | Setting |
|---|---|
| General | **Hostname** `savapage`, set a **root password**, **Unprivileged container ✔** |
| Template | `debian-13-standard` |
| Disks | **8 GB** or more |
| CPU | **2** cores |
| Memory | **2048** MB, swap **512** MB |
| Network | Bridge **`vmbr0`**, IPv4 **DHCP**, **Firewall ✔** |

Click **Finish**, but **don't start it yet**. Select the container, then:

- **Options → Features → Nesting ✔**. This is **required**: Debian 13 needs it.
- **Options → Start at boot → Yes**.
- *(Recommended)* **Snapshots → Take Snapshot**, so you can roll back.

**c. Start it and open its console.** Click **Start**, then **Console**. Log in as **`root`** with the password you set.

> **Copy and paste:** use the **xterm.js** console. Click the arrow next to **Console** at the top and choose **xterm.js**. Paste with **Ctrl + Shift + V**. The default noVNC console can't paste.

---

## 2. Get the scripts

### Recommended: clone from GitHub

First install git.

**VM / physical machine:**

```bash
sudo apt-get update && sudo apt-get install -y git
```

**LXC container:**

```bash
apt-get update && apt-get install -y git
```

Then download the scripts. This is the same command for both:

```bash
git clone https://github.com/syoong81/savapage-easy-install.git ~/savapage-easy-install
```

The scripts are now in `~/savapage-easy-install/`. That's your home folder; in the container it's `/root/savapage-easy-install/`.

### Alternative: SSH in and paste the script

Use this if you'd rather work from your Windows PC, or if the server can't reach GitHub.

**1. Connect from your PC.** Open **PowerShell** from the Start menu.

**VM / physical machine.** Replace `youruser` and `SERVER-IP`. You can find the IP by running `hostname -I` on the machine.

```bash
ssh youruser@SERVER-IP
```

If SSH isn't installed on the VM, run `sudo apt-get install -y openssh-server` in its console first.

**LXC container.** The container doesn't accept root logins over SSH, so connect to the **Proxmox host** instead. Then step into the container. Replace `PROXMOX-IP` and `120` (the container ID):

```bash
ssh root@PROXMOX-IP
```

```bash
pct enter 120
```

You're now root inside the container. Every LXC command in this guide works here, exactly as in the console.

**2. Create the script file.** Open [install-savapage.sh on GitHub](https://github.com/syoong81/savapage-easy-install/blob/main/install-savapage.sh) and click **Copy raw file**. Then open the editor. This is the same command for both:

```bash
mkdir -p ~/savapage-easy-install && nano ~/savapage-easy-install/install-savapage.sh
```

**3. Paste and save.** Paste with a **right-click**. Then press **Ctrl + O** and **Enter** to save, and **Ctrl + X** to exit.

Do the same for [uninstall-savapage.sh](https://github.com/syoong81/savapage-easy-install/blob/main/uninstall-savapage.sh) if you want the uninstaller too.

Using these folder names means every command in this guide works either way.

---

## 3. Run the installer

**VM / physical machine:**

```bash
sudo bash ~/savapage-easy-install/install-savapage.sh
```

**LXC container:**

```bash
bash ~/savapage-easy-install/install-savapage.sh
```

- It takes **about 5–10 minutes**. The SavaPage download is about 150 MB. **Don't close the window.**
- When it's done, you'll see a box saying **"SavaPage 1.7.0-final is installed"** with the web addresses.
- A yellow `[!]` line is a warning; the install continues. For example, with under 2 GB RAM you'll get a memory warning.
- A red `[x]` line means the script stopped. See [Troubleshooting](#troubleshooting).

To change how it installs, see [Install options](#install-options). For example, `HTTPS_REDIRECT=0` keeps the HTTPS redirect off.

---

## 4. Log in and change the password

1. On any computer on the same network, open a web browser and go to:

   ```
   http://SERVER-IP:8631/admin
   ```

   It redirects to the secure address `https://SERVER-IP:8632/admin` (see [HTTPS redirect](#https-redirect)). You can also go straight to the `https://` address.

2. The browser says the connection is **"not private"**. That's expected: SavaPage uses its own self-signed certificate. Click **Advanced → Continue / Proceed**.
3. Log in with user **`admin`** and password **`admin`**.
4. **Change the password right away:** go to **Options → Advanced → Reset internal admin password**. Store the new password in a password manager.

---

## 5. Back up the encryption key

SavaPage encrypts some of its data with a key stored in `encryption.properties`. **Without it, a restored backup can't be read.** Show the file:

**VM / physical machine:**

```bash
sudo cat /opt/savapage/server/data/encryption.properties
```

**LXC container:**

```bash
cat /opt/savapage/server/data/encryption.properties
```

Copy everything it prints into your password manager, or another safe place **off the server**.

---

## 6. Firewall

Nothing to do, on a VM, a physical machine or an LXC container. The script turns on the `ufw` firewall and blocks all incoming traffic except these ports:

| Port | Purpose |
|---|---|
| TCP 22 | SSH |
| TCP 8631 | SavaPage HTTP and IPP printing |
| TCP 8632 | SavaPage HTTPS |
| TCP 9100 | RAW printing |
| UDP 5353 | Printer discovery (AirPrint) |
| UDP 10001 | Ubiquiti device discovery |
| TCP 631 | CUPS web page, to add printers (VM / physical machine; close with `sudo savapage-cups off`) |

TCP 631, the [CUPS web page](#cups-web-page) for adding printers, is also open on a VM or physical machine (not in a container) until you close it with `sudo savapage-cups off`.

Two kinds of network chatter, LLMNR from Windows PCs (UDP 5355) and SSDP/UPnP (UDP 1900), are **blocked quietly**: the firewall drops them without logging. Without this, the console fills with `[UFW BLOCK]` lines that bury the login prompt.

The script also keeps kernel messages off the console (`kernel.printk = 3 4 1 3` in `/etc/sysctl.d/10-console.conf`). They still go to the system log: see them with `journalctl -k`. An unprivileged LXC container can't change this setting. The script then shows a warning, and you can set it on the Proxmox host instead, in the host shell:

```bash
echo 'kernel.printk = 3 4 1 3' > /etc/sysctl.d/10-console.conf && sysctl -p /etc/sysctl.d/10-console.conf
```

Check the firewall at any time.

**VM / physical machine:**

```bash
sudo ufw status verbose
```

**LXC container:**

```bash
ufw status verbose
```

> ⚠️ **Other services on the machine get blocked too** (file sharing, websites…). Allow each one, e.g. `ufw allow 445/tcp` (with `sudo` on a VM), or install with `SKIP_FIREWALL=1`.

**If the container can't run a firewall.** This can happen with some container setups. The script then finishes anyway and warns *"ufw could not start in this container"*. In that case, use Proxmox's firewall instead:

1. Select the container → **Firewall → Add**.
2. Add one rule for each port in the table above. Each rule is **Direction** `in`, **Action** `ACCEPT`, **Protocol** `tcp` or `udp`, **Dest. port**.
3. Under the container's **Firewall → Options**, set **Firewall: Yes** and **Input Policy: DROP**.

> ⚠️ The container's rules only take effect when **Datacenter → Firewall → Options → Firewall** is also on. Before you turn that on, make sure your Datacenter rules still allow the Proxmox web UI (port 8006). Otherwise you can lock yourself out.

---

## 7. Set up SavaPage

In the admin web app:

1. **Options → Advanced → Locale**: your language, e.g. `en-US`.
2. **Options → Financial**: your currency, e.g. `USD`.
3. **Options → User Source**: where users come from. *Unix* uses the server's Linux accounts; *LDAP* uses Active Directory. Then sync users under **Options → User Creation**.
4. **Add your real printers.** SavaPage prints *through* CUPS, Linux's printing system.

   List the printers on the network.

   **VM / physical machine:**

   ```bash
   sudo lpinfo -v
   ```

   **LXC container:**

   ```bash
   lpinfo -v
   ```

   Add one. Replace `Office` with any name, and `PRINTER-IP` with the printer's address.

   **VM / physical machine:**

   ```bash
   sudo lpadmin -p Office -E -v ipp://PRINTER-IP/ipp/print -m everywhere
   ```

   **LXC container:**

   ```bash
   lpadmin -p Office -E -v ipp://PRINTER-IP/ipp/print -m everywhere
   ```

   In SavaPage, open **Printers**. The new printer appears there. Enable it.

   *Prefer clicking to typing?* Turn on the [CUPS web page](#cups-web-page) and add printers there instead.

5. *(Optional)* **Options → Mail** to send email notifications.

---

## 8. Print to SavaPage from devices

- **Web upload (any device):** go to `http://SERVER-IP:8631/user` (it redirects to HTTPS) and upload PDFs or images.
- **Windows:**
  1. Go to *Settings → Bluetooth & devices → Printers & scanners → Add device → Add manually*.
  2. Choose *"Select a shared printer by name"* and enter `ipp://SERVER-IP:8631/printers/airprint`.
- **macOS / Linux:** add an IPP printer with the same URL.
- **iPhone / iPad (AirPrint):** this needs a discovery file.

  **VM / physical machine.** Copy the example file into place:

  ```bash
  sudo cp /opt/savapage/server/examples/linux/avahi/savapage.service /etc/avahi/services/
  ```

  Then edit it:

  ```bash
  sudo nano /etc/avahi/services/savapage.service
  ```

  **LXC container.** Copy the example file into place:

  ```bash
  cp /opt/savapage/server/examples/linux/avahi/savapage.service /etc/avahi/services/
  ```

  Then edit it:

  ```bash
  nano /etc/avahi/services/savapage.service
  ```

  Change the lines marked `$Customize$`. Save with **Ctrl + O**, **Enter**, then exit with **Ctrl + X**. Then restart discovery: `systemctl restart avahi-daemon` (with `sudo` on a VM). See the [manual](https://manual.savapage.org/ch-printer.html#ch-printer-ipp-everywhere) for the details.

Printing over IPP (port 8631) is **never** redirected, so printer URLs always keep working.

---

## Install options

Put options in front of `bash`. Separate several with spaces.

**VM / physical machine:**

```bash
sudo HTTPS_REDIRECT=0 SKIP_FIREWALL=1 bash ~/savapage-easy-install/install-savapage.sh
```

**LXC container:**

```bash
HTTPS_REDIRECT=0 bash ~/savapage-easy-install/install-savapage.sh
```

| Option | Default | Effect |
|---|---|---|
| `HTTPS_REDIRECT=0` | on | Don't send browsers on `http://…:8631` to HTTPS. See [HTTPS redirect](#https-redirect). |
| `CUPS_WEB=0` | on (off in containers) | Keep the CUPS web page (port 631, for adding printers) closed. `CUPS_WEB=1` opens it. Later: `sudo savapage-cups on` / `off`. See [CUPS web page](#cups-web-page). |
| `SKIP_FIREWALL=1` | off | Don't touch the firewall. Use it if you manage the firewall yourself. |
| `AUTO_UPDATES=0` | on | Don't install updates automatically. See [Automatic updates](#automatic-updates). |
| `UPDATE_TIME=04:30` | `03:00` | When the nightly updates run (24-hour clock, server time). |
| `SAVAPAGE_VERSION=…` | `1.7.0-final` | Install a different SavaPage release. |

## Automatic updates

**On by default,** for a server you can set up and forget. Every night the server installs **all** available updates, security fixes and normal ones, with the distribution's own tool, `unattended-upgrades`:

- **02:30:** it refreshes the package lists (the same as `apt-get update`).
- **03:00:** it installs the updates (like `apt-get upgrade`) and removes packages that are no longer needed.
- **Only if an update needs it** (for example a new kernel), it **reboots** right after. SavaPage starts again by itself. Otherwise nothing restarts.
- If the server was off at 03:00, it catches up the next time it starts.
- **The times are the server's own clock.** VMs and containers made with the one-command scripts get the **Proxmox host's timezone**. On a machine you installed by hand, check with `timedatectl`. If it says UTC, set yours, e.g. `sudo timedatectl set-timezone America/New_York` (list them with `timedatectl list-timezones`). The installer warns if the server is on UTC.

This doesn't update **SavaPage itself**. New SavaPage releases come from [savapage.org](https://www.savapage.org/).

**Check it** (with `sudo` on a VM):

| What | Command |
|---|---|
| When it runs next | `systemctl list-timers apt-daily-upgrade.timer` |
| What it installed | `cat /var/log/unattended-upgrades/unattended-upgrades.log` |
| Try it without installing anything | `unattended-upgrade --dry-run --debug` |

**Change the time:** re-run the installer with, for example, `UPDATE_TIME=04:30`. **Turn it off:** re-run it with `AUTO_UPDATES=0`. The distribution's own default then stays: security updates only, at a random time.

## CUPS web page

CUPS, the print system SavaPage prints through, has its own web page. **That's where you add printers**, and check them and their jobs.

**On by default on a VM or physical machine,** for your **local network only**: CUPS refuses other networks, and its admin pages need a login. **Off by default in an LXC container**, whose `root` usually has no password to log in to CUPS with.

**Use it:**

1. Go to **`https://SERVER-IP:631/admin`** and accept the certificate warning, as with SavaPage. (On plain `http://`, the admin pages say *"Upgrade Required"*.)
2. Log in with your **Linux user and password**: `ubuntu` (or `admin` on Debian) on a VM from `proxmox-vm.sh`, or your own user on a machine you installed by hand. The installer adds that user to the `lpadmin` group, which may manage printers.
3. Click **Administration → Add Printer** and follow the steps. Then add the printer in SavaPage's admin web app (step 7).

**Close it when you're done adding printers, or open it again later,** with one command (no need to re-run the installer):

| What | Command |
|---|---|
| Open it | `sudo savapage-cups on` |
| Close it | `sudo savapage-cups off` |
| Is it open? | `savapage-cups status` |

In an LXC container you're root, so leave out `sudo`. `on`/`off` also opens or closes port 631 in the firewall and updates the status screen. **Your choice is kept:** re-running the installer later doesn't change it back. To set it while installing instead, use `CUPS_WEB=0` or `CUPS_WEB=1`, or answer the menu's question.

**In a container,** `savapage-cups on` works, but CUPS needs a user with a password to log in with. Either give root a password (`passwd`), or add printers with commands instead, e.g. `lpadmin -p Office -E -v ipp://PRINTER-IP/ipp/print -m everywhere`.

## HTTPS redirect

The redirect is **on by default**. SavaPage serves its web pages on two ports:

| Address | Result |
|---|---|
| `https://SERVER-IP:8632/admin` | ✅ Secure |
| `http://SERVER-IP:8631/admin` | ↪ Redirects to the secure address (when the redirect is on) |
| `http://SERVER-IP:8632/...` | ❌ "Invalid response": port 8632 only speaks HTTPS |

Printing over IPP on port 8631 is never redirected.

**Turn it off.** Pick one of these.

- **Re-run the installer with the option.** It skips the parts already done.

  **VM / physical machine:**

  ```bash
  sudo HTTPS_REDIRECT=0 bash ~/savapage-easy-install/install-savapage.sh
  ```

  **LXC container:**

  ```bash
  HTTPS_REDIRECT=0 bash ~/savapage-easy-install/install-savapage.sh
  ```

- **Edit the setting with nano.**
  1. Open the config file.

     **VM / physical machine:**

     ```bash
     sudo nano /opt/savapage/server/data/server.properties
     ```

     **LXC container:**

     ```bash
     nano /opt/savapage/server/data/server.properties
     ```

  2. Press **Ctrl + W**, type `redirect.ssl` and press **Enter** to jump to the line.
  3. Change `server.html.redirect.ssl=true` to `server.html.redirect.ssl=false`.
  4. Press **Ctrl + O** and **Enter** to save, then **Ctrl + X** to exit.
  5. Restart SavaPage.

     **VM / physical machine:**

     ```bash
     sudo systemctl restart savapage
     ```

     **LXC container:**

     ```bash
     systemctl restart savapage
     ```

> Running the installer again turns the redirect back **on**, unless you include `HTTPS_REDIRECT=0`. To turn it on by hand, set the line back to `true` and restart.

## Updating the scripts

This gets the newest version from GitHub (if you cloned):

```bash
cd ~/savapage-easy-install && git pull
```

This updates the scripts, not SavaPage itself. To upgrade SavaPage, see the [upgrade guide](https://manual.savapage.org/ch-install-on-linux-upgrade.html).

## What the script changes

1. **Checks** the system:
   - It's Debian 12/13 or Ubuntu 26.04. Other versions get a warning and still install.
   - It's 64-bit and uses systemd.
   - It has 2 GB RAM. Less gets a warning.
   - It isn't using a `savapage` login account. If one exists, the script stops before changing anything.
2. **Installs packages:** Java 21 (Java 17 on Debian 12), CUPS, Poppler, QPDF, ImageMagick, librsvg, Avahi and a few small helper tools.
3. **Creates** the `savapage` service account (home `/opt/savapage`).
4. **Sets up CUPS**, the print system SavaPage prints through:
   - It only accepts connections from the server itself, unless `CUPS_WEB=1`.
   - Printer sharing and remote admin are off, and it won't import remote printers.
   - It applies SavaPage's recommended job-history settings.
   - The original config is saved as `/etc/cups/cupsd.conf.savapage.bak`.
5. **Sets up Avahi** for printer discovery. In containers it also comments out `rlimit-nproc`, which otherwise stops Avahi from starting.
6. **Downloads** [SavaPage 1.7.0](https://download.savapage.org/installer/savapage-setup-1.7.0-final-linux-x64.bin) and **verifies its SHA-512 checksum**.
7. **Runs the SavaPage installer**, then its root step (`MUST-RUN-AS-ROOT`), which installs the `savapage` service.
8. **Turns on the HTTPS redirect**, unless `HTTPS_REDIRECT=0`.
9. **Turns on the `ufw` firewall** ([ports](#6-firewall)), in containers too. If a container can't run it, the script warns and carries on.
10. **Keeps firewall messages off the console:** blocks LLMNR and SSDP chatter without logging, and writes `/etc/sysctl.d/10-console.conf` (not possible in an unprivileged container, so it warns instead).
11. **Turns on automatic updates** ([details](#automatic-updates)): `/etc/apt/apt.conf.d/52savapage-auto-updates`, and fixed times for the `apt-daily` timers. Turn off with `AUTO_UPDATES=0`.

You can safely run it again. It skips what's already done.

## Moving the server to another location

Nothing is tied to a particular network. Shut it down, move it and plug it in. Then:

1. **Find the new IP:** run `hostname -I`. Most networks also accept `HOSTNAME.local`.
2. **Reserve a fixed IP** in the new router (*"DHCP reservation"*), so client devices keep working.
3. **Update the printer URL** on devices that used the old IP.
4. **Update the real printers** if their IPs changed: `lpadmin -p Office -v ipp://NEW-PRINTER-IP/ipp/print` (with `sudo` on a VM).

*Proxmox:* you can also move the VM or container itself. Back it up (**Backup → Backup now**) and restore it on another Proxmox host.

## Everyday commands

On a VM, put `sudo` in front of each command.

| What | Command |
|---|---|
| Is SavaPage running? | `systemctl status savapage` |
| Restart SavaPage | `systemctl restart savapage` |
| Firewall rules | `ufw status verbose` |
| Install OS updates now (they also install themselves nightly) | `apt update && apt upgrade` |
| Change your login password | `passwd` |
| Reset a VM's login password (on the **Proxmox host**) | `qm guest passwd VMID admin` |
| Reset a container's root password (on the **Proxmox host**) | `pct enter CTID`, then `passwd`, then `exit` |
| Edit SavaPage's settings | `nano /opt/savapage/server/data/server.properties` |
| Log files | `ls /opt/savapage/server/logs/` |

## Security

- **Change the `admin` password** straight after installing.
- **Never port-forward** 8631/8632 on your router. If you need outside access, use a VPN.
- The firewall accepts SavaPage traffic from any address, so it relies on your router or network to keep outsiders out. On a shared or guest network, limit it to your own subnet, e.g. `sudo ufw allow from 192.168.1.0/24 to any port 8632`.
- **Keep it updated:** OS updates install themselves every night ([Automatic updates](#automatic-updates)). Check for new SavaPage releases at [savapage.org](https://www.savapage.org/).
- **Back up** `/opt/savapage/server/data/` regularly. The uninstall script makes one for you. Keep a separate copy of `encryption.properties`.

## Troubleshooting

| Problem | Fix |
|---|---|
| `bash\r: No such file or directory` | The script got Windows line endings. Run `sed -i 's/\r$//' ~/savapage-easy-install/*.sh`, or clone it from GitHub instead. |
| `Run this script as root` | On a VM, start the command with `sudo`. |
| `A user named 'savapage' already exists` | Your own login is called `savapage`. Create another admin user and remove that one, or reinstall the OS with another name. Nothing was changed. |
| `is not a supported version` (yellow) | Untested OS version. The install continues; use Debian 12/13 or Ubuntu 26.04 if anything breaks. |
| `x86_64 only` | The processor isn't supported (e.g. Raspberry Pi). |
| `Could not reach download.savapage.org` | No internet access. Check the network and try again. |
| `Checksum mismatch` | The download was damaged or tampered with. Run the script again. If it keeps happening, stop and investigate. |
| `firewalld is active` | Re-run with `SKIP_FIREWALL=1` and open the ports in firewalld yourself. |
| `ufw could not start in this container` (yellow) | This container setup can't run a firewall. SavaPage still works. Use the Proxmox firewall instead, see [Firewall](#6-firewall). |
| LXC: *"Some systemd units have failed"*, or services won't start | Turn on **Options → Features → Nesting**, restart the container and run the script again. |
| LXC: `avahi-daemon` won't start | Run `nano /etc/avahi/avahi-daemon.conf`, put `#` in front of the `rlimit-nproc=` line, save, then run `systemctl restart avahi-daemon`. The script normally does this. |
| LXC console won't paste | Switch to the **xterm.js** console. Click the arrow next to **Console** at the top. |
| "Invalid response" in the browser | You used `http://` with port 8632. Use `http://…:8631` or `https://…:8632`. |
| Browser says "not private" | Normal for a self-signed certificate. Click *Advanced → Continue*. |
| Web page doesn't load | Check the IP (`hostname -I`) and that SavaPage is running (`systemctl status savapage`). Check `ufw status`. Logs are in `/opt/savapage/server/logs/`. |
| Nothing at `SERVER-IP:631` (CUPS page) | It's closed: the default in a container, or someone ran `savapage-cups off`. Open it with `sudo savapage-cups on`. Use `https://`, not `http://`, for the admin pages. See [CUPS web page](#cups-web-page). |
| Printers don't show in SavaPage | Check CUPS sees them with `lpstat -p`. Make sure each one is shared: `lpadmin -p NAME -o printer-is-shared=true`. |
| Forgot the admin password | See the [SavaPage manual](https://manual.savapage.org/). |
| Forgot the VM login password | In the Proxmox host shell: `qm guest passwd VMID admin`. See [Logging in to the VM](#logging-in-to-the-vm). |
| `savapage` / `savapage` doesn't log in | That's SavaPage's service account, which can't log in. Use `admin` (VM) or `root` (container). |

## Uninstall

The uninstall script backs up your data, removes SavaPage, and checks that the machine is clean for a reinstall.

**VM / physical machine:**

```bash
sudo bash ~/savapage-easy-install/uninstall-savapage.sh
```

**LXC container:**

```bash
bash ~/savapage-easy-install/uninstall-savapage.sh
```

Type **`yes`** to confirm. The script:

1. **Backs up** `/opt/savapage/server/data`, including `encryption.properties`, to `/root/savapage-backup-DATE.tar.gz`. Only root can read it.
2. Runs **SavaPage's own uninstaller**.
3. Removes the leftovers: `/opt/savapage`, `/etc/pam.d/savapage` and the `savapage` service account.
4. **Checks the machine is clean.** It prints **PASS** or **FAIL** for each of these:
   - the service, its file and the CUPS notifier are gone;
   - the install folder, the PAM file and the account are gone;
   - no SavaPage processes are left, and the ports are free;
   - CUPS still runs.

When everything says PASS, you can [reinstall](#3-run-the-installer) at any time.

**Options** (put them in front of `bash`, like the install options):

| Option | Effect |
|---|---|
| `ASSUME_YES=1` | Don't ask for confirmation. |
| `SKIP_BACKUP=1` | Don't make the backup. |
| `RESTORE_CUPS=1` | Put back the CUPS config from before SavaPage. |
| `REMOVE_FIREWALL_RULES=1` | Remove the firewall rules for 8631, 8632, 9100, 5353, 10001 and 631 (if opened), the quiet blocks, and `/etc/sysctl.d/10-console.conf`. The SSH rule and the firewall stay. |

**LXC container, the quick way:** delete the whole container (**More → Remove**). Back up `encryption.properties` first.
