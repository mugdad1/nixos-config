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
      # Kept as an imperative path on purpose: the wrapper does
      # `npx -y @grinev/opencode-telegram-bot@latest start`, an impure network
      # fetch at every start. Moving it into the store would pin it, which is
      # worth doing — but it is a separate decision, not part of this port.
      ExecStart = "/home/${username}/.local/bin/opencode-telegram-start";
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
  systemd.services.study = {
    description = "Study PWA no-cache static server";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    serviceConfig = {
      Type = "simple";
      User = username;
      WorkingDirectory = "/home/${username}/Projects/study";
      ExecStart = "${pkgs.python3}/bin/python3 /home/${username}/Projects/study/scripts/serve.py 8091 0.0.0.0";
      Restart = "always";
      RestartSec = "5s";
    };
  };

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
      ConditionPathExists = "/home/${username}/Projects/servers";
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = username;
      WorkingDirectory = "/home/${username}/Projects/servers";
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

  # journald defaults to `auto` — volatile unless /var/log/journal exists — so
  # without this the logs those runit units wrote to /var/log/*.log would not
  # survive a reboot at all.
  services.journald.settings.Journal.Storage = "persistent";
}
