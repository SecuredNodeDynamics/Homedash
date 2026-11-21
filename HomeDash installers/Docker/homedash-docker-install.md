# Installing Homedash on your Docker server

This guide gets Homedash running on any Linux server that already has Docker. You'll need the `homedash-source.tar.gz` file you were given.

## What you need

- A Linux server with **Docker Engine** and the **Docker Compose plugin** (`docker compose`, not the old `docker-compose`)
- Root or `sudo` access on that server
- About 2 GB of free RAM during the first build, and a few GB of disk
- Port **3080** free (you can change it below)

Check Docker and Compose on the server:

```bash
docker --version
docker compose version
```

If either command fails, install Docker first: https://docs.docker.com/engine/install/

---

## Step 1 — Copy the file to your server

Replace `SERVER_IP` and `youruser` with your server's address and login.

**From Linux or macOS:**

```bash
scp homedash-source.tar.gz youruser@SERVER_IP:~/
```

**From Windows (PowerShell):**

```powershell
scp homedash-source.tar.gz youruser@SERVER_IP:~/
```

If your server uses a non-standard SSH port, add `-P PORT` after `scp`.

Then log in to the server:

```bash
ssh youruser@SERVER_IP
```

---

## Step 2 — Unpack it

Homedash should live in `/opt/homedash`. Please use this exact location if you plan to install widget packages later (see Step 6), because the widget agent expects it.

```bash
sudo mkdir -p /opt/homedash
sudo tar -xzf ~/homedash-source.tar.gz -C /opt/homedash
cd /opt/homedash
ls
```

You should see `Dockerfile`, `docker-compose.yml`, `package.json`, and a `src` folder. If you only see a single folder instead, the archive was wrapped. Move its contents up one level:

```bash
sudo bash -c 'shopt -s dotglob && mv /opt/homedash/*/* /opt/homedash/ && rmdir /opt/homedash/*/' 
```

---

## Step 3 — Create the data folders

Homedash stores your settings, login, and uploads in `data/`, and uploaded icons in `icons/`. The container runs as a non-root user (uid 100), so those folders must be owned by it:

```bash
cd /opt/homedash
sudo mkdir -p data icons
sudo chown -R 100:101 data icons
```

---

## Step 4 — (Optional) Start with the core widgets

Skip this step if you're happy with the app's defaults.

To start with a clean dashboard containing Clock, Weather, Notes, Todo, Grocery List, and Bookmarks, create the settings file **before** the first start:

```bash
sudo tee /opt/homedash/data/settings.json >/dev/null <<'EOF'
{
  "appName": "Homedash",
  "tabs": [
    {
      "id": "home",
      "name": "Home",
      "order": 0,
      "widgetIds": ["clock", "weather", "notes", "todo", "grocery-list", "bookmarks"]
    }
  ],
  "enabledWidgets": ["clock", "weather", "notes", "todo", "grocery-list", "bookmarks"],
  "widgetInstances": [
    { "id": "clock", "widgetId": "clock", "key": "default", "label": "Clock" },
    { "id": "weather", "widgetId": "weather", "key": "default", "label": "Weather" },
    { "id": "notes", "widgetId": "notes", "key": "default", "label": "Notes" },
    { "id": "todo", "widgetId": "todo", "key": "default", "label": "Todo" },
    { "id": "grocery-list", "widgetId": "grocery-list", "key": "default", "label": "Grocery List" },
    { "id": "bookmarks", "widgetId": "bookmarks", "key": "default", "label": "Bookmarks" }
  ],
  "bookmarks": [],
  "bookmarkGroups": [{ "id": "general", "name": "General", "order": 0 }]
}
EOF
sudo chown -R 100:101 /opt/homedash/data
```

---

## Step 5 — Build and start

```bash
cd /opt/homedash
sudo docker compose up -d --build
```

The first build compiles the app inside Docker and **can take several minutes**. That's normal. Watch progress with:

```bash
sudo docker compose logs -f
```

Press `Ctrl+C` to stop watching the logs (this does not stop Homedash). When the build finishes, check that it's healthy:

```bash
sudo docker compose ps
```

The status should show `Up` and, after about 20 seconds, `healthy`.

### Create your admin account

Open this in your browser:

```
http://SERVER_IP:3080/setup
```

Choose an administrator username and password. After that, `http://SERVER_IP:3080` takes you to the login page. Sessions last 14 days, and you can change your password under **Settings → General → Account**.

> **Prefer no browser step?** Before starting, open `docker-compose.yml` and uncomment `HOMEDASH_ADMIN_USER` and `HOMEDASH_ADMIN_PASSWORD`, and fill them in. The admin is created on first start. Remove the password from the file afterward.

### Changing the port

Edit `docker-compose.yml`, find `"3080:3080"`, and change the **left** number (for example `"8080:3080"`). Then run `sudo docker compose up -d` again.

---

## Step 6 — (Optional) Enable widget package installs

Homedash can import extra widgets from `.hdwidget` packages. Installing them from the web interface requires a small helper service (the widget agent) on the server. Without it, everything else works, but widget imports won't.

Requirements: a Linux server using **systemd** with **Python 3** installed, and Homedash installed at `/opt/homedash`.

```bash
cd /opt/homedash
sudo HOMEDASH_DIR=/opt/homedash HOMEDASH_DATA_DIR=/opt/homedash/data \
  sh pve/widget-agent/install-agent.sh
```

If the last lines show `active (running)`, you're done. This will not work on systems without systemd, such as many NAS platforms (Synology, Unraid, TrueNAS). Homedash itself still runs fine there.

---

## Day-to-day commands

Run these from `/opt/homedash`:

| Task | Command |
|------|---------|
| See status | `sudo docker compose ps` |
| Follow logs | `sudo docker compose logs -f` |
| Restart | `sudo docker compose restart` |
| Stop | `sudo docker compose down` |
| Start again | `sudo docker compose up -d` |

## Updating to a new version

When you receive a new `homedash-source.tar.gz`, your settings are kept because they live in `data/`, outside the app code. First, back up your data:

```bash
cd /opt/homedash
sudo docker compose down
sudo tar -czf ~/homedash-data-backup.tar.gz data
```

Copy the new tarball to the server (Step 1), then extract it over the top. This only replaces app files, and your `data/` and `icons/` folders are not in the tarball:

```bash
sudo tar -xzf ~/homedash-source.tar.gz -C /opt/homedash
sudo chown -R 100:101 /opt/homedash/data /opt/homedash/icons
sudo docker compose up -d --build
```

## Backups

Everything personal is in `/opt/homedash/data` (settings, layouts, the login database, uploads). Back up that one folder:

```bash
sudo tar -czf ~/homedash-data-backup.tar.gz -C /opt/homedash data
```

To restore, extract it back into `/opt/homedash`, run `sudo chown -R 100:101 /opt/homedash/data`, and start the container.

## Troubleshooting

**The page won't load.**
Run `sudo docker compose ps`. If the container isn't `Up`, check `sudo docker compose logs`. Also check that your firewall allows port 3080 (for example `sudo ufw allow 3080/tcp` on Ubuntu).

**The build is killed or fails with an out-of-memory error.**
The first build needs roughly 2 GB of RAM. Close other heavy services temporarily, or add swap space, then run `sudo docker compose up -d --build` again.

**"Permission denied" or settings won't save.**
Re-run the ownership fix, then restart:

```bash
sudo chown -R 100:101 /opt/homedash/data /opt/homedash/icons
sudo docker compose restart
```

**I forgot my admin password.**
Stop the container, move the login file aside, and visit `/setup` again to create a new admin. Your other settings are unaffected:

```bash
cd /opt/homedash
sudo docker compose down
sudo mv data/auth.json data/auth.json.old
sudo docker compose up -d
```

**Widget imports fail.**
The widget agent from Step 6 isn't running. Check it with `systemctl status homedash-widget-agent`.

## A note on security

Homedash serves plain HTTP on port 3080. That's fine on a home or office network. If you want to reach it from the internet, put it behind a reverse proxy that provides HTTPS (such as Caddy, Nginx Proxy Manager, or Traefik) rather than opening port 3080 directly.

## Uninstalling

```bash
cd /opt/homedash
sudo docker compose down --rmi local
sudo systemctl disable --now homedash-widget-agent 2>/dev/null   # only if you installed it
sudo rm -rf /opt/homedash
```

This permanently deletes your Homedash data, so back up `data/` first if you want to keep it.
