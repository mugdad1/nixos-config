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
#   ~/projects/whatsapp-mcp   ABSENT   -> whatsapp-bridge skips cleanly
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

  # The dedicated WhatsApp session (his word, 2026-10-20: *"i started a new
  # session calledwhatsapp"* — the wake targets the session HE opened, and it
  # gets woken here: one session, both ways).
  waSession = "ses_ea703142affeXvUxkj3GQEtZDF";

  # The donor's 90 s readiness wait, verbatim in behaviour. After= only
  # guarantees opencode was SPAWNED, not that its API port answers — a bot that
  # starts blind is better than one that never starts, so it is bounded at 90 s
  # either way.
  waitOpencode = pkgs.writeShellScript "wait-opencode-api" ''
    i=0
    # PORT: opencode v2 listens on 13420 (v1 used 49374, then the wait grepped
    # a port nothing was bound to and always spun the full 90 s).
    while ! ${pkgs.iproute2}/bin/ss -ltn 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q '127.0.0.1:13420 '; do
      i=$((i + 1))
      if [ "$i" -ge 18 ]; then
        echo "$(date '+%F %T') opencode-telegram: gave up waiting for opencode after 90s, starting anyway"
        break
      fi
      ${pkgs.coreutils}/bin/sleep 5
    done
    echo "$(date '+%F %T') opencode-telegram: opencode API is up, starting bot"
  '';

  # The bot launcher, NIXIFIED 2026-10-15. It used to be a hand-written
  # ~/.local/bin/opencode-telegram-start; when that file was missing systemd
  # reported 203/EXEC (not a crash — the file is simply not there) and
  # switch-to-configuration exited 4, failing an otherwise perfect rebuild.
  # Building it here makes the launcher part of the system closure.
  opencodeTelegramStart = pkgs.writeShellScriptBin "opencode-telegram-start" ''
    # Absolute npx, not a bare one: this script's PATH is whatever the unit
    # sets. `exec` so the node process replaces the shell — without it systemd
    # sees a wrapper PID and SIGTERM lands on the shell first.
    exec ${pkgs.nodejs}/bin/npx -y @grinev/opencode-telegram-bot@latest start
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

  svWatch = pkgs.writeShellApplication {
    name = "sv-watch";
    runtimeInputs = with pkgs; [
      curl
      dnsutils # dig
      docker
      coreutils
      gnused
      gnugrep
      gawk # REQUIRED. writeShellApplication puts these on PATH and nothing else
      # does: the unit sets no `path =`, so without gawk the script inherits
      # systemd's manager PATH and fails with "awk: not found" — the loop body
      # never runs and the sweep reports "checked 0 units" every 60 s, which is
      # worse than no monitor.
      inetutils # hostname — NOT in NixOS's default path
      systemd # systemctl
      # The delivery path for push()/alert() — the same package smartd and the
      # notify-telegram@ OnFailure unit use, so there is exactly one
      # implementation of "send this to my phone".
      (pkgs.callPackage ../../pkgs/notify-telegram.nix {})
    ];
    text = builtins.readFile ../../scripts/thinkcentre/sv-watch.sh;
  };
in {
  # ─── OpenCode server — the singleton the Telegram bot attaches to ───────────
  # OPENCODE IS A SINGLETON: a second `serve --service` exits at once if one
  # already holds 127.0.0.1:13420. There is no unit edge to model a conflicting
  # manual instance, so systemd's restart loop IS the retry construct: it exits,
  # we back off, we take over within RestartSec of the manual instance dying.
  systemd.services.opencode-serve = {
    description = "OpenCode V2 serve (singleton the Telegram bot attaches to)";
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
      ExecStart = "${pkgs.opencode}/bin/opencode serve --service";
      Restart = "always";
      RestartSec = "10s";
    };
  };

  # ─── Telegram bot ──────────────────────────────────────────────────────────
  # Wants=/After= on opencode-serve — deliberately NOT Requires=. Requires
  # propagates STOP, so every opencode restart would take the bot down with it;
  # the donor kept the bot up and re-attaching, and that is the behaviour worth
  # preserving. After= only orders; the ExecStartPre covers readiness.
  systemd.services.opencode-telegram = {
    description = "opencode-telegram bot (waits for the OpenCode API)";
    # Until sops-nix has rendered the config the bot cannot run: with no config
    # it launches an interactive wizard and dies with "Interactive wizard
    # requires a TTY terminal", and Restart=always turns that into a crash
    # loop every 10 s that also leaves the unit in `systemctl --failed`. The
    # condition keeps it skipped-cleanly instead — status reads "condition
    # failed", it stays out of --failed, and it starts by itself the moment the
    # file lands. Ordering on sops-install-secrets matters: that unit runs
    # before sysinit.target, so without this `after` there is no guarantee the
    # render happened before the condition is evaluated.
    unitConfig.ConditionPathExists =
      config.sops.templates."opencode-telegram.env".path;
    wantedBy = ["multi-user.target"];
    wants = ["opencode-serve.service"];
    after = [
      "opencode-serve.service"
      "sops-install-secrets.service"
    ];
    serviceConfig = {
      Type = "simple";
      User = username;
      # EnvironmentFile, not Environment: the values are secrets, so they
      # belong in a file owned by `username` at 0400 that systemd reads
      # directly, rather than being expanded into the unit's Environment=
      # where `systemctl show` would print them back.
      EnvironmentFile = [config.sops.templates."opencode-telegram.env".path];
      Environment = [
        "HOME=/home/${username}"
        "USER=${username}"
        "LOGNAME=${username}"
        # bash FIRST: npm runs install scripts with `spawn sh`, and sh was in
        # none of these directories — the bot died every start with
        # "npm error enoent spawn sh ENOENT" (exit 254). pkgs.bash/bin carries
        # both bash and sh; without it npx resolves fine but the package it
        # fetches cannot run its own lifecycle script.
        "PATH=${pkgs.bash}/bin:${pkgs.nodejs}/bin:/home/${username}/.local/bin:${pkgs.coreutils}/bin:${pkgs.iproute2}/bin:${pkgs.gnugrep}/bin"
      ];
      ExecStartPre = waitOpencode;
      ExecStart = "${opencodeTelegramStart}/bin/opencode-telegram-start";
      # The 90 s readiness wait would otherwise hit the 90 s default start
      # timeout and get SIGKILLed mid-wait.
      TimeoutStartSec = "5min";
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

  # ─── WhatsApp bridge (whatsapp-mcp) ───────────────────────────────────────
  # RESTORED 2026-10-20 on his *"OK bring WhatsApp bAck"* — decisions row 136
  # repeals the row-107 refusal. The run shape is the donor's runit run script:
  # the login user, HOME exported, and the log opened by a shell ALREADY running
  # as that user, so store/bridge.log is never root-owned and downloaded media
  # lands readable — a root run stamps root:root 0600 over every downloaded
  # file (row 38). No `Group =` (row 78: NixOS has no group named after the
  # user, and a unit that fails there takes switch-to-configuration down with
  # it). Restart=always + RestartSec=3 is the donor's tmux `while true … sleep
  # 3` loop, which is what offers a fresh QR when the old one expires (~20 s)
  # instead of dying unpaired.
  #
  # One instance only, ever: a second bridge means two QR channels and two REST
  # servers, and health answers `connected: true` from one while the other
  # cycles QR codes forever. This is the ONE that matters for the move — the
  # clone (and with it the paired session and message history) is NOT on this
  # box as of 2026-10-22, so the condition below keeps the unit skipped-cleanly
  # instead of failing every 3 s, and it starts by itself the moment the repo
  # is re-cloned here at v0.7.0.
  systemd.services.whatsapp-bridge = {
    description = "WhatsApp bridge (whatsapp-mcp whatsmeow) on 127.0.0.1:8080";
    unitConfig.ConditionPathExists = "/home/${username}/projects/whatsapp-mcp/whatsapp-bridge";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "simple";
      User = username;
      # The repo is a plain clone in the home directory, not a store path —
      # it holds the paired session (store/whatsapp.db), so it must run in
      # place or pairing would be lost on every rebuild.
      WorkingDirectory = "/home/${username}/projects/whatsapp-mcp/whatsapp-bridge";
      Environment = [
        "HOME=/home/${username}"
        "USER=${username}"
        "LOGNAME=${username}"
        "PATH=/home/${username}/.nix-profile/bin:${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin"
        # No webhook consumer exists: the bridge POSTs every message to
        # localhost:8769, where nothing listens, and logged "connection
        # refused" for each one. The wake belongs to wa-armsup.sh now, so the
        # outbound webhook is off at the source instead of failing forever
        # into store/bridge.log.
        "WEBHOOK_ENABLED=false"
      ];
      # bash -c carries the `>> store/bridge.log` redirect itself: systemd's
      # own StandardOutput=append: opens the file from PID 1 as root, which is
      # the row-38 trap in a different costume. `mkdir -p store` is there
      # because the redirect is evaluated BEFORE the bridge would create the
      # directory — on a fresh clone the unit would otherwise fail with
      # "store/bridge.log: No such file or directory" and crash-loop.
      ExecStart = "${pkgs.bash}/bin/bash -c 'mkdir -p store && exec ./whatsapp-bridge >> store/bridge.log 2>&1'";
      Restart = "always";
      RestartSec = "3";
    };
  };

  # ── QR pairing page over Tailscale ─────────────────────────────────────────
  # qr-serve.py serves the freshest QR on :8877 so the code can be read from
  # the laptop: the phone doing the scanning cannot display its own code, and
  # this box has no screen either.
  #
  # Scoped to tailscale0 rather than networking.firewall.allowedTCPPorts: a QR
  # links a device to his WhatsApp account, so it must not be readable from the
  # LAN. Outside an actual pairing attempt nothing listens on the port, so the
  # rule otherwise matches an empty port.
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [8877];

  # ── WhatsApp watcher: one arm, and the unit holds it ───────────────────────
  # wa-armsup.sh IS the supervisor — it re-arms watch-whatsapp.py forever over
  # one shared rowid cursor, so exactly ONE process may ever hold it (a second
  # arm starves the first instead of double-reporting). The arm belongs to
  # systemd, not to someone's hand-typed `setsid -f`, which is exactly why a
  # restart used to leave checkup reading "watcher NOT armed" while the bridge
  # went on queueing messages.
  #
  # Exit 3 is the script's documented "stop flag present" refusal. Restart would
  # respawn a supervisor that immediately refuses again — a live-looking refuse
  # loop — so RestartPreventExitStatus=3 pins it down instead.
  systemd.services.whatsapp-watcher = {
    description = "WhatsApp watcher supervisor (one arm, one writer)";
    wantedBy = ["multi-user.target"];
    after = ["whatsapp-bridge.service"];
    serviceConfig = {
      User = username;
      Environment = [
        "HOME=/home/${username}"
        "USER=${username}"
        "LOGNAME=${username}"
        # wa-armsup calls watch-whatsapp.py, whose shebang is `/usr/bin/env
        # python3` — without this PATH the unit cannot even find its own child.
        "PATH=/run/current-system/sw/bin"
        # The wake target: wa-armsup runs `opencode run -s $WA_SESSION` the
        # moment the watcher exits on a hit. Without this the wake is logged
        # as "WA_SESSION unset" and he hears nothing.
        "WA_SESSION=${waSession}"
      ];
      ExecStart = "/run/current-system/sw/bin/wa-armsup.sh 1800";
      Restart = "always";
      RestartSec = "10";
      RestartPreventExitStatus = "3";
    };
  };

  # ── the 313 ritual ─────────────────────────────────────────────────────────
  # "we have in both groups we send 313 at that specific time it means
  # something to us so 3:13am and pm send 313 only to both groups nothing else
  # is requried" — and "u must!!!! not respond to anything". The never-respond
  # half is mechanical: those two JIDs accept ONLY the exact text "313", and
  # only with the one-time ticket wa-313.sh sets.
  #
  # OnCalendar, not an interval: the point is the TIME. "03,15:13:00" is 3:13am
  # and 3:13pm — one timer, two fires, no duplicate units to keep in step.
  # Persistent = true so a missed fire (the box was off at 3:13) is sent on the
  # next boot: a habit that skips a day because the machine was asleep is not a
  # habit. AccuracySec = 1s: the default (1 min) would smear the fire across
  # 3:13:00–3:14:00, and the whole point is the minute.
  systemd.services.wa-313 = {
    description = "Post the bare number 313 to the two ritual groups";
    after = ["whatsapp-bridge.service"];
    serviceConfig = {
      Type = "oneshot";
      User = username;
      Environment = [
        "HOME=/home/${username}"
        "USER=${username}"
        "LOGNAME=${username}"
        "PATH=/run/current-system/sw/bin"
      ];
      ExecStart = "/run/current-system/sw/bin/wa-313.sh";
    };
  };

  systemd.timers.wa-313 = {
    description = "The 313 ritual: 3:13am and 3:13pm";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 03,15:13:00";
      AccuracySec = "1s";
      Persistent = true;
      Unit = "wa-313.service";
    };
  };

  # ─── sv-watch — the health sweep ───────────────────────────────────────────
  # A timer, because the donor looped `sv-watch.sh; sleep 60` and OnUnitActiveSec
  # reproduces that cadence natively — including the serialization: if a sweep
  # runs long, systemd refuses to start a second instance of an active service.
  # The endpoint list is this host's OWN file (scripts/grandpa/http-endpoints),
  # not the ThinkCentre's — copying theirs would check eight URLs this box does
  # not run and page every 60 s.
  environment.etc."sv-watch/http-endpoints".text = builtins.readFile ../../scripts/grandpa/http-endpoints;

  systemd.services.sv-watch = {
    description = "Health sweep: units, containers, HTTP endpoints, DNS";
    # Ordering only, never Requires: the sweep must still run (and report) when
    # docker or blocky are down — that is the entire point of the unit.
    after = ["docker.service" "blocky.service" "network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      User = "root"; # needs the docker CLI and systemctl
      RuntimeDirectory = "sv-watch"; # /run/sv-watch — state + pending, wiped on boot
      StateDirectory = "sv-watch"; # /var/lib/sv-watch — the outbox, must survive
      ExecStart = "${svWatch}/bin/sv-watch";
    };
    environment = {
      STATE = "/run/sv-watch/state";
      PENDING = "/run/sv-watch/http-pending";
      ENDPOINTS = "/etc/sv-watch/http-endpoints";
      OUTBOX = "/var/lib/sv-watch/outbox";
    };
  };

  systemd.timers.sv-watch = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "60s";
      AccuracySec = "1s";
      Unit = "sv-watch.service";
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
