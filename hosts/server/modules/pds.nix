# pds.nix -- AT Protocol Personal Data Server module.
# Imported by hosts/server/default.nix.
# Configures bluesky-pds and adds a plain-HTTP nginx vhost for it.
# TLS is terminated at Cloudflare's edge via the tunnel in cloudflare-tunnel.nix.
#
# Hostname, ports, and data directory come from pdsConfig, which is defined
# once in default.nix and passed via _module.args -- edit them there.
{ pdsConfig, ... }:
let
  hostname   = pdsConfig.hostname;
  adminEmail = pdsConfig.adminEmail;
  pdsDataDir = pdsConfig.dataDir;
  pdsPort    = pdsConfig.port;
in
{
  # -- AT Protocol PDS ---------------------------------------------------------
  # Secrets are loaded from an env file you create manually on the server.
  # See README.md -- "PDS secrets" -- for exactly what to put in it.
  services.bluesky-pds = {
    enable = true;
    environmentFiles = [ "${pdsDataDir}/pds.env" ];
    settings = {
      PDS_HOSTNAME       = hostname;
      PDS_PORT           = pdsPort;
      PDS_DATA_DIRECTORY = pdsDataDir;
      PDS_ADMIN_EMAIL    = adminEmail;
      PDS_CRAWLERS       = "https://bsky.network";
    };
  };

  # -- nginx vhost -------------------------------------------------------------
  # Plain HTTP -- cloudflared routes external HTTPS traffic here; nginx proxies
  # to the PDS daemon. No ACME cert needed; Cloudflare terminates TLS.
  # nginx itself is enabled and tuned in default.nix.
  services.nginx.virtualHosts."${hostname}" = {
    locations."/" = {
      proxyPass       = "http://127.0.0.1:${toString pdsPort}";
      proxyWebsockets = true;
    };
  };

  # -- Persistent directory ----------------------------------------------------
  systemd.tmpfiles.rules = [
    "d ${pdsDataDir} 0750 bluesky-pds bluesky-pds -"
  ];
}
