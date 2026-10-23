# The hand-written service layer, MOVED HERE 2026-10-22 from
# hosts/thinkcentre/services.nix on his "move the services from thinkcentre to
# grandpa" — the ThinkCentre is being returned to its owner, so whatever it
# was the server OF has to have a home. Read that file for the full history of
# each unit; it stays in the repo, commented out, as the record of where this
# came from.
#
# WHAT IS NOT IN THIS FILE, deliberately:
#   docker-stack   grandpa already declares its own in ./default.nix (same
#                  script, same shape) — a second definition here would be a
#                  duplicate-option conflict, not a migration.
#   backup-daily   ./backup.nix is not moved: it mounts /srv/backup, a physical
#                  240G disk that is bolted to the ThinkCentre and cannot travel
#                  with a config change. The disk, the mount, the timer and the
#                  fstab-gated check in checkup.sh move together or not at all.
#   glances        ./glances.nix already exists here, native (:61208).
#   blocky         already on this host via modules/core; only its tailnet
#                  exposure moved, and that is in ./overrides.nix.
#
# DATA PRECONDITIONS, checked on the box 2026-10-22 before this file was
# written — every one of these is why the units below carry a condition:
#   ~/projects/study          PRESENT  -> study starts
#   ~/filen                   ABSENT   -> filen-sync skips cleanly
#   /var/lib/sops-nix/key.txt  PRESENT  -> both templates render
# A unit that FAILS (rather than skips) makes switch-to-configuration exit 4
# and takes the whole `nixos-rebuild switch` down with it even when every
# package built fine — that failure mode is why ConditionPathExists exists on
# three of these.
{
  config,
  pkgs,
  username,
  ...
}: let
  # opencode v2 via the sst/opencode overlay (modules/core/opencode.nix).
  # nixpkgs' own opencode is v1 and stale — this is why the input exists.
  ocPath = "${pkgs.opencode}/bin:${pkgs.coreutils}/bin:${pkgs.iproute2}/bin:${pkgs.gnugrep}/bin";

  # ─── OpenCode server — the fleet's persistent opencode on :13420 ───────────
  # OPENCODE IS A SINGLETON: a second `serve --service` exits at once if one
  # already holds 127.0.0.1:13420 — the interactive TUI holds it for as long as
  # its session lives. Modelling that conflict with systemd's restart loop
  # (start, exit, retry in 10 s) was pure churn: 108 restarts on 2026-10-22,
  # 28 on 2026-10-23, each costing a journal write and a memory peak for a bind
  # it could not win.
  #
  # The wait has to live in the MAIN process, not in ExecStartPre. That attempt
  # (same day) put it in ExecStartPre with TimeoutStartSec=infinity: the unit
  # then sits in `activating`, and `systemctl start` waits for EVERY job in its
  # transaction, so it hung switch-to-configuration for 18 minutes. Type=simple
  # marks the unit active the instant THIS script is forked, so start returns
  # immediately however long it sleeps, and systemd keeps the same PID through
  # `exec`, so once the port frees the main process really is opencode. One
  # sleeping process, zero restarts, and it takes over within 5 s of the TUI
  # letting go. Verified 2026-10-23 across a reboot: with no TUI running it
  # bound the port itself.
  #
  # It USED to exist for the Telegram bot (removed 2026-10-23, row 207). What
  # keeps it now is that it is the only thing that answers :13420 after a reboot
  # — sessions and any agent talking to opencode need it, TUI or not.
  opencodeServe = pkgs.writeShellScript "opencode-serve-wait" ''
    while ${pkgs.iproute2}/bin/ss -ltn 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q '127.0.0.1:13420 '; do
      ${pkgs.coreutils}/bin/sleep 5
    done
    exec ${pkgs.opencode}/bin/opencode serve --service
  '';

  # The recurring Filen 2-WAY sync. bisync and not `sync`: rclone's `sync` is
  # strictly one-directional and would delete remote files on a local delete,
  # while `bisync` is genuinely bidirectional. --resync ONLY when no baseline
  # exists — re-running it would silently re-baseline and mask a real conflict.
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
  # The reasoning for the wait-wrapper lives at opencodeServe above; this is
  # just the unit. It outlived the Telegram bot (removed 2026-10-23) because it
  # is what answers :13420 after a reboot, TUI or not.
  systemd.services.opencode-serve = {
    description = "OpenCode V2 serve (persistent :13420, waits for a free port)";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    serviceConfig = {
      Type = "simple";
      User = username;
      # NO `Group =` here, on purpose: NixOS gives a normal user the primary
      # group `users` and does NOT create a group matching the username, so
      # `Group = "mugdad"` resolved to nothing — the unit failed with
      # "Failed to determine credentials for group 'mugdad'" (exit 216/GROUP)
      # and because a unit was failing, switch-to-configuration exited 4 and
      # the whole rebuild reported failure. With Group= omitted systemd uses
      # the user's primary group, which always exists. HOME matters: opencode
      # resolves its state under it, and a root run would look in /root.
      Environment = [
        "HOME=/home/${username}"
        "USER=${username}"
        "LOGNAME=${username}"
        "PATH=${ocPath}"
      ];
      # A wrapper, NOT the binary: it waits for 13420 to free and then execs
      # into opencode (full reasoning at opencodeServe). Keep it as the MAIN
      # process — moving the wait back into ExecStartPre re-creates the
      # `activating` deadlock that hung a rebuild for 18 minutes.
      ExecStart = opencodeServe;
      Restart = "always";
      RestartSec = "10s";
    };
  };

  # ─── study PWA ─────────────────────────────────────────────────────────────
  # Runs in place, not from the store: serve.py computes
  # ROOT = dirname(dirname(__file__)), so copying it into the Nix store would
  # make it serve an empty store directory.
  #
  # ConditionPathExists ADDED for the move (absent in the source unit): the
  # data is present on this box as of 2026-10-22, but the capital-P path trap
  # this unit has fallen into twice turns a missing WorkingDirectory into a
  # 5 s Restart=always loop, and a unit stuck failing takes the WHOLE rebuild
  # down at exit 4. On a host that just inherited a service, skipping cleanly
  # is strictly the right failure.
  systemd.services.study = {
    description = "Study PWA no-cache static server";
    unitConfig.ConditionPathExists = "/home/${username}/projects/study";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    serviceConfig = {
      Type = "simple";
      User = username;
      WorkingDirectory = "/home/${username}/projects/study";
      ExecStart = "${pkgs.python3}/bin/python3 /home/${username}/projects/study/scripts/serve.py 8091 0.0.0.0";
      Restart = "always";
      RestartSec = "5s";
    };
  };

  # ─── filen-sync — the 2-way drive mirror ───────────────────────────────────
  # Periodic bidirectional sync of the Filen drive root into ~/filen, so the
  # local copy (all KFU material, cv, obsidian, projects, wiki-private) tracks
  # changes made from the phone/web and vice versa.
  #
  # Runs as `username`, not root: it writes into ~/filen, which belongs to that
  # user, and a root run would stamp root-owned files into a directory the user
  # then cannot edit. HOME is set explicitly rather than assumed: the bisync
  # baseline and rclone's own cache/config both resolve under it, and a wrong
  # HOME makes every run look like a first run.
  systemd.services.filen-sync = {
    description = "Two-way bisync: Filen drive root <-> ~/filen";
    # Ordering only. Needs network (it talks to api.filen.io) and the secrets
    # rendered, otherwise the EnvironmentFile below is absent and the unit fails
    # instead of skipping.
    after = ["network-online.target" "sops-install-secrets.service"];
    wants = ["network-online.target"];
    unitConfig = {
      # Skip cleanly when ~/filen has not been created/restored yet, rather than
      # landing in --failed. It will start on its own the moment the directory
      # exists — which it does NOT as of 2026-10-22, so this one is expected to
      # read "condition failed" until the data is migrated.
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
      # Filen credentials, rendered from sops at activation (./secrets.nix).
      EnvironmentFile = [config.sops.templates."filen-sync.env".path];
      ExecStart = "${filenSync}/bin/filen-sync";
      # Generous but bounded: the very first run pulled 2.1 GiB. Bounded so a
      # hung connection fails the unit instead of wedging it forever.
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

  # journald defaults to `auto` — volatile unless /var/log/journal exists — so
  # without this the logs those runit units wrote to /var/log/*.log would not
  # survive a reboot at all.
  services.journald.settings.Journal.Storage = "persistent";
}
