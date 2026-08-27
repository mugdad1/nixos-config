{
  description = "mugdad's nixos configuration";

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

    zen-browser.url = "github:0xc000022070/zen-browser-flake/beta";

    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = {nixpkgs, ...} @ inputs: let
    username = "mugdad";
    system = "x86_64-linux";
    mkHost = host: let
      variables = import ./hosts/${host}/variables.nix;
    in
      nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/${host}
        ];
        specialArgs = {
          inherit
            host
            inputs
            username
            variables
            ;
        };
      };
  in {
    formatter.${system} = nixpkgs.legacyPackages.${system}.alejandra;

    devShells.${system}.default = nixpkgs.legacyPackages.${system}.mkShell {
      packages = with nixpkgs.legacyPackages.${system}; [
        alejandra
        statix
        deadnix
        shellcheck
        shfmt
        treefmt
        nixd
      ];
    };

    nixosConfigurations = {
      t480s = mkHost "t480s";
    };
  };
}
