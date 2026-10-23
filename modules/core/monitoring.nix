# Alerting + disk health, shared by all three hosts.
#
# WHY (2026-10-18): every host could detect a failure and none could report one.
# The detectors were already there - a unit/container/endpoint/DNS sweep
# (sv-watch, on the thinkcentre; removed at his order 2026-10-23, see below),
# and nothing at all for disk failure on any host (`smartctl` was installed,
# the `smartd` daemon was not) - while
# delivery had been off since 2026-10-12, when the ntfy container was removed on
# his "just rm notify". The result he hit: a box can lose a disk or a container
# and the only trace is journald, which nobody reads unasked.
#
# WHAT THIS ADDS, in the two places that were empty:
#
#   1. A delivery path - `notify-telegram`, one script (pkgs/notify-telegram.nix
#      -> scripts/notify-telegram.sh) used by smartd below and by the
#      OnFailure= template unit here. (sv-watch was a third caller until
#      2026-10-23.) It posts to the Telegram Bot API with
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
{
  pkgs,
  config,
  lib,
  host,
  ...
}: let
  notify = pkgs.callPackage ../../pkgs/notify-telegram.nix {};
in {
  environment.systemPackages = [notify];

  # ── the Telegram credential, for EVERY host ────────────────────────────────
  #
  # WHERE IT LIVES AND WHY IT IS HERE. This started in hosts/thinkcentre/
  # secrets.nix, because until 2026-10-18 the ThinkCentre was the only host that
  # could deliver anything. On his order ("do 1 2 now!", item 2 of the alerting
  # work) the age key was placed on all three hosts, so t480s and grandpa can
  # deliver too — and the credential had to move somewhere all three import.
  # `modules/core` is that place, and this module is where the alert path
  # already lives, so the token and the thing that sends with it are one file.
  #
  # Both options are `mkDefault` so a host that wants a different key path or a
  # different ciphertext file can still say so and win.
  #
  # The ciphertext file was RENAMED the same day: secrets/thinkcentre.sops.yaml
  # -> secrets/fleet.sops.yaml. A fleet-wide secret in a file named after one
  # host is exactly the kind of drift the rest of this pass was spent deleting.
  # Nothing re-encrypted — the file name is not in the ciphertext, and
  # .sops.yaml's `path_regex` is generic (`secrets/[^/]+\.sops\.yaml$`), so it
  # keeps covering the new name.
  #
  # NOT ON victus (2026-10-22, "can we skip on it"): that host is set up without
  # the age key, and sops-install-secrets fails the whole activation when a
  # declared secret cannot be decrypted — so declaring the token there would
  # block its very first switch. The gate is by hostname, not by key presence,
  # because activation is exactly where the absence would bite. Consequence:
  # no Telegram alerts FROM the Victus. To turn them on, copy the key to
  # /var/lib/sops-nix/key.txt and delete the `host != "victus"` condition.
  sops = lib.mkIf (host != "victus") {
    defaultSopsFile = lib.mkDefault ../../secrets/fleet.sops.yaml;

    # The private key, at the one path every host uses now:
    # /var/lib/sops-nix/key.txt (root:root 0600), plus ~/.config/sops/age/
    # keys.txt on the laptop for hand-editing with the `sops` CLI.
    # DELIBERATELY not a home directory path: sops-install-secrets runs early
    # in boot, before homes are necessarily useful, and a root-owned path under
    # /var/lib states plainly that this is machine state, not user state.
    #
    # ON A FRESH INSTALL the key is the ONE thing the flake cannot restore for
    # itself (it is not in the repo, by design). Restore it to this path before
    # the first switch, or activation fails while decrypting.
    age.keyFile = lib.mkDefault "/var/lib/sops-nix/key.txt";

    secrets = {
      # Names map onto the YAML structure with `/` as the nesting separator, so
      # "telegram/bot_token" is `telegram: { bot_token: ... }`. Moved here from
      # the ThinkCentre's file 2026-10-18; the values are unchanged.
      "telegram/bot_token" = {};
      "telegram/allowed_user_id" = {};
    };

    # Rendered at activation to /run/secrets/rendered/notify-telegram.env, the
    # path scripts/notify-telegram.sh reads by default — so no unit has to be
    # told where the token is.
    #
    # root:root 0400 (the default) and NOT the `username` owner the ThinkCentre's
    # other two templates use: every caller of notify-telegram is root (smartd,
    # notify-telegram@ — sv-watch until 2026-10-23), so nothing else needs to
    # read it. The script's
    # probe is `[ -r ... ]` as root, so a host that somehow lost its key fails
    # closed — it logs NOTIFY(no-token) and exits 0 rather than queueing forever.
    templates."notify-telegram.env".content = ''
      TELEGRAM_BOT_TOKEN=${config.sops.placeholder."telegram/bot_token"}
      TELEGRAM_CHAT_ID=${config.sops.placeholder."telegram/allowed_user_id"}
    '';
  };

  # OnFailure= hook for any unit that has to be heard about. Used by
  # backup-daily (hosts/thinkcentre/backup.nix); the unit sweep that used to
  # report failed units alongside it went 2026-10-23, which makes this hook the
  # only path a failing unit has to the phone — a failing backup still reaches
  # it with the failed unit named rather than not at all.
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
