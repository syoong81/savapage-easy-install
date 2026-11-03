# Install guide: physical machine or virtual machine

Use this guide for a **physical PC/server** or a **virtual machine** (Proxmox VM, VirtualBox, Hyper-V, VMware…). For a Proxmox LXC container, use [INSTALL-LXC.md](INSTALL-LXC.md) instead.

> Read the [Disclaimer](README.md#disclaimer) first. By running the script, you accept it.

## Contents

1. [What you need](#1-what-you-need)
2. [Open a terminal on the server](#2-open-a-terminal-on-the-server)
3. [Find the server's IP address](#3-find-the-servers-ip-address)
4. [Copy the script to the server](#4-copy-the-script-to-the-server)
5. [Run the installer](#5-run-the-installer)
6. [Log in and change the password](#6-log-in-and-change-the-password)
7. [After installation](#7-after-installation)
8. [Printing to SavaPage from devices](#8-printing-to-savapage-from-devices)

Reference: [Options](#options) · [Redirect HTTP to HTTPS](#redirect-http-to-https-optional) · [What the script changes](#what-the-script-changes) · [Moving the server](#moving-the-server-to-another-location) · [Everyday commands](#everyday-commands) · [Security](#security) · [Troubleshooting](#troubleshooting) · [Uninstall](#uninstall)

---

## 1. What you need

| Item | Details |
|---|---|
| A machine | 64-bit Intel/AMD (x86_64), **2+ CPU cores, 2+ GB RAM, 1+ GB free disk**. An old PC is fine. |
| Operating system | **Debian 12, Debian 13 or Ubuntu 26.04 LTS**. A fresh install is best. |
| Network | Connected to your network, with internet access during the install. |
| An account with admin rights | Any user that can run `sudo` (the one you created when installing the OS can). **Don't name it `savapage`.** That name is reserved for SavaPage's own service account, and the script will stop if it's taken. |
| Your printer(s) | On the same network, or connected to the server by USB. |

*For a Proxmox VM:* 2 cores, 2048 MB RAM and a 16 GB disk is plenty. For a USB printer, pass it through under **VM → Hardware → Add → USB Device**.

---

## 2. Open a terminal on the server

A **terminal** is a text window where you type commands and press **Enter**. Choose **one** of these:

- **At the server:** with a desktop, press **Ctrl + Alt + T**. On a server with no desktop, just log in. You're already at a terminal.
- **Proxmox VM:** click the VM → **Console** and log in.
- **From your Windows PC over the network (SSH):** open **PowerShell** or **Windows Terminal** from the Start menu and type:

  ```bash
  ssh youruser@SERVER-IP
  ```

  Replace `youruser` with your Linux user name and `SERVER-IP` with the server's address (step 3). Type `yes` if asked to trust the computer, then enter your password.

  If SSH isn't installed on the server yet, run this at the server first:

  ```bash
  sudo apt install -y openssh-server
  ```

> **Tip:** when you type a password in a terminal, **nothing appears on screen**, not even dots. That's normal. Type it and press Enter.

---

## 3. Find the server's IP address

On the server, run:

```bash
hostname -I
```

The first number (e.g. `192.168.1.50`) is the server's IP address. **Write it down.** It replaces `SERVER-IP` everywhere in this guide.

---

## 4. Copy the script to the server

You need `install-savapage.sh` on the server. Choose **one** method.

### Option A: PowerShell (built into Windows 10/11)

1. Open the folder holding `install-savapage.sh` in File Explorer.
2. Click the address bar, type `powershell` and press **Enter**. A PowerShell window opens in that folder.
3. Run this, replacing `youruser` and `SERVER-IP`:

   ```bash
   scp install-savapage.sh youruser@SERVER-IP:~
   ```

4. Type `yes` if asked to trust the computer, then enter your Linux password.

The file is now in your home folder on the server (`~/install-savapage.sh`).

### Option B: WinSCP (drag and drop)

1. Download and install [WinSCP](https://winscp.net/).
2. Start a **New Session** with **File protocol** `SFTP`, **Host name** `SERVER-IP`, and your Linux **User name** and **Password**. Click **Login**.
3. Drag `install-savapage.sh` from the left (your PC) into your home folder on the right (the server).

### Option C: USB stick

1. Copy `install-savapage.sh` onto a USB stick and plug it into the server.
2. On the server, find the stick with `lsblk`. It's usually `sdb1`.
3. Mount it and copy the file:

   ```bash
   sudo mount /dev/sdb1 /mnt && cp /mnt/install-savapage.sh ~ && sudo umount /mnt
   ```

### Option D: Paste it

On the server, run `nano ~/install-savapage.sh`, then paste the whole script, press **Ctrl + O** and **Enter** to save, and **Ctrl + X** to exit. (This doesn't work in the Proxmox noVNC console. Use SSH or the xterm.js console instead.)

### Option E: Clone the GitHub repository (alternative install method)

This downloads the install script, the uninstall script and the guides straight onto the server. Nothing needs copying from your PC. On the server, run these one at a time.

Install git:

```bash
sudo apt-get update && sudo apt-get install -y git
```

Download the repository:

```bash
git clone https://github.com/syoong81/savapage-easy-install.git ~/savapage-easy-install
```

Run the installer:

```bash
sudo bash ~/savapage-easy-install/install-savapage.sh
```

That last command replaces step 5. Skip ahead to [step 6](#6-log-in-and-change-the-password) when it finishes.

To get the newest version of the scripts later:

```bash
cd ~/savapage-easy-install && git pull
```

---

## 5. Run the installer

On the server, run:

```bash
sudo bash ~/install-savapage.sh
```

- Enter your password when asked.
- It takes **about 5–10 minutes**. The SavaPage download is about 150 MB.
- **Don't close the window** while it runs.
- When it's done, you'll see a box saying **"SavaPage 1.7.0-final is installed"** with the web addresses to use.

A yellow `[!]` line is a warning; the install continues. A red `[x]` line means the script stopped. See [Troubleshooting](#troubleshooting).

---

## 6. Log in and change the password

1. On any computer on the same network, open a web browser and go to:

   ```
   https://SERVER-IP:8632/admin
   ```

   Make sure it starts with **`https://`**. Plain `http://` on port 8632 gives an "invalid response" error. See [Redirect HTTP to HTTPS](#redirect-http-to-https-optional).

2. The browser will say the connection is **"not private"** or **"not secure"**. That's expected: SavaPage uses its own self-signed certificate. Click **Advanced → Continue / Proceed**.
3. Log in with user name **`admin`** and password **`admin`**.
4. **Change the password right away:** go to **Options → Advanced → Reset internal admin password**, enter a strong password and click **Apply**. Store it in a password manager.
5. **Back up the encryption key file** `/opt/savapage/server/data/encryption.properties`, for example by copying it off with WinSCP. Keep it somewhere safe. Without it, a restored backup cannot be read.

---

## 7. After installation

In the admin web app (`https://SERVER-IP:8632/admin`):

1. **Options → Advanced → Locale**: set your language, e.g. `en-US`.
2. **Options → Financial**: set your currency, e.g. `USD`.
3. **Options → User Source**: decide where users come from.
   - *Unix* uses this server's Linux accounts.
   - *LDAP* uses Active Directory or another directory.

   Then sync them under **Options → User Creation**.
4. **Add your real printers.** SavaPage prints *through* CUPS, Linux's printing system. On the server:
   - Find printers on the network:

     ```bash
     sudo lpinfo -v
     ```

   - Add one. Replace `Office` with any name, and `PRINTER-IP` with the printer's IP:

     ```bash
     sudo lpadmin -p Office -E -v ipp://PRINTER-IP/ipp/print -m everywhere
     ```

   - In SavaPage, open **Printers**. The new printer appears there. Enable it.

   *Prefer a web page?* From your PC run `ssh -L 6310:localhost:631 youruser@SERVER-IP`, then browse to `http://localhost:6310` to use the CUPS web interface.
5. *(Optional)* **Options → Mail** to send email notifications.

---

## 8. Printing to SavaPage from devices

- **Web upload (any device):** users go to `https://SERVER-IP:8632/user` and upload PDFs or images.
- **Windows:**
  1. Go to *Settings → Bluetooth & devices → Printers & scanners → Add device*.
  2. Click *"Add manually"*.
  3. Choose *"Select a shared printer by name"* and enter `ipp://SERVER-IP:8631/printers/airprint`.
- **macOS / Linux:** add an IPP printer with the same URL, `ipp://SERVER-IP:8631/printers/airprint`.
- **iPhone / iPad / Android (AirPrint):** this needs an Avahi service file.
  1. Copy the example from `/opt/savapage/server/examples/linux/avahi/savapage.service`.
  2. Edit the lines marked `$Customize$`.
  3. Save it to `/etc/avahi/services/`, then run `sudo systemctl restart avahi-daemon`.

  See the [manual](https://manual.savapage.org/ch-printer.html#ch-printer-ipp-everywhere).

---

## Options

Put these before `bash` on the command line:

| Variable | Default | Effect |
|---|---|---|
| `HTTPS_REDIRECT=1` | off | Sends browsers that open `http://SERVER-IP:8631` to the secure HTTPS page. See below. |
| `SKIP_FIREWALL=1` | off | Doesn't touch the firewall. Use it if you manage the firewall yourself, or the machine runs other services. |
| `SAVAPAGE_VERSION` | `1.7.0-final` | Installs a different SavaPage release. |

Example:

```bash
sudo HTTPS_REDIRECT=1 bash ~/install-savapage.sh
```

## Redirect HTTP to HTTPS (optional)

SavaPage serves its web pages on two ports:

| Address | Result |
|---|---|
| `https://SERVER-IP:8632/admin` | ✅ secure (recommended) |
| `http://SERVER-IP:8631/admin` | ✅ works, but **unencrypted**: passwords cross the network in plain text |
| `http://SERVER-IP:8632/...` | ❌ "invalid response": port 8632 only speaks HTTPS |

The redirect is **off by default**. When it's on, anyone who opens `http://SERVER-IP:8631` in a browser is sent automatically to `https://SERVER-IP:8632`. Printing over IPP on port 8631 is never redirected, so printers and devices keep working. It can't fix `http://` on port 8632.

**Turn it on during install:**

```bash
sudo HTTPS_REDIRECT=1 bash ~/install-savapage.sh
```

**Turn it on later.** Open the config file:

```bash
sudo nano /opt/savapage/server/data/server.properties
```

Add (or change) this line, then save:

```
server.html.redirect.ssl=true
```

Then restart SavaPage:

```bash
sudo systemctl restart savapage
```

**Turn it off again:** set the line to `server.html.redirect.ssl=false` and restart.

---

## What the script changes

1. **Checks** the machine is Debian 12/13 or Ubuntu 26.04 (it warns on other versions), 64-bit, with systemd, and warns if RAM is under 2 GB.
2. **Installs packages:**
   - **Java 21**, or Java 17 on Debian 12;
   - CUPS, Poppler, QPDF, ImageMagick, librsvg and Avahi;
   - small tools the installer needs.
3. **Creates a system account** called `savapage`, with home folder `/opt/savapage`.
4. **Sets up CUPS**, the print system SavaPage prints through:
   - It only accepts connections from this machine. SavaPage is what the network talks to.
   - Printer sharing and remote admin are off, and it won't import remote printers.
   - It applies SavaPage's recommended job-history settings.
   - The original config is saved as `/etc/cups/cupsd.conf.savapage.bak`.
5. **Sets up Avahi** for automatic printer discovery on the local network.
6. **Downloads** [savapage-setup-1.7.0-final-linux-x64.bin](https://download.savapage.org/installer/savapage-setup-1.7.0-final-linux-x64.bin) and **verifies its SHA-512 checksum**. If the check fails, it stops.
7. **Runs the SavaPage installer** as `savapage`, then the root step (`MUST-RUN-AS-ROOT`), which installs the `savapage` service.
8. *(Only with `HTTPS_REDIRECT=1`)* turns on the HTTP-to-HTTPS redirect.
9. **Turns on the ufw firewall.** It **blocks all incoming traffic** except these ports:

   | Port | Purpose |
   |---|---|
   | TCP 22 | SSH (remote login) |
   | TCP 8631 | SavaPage HTTP and IPP printing |
   | TCP 8632 | SavaPage HTTPS (web apps, secure IPP) |
   | TCP 9100 | JetDirect / RAW printing |
   | UDP 5353 | mDNS printer discovery (AirPrint / IPP Everywhere) |

> ⚠️ **If this machine runs other services** (file sharing, a website, remote desktop…), the firewall will block them. Allow each one afterwards, e.g. `sudo ufw allow 445/tcp`, or run the script with `SKIP_FIREWALL=1`.

You can safely run the script again. It skips steps that are already done and will not reinstall SavaPage over an existing install.

---

## Moving the server to another location

Nothing in the setup is tied to a specific network, so shut it down, move it and plug it in. Then:

1. **Find its new address:** run `hostname -I` on the server. Most networks also let you reach it as `HOSTNAME.local`.
2. **Give it a fixed IP at the new site:** in the new router, reserve an address for the server (often called *"DHCP reservation"* or *"static lease"*). Then client devices keep working.
3. **Update client devices** that used the old IP in their printer URL.
4. **Update real printers** if their IPs changed:

   ```bash
   sudo lpadmin -p Office -v ipp://NEW-PRINTER-IP/ipp/print
   ```

*Proxmox VM:* you can also back it up (**VM → Backup → Backup now**) and restore it on another Proxmox host.

---

## Everyday commands

Check that SavaPage is running:

```bash
sudo systemctl status savapage
```

Restart SavaPage:

```bash
sudo systemctl restart savapage
```

Show the firewall rules:

```bash
sudo ufw status verbose
```

Install operating-system updates (do this regularly):

```bash
sudo apt update && sudo apt upgrade
```

Files:

- Config file: `/opt/savapage/server/data/server.properties`
- Logs: `/opt/savapage/server/logs/`

---

## Security

- **Change the `admin` password** right after installing.
- **Never port-forward** 8631/8632 on your router. If you need outside access, use a VPN.
- **The firewall accepts SavaPage connections from any address**, so the server relies on your router or network to keep outsiders out. On a guest network or a shared building network, consider limiting it, e.g. `sudo ufw allow from 192.168.1.0/24 to any port 8632`.
- **Keep it updated.** Install OS updates regularly. Check [savapage.org](https://www.savapage.org/) for new releases and follow the [upgrade guide](https://manual.savapage.org/ch-install-on-linux-upgrade.html).
- **Back up** `/opt/savapage/server/data/` regularly, and keep a separate copy of `encryption.properties`.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `bash\r: No such file or directory` | The file got Windows line endings. Run `sed -i 's/\r$//' ~/install-savapage.sh` and try again. |
| `Run this script as root` | You forgot `sudo`. Run `sudo bash ~/install-savapage.sh`. |
| `A user named 'savapage' already exists` | Your own login account is called `savapage`. Create a new admin user, then remove or rename the old one. Or reinstall the OS with a different user name. The script changed nothing. |
| `is not a supported version` (yellow) | Your OS version hasn't been tested. The install continues, but use Debian 12/13 or Ubuntu 26.04 if anything breaks. |
| `x86_64 only` | The machine's processor isn't supported. See [What you need](#1-what-you-need). |
| `recommends at least 2 GB RAM` (yellow) | SavaPage may be slow. Give the machine or VM more memory if you can. |
| `Could not reach download.savapage.org` | The server has no internet access. Check its network and try again. |
| `Checksum mismatch` | The download was corrupted or tampered with. Run the script again. If it keeps happening, stop and investigate. |
| `firewalld is active` | Rerun with `SKIP_FIREWALL=1` and open the ports in firewalld yourself. |
| "invalid response" in the browser | You used `http://` on port 8632. Use **`https://`**SERVER-IP:8632/admin. |
| Browser says "not private" | Normal for a self-signed certificate. Click *Advanced → Continue*. |
| Can't open the web page from another PC | Check the IP (`hostname -I`), the URL (`https://`, port `8632`) and the firewall (`sudo ufw status`). |
| Page doesn't load at all | Run `sudo systemctl status savapage` and check the logs in `/opt/savapage/server/logs/`. |
| Printers don't show in SavaPage | Check CUPS sees them: `lpstat -p`. Make sure each one is shared: `sudo lpadmin -p NAME -o printer-is-shared=true`. |
| Lost SSH after installing | Port 22 is opened by the script. If you use a different SSH port, log in at the console and run `sudo ufw allow PORT/tcp`. |
| Forgot the admin password | See *Reset internal admin password* in the [manual](https://manual.savapage.org/). |

Still stuck? Read the official [SavaPage manual](https://manual.savapage.org/).

---

## Uninstall

This removes SavaPage **and all of its data**: users, print history and settings.

### The easy way: the uninstall script

Copy `uninstall-savapage.sh` to the server, the same way as the install script ([step 4](#4-copy-the-script-to-the-server)). If you cloned the repository, it's already in `~/savapage-easy-install/`. Then run:

```bash
sudo bash ~/uninstall-savapage.sh
```

Type **`yes`** to confirm. The script:

1. **Backs up** `/opt/savapage/server/data` (including `encryption.properties`) to `/root/savapage-backup-DATE.tar.gz`. The backup is readable by root only.
2. Runs **SavaPage's own uninstaller**, which removes the service and the CUPS notifier.
3. Removes the leftovers: `/opt/savapage`, `/etc/pam.d/savapage` and the `savapage` service account. It never touches a normal login account that happens to be called `savapage`.
4. **Checks the machine is clean** and ready for a fresh install. Each check prints **PASS** or **FAIL**:

   ```
   [PASS] savapage service removed
   [PASS] savapage service file deleted
   [PASS] SavaPage CUPS notifier removed
   [PASS] /opt/savapage deleted
   [PASS] /etc/pam.d/savapage deleted
   [PASS] 'savapage' service account removed
   [PASS] no SavaPage processes running
   [PASS] ports 8631, 8632, 9100 are free
   [PASS] CUPS still running (needed for reinstall)
   ```

If every line says PASS, reinstall any time with `sudo bash ~/install-savapage.sh`. You can also run the uninstall script on a machine without SavaPage just to run the checks.

**Options** (put them before `bash`):

| Variable | Effect |
|---|---|
| `ASSUME_YES=1` | Doesn't ask for confirmation. |
| `SKIP_BACKUP=1` | Doesn't make the data backup. |
| `RESTORE_CUPS=1` | Puts back the CUPS config from before SavaPage was installed. |
| `REMOVE_FIREWALL_RULES=1` | Removes the firewall rules for ports 8631, 8632, 9100 and 5353. The SSH rule and the firewall itself stay. |

Example, to remove everything the install script added:

```bash
sudo RESTORE_CUPS=1 REMOVE_FIREWALL_RULES=1 bash ~/uninstall-savapage.sh
```

To turn the firewall off completely as well:

```bash
sudo ufw disable
```

### By hand

<details>
<summary>Manual steps, if you can't use the uninstall script</summary>

Back up `/opt/savapage/server/data/` (including `encryption.properties`) first if you might need it.

**1. Run SavaPage's own uninstaller.** It stops the service and removes the systemd service and the SavaPage CUPS notifier. When it asks *"Would you like to uninstall? [yes or no]"*, type **`yes`** and press Enter.

```bash
cd /opt/savapage && sudo ./uninstall
```

**2. Remove the install folder, the `savapage` account and SavaPage's login (PAM) file.** The uninstaller leaves these behind:

```bash
cd / && sudo rm -rf /opt/savapage /etc/pam.d/savapage && sudo userdel savapage
```

You can reinstall at any time by running the script again.

**3. (Optional) Undo the script's other changes.** Restore the original CUPS config:

```bash
sudo cp /etc/cups/cupsd.conf.savapage.bak /etc/cups/cupsd.conf && sudo systemctl restart cups
```

Turn the firewall off again:

```bash
sudo ufw disable
```

</details>
