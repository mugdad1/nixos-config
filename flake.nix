{
  description = "FrostPhoenix's nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-gaming.url = "github:fufexan/nix-gaming";
    nix-flatpak.url = "github:gmodena/nix-flatpak";

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    maple-mono = {
      url = "github:subframe7536/maple-font?ref=v7.8";
      flake = false;
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    superfile.url = "github:yorukot/superfile";
    zen-browser.url = "github:0xc000022070/zen-browser-flake/beta";
  };

  outputs =
    { nixpkgs, self, ... }@inputs:
    let
      username = "mugdad";
      gpu = "amd-nvidia-hybrid";
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      lib = nixpkgs.lib;
      mkHost = host: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./hosts/${host} ];
        specialArgs = {
          inherit host gpu self inputs username;
        };
      };
    in
    {
      nixosConfigurations = {
        desktop = mkHost "desktop";
        laptop = mkHost "laptop";
        p14s = mkHost "p14s";
        rog = mkHost "rog";
        vm = mkHost "vm";
      };
    };
}
