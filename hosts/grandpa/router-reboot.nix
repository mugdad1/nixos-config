# ─── router-reboot, daily at 03:13 ──────────────────────────────────────────
#
# The SCHEDULED half of router-reboot. The command itself lives in
# modules/core/router-reboot.nix so every host can run it interactively; this
# file holds only the timer, and it is in hosts/grandpa/ for one reason:
#
#   A timer in modules/core would fire on grandpa AND victus AND t480s, all
#   at 03:13. Two laptops are usually suspended so they would usually miss
#   it — but "usually" is not a guarantee, and on the night one is awake the
#   second reboot would land while the router was still down, fail to log in,
#   and go red. grandpa is the box that is on at 03:13 by construction. Same
#   split backup.nix already uses: shared tools in modules/core, grandpa's
#   scheduled jobs here.
#
# THE HOUR. His ask: *"daily at 3:13 am"*, bounded by *"i prefer after 11pm
# and before 4am"*. 03:13 sits inside that window and is already a house hour
# — the whatsapp ritual fires at 3:13am too (6b24a22) — so nothing here fights
# an existing schedule.
#
# WHY THE HOUR MATTERS ENOUGH TO PIN IT: 192.168.8.1 is not just the gateway,
# it is the second nameserver in servers.md rule 4 and blocky's pinned
# upstream. The reboot takes ~40-60s, during which resolution house-wide
# fails. At 03:13 nobody notices; at any ordinary hour every lookup on both
# machines fails for a minute.
#
# Persistent = false IS THE DECISION, not a default. With it off, a run missed
# because grandpa was off is simply skipped. With it on, systemd would fire
# the moment the box next boots — so an outage ending at 10am would reboot the
# router at 10am, which is exactly the disruptive daytime run the 03:13 window
# exists to avoid. Catching up on this job is worse than missing it.
#
# Runs as him, not root, because the wrapper reads $HOME/.config/router-
# reboot/pass: a root run would look in /root, find nothing, and fail on the
# first timer fire with a message pointing at a file he never created. HOME is
# set explicitly rather than trusted from the user database.
#
# ExecStart is PATH-resolved through /run/current-system/sw/bin rather than a
# store path, for the reason row 216 wrote down: a hardcoded store path is a
# reference the garbage collector can invalidate while the config that wrote it
# looks perfectly healthy. systemPackages lands the wrapper there by
# construction, so it is the same binary he would type.
#
# The unit is non-interactive, so it can never record the password — that is a
# thing only he can do, interactively, once. Until he has, the timer fails
# loudly with a journal line saying so. Deliberate: a Condition* that quietly
# skipped instead would hide an unconfigured tool behind a green unit, which
# is the failure mode this wiki keeps documenting.
{...}: {
  systemd.services.router-reboot = {
    description = "Reboot the house router (Huawei H122-373 at 192.168.8.1)";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      User = "mugdad";
      Environment = ["HOME=/home/mugdad"];
      ExecStart = "/run/current-system/sw/bin/router-reboot";
      # The script blocks through the ~40-60s reboot plus a 120s poll; bound
      # it so a hung network can never leave the unit running forever.
      TimeoutStartSec = "5min";
    };
  };

  systemd.timers.router-reboot = {
    description = "Daily router reboot at 03:13";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 03:13:00";
      # systemd's 1min default accuracy would land anywhere in 03:12–03:13;
      # the hour is a motif here, so hold it to the minute.
      AccuracySec = "10s";
      # Explicit, because the alternative is a daytime reboot (see above).
      Persistent = false;
      # Not the default pairing, but stating it means renaming one unit
      # cannot silently orphan the other.
      Unit = "router-reboot.service";
    };
  };
}
