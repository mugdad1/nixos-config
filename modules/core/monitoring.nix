# Alerting + disk health, shared by all three hosts.
#
# WHY (2026-10-18): every host could detect a failure and none could report one.
# The detectors were already there - sv-watch on the thinkcentre (units,
# containers, published endpoints, DNS), and nothing at all for disk failure on
# any host (`smartctl` was installed, the `smartd` daemon was not) - while
# delivery had been off since 2026-10-12, when the ntfy container was removed on
# his "just rm notify". The result he hit: a box can lose a disk or a container
# and the only trace is journald, which nobody reads unasked.
#
# WHAT THIS ADDS, in the two places that were empty:
#
#   1. A delivery path - `notify-telegram`, one script (pkgs/notify-telegram.nix
#      -> scripts/notify-telegram.sh) used by sv-watch, by smartd below, and by
#      the OnFailure= template unit here. It posts to the Telegram Bot API with
#      the token out of sops; on a host with no key yet it logs NOTIFY(no-token)
#      and exits 0 instead of queueing forever. See that script's header.
#
#   2. `smartd` on every host. It is the one thing that notices a disk going bad
#      BEFORE it takes the box with it, and it was simply not enabled anywhere.
#      Autodetect covers sda/nvme0n1 without naming devices that move between
#      boots (their /dev paths do - see hosts/thinkcentre's hardware comment).
#      SMART was last configured by hand on the donor Void install; this is the
#      NixOS replacement.
#
# The smartd hook is deliberately `notifications.mail` with our own script as
# the `mailer`: smartd calls a sendmail-compatible binary as
# `<mailer> -i <recipient>` and pipes the report to stdin, which is exactly the
# interface notify-telegram implements (it ignores `-i`; the chat id is the
# secret). `wall` also stays on - the journal copy is what you find when you
# eventually look, and on a headless box it costs nothing.
{pkgs, config, ...}: let
  notify = pkgs.callPackage ../../pkgs/notify-telegram.nix {};
in {
  environment.systemPackages = [notify];

  # OnFailure= hook for any unit that has to be heard about. Used by
  # backup-daily (hosts/thinkcentre/backup.nix); sv-watch already reports failed
  # units on its own sweep, but a failing backup should reach the phone with
  # the failed unit named, not wait for a sweep to classify it.
  #
  # `%i` is the failed unit's name as the instance, `%n` in the caller expands
  # to the same, so `unitConfig.OnFailure = ["notify-telegram@%n.service"]`
  # produces "backup-daily.service failed on thinkcentre".
  systemd.services."notify-telegram@" = {
    description = "Telegram alert that %i failed";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${notify}/bin/notify-telegram --title 'unit failed' \"%i failed on ${config.networking.hostName}\"";
    };
  };

  services.smartd = {
    enable = true;
    autodetect = true;
    notifications = {
      mail = {
        # Default is `services.mail.sendmailSetuidWrapper != null`, which is
        # false here: there is no MTA on any of these boxes and there will not
        # be one. The mailer below is the whole point.
        enable = true;
        mailer = "${notify}/bin/notify-telegram";
        recipient = "telegram";
        sender = "smartd@${config.networking.hostName}";
      };
      # An attrset with `enable`, not a bool (the first draft of this file set
      # `wall = true;` and the eval refused it - which is the good kind of loud).
      wall.enable = true;
    };
  };
}
