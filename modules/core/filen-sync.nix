# filen-sync — the fleet's two-way Filen drive mirror.
#
# MOVED HERE 2026-10-31 from hosts/grandpa/services.nix + secrets.nix. It was
# host-local because grandpa was the only box that ran it; he then asked for the
# same thing on the laptops ("do u see filen-sync for grandpa i want it same
# here same env same everything"), so the unit, its timer and the sops template
# that feeds it now live in the shared core layer where all three hosts get them
# from one definition.
#
# WHAT IT DOES: a periodic BIDIRECTIONAL sync of the Filen drive root into
# ~/filen. `bisync`, not `sync`: rclone's `sync` is strictly one-directional and
# would delete remote files on a local delete. The first run with no baseline
# gets --resync; re-running --resync later would silently re-baseline and mask a
# real conflict, so it is only used when the state file is absent.
#
# It runs as `username`, not root: it writes into ~/filen, which belongs to that
# user, and a root run would stamp root-owned files into a directory the user
# then cannot edit. HOME is set explicitly rather than assumed: the bisync
# baseline and rclone's own cache/config both resolve under it, and a wrong
# HOME makes every run look like a first run.
{
  config,
  pkgs,
  username,
  ...
}: let
  filenSync = pkgs.writeShellApplication {
    name = "filen-sync";
    runtimeInputs = [
      (pkgs.callPackage ../../pkgs/filen-cli.nix {})
      pkgs.coreutils
    ];
    text = ''
      state="$HOME/.cache/rclone/bisync/filen_..home_mugdad_filen.path1.lst"
      args=(bisync "filen:" "$HOME/filen")

      if [ ! -f "$state" ]; then
        echo "[filen-sync] no baseline at $state — establishing it with --resync"
        args+=(--resync)
      fi

      exec filen --skip-update rclone "''${args[@]}"
    '';
  };
in {
  # The credentials are fleet-scope ciphertext in secrets/fleet.sops.yaml; these
  # two lines only say "decrypt this key on this host". The EnvironmentFile is
  # rendered at activation into /run/secrets/rendered/, so no plaintext Filen
  # credential exists outside the encrypted file and that root-owned directory.
  sops.secrets."filen/email" = {};
  sops.secrets."filen/password" = {};

  # Own template rather than reusing another: EnvironmentFile wants plain
  # KEY=value lines, while a template is free to render whatever shape its unit
  # reads. Owner `username` (the default would be root:root 0400): the unit runs
  # as this user and a root-owned EnvironmentFile gives it "Permission denied".
  sops.templates."filen-sync.env" = {
    owner = username;
    mode = "0400";
    content = ''
      FILEN_CLI_EMAIL=${config.sops.placeholder."filen/email"}
      FILEN_CLI_PASSWORD=${config.sops.placeholder."filen/password"}
    '';
  };

  systemd.services.filen-sync = {
    description = "Two-way bisync: Filen drive root <-> ~/filen";
    # Ordering only. Needs network (it talks to api.filen.io) and the secrets
    # rendered, otherwise the EnvironmentFile below is absent and the unit fails
    # instead of skipping.
    after = ["network-online.target" "sops-install-secrets.service"];
    wants = ["network-online.target"];
    unitConfig = {
      # Skip cleanly when ~/filen has not been created/restored yet, rather than
      # landing in --failed. It starts on its own the moment the directory
      # exists, so on a fresh host this reads "condition failed" until
      # `mkdir ~/filen` is run (or the directory is restored from a backup).
      ConditionPathExists = "/home/${username}/filen";
    };
    serviceConfig = {
      Type = "oneshot";
      User = username;
      Environment = [
        "HOME=/home/${username}"
        "USER=${username}"
        "LOGNAME=${username}"
      ];
      EnvironmentFile = [config.sops.templates."filen-sync.env".path];
      ExecStart = "${filenSync}/bin/filen-sync";
      # Generous but bounded: the very first run pulled 2.1 GiB on grandpa.
      # Bounded so a hung connection fails the unit instead of wedging it.
      TimeoutStartSec = "60min";
    };
  };

  systemd.timers.filen-sync = {
    wantedBy = ["timers.target"];
    timerConfig = {
      # Wait out boot: tailscale/network come up first, and an immediate sync
      # would just fail and burn a retry.
      OnBootSec = "10min";
      # Cadence for an idle box. AccuracySec matters — the default of 1 min
      # would smear a 30 min cadence into something erratic.
      OnUnitActiveSec = "30min";
      AccuracySec = "1min";
      # NOT Persistent=: that only applies to OnCalendar timers. Missed runs
      # while the box was off are recovered by OnBootSec instead.
    };
  };
}
