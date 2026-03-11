# server

A combined NixOS server configuration running an
[AT Protocol](https://atproto.com) Personal Data Server (PDS) and a
[Mastodon](https://joinmastodon.org) instance on the same machine, exposed
to the internet via a [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/).

---

## What's included

- **PDS** (`modules/pds.nix`) — the official `bluesky-pds` daemon, proxied by nginx
- **Mastodon** (`modules/mastodon.nix`) — ActivityPub-compatible microblogging, nginx vhost managed by the NixOS module
- **Cloudflare Tunnel** (`modules/cloudflare-tunnel.nix`) — single outbound tunnel routing both hostnames; no inbound ports beyond SSH
- **nginx** — shared reverse proxy; serves plain HTTP on localhost; Cloudflare terminates TLS at the edge
- **SSH** — hardened, key-only
- **fail2ban** — bans IPs that hammer SSH
- **Firewall** — port 22 only (no 80/443 needed server-side)

---

## File layout

```
hosts/server/
├── default.nix                  # host skeleton — boot, network, user, SSH, nginx, nix
├── hardware-configuration.nix   # generated from your hardware — replace the stub
├── README.md                    # this file
└── modules/
    ├── cloudflare-tunnel.nix    # cloudflared service + ingress rules for both hostnames
    ├── pds.nix                  # bluesky-pds + nginx vhost
    └── mastodon.nix             # mastodon + nginx vhost overrides
```

---

## Prerequisites

Before you start you need:

- A server or VPS with a public IP (any cloud provider)
- A domain managed by Cloudflare (free plan is fine)
- Two DNS hostnames pointing at the same server — these will become CNAMEs to the tunnel (see [Cloudflare Tunnel setup](#cloudflare-tunnel-setup) below)
- An SSH key pair on your local machine (`ssh-keygen -t ed25519` if you don't have one)
- `cloudflared` on your local machine:
  ```bash
  # macOS
  brew install cloudflared
  # NixOS / Linux
  nix-shell -p cloudflared
  ```

---

## Cloudflare Tunnel setup

Do this on your **local machine** before deploying. You need your domain on Cloudflare first.

### 1. Authenticate

```bash
cloudflared tunnel login
```

A browser window opens. Select the domain you want to use.

### 2. Create the tunnel

```bash
cloudflared tunnel create server
```

Note the UUID printed — you'll put it in `modules/cloudflare-tunnel.nix` as `tunnelId`.
The credentials JSON is saved to `~/.cloudflared/<uuid>.json`.

### 3. Add DNS records in Cloudflare

In the Cloudflare dashboard for your domain, add two CNAMEs:

| Type  | Name     | Target                          | Proxy status |
|-------|----------|---------------------------------|--------------|
| CNAME | `pds`    | `<uuid>.cfargotunnel.com`       | Proxied      |
| CNAME | `social` | `<uuid>.cfargotunnel.com`       | Proxied      |

Replace `pds` and `social` with whatever subdomains match your chosen hostnames.

### 4. Set SSL/TLS mode

In the Cloudflare dashboard: **SSL/TLS → Overview → Full** (not "Full (strict)").

nginx serves plain HTTP on localhost; Cloudflare handles TLS at the edge.
"Full (strict)" would fail because there is no valid cert server-side.

### 5. Update the configuration

In `modules/cloudflare-tunnel.nix`, set:

```nix
tunnelId        = "<your-tunnel-uuid>";
pdsHostname      = "pds.example.com";     # your actual PDS domain
mastodonHostname = "social.example.com";  # your actual Mastodon domain
```

Also update the matching `hostname` values in `modules/pds.nix` and
`modules/mastodon.nix` — all three must agree.

---

## First-time installation

### 1. Install NixOS on the server

Boot from the [Minimal ISO](https://nixos.org/download) and verify connectivity:

```bash
ping nixos.org
```

Partition and format the disk (replace `vda` with your disk from `lsblk`):

```bash
sudo parted /dev/vda -- mklabel gpt
sudo parted /dev/vda -- mkpart root ext4 512MB 100%
sudo parted /dev/vda -- mkpart ESP fat32 1MB 512MB
sudo parted /dev/vda -- set 2 esp on

sudo mkfs.ext4 -L nixos /dev/vda1
sudo mkfs.fat -F 32 -n boot /dev/vda2
```

Mount:

```bash
sudo mount /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/boot
sudo mount -o umask=077 /dev/disk/by-label/boot /mnt/boot
```

Generate hardware config:

```bash
sudo nixos-generate-config --root /mnt
```

### 2. Clone this repo

```bash
nix-shell -p git
git clone https://github.com/ewanc26/nix-starter.git /mnt/etc/nixos
```

### 3. Copy the hardware config

```bash
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/etc/nixos/hosts/server/hardware-configuration.nix
```

### 4. Edit the configuration

There are four places to fill in your details. Open each file and update the
values marked `TODO`.

**`hosts/server/default.nix`**:
```nix
adminUser = "yourname";
```
And replace the placeholder SSH key:
```nix
openssh.authorizedKeys.keys = [
  "ssh-ed25519 AAAA... you@yourhost"
];
```
Your public key is in `~/.ssh/id_ed25519.pub` on your local machine.

**`hosts/server/modules/cloudflare-tunnel.nix`**:
```nix
tunnelId         = "<your-tunnel-uuid>";
pdsHostname      = "pds.example.com";
mastodonHostname = "social.example.com";
```

**`hosts/server/modules/pds.nix`**:
```nix
hostname   = "pds.example.com";
adminEmail = "you@example.com";
```

**`hosts/server/modules/mastodon.nix`**:
```nix
hostname = "social.example.com";
```
And your SMTP details:
```nix
smtp = {
  host        = "smtp.yourprovider.com";
  port        = 587;
  user        = "mastodon@example.com";
  fromAddress = "notifications@social.example.com";
};
```

### 5. Install

```bash
sudo nixos-install --flake /mnt/etc/nixos#server --root /mnt
```

Set a root password when prompted, then set your user password:

```bash
sudo nixos-enter --root /mnt
passwd yourname
exit
```

### 6. Reboot

```bash
sudo reboot
```

SSH in after reboot:

```bash
ssh yourname@<server-ip>
```

---

## Secrets

Neither service will start until their secret files exist on the server.
Create them after first boot, before starting anything.

### PDS secrets

The PDS needs three values that must not be committed to git.

Generate them:

```bash
openssl rand --hex 16   # PDS_JWT_SECRET
openssl rand --hex 16   # PDS_ADMIN_PASSWORD
openssl ecparam -name secp256k1 -genkey -noout \
  | openssl ec -text -noout 2>/dev/null \
  | grep priv -A 3 \
  | tail -3 \
  | tr -d ' \n:' \
  | sed 's/^00//'       # PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX
```

Create the env file:

```bash
sudo mkdir -p /var/lib/pds
sudo nano /var/lib/pds/pds.env
```

Contents:

```env
PDS_JWT_SECRET=<output of first command>
PDS_ADMIN_PASSWORD=<output of second command>
PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX=<output of third command>
```

Lock it down:

```bash
sudo chown bluesky-pds:bluesky-pds /var/lib/pds/pds.env
sudo chmod 400 /var/lib/pds/pds.env
```

### Mastodon secrets

Mastodon needs four secret files plus an SMTP password file.

```bash
sudo mkdir -p /var/lib/mastodon/secrets

# Secret key base
sudo sh -c 'openssl rand -hex 64 > /var/lib/mastodon/secrets/secret-key-base'

# OTP secret
sudo sh -c 'openssl rand -hex 64 > /var/lib/mastodon/secrets/otp-secret'

# VAPID keys for Web Push notifications
nix-shell -p nodejs --run "node -e \"
  const {generateVAPIDKeys} = require('web-push');
  const k = generateVAPIDKeys();
  const fs = require('fs');
  fs.writeFileSync('/var/lib/mastodon/secrets/vapid-private-key', k.privateKey);
  fs.writeFileSync('/var/lib/mastodon/secrets/vapid-public-key',  k.publicKey);
\""

# SMTP password (one line, no trailing newline)
sudo sh -c 'echo -n "your-smtp-password" > /var/lib/mastodon/secrets/smtp-password'

# Fix ownership and permissions
sudo chown -R mastodon:mastodon /var/lib/mastodon/secrets
sudo chmod 400 /var/lib/mastodon/secrets/*
```

### Cloudflare Tunnel credentials

Copy the credentials JSON from your local machine to the server:

```bash
# Create the directory on the server
ssh yourname@<server-ip> \
  "sudo mkdir -p /var/lib/cloudflared && \
   sudo chown cloudflared:cloudflared /var/lib/cloudflared"

# Copy the credentials file
scp ~/.cloudflared/<uuid>.json \
    yourname@<server-ip>:/tmp/<uuid>.json

# Move it into place on the server
ssh yourname@<server-ip> \
  "sudo mv /tmp/<uuid>.json /var/lib/cloudflared/<uuid>.json && \
   sudo chown cloudflared:cloudflared /var/lib/cloudflared/<uuid>.json && \
   sudo chmod 400 /var/lib/cloudflared/<uuid>.json"
```

---

## Starting the services

Once all secrets are in place, start everything:

```bash
sudo systemctl start bluesky-pds
sudo systemctl start mastodon-web mastodon-sidekiq mastodon-streaming
sudo systemctl start cloudflared-tunnel-<uuid>
```

Check status:

```bash
sudo systemctl status bluesky-pds
sudo systemctl status mastodon-web
sudo systemctl status mastodon-sidekiq
sudo systemctl status mastodon-streaming
sudo systemctl status cloudflared-tunnel-<uuid>
```

Verify through the tunnel:

```bash
curl https://pds.example.com/xrpc/_health
# {"version":"..."}

curl https://social.example.com/api/v1/instance
# JSON with instance info
```

---

## Creating accounts

### First PDS account

```bash
goat account create \
  --pds-host https://pds.example.com \
  --handle yourhandle.pds.example.com \
  --email you@example.com \
  --invite-code $(goat admin invite-code create \
      --pds-host https://pds.example.com \
      --admin-password <your PDS_ADMIN_PASSWORD>)
```

### First Mastodon admin account

```bash
sudo -u mastodon mastodon-env bundle exec bin/tootctl accounts create \
  youruser \
  --email you@example.com \
  --confirmed \
  --role Owner
```

---

## Ongoing maintenance

### Applying configuration changes

After editing any `.nix` file:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#server
```

### Updating packages

The package versions are pinned to the `nixpkgs` input. To update:

```bash
cd /etc/nixos
sudo nix flake update
sudo nixos-rebuild switch --flake /etc/nixos#server
```

### Rolling back

```bash
sudo nixos-rebuild switch --rollback
```

Or reboot and select an older generation from the boot menu.

### Viewing logs

```bash
sudo journalctl -u bluesky-pds -f
sudo journalctl -u mastodon-web -f
sudo journalctl -u mastodon-sidekiq -f
sudo journalctl -u mastodon-streaming -f
sudo journalctl -u nginx -f
sudo journalctl -u cloudflared-tunnel-<uuid> -f
```

### Backing up

Everything important lives in `/var/lib/pds/` and `/var/lib/mastodon/`.
Back them up regularly.

```bash
# PDS — database and secrets
sudo tar -czf pds-backup-$(date +%Y%m%d).tar.gz /var/lib/pds/

# Mastodon — PostgreSQL database
sudo pg_dump mastodon_production | gzip > mastodon-db-$(date +%Y%m%d).sql.gz

# Mastodon — media uploads and secrets
sudo tar -czf mastodon-data-$(date +%Y%m%d).tar.gz \
  /var/lib/mastodon/secrets \
  /var/lib/mastodon/public/system
```

Losing `/var/lib/pds/` means losing all accounts on your PDS and the ability
to recover them. Losing the Mastodon database means losing all posts, follows,
and account data. Back both up off-server.

---

## Traffic flow

```
Browser
  │  HTTPS
  ▼
Cloudflare edge  ←──── cloudflared (outbound from server)
  │  HTTP (Host: pds.example.com or social.example.com)
  ▼
nginx :80 (localhost)
  ├── pds.example.com     → bluesky-pds :3000
  └── social.example.com  → mastodon-web / mastodon-streaming
```

nginx never sees raw HTTPS; Cloudflare decrypts at the edge and forwards plain
HTTP tagged with the original `Host` header. nginx uses that header to route to
the right backend.

---

## Getting help

- AT Proto PDS docs: https://atproto.com/guides/self-hosting
- Mastodon admin docs: https://docs.joinmastodon.org/admin/
- Cloudflare Tunnel docs: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/
- NixOS `bluesky-pds` options: https://search.nixos.org/options?query=bluesky-pds
- NixOS `mastodon` options: https://search.nixos.org/options?query=mastodon
- NixOS manual: https://nixos.org/manual/nixos/stable
- NixOS Discourse: https://discourse.nixos.org
