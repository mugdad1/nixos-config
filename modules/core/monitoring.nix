# Grandpa's sops wiring (fleet-scoped until 2026-11-02; see the gate below).
# Disk health WAS here too and is gone — see the note at the bottom of this file.
#
# SMART MONITORING REMOVED 2026-10-25 at his order ("rm smartd"). It was added
# 2026-10-18 because every host could detect a failure and none could report
# one, and it is being taken out for the same reason it stopped mattering: the
# reporting never had anywhere to go. Both transports tried since October are
# gone — the ntfy container (2026-10-12, "just rm notify") and Telegram itself,
# removed wholesale 2026-10-23 (row 207): the bot, the `notify-telegram`
# script, the `notify-telegram@` OnFailure= template and its `telegram/*` sops
# keys all went in one commit. smartd was left running afterwards to `wall`
# only, which is a log nobody reads unasked on a headless box.
#
# So the state to expect, stated plainly: no disk daemon, no unit/container
# sweep (sv-watch went 2026-10-23 too), no delivery path of any kind. A failing
# disk or a failing unit is journald and `systemctl --failed`, and that is all.
# Re-adding a detector before adding a TRANSPORT would repeat the mistake this
# file was written to fix — build the delivery half first.
#
# This module is in modules/core, so victus imports it: the laptop loses disk
# monitoring in the same commit as the server. Flagged to him before it was done.
#
# The sops block below is the fleet wiring, not a credential: it names the
# ciphertext file and the age key path for every host. Its last entries were
# the `telegram/*` secrets; what remains is what the surviving services still
# read — `filen/*`, `sear/secret_key`, and `opencode/*`.
#
# SCOPED TO GRANDPA ON 2026-11-02 (his order "sops is for grandpa"). Between
# 2026-10-31 and that day every host decrypted `filen/*`; the laptops now hold
# no age key and no secrets, and filen-sync is gated the same way. The age key
# (/var/lib/sops-nix/key.txt) is needed on the server only.
{
  lib,
  host,
  ...
}: {
  # ── sops wiring — grandpa only ──────────────────────────────────────────────
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
  # SCOPED TO GRANDPA ONLY 2026-11-02 (his order: "sops is for grandpa"). The
  # laptops hold no age key and declare no secrets any more (filen-sync's
  # declarations live in modules/core/filen-sync.nix, gated the same way), so
  # these defaults would be dead weight there.
  sops = lib.mkIf (host == "grandpa") {
    defaultSopsFile = lib.mkDefault ../../secrets/fleet.sops.yaml;

    # The private key, at the one path grandpa uses:
    # /var/lib/sops-nix/key.txt (root:root 0600).
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
  # REMOVED 2026-10-25 at his order ("rm smartd"). smartd was the last watcher
  # on the box; with it gone this host has no disk monitoring and no unit
  # sweep, and the failure surface is journald plus `systemctl --failed`.
  # Worth stating because the removal reads as an oversight otherwise: it is
  # not. Nothing here delivers anywhere — the Telegram mailer went 2026-10-23
  # (row 207), the template unit went the same day, and the container/unit
  # sweep (sv-watch) was deleted before that — so smartd was reporting to a
  # log nobody reads. Taking the daemon out is the honest version of a
  # notification path with no transport.
  #
  # NOTE: this file is in modules/core, which victus imports too — the laptop
  # loses disk monitoring in the same commit. Flagged before it was done.
}
