{
  description = "FrostPhoenix's nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    nixos-hardware.url = "github:NixOS/nixos-hardware";

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    maple-mono = {
      url = "github:subframe7536/maple-font?ref=v7.8";
      flake = false;
    };

    nixvim.url = "github:nix-community/nixvim";
    superfile.url = "github:yorukot/superfile";
    zen-browser.url = "github:0xc000022070/zen-browser-flake/beta";
    cardwire = {
      url = "github:opengamingcollective/cardwire";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    self,
    cardwire,
    ...
  } @ inputs: let
    username = "mugdad";
    system = "x86_64-linux";
    lib = nixpkgs.lib;
    mkHost = host: gpu:
      nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/${host}
          cardwire.nixosModules.default
        ];
        specialArgs = {
          inherit
            host
            gpu
            self
            inputs
            username
            ;
        };
      };
  in {
    formatter.${system} = nixpkgs.legacyPackages.${system}.alejandra;

    packages.${system}.nvim = inputs.nixvim.legacyPackages.${system}.makeNixvim {
      imports = [ ./modules/home/nvim-config.nix ];
    };

    nixosConfigurations = {
      rog = mkHost "rog" "amd-nvidia-hybrid";
      t480s = mkHost "t480s" "intel";
    };
  };
}
