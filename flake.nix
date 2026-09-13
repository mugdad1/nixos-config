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
  };

  outputs = {
    nixpkgs,
    self,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    mkHost = host: let
      variables = import ./hosts/${host}/variables.nix;
    in
      nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/${host}
        ];
        specialArgs = {
          inherit host inputs variables;
          inherit (variables) username;
        };
      };

    # Bootable installer ISO for the X509F:
    # nix build .#installer → flash to USB with dd/ventoy.
    mkInstaller = config_:
      (nixpkgs.lib.nixosSystem {
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          config_
        ];
      }).config.system.build.isoImage;
  in {
    formatter.${system} = nixpkgs.legacyPackages.${system}.alejandra;

    packages.${system} = {
      asus-installer = mkInstaller ./hosts/installer.nix;
      installer = self.packages.${system}.asus-installer;
    };

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
      asus = mkHost "asus";
    };
  };
}
