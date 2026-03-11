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

  # Secret files — create these on the server before starting Mastodon.
  # See README.md — "Mastodon secrets" — for generation commands.
  secretsDir = "/var/lib/mastodon/secrets";
in
{
  # ── Mastodon ──────────────────────────────────────────────────────────────
  services.mastodon = {
    enable      = true;
    localDomain = hostname;

    configureNginx = true;

    streamingProcesses = 1;

    secretKeyBaseFile   = "${secretsDir}/secret-key-base";
    # otpSecretFile was removed in Mastodon 4.4.0 — do not set it.
    vapidPrivateKeyFile = "${secretsDir}/vapid-private-key";
    vapidPublicKeyFile  = "${secretsDir}/vapid-public-key";

    # SMTP — configure an outbound mail server so Mastodon can send emails.
    # TODO: replace with your actual SMTP details.
    smtp = {
      host         = "smtp.example.com";
      port         = 587;
      user         = "mastodon@example.com";
      # Place your SMTP password in this file (one line, no trailing newline).
      # TODO: create ${secretsDir}/smtp-password on the server.
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
    "d /var/lib/mastodon/secrets 0700 mastodon mastodon -"
  ];
}
