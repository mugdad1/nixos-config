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
{pkgs, username, ...}: let
  # opencode v2 via the sst/opencode overlay (modules/core/opencode.nix).
  # nixpkgs' own opencode is v1 and stale — this is why the input exists.
  ocPath = "${pkgs.opencode}/bin:${pkgs.coreutils}/bin:${pkgs.iproute2}/bin:${pkgs.gnugrep}/bin";

  # The donor's 90 s readiness wait, verbatim in behaviour. It exists because
  # After= only guarantees opencode was SPAWNED, not that :49374 answers — and
  # on 2026-10-04 the bot came up ~1 min early, logged "reason=startup", and
  # then never retried, staying up but permanently blind while every service
  # showed green. Bounded at 90 s: a bot that starts blind is better than none.
  waitOpencode = pkgs.writeShellScript "wait-opencode-api" ''
    i=0
    while ! ${pkgs.iproute2}/bin/ss -ltn 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q '127.0.0.1:49374 '; do
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
      inetutils # hostname — NOT in NixOS's default path
      systemd # systemctl
    ];
    text = builtins.readFile ./sv-watch.sh;
  };
in {
  # ─── OpenCode server — the singleton the Telegram bot attaches to ───────────
  # OPENCODE IS A SINGLETON: a second `serve --service` exits at once if one
  # already holds 127.0.0.1:49374. Under runit the holder was usually a
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
  # DISABLED 2026-10-12 on his word. Commented out, not deleted, so the port
  # work below survives and can be re-enabled by removing the block comment.
  # `waitOpencode` above is now unused — harmless, kept for the re-enable.
  /*
  # Wants=/After= on opencode-serve — deliberately NOT Requires=. Requires
  # propagates STOP, so every opencode restart would take the bot down with it;
  # the donor kept the bot up and re-attaching, and that is the behaviour worth
  # preserving. After= only orders; the ExecStartPre covers readiness.
  systemd.services.opencode-telegram = {
    description = "opencode-telegram bot (waits for the OpenCode API)";
    wantedBy = ["multi-user.target"];
    wants = ["opencode-serve.service"];
    after = ["opencode-serve.service"];
    serviceConfig = {
      Type = "simple";
      User = username;
      Group = username;
      Environment = [
        "HOME=/home/${username}"
        "USER=${username}"
        "LOGNAME=${username}"
        "PATH=${pkgs.nodejs}/bin:/home/${username}/.local/bin:${pkgs.coreutils}/bin:${pkgs.iproute2}/bin:${pkgs.gnugrep}/bin"
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
  */

  # ─── study PWA ─────────────────────────────────────────────────────────────
  # DISABLED 2026-10-12 on his word. Commented out, not deleted. The reason it
  # ran in place still holds for a re-enable: serve.py computes
  # ROOT = dirname(dirname(__file__)), so copying it into the Nix store would
  # make it serve an empty store directory. Also a behaviour change worth
  # knowing: under runit this ran as ROOT (the run script had no chpst -u).
  /*
  systemd.services.study = {
    description = "Study PWA no-cache static server";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    serviceConfig = {
      Type = "simple";
      User = username;
      Group = username;
      WorkingDirectory = "/home/${username}/Projects/study";
      ExecStart = "${pkgs.python3}/bin/python3 /home/${username}/Projects/study/scripts/serve.py 8091 0.0.0.0";
      Restart = "always";
      RestartSec = "5s";
    };
  };
  */

  # ─── sv-watch — the health sweep ───────────────────────────────────────────
  # The donor looped `sv-watch.sh; sleep 60` inside its run script so the
  # script stayed a testable single shot. A timer is that shape natively, and
  # OnUnitActiveSec reproduces the cadence exactly. If a sweep runs long (13
  # curls + a dig, up to ~68 s), systemd simply refuses to start a second
  # instance of an active service — the same serialization the sleep gave.
  # AccuracySec matters: the default is 1 min, which would smear/alias a 60 s
  # cadence into something erratic.
  environment.etc."sv-watch/http-endpoints".text = builtins.readFile ./http-endpoints;

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
