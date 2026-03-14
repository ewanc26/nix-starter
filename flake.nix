# nix-starter — standalone NixOS configurations
# This is intentionally decoupled from any personal flake infrastructure.
# Each host under hosts/ is a self-contained NixOS system.
#
# Source: https://github.com/ewanc26/nix-starter
#
# Build / deploy (from /etc/nixos after cloning there):
#   sudo nixos-rebuild switch --flake /etc/nixos#<hostname>
{
  description = "nix-starter — beginner-friendly NixOS configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Isabel's packages — provides pds-gatekeeper NixOS module and package
    tgirlpkgs = {
      url = "github:tgirlcloud/pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, tgirlpkgs, ... }:
    {
      nixosConfigurations = {

        as-the-gods-intended = nixpkgs.lib.nixosSystem {
          modules = [
            ./hosts/as-the-gods-intended/default.nix
            home-manager.nixosModules.home-manager
            { nixpkgs.hostPlatform = "x86_64-linux"; }
          ];
        };

        # Combined PDS + Mastodon server.
        # Service config lives in hosts/server/modules/{pds,mastodon}.nix.
        server = nixpkgs.lib.nixosSystem {
          modules = [
            tgirlpkgs.nixosModules.default
            ./hosts/server/default.nix
            { nixpkgs.hostPlatform = "x86_64-linux"; }
          ];
        };

      };
    };
}
