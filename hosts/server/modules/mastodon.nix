# mastodon.nix — Mastodon module.
# Imported by hosts/server/default.nix.
# configureNginx = true lets the mastodon module inject its own nginx vhost
# (static files, WebSocket upgrades, streaming proxy) automatically.
# ACME and SSL are forced off — TLS is terminated at Cloudflare's edge.
{ lib, ... }:
let
  # ── Mastodon configuration ─────────────────────────────────────────────────
  # TODO: set these before deploying.
  hostname = "social.example.com";  # must match the ingress hostname in cloudflare-tunnel.nix

  # All Mastodon data lives on the dedicated /srv disk.
  # See hardware-configuration.nix for how to mount it.
  mastodonDataDir = "/srv/mastodon";

  # Secret files — create these on the server before starting Mastodon.
  # See README.md — "Mastodon secrets" — for generation commands.
  secretsDir = "/srv/mastodon/secrets";
in
{
  # ── Mastodon ──────────────────────────────────────────────────────────────
  services.mastodon = {
    enable      = true;
    localDomain = hostname;
    dataDir     = mastodonDataDir;

    configureNginx = true;

    streamingProcesses = 1;

    secretKeyBaseFile   = "${secretsDir}/secret-key-base";
    # otpSecretFile was removed in Mastodon 4.4.0 — do not set it.
    vapidPrivateKeyFile = "${secretsDir}/vapid-private-key";
    vapidPublicKeyFile  = "${secretsDir}/vapid-public-key";

    # SMTP — Resend (https://resend.com) is the recommended provider.
    # Sign up, create an API key, and place it in the smtp-password file.
    # The API key is used as the SMTP password; the username is always "resend".
    # TODO: create ${secretsDir}/smtp-password containing your Resend API key.
    smtp = {
      host         = "smtp.resend.com";
      port         = 587;
      user         = "resend";
      passwordFile = "${secretsDir}/smtp-password";
      fromAddress  = "notifications@${hostname}";
      authenticate = true;
    };
  };

  # ── Override the mastodon-generated nginx vhost ────────────────────────────
  # configureNginx = true would normally enable ACME and forceSSL. We force
  # both off because Cloudflare terminates TLS at the edge; nginx only needs
  # to serve plain HTTP on localhost.
  services.nginx.virtualHosts."${hostname}" = {
    enableACME = lib.mkForce false;
    forceSSL   = lib.mkForce false;
  };

  # ── Persistent secrets directory ───────────────────────────────────────────
  systemd.tmpfiles.rules = [
    "d ${mastodonDataDir}         0750 mastodon mastodon -"
    "d ${secretsDir}              0700 mastodon mastodon -"
  ];
}
