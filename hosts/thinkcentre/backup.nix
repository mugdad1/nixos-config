# Nightly 03:17 backup — port of the donor's runit pair
# /etc/sv/backup-daily (a sleep-loop, because Void has no cron at all) plus
# /usr/local/bin/backup-run.sh, which is carried verbatim as
# ../../scripts/thinkcentre/backup-run.sh.
#
#   runit while-loop + /var/log/backup-daily.log  ->  systemd.timer + journald
#   wait_for_sane_clock()                          ->  wait-sane-clock ExecStartPre
#
# WHY THE CLOCK GUARD EXISTS AT ALL: the CMOS battery was removed 2026-10-04,
# so every AC-cut boot starts at 2015-01-01 and only NTP puts it right —
# 10–20 s typically, once observed never within 120 s. On 2026-10-06 the donor
# logged "2015-01-01 03:00:16 sleeping 1004s until 2015-01-01 03:17:00" and the
# backup fired at 05:49 instead.
#
# `After=time-sync.target` is NOT the guard. Measured in the KVM rehearsal:
# stock systemd never activates time-sync.target (nothing pulls it and
# systemd-time-wait-sync is not shipped), so that ordering gates nothing. It is
# kept below as documentation of intent only.
{pkgs, ...}: let
  backupRun = pkgs.writeShellScriptBin "backup-run" (builtins.readFile ../../scripts/thinkcentre/backup-run.sh);

  # SKIP, DON'T PROCEED. The donor's guard was best-effort: after 120 s it ran
  # anyway. That is actively dangerous here, because backup-run.sh rotates
  # FIRST — `rm -rf daily-6`, shift the chain, then TODAY=$(date +%Y-%m-%d) and
  # DOW=$(date +%w) decide the rotation family. Running on a 2015 clock:
  #   * evicts a real snapshot to make room,
  #   * writes 2015 mtimes into the new daily-0,
  #   * which becomes the next night's --link-dest base, so the following run
  #     re-copies the whole 639 MB and evicts ANOTHER real backup.
  # The read-back verify still passes (content matches), so nothing alerts.
  # Failing the unit is the honest outcome: it is visible in `systemctl status`
  # and the timer simply tries again tomorrow.
  waitClock = pkgs.writeShellScriptBin "wait-sane-clock" ''
    i=0
    while [ "$(timedatectl show -p NTPSynchronized --value)" != "yes" ]; do
      i=$((i + 1))
      if [ "$i" -ge 60 ]; then
        echo "[backup-daily] clock still unsynced after 120s - REFUSING to run"
        echo "[backup-daily] backup-run.sh rotates on wall-clock (rm -rf daily-6,"
        echo "[backup-daily] TODAY/DOW from date), so a 2015 clock would evict a real"
        echo "[backup-daily] snapshot and poison the --link-dest base. Skipping."
        exit 1
      fi
      sleep 2
    done
    # Belt and braces: even once NTP reports synced, refuse a pre-2026 clock.
    # This is the donor's own year-floor check, and it is clock-agnostic.
    if [ "$(date +%Y)" -lt 2026 ]; then
      echo "[backup-daily] NTP says synced but date reads $(date '+%F %T') - refusing to rotate"
      exit 1
    fi
    echo "[backup-daily] clock gate passed at $(date '+%F %T') after $i extra probes"
  '';
in {
  systemd.services.backup-daily = {
    description = "Snapshot sources onto /srv/backup (rsync + verify + rotate)";
    # Ordering of record only — see the header: this gates nothing on its own.
    after = ["time-sync.target"];
    # And tell him when it fails. sv-watch's unit sweep would also see this,
    # but only on its next 60 s tick and only as a generic "unit down" line -
    # a backup that did not run is worth a page that names it, which is what
    # the template unit in modules/core/monitoring.nix does. %n expands to this
    # unit's own name, so the message reads "backup-daily.service failed on
    # thinkcentre".
    unitConfig.OnFailure = ["notify-telegram@%n.service"];
    # Tools backup-run.sh shells out to. This is the NixOS replacement for the
    # donor's hand-built PATH= line.
    path = with pkgs; [
      coreutils
      findutils
      util-linux # findmnt
      gnugrep
      rsync
      systemd # timedatectl, for the clock gate
    ];
    serviceConfig = {
      Type = "oneshot";
      # Refuses a bogus clock rather than running anyway (see above).
      ExecStartPre = "${waitClock}/bin/wait-sane-clock";
      ExecStart = "${backupRun}/bin/backup-run";
      # 639 MB of rsync with hardlinking; generous, but bounded so a hung
      # mount fails the unit instead of wedging it forever.
      TimeoutStartSec = "30min";
    };
  };

  systemd.timers.backup-daily = {
    description = "Daily 03:17 backup (donor runit loop ported)";
    wantedBy = ["timers.target"];
    after = ["time-sync.target"];
    timerConfig = {
      OnCalendar = "*-*-* 03:17:00";
      # Correct for the legitimate case (box was off across 03:17 → catch up).
      # It does NOT protect against a wrong clock — with a dead CMOS it changes
      # the failure mode from "fires at 03:17 in 2015" to "fires at a random
      # instant once NTP steps, or skips the real day". The ExecStartPre guard
      # is what actually handles that; see the header.
      Persistent = true;
      # Default AccuracySec is 1 min, which would smear 03:17:00 into a window.
      AccuracySec = "1s";
      RandomizedDelaySec = 0;
    };
  };
}
