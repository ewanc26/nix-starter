# cloudflare-tunnel.nix — Cloudflare Tunnel module.
# Imported by hosts/server/default.nix.
#
# Cloudflared dials outbound to Cloudflare's edge — no inbound ports needed
# beyond SSH. Both services are routed by hostname to nginx on localhost.
#
# One-time setup (on your local machine before deploying):
#
#   cloudflared tunnel login
#   cloudflared tunnel create server
#   # note the UUID printed — put it in tunnelId below
#
# Then in Cloudflare DNS add two CNAMEs:
#   pds.example.com     CNAME  <tunnelId>.cfargotunnel.com  (Proxied)
#   social.example.com  CNAME  <tunnelId>.cfargotunnel.com  (Proxied)
#
# SSL/TLS mode in the Cloudflare dashboard for each hostname: set to "Full"
# (not "Full (strict)") — nginx serves plain HTTP; Cloudflare terminates TLS.
#
# Copy the credentials JSON to the server before starting the tunnel:
#
#   ssh admin@your-server \
#     "sudo mkdir -p /var/lib/cloudflared && \
#      sudo chown cloudflared:cloudflared /var/lib/cloudflared"
#
#   scp ~/.cloudflared/<tunnelId>.json \
#       admin@your-server:/tmp/<tunnelId>.json
#
#   ssh admin@your-server \
#     "sudo mv /tmp/<tunnelId>.json /var/lib/cloudflared/<tunnelId>.json && \
#      sudo chown cloudflared:cloudflared /var/lib/cloudflared/<tunnelId>.json && \
#      sudo chmod 400 /var/lib/cloudflared/<tunnelId>.json"
{ ... }:
let
  # ── Tunnel configuration ────────────────────────────────────────────────────
  # TODO: replace with the UUID from `cloudflared tunnel create server`.
  tunnelId        = "00000000-0000-0000-0000-000000000000";
  credentialsFile = "/var/lib/cloudflared/${tunnelId}.json";

  # These must match the hostnames in pds.nix and mastodon.nix.
  pdsHostname      = "pds.example.com";
  mastodonHostname = "social.example.com";
in
{
  services.cloudflared = {
    enable = true;
    tunnels.${tunnelId} = {
      inherit credentialsFile;
      default = "http_status:404";
      ingress = {
        # Both hostnames route to nginx on localhost; nginx differentiates by
        # the Host header and proxies each to the correct backend service.
        ${pdsHostname}      = "http://127.0.0.1:80";
        ${mastodonHostname} = "http://127.0.0.1:80";
      };
    };
  };

  # Ensure the credentials directory exists with correct ownership before the
  # tunnel service starts. The JSON file itself must be copied manually — see
  # the setup instructions at the top of this file.
  systemd.tmpfiles.rules = [
    "d /var/lib/cloudflared 0700 cloudflared cloudflared -"
  ];
}
