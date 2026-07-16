# AGENTS.md

Guidance for agents working on nix-starter, a beginner-friendly standalone set of NixOS configurations.

## Principles

- This repo intentionally contains no personal infrastructure or hidden shared abstractions. Examples must work from this checkout alone.
- `flake.nix` wires hosts; `hosts/as-the-gods-intended/` is the laptop example and `hosts/server/` is the hardened server/PDS/Mastodon example.
- Keep generated `hardware-configuration.nix` clearly replaceable and do not publish real machine identifiers or secrets.

## Rules

- Favor explicit readable Nix over clever abstraction. Explain non-obvious security/network settings near the host that uses them.
- Never embed Cloudflare, PDS, Mastodon, user password, SSH, or DNS credentials.
- Preserve firewall and service hardening unless a change explicitly accounts for the security impact.
- Pin inputs and review `flake.lock` changes. Avoid impure local paths.
- Documentation is part of the product; commands must work for a first-time user.

## Validation

Run `nix flake check`, format Nix files, and build each affected host configuration without switching. Evaluate both host outputs after shared changes. Check README commands, placeholder values, firewall ports, and secret setup from a clean-user perspective. Never activate a host or deploy services as routine validation.
