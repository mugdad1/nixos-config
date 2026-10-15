{
  description = "mugdad's nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake/beta";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Official opencode flake — nixpkgs' opencode is stale (v1); this is v2
    opencode = {
      url = "github:sst/opencode";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets. The repo is PUBLIC (github.com/mugdad1/nixos-config), so a
    # credential can never be written inline in Nix — see .sops.yaml for the
    # full reasoning. sops-nix decrypts at activation with an age key that
    # never enters git, which keeps secrets declarative (they survive a
    # reinstall) without publishing them.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    self,
    ...
  } @ inputs:
    let
      system = "x86_64-linux";

      mkHost = host:
        let
          variables = import ./hosts/${host}/variables.nix;
        in
        nixpkgs.lib.nixosSystem {
          modules = [
            ./hosts/${host}
            inputs.sops-nix.nixosModules.sops
          ];
          specialArgs = {
            inherit host inputs variables;
            inherit (variables) username;
          };
        };
    in
    {
      formatter.${system} = nixpkgs.legacyPackages.${system}.alejandra;

      devShells.${system} = {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          packages = with nixpkgs.legacyPackages.${system}; [
            alejandra
            statix
            deadnix
            shellcheck
            shfmt
            treefmt
            stylua
            taplo
            nixd
          ];
        };

        kernel = nixpkgs.legacyPackages.${system}.mkShell {
          packages = with nixpkgs.legacyPackages.${system}; [
            gnumake
            gcc
            linuxPackages_latest.kernel.dev
          ];
          shellHook = ''
            export KDIR="${nixpkgs.legacyPackages.${system}.linuxPackages_latest.kernel.dev}/lib/modules/${nixpkgs.legacyPackages.${system}.linuxPackages_latest.kernel.dev.version}/build"
            echo "Kernel dev shell ready"
            echo "Kernel: $(uname -r)"
            echo "KDIR: $KDIR"
          '';
        };
      };

      nixosConfigurations = {
        t480s = mkHost "t480s";
      };
    };
}
