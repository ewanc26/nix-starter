# as-the-gods-intended — system configuration.
# See home.nix for user-facing tool configuration.
# See README.md for setup instructions.
{ pkgs, lib, ... }:
let
  # ── Desktop toggle ──────────────────────────────────────────────────────────
  # Set to true to enable a minimal KDE Plasma 6 desktop environment.
  # Set to false (the default) for a pure TUI system with no display server.
  enableDesktop = false;
in
{
  imports = [
    ./hardware-configuration.nix
    ./home.nix
  ];

  # ── Boot ──────────────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.tmp.cleanOnBoot = true;

  # ── Networking ────────────────────────────────────────────────────────────
  networking.hostName = "as-the-gods-intended";
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  # ── Locale ────────────────────────────────────────────────────────────────
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "uk";
  };

  # ── User ──────────────────────────────────────────────────────────────────
  # TODO: replace "friend" with the actual username before deploying.
  # Also update home.nix (username and homeDirectory) to match.
  users.users.friend = {
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel"
    ] ++ lib.optionals enableDesktop [ "audio" "video" ];
    shell = pkgs.zsh;
  };

  # Enable zsh system-wide so it is a valid login shell.
  programs.zsh.enable = true;

  # ── System packages ───────────────────────────────────────────────────────
  # User-facing tools with configuration are managed declaratively in home.nix.
  # This list covers utilities useful to all users (including root) and tools
  # that don't have meaningful per-user config.
  environment.systemPackages = with pkgs; [
    nano
    wget
    curl
    rsync
    unzip
    zip
    tree
    ripgrep
    fd
    eza
    openssh
    arduino-cli
  ];

  # ── Desktop (optional) ────────────────────────────────────────────────────
  # Enabled by setting enableDesktop = true at the top of this file.
  # Provides a minimal KDE Plasma 6 session via Wayland + SDDM.
  # Heavy or unwanted KDE bundled apps are excluded to keep the install lean.
  services.xserver = lib.mkIf enableDesktop {
    enable = true;
    xkb.layout = "gb";
  };

  services.displayManager.sddm = lib.mkIf enableDesktop {
    enable = true;
    wayland.enable = true;
  };

  services.desktopManager.plasma6.enable = lib.mkIf enableDesktop true;

  environment.plasma6.excludePackages = lib.mkIf enableDesktop (with pkgs.kdePackages; [
    oxygen       # legacy theme
    elisa        # music player
    kmail        # email client
    kontact      # PIM suite
    korganizer   # calendar
    kaddressbook # contacts
    akregator    # RSS reader
    dragon       # video player
  ]);

  # Pipewire audio — only needed with a desktop session.
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = lib.mkIf enableDesktop true;
  services.pipewire = lib.mkIf enableDesktop {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # ── Services ──────────────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  # ── Nix ───────────────────────────────────────────────────────────────────
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11";
}
