# as-the-gods-intended

A minimal, TUI-based NixOS laptop config. No desktop environment — just a
clean terminal experience with a curated set of tools.

Everything is declared in two files in this directory — `default.nix` for
system settings and `home.nix` for user tools and config. Nothing needs to
be manually created or copied anywhere. If you want to change something,
edit the relevant file and rebuild.

---

## What is NixOS?

NixOS is a Linux distribution where the entire system — every package, every
config file, every service — is declared in a set of files. Instead of running
`apt install` or editing `/etc/...` files by hand, you describe what you want,
then rebuild. If something goes wrong, you can roll back to the previous working
state from the boot menu.

The trade-off: it's different from every other Linux distro. This README will
walk you through the whole process.

---

## What's included

- **Shell:** zsh
- **Editor:** Helix (`hx`) — a modern terminal editor (think Vim, but with
  sane defaults and built-in language support)
- **Git:** git
- **File tools:** eza (better `ls`), bat (better `cat`), ripgrep (`rg`),
  fd, fzf, tree
- **System:** btop (task manager), tmux (terminal multiplexer), wget, curl,
  rsync, unzip/zip
- **System info:** fastfetch (the pretty system summary on login)
- **Hardware:** arduino-cli

---

## First-time installation

### 1. Download the NixOS installer

Go to https://nixos.org/download and download the **Minimal ISO image**
(not the Graphical one — you won't need it).

Flash it to a USB stick. On Linux/macOS:

```bash
sudo dd if=nixos-*.iso of=/dev/sdX bs=4M status=progress
```

Replace `/dev/sdX` with your USB device (`lsblk` will show you which one).
On Windows, use [Rufus](https://rufus.ie) or [Balena Etcher](https://etcher.balena.io).

### 2. Boot from the USB

Restart the laptop, enter the boot menu (usually F12, F2, or Delete — depends
on the machine), and select the USB. You'll land at a terminal prompt.

### 3. Connect to the internet

If you're on Wi-Fi:

```bash
sudo systemctl start wpa_supplicant
wpa_cli
```

Inside `wpa_cli`:

```
add_network
set_network 0 ssid "YourNetworkName"
set_network 0 psk "YourPassword"
enable_network 0
quit
```

Ethernet will work automatically. Check connectivity with `ping nixos.org`.

### 4. Partition the disk

Find your disk name:

```bash
lsblk
```

It'll be something like `nvme0n1` (NVMe SSD) or `sda` (SATA).

Partition it (replace `nvme0n1` with your disk):

```bash
sudo parted /dev/nvme0n1 -- mklabel gpt
sudo parted /dev/nvme0n1 -- mkpart root ext4 512MB 100%
sudo parted /dev/nvme0n1 -- mkpart ESP fat32 1MB 512MB
sudo parted /dev/nvme0n1 -- set 2 esp on
```

Format the partitions:

```bash
sudo mkfs.ext4 -L nixos /dev/nvme0n1p1
sudo mkfs.fat -F 32 -n boot /dev/nvme0n1p2
```

Mount them:

```bash
sudo mount /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/boot
sudo mount -o umask=077 /dev/disk/by-label/boot /mnt/boot
```

### 5. Generate hardware config

This detects your hardware and writes a config file for it:

```bash
sudo nixos-generate-config --root /mnt
```

This creates `/mnt/etc/nixos/hardware-configuration.nix`. You'll copy it into
the repo in step 7.

### 6. Clone this repo onto the machine

```bash
nix-shell -p git
git clone https://github.com/ewanc26/nix-starter.git /mnt/etc/nixos
```

### 7. Replace the hardware config

```bash
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/etc/nixos/hosts/as-the-gods-intended/hardware-configuration.nix
```

### 8. Set your username

The placeholder username is `friend`. You need to replace it in two files.

In `default.nix`:

```bash
nano /mnt/etc/nixos/hosts/as-the-gods-intended/default.nix
```

Find and replace:

```nix
users.users.friend = {
```

In `home.nix`, find and replace all three occurrences:

```bash
nano /mnt/etc/nixos/hosts/as-the-gods-intended/home.nix
```

```nix
home-manager.users.friend = {
  home.username = "friend";
  home.homeDirectory = "/home/friend";
```

Save and exit each file with `Ctrl+O`, `Enter`, `Ctrl+X`.

Also update `git.userName` and `git.userEmail` in `home.nix` while you're there.

### 9. Install

```bash
sudo nixos-install --flake /mnt/etc/nixos#as-the-gods-intended --root /mnt
```

It will ask you to set a root password at the end. Set one (you can change
it later) and don't forget it.

Then set a password for your user:

```bash
sudo nixos-enter --root /mnt
passwd your-username
exit
```

### 10. Reboot

```bash
sudo reboot
```

Remove the USB when prompted. The system will boot into a login prompt.
Log in with the username and password you set.

---

## After installation

### Making changes

There are two config files:

- `default.nix` — system-level settings (hostname, locale, boot, SSH, system packages)
- `home.nix` — everything user-facing (shell, git, editor, aliases, tool settings)

For most day-to-day changes — tweaking a setting, changing an alias, adding a
package — you'll only need to touch `home.nix`. To add a new tool and configure
it, install it via `home.packages` and add its `programs.<name>` block:

```nix
home.packages = with pkgs; [ mycli ];

programs.mycli = {
  enable = true;
  # settings go here
};
```

For packages without a home-manager module, just add them to `home.packages`
or `environment.systemPackages` in `default.nix`.

After any change, apply it with the `nrs` alias (set up in your shell):

```bash
nrs
```

Or explicitly:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#as-the-gods-intended
```

### Enabling the desktop

The system installs as a pure TUI environment by default. To get a minimal
KDE Plasma 6 desktop, open `default.nix` and change the one line at the top:

```nix
enableDesktop = true;
```

Then rebuild:

```bash
nrs
```

On next boot, SDDM will appear and you can log into a Plasma Wayland session.
Heavy bundled apps (Kmail, Kontact, Elisa, etc.) are excluded to keep the
install size down. You can add them back in `environment.systemPackages` if
you want them later.

To go back to TUI-only, set `enableDesktop = false` and rebuild again.

### Rolling back

If a rebuild breaks something, reboot and select an older generation from the
boot menu. Once you're back in a working state, you can run:

```bash
sudo nixos-rebuild switch --rollback
```

### Searching for packages

```bash
nix search nixpkgs <name>
```

Or browse https://search.nixos.org/packages.

### Tool configuration

All tool config is declared in `home.nix` — nothing lives in dotfiles or
needs to be touched in `~/.config/`. When you rebuild, every setting is
applied automatically.

The configured tools and where to find their settings in `home.nix`:

| Tool | Section |
|------|---------|
| zsh | `programs.zsh` — history, aliases, fzf integration |
| git | `programs.git` — update name/email here before first use |
| tmux | `programs.tmux` — prefix, mouse, pane keys, status bar |
| bat | `programs.bat` — colour theme, line number style |
| btop | `programs.btop` — update interval, layout, sorting |
| fastfetch | `programs.fastfetch` — which info modules to show |
| helix | `programs.helix` — editor settings and language config |

### Helix configuration

If you have settings you prefer over the defaults, edit the `programs.helix`
block in `home.nix` and rebuild. No files to copy — the config is generated
from whatever is in that block.

---

## Getting help

- NixOS manual: https://nixos.org/manual/nixos/stable
- Package search: https://search.nixos.org/packages
- Options search: https://search.nixos.org/options
- Home Manager options: https://nix-community.github.io/home-manager/options.xhtml
- NixOS Discourse (forum): https://discourse.nixos.org — friendly to beginners
