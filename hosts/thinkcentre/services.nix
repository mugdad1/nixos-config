# The four hand-written runit units that have no NixOS module, ported to
# systemd. They live HERE and not in modules/core on purpose: core is
# auto-imported into every host by scanPaths, so anything host-specific placed
# there would silently land on the laptop too.
#
# What runit could not express and systemd now does, per unit:
#   opencode-serve    a wait-for-port-free loop  -> Restart= + RestartSec
#   opencode-telegram a wait-for-port-up loop    -> Wants=/After= + bounded ExecStartPre
#   study             nothing (plain foreground) -> Type=simple
#   sv-watch          a `while true; sleep 60`  -> a real timer
#
# Logging: every donor unit did `exec >>/var/log/X.log 2>&1` (and two of them
# got the redirection order wrong at some point, losing hours of output).
# systemd's default IS the journal, so the correct port is to DELETE the
# redirect: `journalctl -u <name> -f -b`. Set journald persistent below so it
# survives reboot the way those .log files did.
{
  config,
  pkgs,
  username,
  ...
}: let
  # opencode v2 via the sst/opencode overlay (modules/core/opencode.nix).
  # nixpkgs' own opencode is v1 and stale — this is why the input exists.
  ocPath = "${pkgs.opencode}/bin:${pkgs.coreutils}/bin:${pkgs.iproute2}/bin:${pkgs.gnugrep}/bin";

  # The donor's 90 s readiness wait, verbatim in behaviour. It exists because
  # After= only guarantees opencode was SPAWNED, not that its API port answers — and
  # on 2026-10-04 the bot came up ~1 min early, logged "reason=startup", and
  # then never retried, staying up but permanently blind while every service
  # showed green. Bounded at 90 s: a bot that starts blind is better than none.
  waitOpencode = pkgs.writeShellScript "wait-opencode-api" ''
    i=0
    # PORT MOVED. This grepped for :49374, which is opencode v1's port. This
    # box runs v2 (modules/core/opencode.nix), and v2's own log says
    # "server listening on http://127.0.0.1:13420" — verified 2026-10-13 with
    # `curl 127.0.0.1:13420 -> HTTP 200` while :49374 gave HTTP 000. So the wait
    # could never succeed: it spun the full 90 s on every start and then began
    # anyway. Bounded either way — a wrong port costs 90 s, not a hang.
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
  # ~/.local/bin/opencode-telegram-start inherited from the Void install, and
  # that single file was the unit's whole existence: the 2026-10-15 reinstall
  # recreated none of ~/.local/bin, so ExecStart resolved to nothing, systemd
  # reported 203/EXEC (not a crash, not a config error — the file is simply
  # not there), and switch-to-configuration exited 4 over it, failing an
  # otherwise perfectly good `nixos-rebuild switch`. The same class of bug as
  # the capital-P paths: state the flake did not own, so the flake could not
  # bring it back. Building it here makes the launcher part of the system
  # closure — it exists on a fresh install by construction.
  #
  # The `npx -y @grinev/opencode-telegram-bot@latest` is unchanged on purpose.
  # The previous comment reserved pinning it into the store as a separate
  # decision, and that reservation still stands: `@latest` means every start
  # can pick up a new bot version (impure, but the behaviour the donor ran),
  # while pinning means an explicit version choice plus an npm dependency hash
  # to maintain. This commit fixes WHO provides the script, not WHICH version
  # of the bot runs.
  opencodeTelegramStart = pkgs.writeShellScriptBin "opencode-telegram-start" ''
    # Absolute npx, not a bare one: this script's PATH is whatever the unit
    # sets, and a bare `npx` would resolve differently depending on it. `exec`
    # so the node process replaces the shell — without it systemd sees a
    # wrapper PID, SIGTERM lands on the shell first, and the bot gets SIGKILL
    # on TimeoutStopSec instead of shutting down.
    exec ${pkgs.nodejs}/bin/npx -y @grinev/opencode-telegram-bot@latest start
  '';

  # The recurring Filen 2-WAY sync, nixified 2026-10-15 (his ask: "2 way sync",
  # and this repo's standing rule is that state lives in the flake).
  #
  # WHY bisync AND NOT `sync`: rclone's `sync` is strictly one-directional —
  # it makes DEST look like SOURCE, and a file deleted locally would be deleted
  # on the drive. `bisync` is genuinely bidirectional and is the only one of
  # the two that propagates both ways. The first run used `--resync`, which
  # establishes the baseline; the dry run before it reported 1794 files going
  # remote -> local and ZERO deletions, and the real run matched exactly
  # (1794 files, 11 top-level entries, 0 deletions).
  #
  # --resync ONLY when no baseline exists. Re-running it would silently
  # re-baseline and could mask a genuine conflict, which defeats the point of a
  # two-way sync. The baseline is rclone's own state:
  #   ~/.cache/rclone/bisync/filen_..home_mugdad_filen.path{1,2}.lst
  # (rclone 1.74.2's default state path — verified present after the first
  # run). If that cache is ever wiped, the guard below re-baselines instead of
  # failing, which is the correct recovery: an empty cache means rclone has no
  # history to compare against, not that the data should be discarded.
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
      gawk # REQUIRED, not optional. sv-watch.sh pipes `systemctl
      # list-unit-files` into awk. writeShellApplication puts these on PATH and
      # nothing else does: the unit sets no `path =`, so the script otherwise
      # inherits systemd's manager PATH, which has no gawk on it. Without this
      # entry the command fails with "awk: not found", the loop body never runs
      # and the whole unit sweep reports "checked 0 units" every 60 s — a
      # monitor that silently checks nothing, which is worse than no monitor.
      inetutils # hostname — NOT in NixOS's default path
      systemd # systemctl
    ];
    text = builtins.readFile ../../scripts/thinkcentre/sv-watch.sh;
  };

  # ─── docker-stack — the compose launcher ────────────────────────────────────
  # The one thing `nixos-rebuild` could not bring back after the migration: 13
  # compose projects / 18 containers live as FILES under ~/Projects/servers, so
  # a reinstall restored them and started none of them. See the long header in
  # ../../scripts/thinkcentre/docker-stack.sh for why they were kept as compose
  # rather than nixified.
  dockerStack = pkgs.writeShellApplication {
    name = "docker-stack";
    runtimeInputs = with pkgs; [
      docker
      coreutils
      gnugrep # `grep -qx` for the DISABLED list
    ];
    text = builtins.readFile ../../scripts/thinkcentre/docker-stack.sh;
  };
in {
  # ─── OpenCode server — the singleton the Telegram bot attaches to ───────────
  # OPENCODE IS A SINGLETON: a second `serve --service` exits at once if one
  # already held the opencode API port (127.0.0.1:13420 since opencode v2; it
  # was :49374 under v1). Under runit the holder was usually a
  # hand-started instance, and the unit waited in an ss loop (134 logged waits).
  # There is no unit edge to model that — Requires=/BindsTo= relate units, and
  # the conflicting process is manual. systemd's restart loop IS the retry
  # construct: it exits, we back off, we take over within RestartSec of the
  # manual instance dying. `always` rather than `on-failure` because the exit
  # code when the port is held is not guaranteed nonzero.
  systemd.services.opencode-serve = {
    description = "OpenCode V2 serve (singleton the Telegram bot attaches to)";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    serviceConfig = {
      Type = "simple";
      User = username;
      # NO `Group =` here, on purpose. It used to be `Group = username`, which
      # crashed the unit at every start: NixOS gives a normal user the primary
      # group `users` and does NOT create a group matching the username, so
      # `Group = "mugdad"` resolved to nothing — journal showed
      # "Failed to determine credentials for group 'mugdad': Unknown group",
      # exit 216/GROUP, and because a unit was failing, switch-to-configuration
      # exited 4 and the whole `nixos-rebuild switch` reported failure.
      # With Group= omitted, systemd uses the user's primary group (`users`),
      # which always exists. HOME matters: opencode resolves its state under it,
      # and running as root would look in /root instead (the donor used chpst -u
      # void for this).
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
  # DISABLED 2026-10-12, RE-ENABLED 2026-10-13 on his word ("also run study
  # and telegram"). What blocked the re-enable before was not this file: the
  # wrapper ~/.local/bin/opencode-telegram-start and the opencode state under
  # ~/.local/state/opencode lived on the Void install that was replaced, so both
  # were simply absent. They came back off the backup disk today (snapshots/
  # daily-1, the last Void snapshot).
  # Wants=/After= on opencode-serve — deliberately NOT Requires=. Requires
  # propagates STOP, so every opencode restart would take the bot down with it;
  # the donor kept the bot up and re-attaching, and that is the behaviour worth
  # preserving. After= only orders; the ExecStartPre covers readiness.
  systemd.services.opencode-telegram = {
    description = "opencode-telegram bot (waits for the OpenCode API)";
    # Until sops-nix has rendered the config the bot cannot run: with no config
    # it launches an interactive wizard and dies with
    #   "CLI error: Interactive wizard requires a TTY terminal"
    # (exit 1), and Restart=always turns that into a crash loop every 10 s that
    # also leaves the unit in `systemctl --failed`.
    #
    # CHANGED 2026-10-13. This used to guard
    # ~/.config/opencode-telegram-bot/.env, and that path was the blocker for
    # days: the token existed but was in no snapshot, because backup-run.sh's
    # SOURCES never included .config, so it had to be re-issued from @BotFather
    # and written by hand. Two things made that the wrong home for it. It is
    # outside the flake, so a reinstall would not restore it — the exact failure
    # the whole migration is about. And the repo is public, so a hand-written
    # .env sits one careless `git add -A` or `git add .` away from being
    # published. The config is now a sops template (./secrets.nix), encrypted in
    # the repo and rendered at activation; see that file for the full reasoning.
    #
    # The condition is retained, and still means the same thing: until the file
    # exists the unit is skipped cleanly rather than failed — status reads
    # "condition failed", it stays out of --failed, and it starts by itself the
    # moment the file lands. Ordering on sops-install-secrets matters: that unit
    # runs before sysinit.target, and without an explicit `after` there is no
    # guarantee the render happened before this condition is evaluated.
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
      # The rendered config. EnvironmentFile, not Environment: the values are
      # secrets, so they belong in a file owned by `username` at 0400 that
      # systemd reads directly, rather than being expanded into the unit's
      # Environment= list where `systemctl show` would print them back.
      EnvironmentFile = [config.sops.templates."opencode-telegram.env".path];
      Environment = [
        "HOME=/home/${username}"
        "USER=${username}"
        "LOGNAME=${username}"
        # bash FIRST: npm runs install scripts with `spawn sh`, and sh was in
        # none of these directories — the bot died every start with
        # "npm error enoent spawn sh ENOENT" (exit 254). pkgs.bash/bin carries
        # both bash and sh. Without it npx resolves fine (nodejs/bin) but the
        # package it fetches cannot run its own lifecycle script.
        "PATH=${pkgs.bash}/bin:${pkgs.nodejs}/bin:/home/${username}/.local/bin:${pkgs.coreutils}/bin:${pkgs.iproute2}/bin:${pkgs.gnugrep}/bin"
      ];
      ExecStartPre = waitOpencode;
      # NIXIFIED 2026-10-15. This was the imperative
      # /home/${username}/.local/bin/opencode-telegram-start — a file outside
      # the flake, so a reinstall could not recreate it, which is exactly how
      # it came back missing and took the whole rebuild down with a 203/EXEC.
      # The store path replaces it; the wrapper's own comment still records
      # that `npx ... @latest` is an impure fetch at every start, and that
      # pinning the bot version remains an open, separate decision.
      ExecStart = "${opencodeTelegramStart}/bin/opencode-telegram-start";
      # The 90 s readiness wait would otherwise hit the 90 s default start
      # timeout and get SIGKILLed mid-wait.
      TimeoutStartSec = "5min";
      Restart = "always";
      RestartSec = "10s";
    };
  };

  # ─── study PWA ─────────────────────────────────────────────────────────────
  # DISABLED 2026-10-12, RE-ENABLED 2026-10-13 on his word. Blocked on the same
  # thing as the bot: ~/Projects/study was on the Void install and did not
  # exist on this box until it was restored from snapshots/daily-1 today.
  # serve.py is present at that path now.
  #
  # The reason it runs in place still holds: serve.py computes
  # ROOT = dirname(dirname(__file__)), so copying it into the Nix store would
  # make it serve an empty store directory. Also a behaviour change worth
  # knowing: under runit this ran as ROOT (the run script had no chpst -u).
  #
  # CASE, 2026-10-15. This read /home/${username}/Projects/study — capital P —
  # and the 2026-10-15 reinstall restored everything to ~/projects (lowercase).
  # ext4 is case-sensitive, so the path simply did not exist: the unit failed at
  # step CHDIR, `Restart=always` turned that into a 5 s loop (63 restarts by the
  # time it was caught), and — the part that actually costs — a unit stuck
  # failing makes switch-to-configuration exit 4, which fails the WHOLE
  # `nixos-rebuild switch` even though every package built fine. AGENTS.md
  # item 9 records the lowercase layout as the live one; the wiki's
  # `~/Projects/...` spellings are history.
  systemd.services.study = {
    description = "Study PWA no-cache static server";
    # Skip cleanly instead of crash-looping when the repo has not been restored
    # yet — the same guard docker-stack already carries, and the reason that
    # unit stayed quiet through this reinstall while these two did not.
    unitConfig.ConditionPathExists = "/home/${username}/projects/study/scripts/serve.py";
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

  # ── WhatsApp bridge: REMOVED 2026-10-16, his order ("rm whatsapp fully
  # fully fully", "Never whatsapp. No one.") — decisions row 107. The unit,
  # its case history and the tailscale0 QR port are gone with it.
  # The last piece went 2026-10-17, on his "rm whatsapp mcp": the 222 M
  # ~/projects/whatsapp-mcp clone — which this comment used to keep on disk as
  # the message-history archive — was deleted after a recon found no store/,
  # no messages.db and no unpushed work (decisions row 111). Nothing in this
  # repo referenced the path, so no unit moved with it.

  # The unit half of the launcher defined above.
  #
  # Ordering: Requires/After docker.service (a launcher that runs before the
  # daemon exists would fail every boot), but wantedBy multi-user.target so it
  # is a plain part of "the machine is up". Type=oneshot + RemainAfterExit
  # makes `systemctl status docker-stack` show the LAST run's exit code, which
  # is what makes a failed project visible instead of scrolling past.
  #
  # Runs as `username`, not root: the user is in the docker group, and
  # docker compose reads ~/Projects/servers/.env files whose owner is that
  # user. Running as root would work too but would rewrite the bind-mounted
  # files' ownership to root on the first `up`, which is a slow-motion
  # permission bug waiting for a later hand-edit.
  systemd.services.docker-stack = {
    description = "Bring the compose stack under ~/Projects/servers up";
    # Requires, not just wants: if dockerd is genuinely dead there is nothing
    # to launch and the failure should be dockerd's, not a confusing
    # "docker: not found" from this unit.
    requires = ["docker.service"];
    after = ["docker.service"];
    wantedBy = ["multi-user.target"];
    unitConfig = {
      # Re-run on every boot. `ConditionPathExists` guards the directory so a
      # box that has never had the stack restored skips cleanly instead of
      # landing in --failed on first install.
      # CASE 2026-10-15: was ~/Projects/servers (capital P); the reinstall
      # restored to ~/projects, so this condition was false and the whole
      # 18-container stack sat unstarted with the guard reading it as
      # "not restored yet". Same lowercase rule as AGENTS.md item 9.
      ConditionPathExists = "/home/${username}/projects/servers";
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = username;
      WorkingDirectory = "/home/${username}/projects/servers";
      ExecStart = "${dockerStack}/bin/docker-stack";
      TimeoutStartSec = "15min"; # first boot pulls 13 images, that is minutes
    };
  };

  # ─── sv-watch — the health sweep ───────────────────────────────────────────
  # The donor looped `sv-watch.sh; sleep 60` inside its run script so the
  # script stayed a testable single shot. A timer is that shape natively, and
  # OnUnitActiveSec reproduces the cadence exactly. If a sweep runs long (13
  # curls + a dig, up to ~68 s), systemd simply refuses to start a second
  # instance of an active service — the same serialization the sleep gave.
  # AccuracySec matters: the default is 1 min, which would smear/alias a 60 s
  # cadence into something erratic.
  environment.etc."sv-watch/http-endpoints".text = builtins.readFile ../../scripts/thinkcentre/http-endpoints;

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
  # then cannot edit — a permission bug that only shows up on the next hand
  # write. HOME is set explicitly rather than assumed: the bisync baseline and
  # rclone's own cache/config both resolve under it, and a wrong HOME makes
  # every run look like a first run.
  systemd.services.filen-sync = {
    description = "Two-way bisync: Filen drive root <-> ~/filen";
    # Ordering only. Needs network (it talks to api.filen.io) and the secrets
    # rendered, otherwise the EnvironmentFile below is absent and the unit fails
    # instead of skipping.
    after = ["network-online.target" "sops-install-secrets.service"];
    wants = ["network-online.target"];
    unitConfig = {
      # Skip cleanly when ~/filen has not been created/restored yet, rather than
      # landing in --failed — the same guard study, docker-stack and
      # opencode-telegram already carry. It will start on its own the moment the
      # directory exists.
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
      # A file, not Environment=: these are secrets, and Environment= would put
      # them in the unit definition where `systemctl show` reads them back.
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
