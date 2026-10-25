{
  description = "mugdad's nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Frozen nixpkgs, used ONLY to pin hplip — see modules/core/hplip.nix.
    # Deliberately pinned to an exact rev, not a branch: its whole job is to
    # stay put while nixpkgs keeps moving.
    nixpkgs-hplip.url = "github:NixOS/nixpkgs/6510408d147d8c5e6d76043e899e9251756f6a75";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake/beta";
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
  } @ inputs: let
    system = "x86_64-linux";

    mkHost = host: let
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
  in {
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
      # Lenovo ThinkPad T480s — REMOVED 2026-10-22, the day the Victus arrived
      # (his "rm thinkpad"). It carried the fleet's daily-laptop role since
      # 2026-10-11; hosts/t480s/ is deleted and the Victus took over. Its home
      # directory lives on as a backup at grandpa:~/backup/t480s/. Git history
      # is the record.
      #
      # HP Victus 15 — i5-12th-gen H + RTX 3050 Laptop, the new daily laptop.
      # Created 2026-10-22. hardware-configuration.nix is the real generated
      # file; install.sh overwrites it on a fresh install.
      victus = mkHost "victus";
      # Lenovo ThinkCentre M900x (10LY) — REMOVED 2026-10-22. It was the fleet's
      # first NixOS server after the Void migration, but it went back to its
      # owner (his "rm thinkcentre host"), so hosts/thinkcentre/ is gone and
      # nothing here declares it any more. The service layer it carried lives
      # on grandpa (see the MOVED FROM notes in hosts/grandpa/). sv-watch.sh,
      # its http-endpoints and postboot-verify.sh went 2026-10-23 with sv-watch
      # itself. Git history is the record.
      #
      # CORRECTION 2026-10-25: this comment used to say "the compose launcher now
      # lives at scripts/grandpa/docker-stack.sh and is read by
      # hosts/grandpa/default.nix". Both halves went that day: the `docker-stack`
      # UNIT was removed with the whole compose stack — seven projects, their
      # data and their configs — and he then chose to delete the orphaned script
      # too ("2 do it"), so `scripts/grandpa/` holds only `ac.sh` and
      # scripts/thinkcentre/ is empty. Nothing sweeps ~/projects/servers and
      # nothing can come back at boot. The design is still worth remembering if a
      # stack ever returns — compose files as source of truth, one oneshot as the
      # *when* — and both the script and its unit are in git history.
      # Grandpa's box — Intel i3-2120 (Sandy Bridge), 6 GiB, single 298 GiB HDD,
      # headless server / CLI box. NixOS **installed 2026-10-16** and
      # `hardware-configuration.nix` is the real generated file from that day
      # (see the header in hosts/grandpa/default.nix and decisions.md rows
      # 103 / 112); the placeholder warning this comment used to carry is gone.
      # It deploys like the laptop: `--flake .#grandpa`.
      grandpa = mkHost "grandpa";
    };
  };
}
