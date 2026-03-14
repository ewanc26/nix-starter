# server — combined AT Protocol PDS + Mastodon server.
# Service-specific config lives in modules/pds.nix and modules/mastodon.nix.
# Both services are exposed via a Cloudflare Tunnel (modules/cloudflare-tunnel.nix) —
# no inbound ports beyond SSH are required.
# See README.md for setup instructions.
{ pkgs, ... }:
let
  # ── Configuration ─────────────────────────────────────────────────────────
  # TODO: set these before deploying.
  adminUser = "admin";  # your desired username

  # Shared PDS settings — single source of truth consumed by pds.nix and
  # pds-gatekeeper.nix via _module.args.pdsConfig.
  pdsConfig = {
    hostname   = "pds.example.com";  # TODO: your PDS hostname
    adminEmail = "you@example.com";  # TODO: your admin email
    dataDir    = "/srv/pds";
    port       = 3000;
  };
in
{
  _module.args.pdsConfig = pdsConfig;

  imports = [
    ./hardware-configuration.nix
    ./modules/cloudflare-tunnel.nix
    ./modules/pds.nix
    ./modules/pds-gatekeeper.nix
    ./modules/mastodon.nix
  ];

  # ── Boot ──────────────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.tmp.cleanOnBoot = true;

  # ── Networking ────────────────────────────────────────────────────────────
  networking.hostName = "server";
  networking.networkmanager.enable = true;

  # Cloudflared dials outbound — no inbound web ports needed.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  # ── Locale ────────────────────────────────────────────────────────────────
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_GB.UTF-8";
  console.keyMap = "uk";

  # ── User ──────────────────────────────────────────────────────────────────
  # TODO: replace adminUser above, then add your SSH public key below.
  # Password login is disabled — you must add a public key before deploying.
  users.users.${adminUser} = {
    isNormalUser = true;
    extraGroups  = [ "wheel" ];
    shell        = pkgs.bash;
    # TODO: replace with your actual SSH public key.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAA... you@yourhost"
    ];
  };

  # ── Packages ──────────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    atproto-goat  # official AT Proto account management CLI
    cloudflared   # tunnel CLI — useful for setup and inspection
    curl
    wget
    git
    jq
    htop
    nano
  ];

  # ── SSH — hardened, key-only ───────────────────────────────────────────────
  services.openssh = {
    enable = true;
    ports  = [ 22 ];
    settings = {
      PermitRootLogin              = "no";
      PasswordAuthentication       = false;
      KbdInteractiveAuthentication = false;
      MaxAuthTries                 = 3;
      ClientAliveInterval          = 300;
      ClientAliveCountMax          = 2;
      X11Forwarding                = false;
    };
  };

  # ── fail2ban — ban IPs that hammer SSH ────────────────────────────────────
  services.fail2ban = {
    enable   = true;
    maxretry = 5;
    jails.sshd.settings = {
      enabled  = true;
      port     = "22";
      filter   = "sshd";
      backend  = "systemd";
      maxretry = 5;
      findtime = 600;
      bantime  = 600;
    };
  };

  # ── nginx — shared reverse proxy ──────────────────────────────────────────
  # Serves plain HTTP on localhost only — Cloudflare terminates TLS at the edge.
  # Each module in modules/ merges its own virtualHost entries in here.
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedGzipSettings  = true;
    recommendedOptimisation   = true;
    # No recommendedTlsSettings — no server-side TLS with a CF tunnel.
  };

  # ── Maintenance ───────────────────────────────────────────────────────────
  services.fstrim.enable    = true;
  services.timesyncd.enable = true;

  services.journald.extraConfig = ''
    SystemMaxUse=500M
    MaxRetentionSec=1month
  '';

  # ── Nix ───────────────────────────────────────────────────────────────────
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store   = true;
  nix.gc = {
    automatic = true;
    dates     = "weekly";
    options   = "--delete-older-than 30d";
  };
  nix.settings.allowed-users = [ "root" "@wheel" ];

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11";
}
