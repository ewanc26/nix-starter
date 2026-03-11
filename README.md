# nix-starter

**https://github.com/ewanc26/nix-starter**

Beginner-friendly, self-contained NixOS configurations.
No personal infrastructure, no shared abstractions — just plain NixOS.

## Hosts

| Host | Description |
|------|-------------|
| [`as-the-gods-intended`](hosts/as-the-gods-intended/README.md) | Minimal TUI laptop, optional KDE Plasma desktop |

## Structure

```
flake.nix                        — top-level flake, wires up all hosts
hosts/
└── as-the-gods-intended/
    ├── default.nix              — system config (boot, networking, packages)
    ├── home.nix                 — user config (shell, editor, tools)
    ├── hardware-configuration.nix  — generated per-machine, replace before install
    └── README.md                — full setup guide for that host
```

## Adding a new host

1. Copy an existing host directory as a starting point:
   ```bash
   cp -r hosts/as-the-gods-intended hosts/my-new-host
   ```
2. Update `networking.hostName`, the username, and the hardware config.
3. Add an entry to `flake.nix` under `nixosConfigurations`.
4. Follow the setup guide in the new host's `README.md`.

## Resources

- NixOS manual: https://nixos.org/manual/nixos/stable
- Package search: https://search.nixos.org/packages
- Home Manager options: https://nix-community.github.io/home-manager/options.xhtml
- NixOS Discourse: https://discourse.nixos.org
