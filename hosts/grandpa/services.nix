# The hand-written service layer, MOVED HERE 2026-10-22 from
# hosts/thinkcentre/services.nix on his "move the services from thinkcentre to
# grandpa" — the ThinkCentre is being returned to its owner, so whatever it
# was the server OF has to have a home. Read that file for the full history of
# each unit; it stays in the repo, commented out, as the record of where this
# came from.
#
# WHAT IS NOT IN THIS FILE, deliberately:
#   docker-stack   was in ./default.nix and is GONE as of 2026-10-25 — the seven
#                  compose projects and their data were removed at his order,
#                  so there is no launcher to declare. Same reason no second
#                  definition belongs here: a duplicate option is a conflict,
#                  not a migration.
#   backup-daily   ./backup.nix is not moved: it mounts /srv/backup, a physical
#                  240G disk that is bolted to the ThinkCentre and cannot travel
#                  with a config change. The disk, the mount, the timer and the
#                  fstab-gated check in checkup.sh move together or not at all.
#   glances        was ./glances.nix; DELETED 2026-10-25 at his order.
#   tailscale-serve / glances / smartd
#                  all gone 2026-10-25 — the first two because their targets
#                  (vaultwarden :8443, vikunja :444, the glances page) were
#                  removed with the compose stack, the third because it had no
#                  transport left to report through.
#   nginx          removed 2026-10-25 in the strip commit and RESTORED the same
#                  day, an hour later: killing :80 did not read as "sparse
#                  box", it read as "box is down" — he hit it in a browser and
#                  got ERR_CONNECTION_REFUSED. nginx lives in ./default.nix and
#                  serves the index; it is NOT declared here, because this file
#                  is the service layer and the web server fronts it.
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
  pkgs,
  username,
  ...
}: {
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

  # filen-sync moved to modules/core/filen-sync.nix on 2026-10-31, when he
  # asked for the same setup on the laptops. The unit, timer and its sops
  # template now live in the shared layer; this host file keeps only the units
  # that are grandpa-specific.
  #
  # The reasoning for the wait-wrapper lives at opencodeServe above; this is
  # just the unit. It outlived the Telegram bot (removed 2026-10-23) because it
  # is what answers :13420 after a reboot, TUI or not.
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

  # The index links study at grandpa's tailnet address; keep the bind on
  # 0.0.0.0 so loopback also works, and let the firewall expose it on
  # tailscale0 only.
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [8091];

  # journald defaults to `auto` — volatile unless /var/log/journal exists — so
  # without this the logs those runit units wrote to /var/log/*.log would not
  # survive a reboot at all.
  services.journald.settings.Journal.Storage = "persistent";
}
