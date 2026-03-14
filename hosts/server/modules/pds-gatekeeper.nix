# pds-gatekeeper.nix -- TOTP 2FA proxy in front of the AT Protocol PDS.
# Imported by hosts/server/default.nix.
#
# By Bailey Townsend; NixOS module and package by Isabel (tgirlcloud/pkgs).
# Sits between nginx and the PDS for a small set of auth endpoints, adding
# TOTP-based two-factor authentication on top of the standard ATProto login flow.
#
# Architecture:
#   nginx (auth routes, priority 500)
#     |
#     v proxy_pass
#   PDS Gatekeeper (127.0.0.1:3602)
#     |
#     v proxies upstream to
#   PDS (127.0.0.1:<pdsConfig.port>)
#
# Prerequisites:
#   - hosts/server/modules/pds.nix must be imported (provides bluesky-pds and nginx vhost)
#   - tgirlpkgs.nixosModules.default wired in via flake.nix
#   - /srv/pds/pds.env present on the server (shared with bluesky-pds)
#
# Hostname, ports, and data directory come from pdsConfig, which is defined
# once in default.nix and passed via _module.args -- edit them there.
{ pkgs, pdsConfig, ... }:
let
  hostname   = pdsConfig.hostname;
  pdsDataDir = pdsConfig.dataDir;
  pdsPort    = pdsConfig.port;

  gkHost = "127.0.0.1";
  gkPort = 3602;
  gkUrl  = "http://${gkHost}:${toString gkPort}";
in
{
  # -- PDS Gatekeeper service --------------------------------------------------
  services.pds-gatekeeper = {
    enable = true;
    # Reuse the same env file that bluesky-pds reads from /srv/pds/pds.env.
    environmentFiles = [ "${pdsDataDir}/pds.env" ];
    settings = {
      GATEKEEPER_HOST        = gkHost;
      GATEKEEPER_PORT        = gkPort;
      PDS_BASE_URL           = "http://127.0.0.1:${toString pdsPort}";
      PDS_HOSTNAME           = hostname;
      PDS_DATA_DIRECTORY     = pdsDataDir;
      GATEKEEPER_TRUST_PROXY = "true";
      # Gatekeeper expects a .env file path; supply an empty nix-store file
      # so it doesn't error on startup (secrets come via environmentFiles above).
      PDS_ENV_LOCATION = toString (pkgs.writeText "gatekeeper-pds-env" "");
    };
  };

  # -- Systemd tweaks ----------------------------------------------------------
  systemd.services.pds-gatekeeper = {
    after  = [ "bluesky-pds.service" ];
    wants  = [ "bluesky-pds.service" ];
    serviceConfig = {
      Restart    = "always";
      RestartSec = 5;
    };
  };

  # -- nginx routes ------------------------------------------------------------
  # These four endpoints are intercepted by gatekeeper before the catch-all
  # "/" location in pds.nix. Priority 500 < 1000 (default) ensures they are
  # written earlier in the nginx config and matched first.
  services.nginx.virtualHosts."${hostname}" = {
    locations."/xrpc/com.atproto.server.createSession" = {
      proxyPass = gkUrl;
      priority  = 500;
    };
    locations."/xrpc/com.atproto.server.getSession" = {
      proxyPass = gkUrl;
      priority  = 500;
    };
    locations."/xrpc/com.atproto.server.updateEmail" = {
      proxyPass = gkUrl;
      priority  = 500;
    };
    locations."/@atproto/oauth-provider/~api/sign-in" = {
      proxyPass = gkUrl;
      priority  = 500;
    };
  };
}
