# AGENTS.md

Guidance for agents working on the standalone NixOS starter flake.

## Flake and host map

- `flake.nix` pins NixOS/Home Manager 25.11 plus `tgirlcloud/pkgs`, and exports two `x86_64-linux` systems: `as-the-gods-intended` and `server`. Keep `flake.lock` reviewed with any input update.
- `hosts/as-the-gods-intended/default.nix` is the NixOS host; `home.nix` is the Home Manager profile; its hardware file is a placeholder that must be replaced on the target machine.
- `hosts/server/default.nix` defines the shared PDS configuration and imports Cloudflare tunnel, Bluesky PDS, PDS Gatekeeper, and Mastodon modules. Only SSH port 22 is opened; cloudflared reaches nginx over localhost HTTP.
- `pdsConfig` in `hosts/server/default.nix` is authoritative for the PDS hostname, admin email, data directory (`/srv/pds`), and port. Cloudflare and Mastodon hostnames remain separate constants and must match their DNS/vhost configuration.

## Safety and known documentation drift

- Both hardware files and values such as `friend`, `admin`, `AAAA...`, `example.com`, and the zero tunnel UUID are non-deployable placeholders. Never switch or install a host until they have been replaced and the generated hardware config is reviewed.
- Secrets are runtime files, not Nix values: PDS uses `/srv/pds/pds.env`, Mastodon uses `/srv/mastodon/secrets`, and cloudflared uses `/var/lib/cloudflared/<uuid>.json`. Do not add these or their contents to Git or the Nix store.
- `hosts/server/README.md` contains stale instructions that create PDS secrets under `/var/lib/pds` and initially describes editing hostname/email in `modules/pds.nix`; the executable configuration uses `/srv/pds` and `default.nix`'s `pdsConfig`. It also briefly creates `/var/lib/mastodon/secrets` before writing `/srv/mastodon/secrets`. Follow evaluated module paths and correct the docs when working there.
- Gatekeeper intercepts four exact authentication/account routes at nginx priority 500 and reads the same PDS env file. Preserve the ordinary PDS catch-all and verify upstream module option/API changes when updating `tgirlpkgs`.
- Mastodon lets its NixOS module configure nginx, then force-disables ACME and `forceSSL` because Cloudflare terminates TLS. Changing tunnel or TLS topology requires coordinated nginx, firewall, DNS, and documentation changes.
- Favor explicit beginner-readable host-local configuration. Do not hide required setup behind private paths or personal flake modules.

## Validation

Run the repository formatter (`nix fmt`) and `nix flake check`. Build without activation using `nix build .#nixosConfigurations.as-the-gods-intended.config.system.build.toplevel` and the corresponding `server` output after shared changes. For module changes also evaluate the relevant option paths and inspect generated nginx/systemd configuration where practical. Check README commands against the actual `/srv` paths and placeholders. Never run `nixos-rebuild switch`, `nixos-install`, DNS/tunnel creation, or service/account commands as routine validation.
