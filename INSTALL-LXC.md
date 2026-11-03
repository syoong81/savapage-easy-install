# Install guide: Proxmox LXC container

Use this guide to run SavaPage in a **Proxmox LXC container**. For a physical machine or a VM, use [INSTALL-VM.md](INSTALL-VM.md) instead.

> Read the [Disclaimer](README.md#disclaimer) first. By running the script, you accept it.

**Container or VM?** A container is lighter and works well when your printers are **on the network**. If a printer connects by **USB**, use a VM: USB passthrough to containers is fiddly.

## Contents

1. [Download the Debian 13 template](#1-download-the-debian-13-template)
2. [Create the container](#2-create-the-container)
3. [Get the scripts into the container](#3-get-the-scripts-into-the-container)
4. [Run the installer](#4-run-the-installer)
5. [Log in and change the password](#5-log-in-and-change-the-password)
6. [(Optional) Proxmox firewall rules](#6-optional-proxmox-firewall-rules)
7. [Next steps](#7-next-steps)

Reference: [How the script handles containers](#how-the-script-handles-containers) · [Options](#options) · [Moving the container](#moving-the-container-to-another-site) · [Troubleshooting](#troubleshooting) · [Uninstall](#uninstall)

---

## 1. Download the Debian 13 template

In the Proxmox web UI:

1. Click your storage (usually **`local`**) under your node.
2. Open **CT Templates → Templates**.
3. Search for **`debian-13-standard`**, select it and click **Download**.

*Or* in the Proxmox host shell (**Node → Shell**), list the available Debian 13 templates:

```bash
pveam update && pveam available --section system | grep debian-13
```

Then download the one it lists, using its exact file name:

```bash
pveam download local debian-13-standard_13.x-x_amd64.tar.zst
```

Debian 12 (`debian-12-standard`) also works.

---

## 2. Create the container

Click **Create CT** (top right) and fill in:

| Tab | Setting |
|---|---|
| General | **Hostname** `savapage`, set a **root password**, **Unprivileged container ✔** |
| Template | the `debian-13-standard` template |
| Disks | **8 GB** or more |
| CPU | **2** cores |
| Memory | **2048** MB, swap **512** MB |
| Network | Bridge **`vmbr0`**, IPv4 **DHCP**, **Firewall ✔** |
| DNS | leave the defaults |

Click **Finish**, but **don't start it yet**. Then select the container:

- **Options → Features → Nesting ✔** (**required**: Debian 13's systemd needs it).
- **Options → Start at boot → Yes**.
- *(Recommended)* **Snapshots → Take Snapshot**, so you can roll back.

Start the container.

<details>
<summary><b>Or create it with one command on the Proxmox host</b></summary>

Change `120` (the container ID), the template file name and `local-lvm` (the storage) to match your system. It will ask for a root password.

```bash
pct create 120 local:vztmpl/debian-13-standard_13.x-x_amd64.tar.zst --hostname savapage --unprivileged 1 --features nesting=1 --cores 2 --memory 2048 --swap 512 --rootfs local-lvm:8 --net0 name=eth0,bridge=vmbr0,ip=dhcp,firewall=1 --onboot 1 --password --start 1
```

</details>

---

## 3. Get the scripts into the container

Choose **one** method. **Option A (GitHub) is recommended.** It needs nothing from your PC, and it's the easiest way to get updates later.

The commands below run in the **Proxmox host shell** (**Node → Shell** in the web UI). Replace `120` with your container ID.

### Option A: Clone from GitHub (recommended)

Install git in the container:

```bash
pct exec 120 -- bash -c 'apt-get update && apt-get install -y git'
```

Download the scripts and guides into the container:

```bash
pct exec 120 -- git clone https://github.com/syoong81/savapage-easy-install.git /root/savapage-easy-install
```

The scripts are now in `/root/savapage-easy-install/` inside the container. Continue with [step 4](#4-run-the-installer).

To get the newest version of the scripts later:

```bash
pct exec 120 -- git -C /root/savapage-easy-install pull
```

### Option B: PowerShell (built into Windows 10/11)

This copies the scripts from your PC to the Proxmox host, then into the container.

1. Download the scripts to your PC from [the GitHub page](https://github.com/syoong81/savapage-easy-install) (**Code → Download ZIP**), and unzip them.
2. Open the unzipped folder in File Explorer, click the address bar, type `powershell` and press **Enter**.
3. Run this, replacing `PROXMOX-IP` with your Proxmox host's IP (the one you use for the web UI, without `:8006`):

   ```bash
   scp install-savapage.sh uninstall-savapage.sh root@PROXMOX-IP:/root/
   ```

4. Type `yes` if asked to trust the computer, then enter the Proxmox **root** password.
5. In the Proxmox host shell, push both scripts into the container. First the install script:

   ```bash
   pct push 120 /root/install-savapage.sh /root/install-savapage.sh
   ```

   Then the uninstall script:

   ```bash
   pct push 120 /root/uninstall-savapage.sh /root/uninstall-savapage.sh
   ```

### Option C: WinSCP (drag and drop)

1. Download the scripts to your PC as in Option B, step 1.
2. Download and install [WinSCP](https://winscp.net/).
3. Start a **New Session** with **File protocol** `SFTP`, **Host name** `PROXMOX-IP`, **User name** `root`, and the Proxmox root password. Click **Login**.
4. Drag `install-savapage.sh` and `uninstall-savapage.sh` into `/root/` on the right.
5. Push both scripts into the container with the two `pct push` commands from Option B, step 5.

### Option D: SSH into the container and paste the script

The container doesn't accept root password logins over SSH, so go in through the Proxmox host.

1. From your PC, connect to the Proxmox host:

   ```bash
   ssh root@PROXMOX-IP
   ```

2. Open a root shell inside the container:

   ```bash
   pct enter 120
   ```

3. Open [install-savapage.sh on GitHub](https://github.com/syoong81/savapage-easy-install/blob/main/install-savapage.sh) and click the **Copy raw file** button. Then, in the SSH window, run:

   ```bash
   nano /root/install-savapage.sh
   ```

4. Paste with a **right-click** (or **Ctrl + Shift + V**). Press **Ctrl + O** and **Enter** to save, and **Ctrl + X** to exit.
5. Type `exit` to leave the container.

---

## 4. Run the installer

In the Proxmox host shell, run the command that matches how you got the scripts. It takes **about 5–10 minutes**. Don't close the shell.

| You used… | Run |
|---|---|
| **Option A** (GitHub) | `pct exec 120 -- bash /root/savapage-easy-install/install-savapage.sh` |
| **Options B, C or D** | `pct exec 120 -- bash /root/install-savapage.sh` |

For example, after cloning from GitHub:

```bash
pct exec 120 -- bash /root/savapage-easy-install/install-savapage.sh
```

When it's done, you'll see a box saying **"SavaPage 1.7.0-final is installed"** with the container's web addresses.

A yellow `[!]` line is a warning; the install continues. In a container you'll always see *"Firewall skipped (LXC)"*, which is expected. A red `[x]` line means the script stopped. See [Troubleshooting](#troubleshooting).

**With install options.** Put the [options](#options) after `env` and before `bash`. For example, to turn on the HTTP-to-HTTPS redirect:

```bash
pct exec 120 -- env HTTPS_REDIRECT=1 bash /root/savapage-easy-install/install-savapage.sh
```

If you used Options B–D, use `/root/install-savapage.sh` instead.

**Find the container's IP** (if you missed it in the output):

```bash
pct exec 120 -- hostname -I
```

> You can also run the installer from inside the container, from its **Console** in the Proxmox UI or after `pct enter 120`. Leave out `pct exec 120 --` and `env`, e.g. `HTTPS_REDIRECT=1 bash /root/savapage-easy-install/install-savapage.sh`. You're root there, so `sudo` isn't needed.

---

## 5. Log in and change the password

1. On any computer on the same network, open:

   ```
   https://CONTAINER-IP:8632/admin
   ```

   It must start with **`https://`**. Plain `http://` on port 8632 gives an "invalid response" error. See [Redirect HTTP to HTTPS](INSTALL-VM.md#redirect-http-to-https-optional).

2. Accept the browser's certificate warning (*Advanced → Continue*). It appears because SavaPage uses its own self-signed certificate.
3. Log in as **`admin`** / **`admin`**.
4. **Change the password right away:** **Options → Advanced → Reset internal admin password**.
5. **Back up the encryption key file.** Copy it out of the container to the Proxmox host:

   ```bash
   pct pull 120 /opt/savapage/server/data/encryption.properties /root/savapage-encryption.properties
   ```

   Then keep it somewhere safe off the server. Without it, a restored backup cannot be read.

---

## 6. (Optional) Proxmox firewall rules

The script doesn't set up a firewall inside a container. To limit what can reach it, use Proxmox's firewall instead.

1. Select the container → **Firewall → Add**, and add these rules. Each one is **Direction** `in`, **Action** `ACCEPT`, **Enable ✔**:

   | Protocol | Dest. port | Purpose |
   |---|---|---|
   | tcp | 22 | SSH (optional) |
   | tcp | 8631 | SavaPage HTTP / IPP printing |
   | tcp | 8632 | SavaPage HTTPS |
   | tcp | 9100 | RAW printing |
   | udp | 5353 | mDNS printer discovery |

2. Under the container's **Firewall → Options**, set **Firewall: Yes** and **Input Policy: DROP**.

> ⚠️ Container firewall rules only take effect when the firewall is also on at **Datacenter → Firewall → Options**. Before you turn that on, check that your Datacenter rules still allow you into the Proxmox web UI (port 8006) and SSH. Otherwise you can lock yourself out of the host.

---

## 7. Next steps

Everything after this is the same as on a VM. Run commands in the container's console, or prefix them with `pct exec 120 --` on the host. You're root in the container, so leave out `sudo`.

- [After installation](INSTALL-VM.md#7-after-installation): locale, users, adding printers
- [Printing to SavaPage from devices](INSTALL-VM.md#8-printing-to-savapage-from-devices)
- [Redirect HTTP to HTTPS (optional)](INSTALL-VM.md#redirect-http-to-https-optional)
- [Everyday commands](INSTALL-VM.md#everyday-commands) and [Security](INSTALL-VM.md#security)

---

## How the script handles containers

The script detects LXC automatically. Compared with a VM, it:

- **skips ufw**, which doesn't work reliably in unprivileged containers, and prints the ports to allow in Proxmox instead;
- **adjusts Avahi** (comments out `rlimit-nproc`) so printer discovery can start in a container;
- **warns** if system services have failed, which usually means *Nesting* is off.

Everything else (Java 21, CUPS locked to the container itself, the checksum-verified SavaPage 1.7.0 install) is the same as on a VM. See [What the script changes](INSTALL-VM.md#what-the-script-changes).

## Options

Put these in front of `bash`. For example, to turn on the HTTP-to-HTTPS redirect:

```bash
pct exec 120 -- env HTTPS_REDIRECT=1 bash /root/savapage-easy-install/install-savapage.sh
```

| Variable | Default | Effect |
|---|---|---|
| `HTTPS_REDIRECT=1` | off | Sends browsers on `http://…:8631` to the HTTPS page. See [details](INSTALL-VM.md#redirect-http-to-https-optional). |
| `SKIP_FIREWALL=0` | (skipped in containers) | Tries to set up ufw inside the container anyway. |
| `SAVAPAGE_VERSION` | `1.7.0-final` | Installs a different SavaPage release. |

## Moving the container to another site

- **Moving the whole Proxmox machine?** Nothing to do. Then follow [Moving the server](INSTALL-VM.md#moving-the-server-to-another-location) to update IP addresses.
- **Moving just the container?** Back it up with **Container → Backup → Backup now** (or `vzdump 120`). Copy the backup file to the new Proxmox host and restore it there with **Storage → Backups → Restore**.

In the new network, reserve a fixed IP for the container in the router, so client devices keep working.

## Troubleshooting

| Problem | Fix |
|---|---|
| Services fail, or *"Some systemd units have failed"* | Turn on **Options → Features → Nesting**, restart the container and run the script again. |
| `avahi-daemon` won't start | Comment out `rlimit-nproc` in `/etc/avahi/avahi-daemon.conf`, then `systemctl restart avahi-daemon`. The script normally does this for you. |
| `pct push`: *no such file* | The script isn't on the Proxmox host yet, or it's in a different folder. Check with `ls /root/`. |
| `bash\r: No such file or directory` | Windows line endings. In the container, run `sed -i 's/\r$//' /root/install-savapage.sh` and try again. |
| `sudo: unable to resolve host` | Harmless. You're root in the container, so `sudo` isn't needed. |
| "invalid response" in the browser | Use **`https://`**CONTAINER-IP:8632/admin, not `http://`. |
| Can't reach the web page | Check the IP with `pct exec 120 -- hostname -I`. If you turned on the Proxmox firewall, check the rules in [step 6](#6-optional-proxmox-firewall-rules). |

More problems are covered in the [VM guide's troubleshooting](INSTALL-VM.md#troubleshooting).

## Uninstall

The easiest way is to delete the container: **Container → More → Remove**. Back up `encryption.properties` and `/opt/savapage/server/data/` first if you might need them.

### Keep the container, remove only SavaPage: the uninstall script

Run this on the Proxmox host. `ASSUME_YES=1` is needed with `pct exec`, because there's no way to type `yes` there.

If you cloned from GitHub (recommended):

```bash
pct exec 120 -- env ASSUME_YES=1 bash /root/savapage-easy-install/uninstall-savapage.sh
```

If you copied the scripts with PowerShell or WinSCP (Options B or C in [step 3](#3-get-the-scripts-into-the-container)):

```bash
pct exec 120 -- env ASSUME_YES=1 bash /root/uninstall-savapage.sh
```

The script:

- backs up the data folder (including `encryption.properties`) to `/root/savapage-backup-DATE.tar.gz` inside the container;
- runs SavaPage's own uninstaller and removes the leftovers;
- **checks that the container is clean** and ready for a reinstall, printing **PASS** or **FAIL** for each check.

Copy the backup out to the Proxmox host. Use the file name the script printed:

```bash
pct pull 120 /root/savapage-backup-DATE.tar.gz /root/savapage-backup-DATE.tar.gz
```

When every check says PASS, you can reinstall at any time with [step 4](#4-run-the-installer). For the other options (`SKIP_BACKUP=1`, `RESTORE_CUPS=1`), see the [VM guide](INSTALL-VM.md#the-easy-way-the-uninstall-script). Put them after `env`.

<details>
<summary>Manual uninstall in one command, without the script</summary>

This runs SavaPage's own uninstaller, answering its *"yes or no"* question for you. Then it deletes the folder, the account and SavaPage's login (PAM) file. It makes **no backup**.

```bash
pct exec 120 -- bash -c 'cd /opt/savapage && echo yes | ./uninstall && cd / && rm -rf /opt/savapage /etc/pam.d/savapage && userdel savapage'
```

</details>
