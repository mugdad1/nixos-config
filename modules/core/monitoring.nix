# Disk health + the fleet's sops wiring, shared by every host.
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
# DELIVERY, or the lack of it. Two transports were tried and BOTH are gone now:
# the ntfy container (2026-10-12, "just rm notify") and then Telegram itself,
# removed wholesale at his order on 2026-10-23 (row 207) - the bot, the
# `notify-telegram` script, the `notify-telegram@` OnFailure= template, its
# sops secrets and the `telegram/*` key pair all went in one commit.
#
# WHAT IS LEFT is `smartd`, still worth running on its own: it is the one thing
# that notices a disk going bad BEFORE it takes the box with it, and it was
# simply not enabled anywhere. Autodetect covers sda/nvme0n1 without naming
# devices that move between boots (their /dev paths do - see hosts/thinkcentre's
# hardware comment). SMART was last configured by hand on the donor Void
# install; this is the NixOS replacement.
#
# Its notifications now go to `wall` only. `notifications.mail` went with
# Telegram: smartd calls a sendmail-compatible binary as `<mailer> -i
# <recipient>` and pipes the report to stdin, and with no such binary left on
# the box there is nothing for it to call - an MTA would be the only
# alternative and there will not be one. `wall` still stays on - the journal
# copy is what you find when you eventually look, and on a headless box it
# costs nothing. Net effect to be explicit about: a failing disk is logged,
# not telephoned. Nothing on this box pushes a message anywhere now.
#
# The sops block below is the fleet wiring, not the credential it used to
# carry: it names the ciphertext file and the age key path for every host
# except victus (see the comment there). The `telegram/*` secrets it declared
# were the last entries in it.
{
  pkgs,
  config,
  lib,
  host,
  ...
}: {
  # ── the fleet's sops wiring, for every host except victus ──────────────────
  #
  # WHAT THIS BLOCK IS. It used to exist to carry the Telegram credential
  # fleet-wide: it started in hosts/thinkcentre/secrets.nix because until
  # 2026-10-18 the ThinkCentre was the only host that could deliver anything,
  # then had to move somewhere all three hosts import once the age key was
  # placed on them. Telegram went wholesale on 2026-10-23 (row 207) and took
  # the last `sops.secrets` entry with it — what is left is the two defaults a
  # host needs before it can declare ANY secret at all, which is why it stayed
  # in modules/core rather than being deleted with the credential.
  #
  # Both options are `mkDefault` so a host that wants a different key path or a
  # different ciphertext file can still say so and win.
  #
  # The ciphertext file was RENAMED on 2026-10-18: secrets/thinkcentre.sops.yaml
  # -> secrets/fleet.sops.yaml. A fleet-wide secret in a file named after one
  # host is exactly the kind of drift the rest of that pass was spent deleting.
  # Nothing re-encrypted — the file name is not in the ciphertext, and
  # .sops.yaml's `path_regex` is generic (`secrets/[^/]+\.sops\.yaml$`), so it
  # keeps covering the new name.
  #
  # NOT ON victus (2026-10-22, "can we skip on it"): that host is set up without
  # the age key, and sops-install-secrets fails the whole activation when a
  # declared secret cannot be decrypted — so declaring a secret there would
  # block its very first switch. The gate is by hostname, not by key presence,
  # because activation is exactly where the absence would bite. Consequence:
  # grandpa's secrets decrypt from here, the Victus's own host file does not
  # participate. To change that, copy the key to /var/lib/sops-nix/key.txt and
  # delete the `host != "victus"` condition.
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
  };

  # OnFailure= USED to be wired here too: `unitConfig.OnFailure =
  # ["notify-telegram@%n.service"]` on callers such as backup-daily, which
  # reported "backup-daily.service failed on thinkcentre" to the phone. The
  # template unit went with Telegram on 2026-10-23 (row 207), and so did the
  # unit sweep that had shared it — so a failing unit now has NO notification
  # path at all, only journald and `systemctl --failed`. Recorded here rather
  # than left silent, because the hook's absence is a real regression and the
  # next person to add a transport should re-add it.
  services.smartd = {
    enable = true;
    autodetect = true;
    notifications = {
      # NO MAIL, since 2026-10-23 (row 207). `notifications.mail` was never the
      # generic option here: it was `enable = true` with our own
      # `notify-telegram` as the `mailer`, because smartd calls a
      # sendmail-compatible binary as `<mailer> -i <recipient>` and pipes the
      # report to stdin, which is the interface that script implemented. With
      # Telegram gone there is no such binary left on the box, and `enable`
      # without one would point smartd at a sendmail that does not exist. The
      # default for this option is `sendmailSetuidWrapper != null`, which is
      # false — there is no MTA on any of these boxes and there will not be
      # one — so dropping the block is the honest spelling of "no delivery".
      #
      # An attrset with `enable`, not a bool (the first draft of this file set
      # `wall = true;` and the eval refused it - which is the good kind of loud).
      wall.enable = true;
    };
  };
}
