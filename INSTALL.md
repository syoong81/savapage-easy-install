# Install guide

One guide for both ways to run SavaPage:

- **VM or physical machine:** a Proxmox VM, VirtualBox, Hyper-V, or an old PC/server.
- **Proxmox LXC container:** lighter than a VM. Use it when your printers are on the network. A printer that plugs in by **USB** is easier with a VM.

> Read the [Disclaimer](README.md#disclaimer) first. By running the scripts, you accept it.

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

Reference: [Install options](#install-options) · [HTTPS redirect](#https-redirect) · [Updating the scripts](#updating-the-scripts) · [What the script changes](#what-the-script-changes) · [Moving the server](#moving-the-server-to-another-location) · [Everyday commands](#everyday-commands) · [Security](#security) · [Troubleshooting](#troubleshooting) · [Uninstall](#uninstall)

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

CUPS (631) stays blocked. Check the firewall at any time.

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
| `SKIP_FIREWALL=1` | off | Don't touch the firewall. Use it if you manage the firewall yourself. |
| `SAVAPAGE_VERSION=…` | `1.7.0-final` | Install a different SavaPage release. |

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
   - It only accepts connections from the server itself.
   - Printer sharing and remote admin are off, and it won't import remote printers.
   - It applies SavaPage's recommended job-history settings.
   - The original config is saved as `/etc/cups/cupsd.conf.savapage.bak`.
5. **Sets up Avahi** for printer discovery. In containers it also comments out `rlimit-nproc`, which otherwise stops Avahi from starting.
6. **Downloads** [SavaPage 1.7.0](https://download.savapage.org/installer/savapage-setup-1.7.0-final-linux-x64.bin) and **verifies its SHA-512 checksum**.
7. **Runs the SavaPage installer**, then its root step (`MUST-RUN-AS-ROOT`), which installs the `savapage` service.
8. **Turns on the HTTPS redirect**, unless `HTTPS_REDIRECT=0`.
9. **Turns on the `ufw` firewall** ([ports](#6-firewall)), in containers too. If a container can't run it, the script warns and carries on.

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
| Install OS updates | `apt update && apt upgrade` |
| Edit SavaPage's settings | `nano /opt/savapage/server/data/server.properties` |
| Log files | `ls /opt/savapage/server/logs/` |

## Security

- **Change the `admin` password** straight after installing.
- **Never port-forward** 8631/8632 on your router. If you need outside access, use a VPN.
- The firewall accepts SavaPage traffic from any address, so it relies on your router or network to keep outsiders out. On a shared or guest network, limit it to your own subnet, e.g. `sudo ufw allow from 192.168.1.0/24 to any port 8632`.
- **Keep it updated:** OS updates regularly, and new SavaPage releases from [savapage.org](https://www.savapage.org/).
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
| Printers don't show in SavaPage | Check CUPS sees them with `lpstat -p`. Make sure each one is shared: `lpadmin -p NAME -o printer-is-shared=true`. |
| Forgot the admin password | See the [SavaPage manual](https://manual.savapage.org/). |

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
| `REMOVE_FIREWALL_RULES=1` | Remove the firewall rules for 8631, 8632, 9100 and 5353. The SSH rule and the firewall stay. |

**LXC container, the quick way:** delete the whole container (**More → Remove**). Back up `encryption.properties` first.
