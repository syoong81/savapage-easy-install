# SavaPage Easy Installer/Uninstaller for Debian / Ubuntu

A one-step install script for the [SavaPage](https://www.savapage.org/) print server (version **1.7.0**).

> **Made for personal use.** I wrote this script to set up my own print server and am sharing it as-is. It is not a commercial product, it comes with no support, and it is **not** made, endorsed or supported by the SavaPage project or Datraverse B.V. Read the [Disclaimer](#disclaimer) before you use it.

## What it does

[SavaPage](https://www.savapage.org/) is free, open-source print management software. Run it on a server and it gives you:

- a **web portal** where people upload documents to print,
- **secure / pull printing**: jobs wait until the user releases them at the printer,
- **print accounting and quotas** per user,
- one shared print queue that phones, tablets and computers can use without installing drivers.

Installing it by hand takes many steps: Java, CUPS, a system account, CUPS hardening, the installer, a root-only step, and the firewall. **`install-savapage.sh` does all of them for you.** It detects whether it's running on a normal machine or in an LXC container, and adjusts itself.

The setup isn't tied to any particular network, so you can set it up at one location and move it to another.

## How to install

Everything is in **[INSTALL.md](INSTALL.md)**, one guide for both a **VM / physical machine** and a **Proxmox LXC container**.

The short version, on a VM or physical machine:

```bash
sudo apt-get update && sudo apt-get install -y git
```

```bash
git clone https://github.com/syoong81/savapage-easy-install.git ~/savapage-easy-install && sudo bash ~/savapage-easy-install/install-savapage.sh
```

In a Proxmox LXC container's console you're root, so leave out `sudo`. Then open `http://SERVER-IP:8631/admin`, which redirects to HTTPS, log in as `admin` / `admin` and change the password.

## Supported systems

| System | Status |
|---|---|
| Debian 13 (trixie), Proxmox LXC container | ✅ Tested: install, ufw firewall, web apps, IPP printing, HTTPS redirect (on by default and turned off), re-running the script, start after reboot, uninstall script and reinstall |
| Ubuntu 26.04 LTS, Proxmox VM | ✅ Tested: install, ufw firewall, web apps, IPP printing, HTTPS redirect on by default, uninstall script (all options) and reinstall |
| Debian 12 (bookworm) | Supported, not yet tested |

The machine must be 64-bit Intel/AMD (x86_64). Raspberry Pi / ARM is not supported, because SavaPage only publishes x86_64 installers.

## Files

| File | What it is |
|---|---|
| `install-savapage.sh` | The install script |
| `uninstall-savapage.sh` | The uninstall script. It backs up your data, removes SavaPage and checks the machine is clean for a reinstall. |
| `INSTALL.md` | Step-by-step install guide for a VM / physical machine and a Proxmox LXC container |
| `LICENSE` | MIT License for these scripts and guides |

## License

The scripts and guides in this repository are released under the [MIT License](LICENSE). That license covers **only this repository**. SavaPage itself, which the script downloads, is licensed separately under the [GNU AGPL v3](https://www.gnu.org/licenses/agpl-3.0.html).

---

## Disclaimer

**Please read this carefully. By using this script, you accept these terms.**

1. **Personal project.** This script was made for personal use and is shared in the hope that it is useful. There is no support, maintenance commitment or guarantee of future updates.

2. **No warranty.** This script and its instructions are provided **"AS IS"**, without warranty of any kind, express or implied. That includes, but is not limited to, warranties of merchantability, fitness for a particular purpose, and non-infringement.

3. **Limitation of liability.** To the maximum extent permitted by law, the author and contributors are **not liable** for any claim, damages or other liability arising from the use of, or inability to use, this script or SavaPage. That covers, without limitation, data loss, downtime, security incidents, misprinted or lost documents, hardware damage, and lost profits. It applies whether the claim is in contract, tort or otherwise.

4. **You are responsible for your system.** The script changes system configuration: it installs packages, creates a user account, edits CUPS and Avahi settings, and (on a VM or physical machine) **turns on a firewall that blocks other incoming traffic**. Run it only on a machine you own or are authorized to administer. Ideally use a fresh, dedicated machine. **Back up anything important first.**

5. **Review before running.** The script runs with administrator (root) rights. Read it, or have someone you trust read it, before you run it. Test it on a non-production machine first.

6. **Security is your responsibility.** After installation, you must:
   - change the default `admin` / `admin` password **immediately**,
   - keep the operating system and SavaPage updated,
   - **never** expose SavaPage directly to the internet,
   - decide who may reach the server on your network.

7. **Privacy and data protection.** Print servers handle documents that may hold personal or confidential information, and SavaPage stores user names and print history. *You* are responsible for complying with the data-protection laws that apply to you (e.g. GDPR, HIPAA, FERPA) and with any relevant policies.

8. **Third-party software.** The script downloads software from Debian/Ubuntu package mirrors and from `download.savapage.org`. Each is covered by its own license and terms. **SavaPage is licensed under the [GNU AGPL v3](https://www.gnu.org/licenses/agpl-3.0.html)**, and you must comply with it. The script checks the SavaPage installer's SHA-512 checksum against the list published on the same download server. That guards against a corrupted download, but it **cannot** guarantee the software is free of defects or vulnerabilities.

9. **Not professional advice.** These instructions are general guidance, not legal, security or IT consulting advice.

10. **Trademarks.** SavaPage, Debian, Ubuntu and Proxmox are trademarks of their respective owners. They are used here only to identify the software, with no affiliation implied.
