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

    # BACK 2026-10-25, and the reason is worth one line: af010f2 removed this
    # input on 2026-10-23 as "unused" — which was true for exactly one day,
    # because hosts/t480s/ had been deleted the day before. Its only consumer
    # is hosts/t480s/default.nix (lenovo-thinkpad-t480s), so removing the host
    # and keeping the input would have been dead weight and removing the input
    # and bringing the host back is this. Both now move together.
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
      # Lenovo ThinkPad T480s — BACK 2026-10-25, after three days as a ghost.
      # Timeline worth keeping straight, because this line has flipped twice:
      #   2026-10-11  t480s added, the fleet's daily laptop
      #   2026-10-22  his "rm thinkpad" — hosts/t480s/ deleted (c1bb20e), the
      #               day the Victus arrived, and install.sh was made to refuse
      #               this DMI rather than sed a variables.nix that was gone
      #   2026-10-25  "bring him back to nixos-config and he will be aside with
      #               victus" — restored from c1bb20e^ by git checkout
      # The fleet is THREE: grandpa + victus + t480s. The flake declares what
      # exists, so a machine in his hands that is not here would be a lie of
      # the same kind the removal was fixing — only in the other direction.
      #
      # Its home directory was never deleted and lives as a backup at
      # grandpa:~/backup/t480s/ — that is a copy, NOT a restore; nothing here
      # pulls it back.
      #
      # hardware-configuration.nix is the file nixos-generate-config wrote on
      # this machine (root c0e89f41 ext4, ESP 56B8-0DD5). IT IS THE ONE THING
      # TO RE-CHECK BEFORE A BUILD ON THAT HARDWARE: if the ThinkPad was
      # reinstalled or had a disk swap between 10-22 and 10-25, those UUIDs are
      # stale and the generated file must be re-taken from the machine. An eval
      # will happily build a system that cannot find its root.
      t480s = mkHost "t480s";
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
