# Homedash Proxmox VE installer

Creates a **Debian 13** LXC on your Proxmox host, installs **Docker + Compose**, then builds and runs Homedash.

## Copy the installer package to Proxmox VE

Replace `PVE_HOST` with the hostname or IP address of the desired Proxmox VE
host. These commands copy the installer, package, and checksum into
`/root/homedash-pve/` on that host.

### Linux or macOS desktop

Run from the Homedash project directory:

```bash
ssh root@PVE_HOST 'mkdir -p /root/homedash-pve'
scp homedash-pve-install.sh \
  homedash-pve-package.tar.gz \
  homedash-pve-package.tar.gz.sha256 \
  root@PVE_HOST:/root/homedash-pve/
ssh root@PVE_HOST
```

### Windows desktop using PowerShell

Windows 10 and 11 normally include the OpenSSH `ssh` and `scp` commands. Open
PowerShell in the folder containing the three generated files and run:

```powershell
ssh root@PVE_HOST "mkdir -p /root/homedash-pve"
scp homedash-pve-install.sh homedash-pve-package.tar.gz homedash-pve-package.tar.gz.sha256 root@PVE_HOST:/root/homedash-pve/
ssh root@PVE_HOST
```

After connecting to the Proxmox host:

```bash
cd /root/homedash-pve
bash homedash-pve-install.sh homedash-pve-package.tar.gz
```

If the Proxmox host uses a nonstandard SSH port, add `-p PORT` to `ssh` and
`-P PORT` to `scp`.

## Build an uploadable package

From the Homedash project root:

```bash
./pve.build.sh
```

This creates `homedash-pve-package.tar.gz`, its SHA-256 checksum, and the
companion `homedash-pve-install.sh`. The package
contains sanitized source, the PVE/LXC installer, and no runtime data or saved
credentials. Upload all three files to the Proxmox host, then run as root:

```bash
bash homedash-pve-install.sh homedash-pve-package.tar.gz
```

The wizard prompts for the Homedash administrator username and password. The
fresh dashboard starts with Clock, Weather, Notes, Todo, Grocery List, and
Bookmarks only; other widgets can be imported after login using `.hdwidget`
packages.

For convenient transfer, the build also creates `homedash-pve-bundle.zip` and
`homedash-pve-bundle.zip.sha256`. The ZIP contains:

- `PVE-INSTALL-README.md`
- `homedash-pve-install.sh`
- `homedash-pve-package.tar.gz`
- `homedash-pve-package.tar.gz.sha256`

## Install modes

Running `bash pve/homedash.sh` opens a whiptail menu (same style as community-scripts):

1. **Default Install** — Homedash defaults (Debian 13, Docker nesting, 2 CPU / 4 GB / 16 GB)
2. **Advanced Install** — step-by-step wizard, starting with container type and **root password**, then CTID, hostname, disk/CPU/RAM, bridge, IPv4/IPv6, MTU/DNS/MAC/VLAN, tags, SSH, FUSE/TUN/nesting/keyctl, GPU/mknod/protection/timezone, Homedash source + port, verbose, and a final confirmation

Skip the menu with:

```bash
bash pve/homedash.sh default
bash pve/homedash.sh advanced
# or: METHOD=advanced bash pve/homedash.sh
```

## What you get

| Item | Default |
|------|---------|
| OS | Debian 13 (Trixie) |
| Type | Unprivileged LXC |
| Features | `nesting=1`, `keyctl=1`, `fuse=1` (required for Docker) |
| CPU / RAM / Disk | 2 / 4096 MiB / 16 GB |
| Root password | Blank = automatic console login (set in Advanced) |
| App path | `/opt/homedash` |
| Config volume | `/opt/homedash/data` → container `/config` |
| URL | `http://<ct-ip>:3080` |

## Prerequisites

1. Proxmox VE host with a Debian 13 LXC template available (`pveam`).
2. Homedash source as either:
   - a **git repo URL**, or
   - a **packed tarball** (recommended if the project is not on GitHub yet).

If your host complains about unsupported Debian 13, update Proxmox first:

```bash
apt update && apt install --only-upgrade pve-container -y
```

## Option A — Pack source, then install (no public git repo)

On the machine that has Homedash:

```bash
cd /path/to/homedash
bash pve/pack-source.sh
# creates ./homedash-source.tar.gz
```

**Always run `pack-source.sh` before copying to Proxmox.** Do not reuse an old tarball from your dev checkout — it may contain your personal `data/` (layouts, widget API keys, auth). The pack script excludes `data/`, secrets, and compliance reports; the guest installer also wipes any leaked runtime files and creates an empty `/opt/homedash/data` volume.

```bash
scp -r pve homedash-source.tar.gz root@YOUR_PVE:/root/homedash-install/
```

On the Proxmox host:

```bash
cd /root/homedash-install
HOMEDASH_SOURCE_TAR=/root/homedash-install/homedash-source.tar.gz bash pve/homedash.sh
```

## Option B — Install from a git repository

```bash
# Copy only the pve/ folder to the Proxmox host, then:
HOMEDASH_REPO=https://github.com/YOU/homedash.git \
HOMEDASH_BRANCH=main \
bash pve/homedash.sh
```

## Non-interactive example

```bash
CTID=150 \
HN=homedash \
CORE_COUNT=2 \
RAM_SIZE=4096 \
DISK_SIZE=16 \
BRIDGE=vmbr0 \
STORAGE=local-lvm \
TEMPLATE_STORAGE=local \
NET=dhcp \
HOMEDASH_SOURCE_TAR=/root/homedash-source.tar.gz \
HOMEDASH_PORT=3080 \
bash pve/homedash.sh
```

Static IP:

```bash
NET=192.168.1.50/24 GATEWAY=192.168.1.1 bash pve/homedash.sh
```

## After install

```bash
pct enter <CTID>
cd /opt/homedash
docker compose ps
docker compose logs -f
```

Rebuild after updating source:

```bash
cd /opt/homedash
# git pull   # if using a repo
docker compose up -d --build
```

## Guest-only reinstall

If the LXC already exists and you only want to re-run the app installer:

```bash
pct push <CTID> pve/install/homedash-install.sh /root/homedash-install.sh
pct push <CTID> pve/homedash-source.tar.gz /tmp/homedash-source.tar.gz
pct exec <CTID> -- env HOMEDASH_SOURCE_TAR=/tmp/homedash-source.tar.gz \
  bash /root/homedash-install.sh
```

### Reset to a clean dashboard (remove leaked personal data)

If a dev tarball seeded your personal dashboard into the CT:

```bash
pct exec <CTID> -- bash -lc 'cd /opt/homedash && docker compose down'
pct exec <CTID> -- rm -rf /opt/homedash/data
pct exec <CTID> -- env HOMEDASH_SOURCE_TAR=/tmp/homedash-source.tar.gz bash /root/homedash-install.sh
```

Then open `http://<ct-ip>:3080/setup` to create a new admin account.

## Notes

- First Docker build compiles Next.js inside the CT and can take several minutes.
- Persistent settings live in `/opt/homedash/data` (mapped to `/config` in the container).
- Icons are bind-mounted from `/opt/homedash/icons`.

## Authentication

Homedash is behind a login wall:

1. First visit (no users yet) → `/setup` to create the admin username/password.
2. Later visits → `/login`. Session cookie lasts 14 days.
3. Logout from the header (desktop) or mobile menu.
4. Change password under **Settings → General → Account**.

Optional env (in `docker-compose.yml`):

| Variable | Purpose |
|----------|---------|
| `HOMEDASH_SESSION_SECRET` | Pin the HMAC secret (otherwise stored in `data/session-secret`) |
| `HOMEDASH_ADMIN_USER` + `HOMEDASH_ADMIN_PASSWORD` | Seed the first admin when `data/auth.json` is missing |

Auth data: `data/auth.json` (password hashes only — never plaintext).
