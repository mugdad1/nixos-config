# Secrets, declaratively — the answer to "this repo is PUBLIC on GitHub".
#
# WHY (2026-10-13): github.com/mugdad1/nixos-config is public, and the flake is
# the source of truth. Those collide, because the obvious way to declare a
# credential in Nix is `foo = "the-token";` — which would publish it, and would
# keep it published in the permanent commit history even if a later commit
# removed it. Deleting a secret from a public repo does not un-share it.
#
# The rule this file enforces: **no plaintext credential ever appears in a .nix
# file, in the repo, or on stdout.** Encrypted ciphertext may be committed,
# because it is useless without a private key that never enters git.
#
#   secrets/fleet.sops.yaml   AES-256-GCM ciphertext, committed
#                             (renamed from thinkcentre.sops.yaml 2026-10-18:
#                             it is now the whole fleet's file, read by all
#                             three hosts via modules/core/monitoring.nix)
#   .sops.yaml                      the PUBLIC age recipient key, committed
#   ~/.config/sops/age/keys.txt     private key, laptop, mode 600, NOT in git
#   /var/lib/sops-nix/key.txt       private key, server,  mode 600, NOT in git
#
# Verified the same day this was added: every commit in `git log --all -p` was
# scanned for github_pat/ghp_/telegram-token/AWS-key/PEM patterns. Clean. The
# scan is worth repeating after any force-push or history rewrite.
#
# ON A REINSTALL — this is the bootstrap step that a purely declarative system
# cannot do for itself: the private key is not in the repo (that is the point),
# so it must be restored by hand BEFORE `nixos-rebuild switch`, or activation
# fails while decrypting. Copy it to /var/lib/sops-nix/key.txt (mode 600,
# root:root) first. Everything else — the encrypted file, the wiring below —
# comes back with the flake on its own.
#
# Adding a secret:
#   1. put a plaintext value in a scratch file OUTSIDE the repo
#   2. `sops -e -i` it into secrets/fleet.sops.yaml (or use `sops` on the
#      file to edit it in place — sops decrypts to your editor and re-encrypts)
#   3. declare it in `sops.secrets` below, then reference
#      `config.sops.placeholder."<name>"` from a template or a service
{
  config,
  username,
  ...
}: {
  # ═══════════════ MOVED 2026-10-22 → hosts/grandpa ═════════════════════════
  # The units that read this left with the service layer ("move the services
  # from thinkcentre to grandpa"). Kept, not deleted: the history above still
  # describes what this file was for, and the box returns as-is if it ever does.
  # Everything above this line (the commentary and the module arguments) stays
  # valid; only the declarations below are inert.
  # ═══════════════════════════════════════════════════════════════════════════
  #   sops = {
  #     # The file itself and this pointer are ALSO defaulted fleet-wide in
  #     # modules/core/monitoring.nix (mkDefault, same value). Stated here as well
  #     # because this file is where the other ThinkCentre-only secrets live and a
  #     # reader should not have to go find which module supplies the default.
  #     defaultSopsFile = ../../secrets/fleet.sops.yaml;

  #     # Where the private key lives ON THE SERVER. Deliberately NOT
  #     # ~/.config/sops/age/keys.txt: sops-install-secrets runs early in boot,
  #     # before user homes are necessarily useful, and a root-owned path under
  #     # /var/lib states plainly that this is machine state, not user state.
  #     age.keyFile = "/var/lib/sops-nix/key.txt";

  #     secrets = {
  #       # NOTE 2026-10-18: `telegram/bot_token` and `telegram/allowed_user_id`
  #       # used to be declared here. They moved to modules/core/monitoring.nix,
  #       # because alerting now runs on all three hosts and every host needs the
  #       # same two values — declaring them in a host file meant t480s and grandpa
  #       # could not render notify-telegram.env at all. The values are unchanged.
  #       "opencode/server_password" = {};
  #       # NOTE 2026-10-15: `opencode/server_username` was removed from this list.
  #       # The username is the fixed string `opencode` (see the template below —
  #       # the server 401s on any other), so it is a constant, not a secret, and
  #       # declaring it here only rendered a 0400 root-owned file that nothing
  #       # read. The ciphertext still sits harmlessly in
  #       # secrets/fleet.sops.yaml; sops ignores keys with no declaration,
  #       # and re-encrypting the file to drop it would buy nothing.

  #       # Filen account (the cloud drive holding ~/filen — all KFU material).
  #       # Same file as everything else since 2026-10-15 — see .sops.yaml for the
  #       # second-recipient change that made one file possible. Originally written
  #       # into a SEPARATE secrets/filen.sops.yaml with `sopsFile`, because the
  #       # original private key was missing and adding a key to an existing sops
  #       # file means decrypt+re-encrypt (needs the private key) while a fresh
  #       # file needs only the public recipient. That workaround is retired now a
  #       # new key is installed; the entry is kept with its own comment because
  #       # the password in it was pasted in plaintext on 2026-10-15 and is due a
  #       # rotation — re-encrypting after rotation now needs no workaround.
  #       "filen/email" = {};
  #       "filen/password" = {};
  #     };

  #     # The whole bot config, rendered at activation into a file that never
  #     # exists on disk in plaintext outside the running system.
  #     #
  #     # This replaces ~/.config/opencode-telegram-bot/.env. That path was the
  #     # original plan and is what ConditionPathExists used to guard — but it was
  #     # unrecoverable by design (backup-run.sh's SOURCES never included
  #     # .config), it is outside the flake so a reinstall would not restore it,
  #     # and writing it by hand puts a token at a path a future `git add -A` or a
  #     # stray backup could pick up. A rendered template is declarative,
  #     # re-installable, and readable only by root and this unit.
  #     templates."opencode-telegram.env" = {
  #       # The unit runs as `username`, so it must be able to read the file.
  #       # Default is root:root 0400, which would give the unit an
  #       # "Access denied" and a crash loop that looks like a bot bug.
  #       owner = username;
  #       mode = "0400";
  #       content = ''
  #         TELEGRAM_BOT_TOKEN=${config.sops.placeholder."telegram/bot_token"}
  #         TELEGRAM_ALLOWED_USER_ID=${config.sops.placeholder."telegram/allowed_user_id"}

  #         # OpenCode v2. The bot defaults to v1 and CANNOT detect the version, so
  #         # every value here is load-bearing: v1's default port is 4096 and v2's
  #         # is 13420, and a stale port makes the wait-loop spin out and start a
  #         # bot that is permanently blind while every unit reads green.
  #         OPENCODE_SERVER_VERSION=v2
  #         OPENCODE_API_URL=http://127.0.0.1:13420
  #         # USERNAME IS A LITERAL, not a sops placeholder, and NOT "mugdad".
  #         # 2026-10-15: the server rejects Basic auth unless the username is
  #         # exactly `opencode` — measured live against 127.0.0.1:13420, where
  #         # username `opencode` returned HTTP 200 while `mugdad`, `root` and the
  #         # empty string each returned 401, same password throughout. The value
  #         # `mugdad` was a credential I minted myself when the secrets were first
  #         # written; it was wrong from the start, and it produced exactly the
  #         # symptom he reported — "opencode server is unavailable" — with the
  #         # bot's own log saying only "check OPENCODE_SERVER_USERNAME and
  #         # OPENCODE_SERVER_PASSWORD", which reads like a missing value rather
  #         # than a wrong one.
  #         #
  #         # It is a constant of the server, not a credential, so it belongs in
  #         # Nix where a reviewer can see it — and it doubles as the bot's own
  #         # built-in fallback (`getEnvVar(...) || "opencode"`). The corresponding
  #         # `opencode/server_username` entry was dropped from `sops.secrets`
  #         # below: it rendered a root-owned file nothing reads.
  #         OPENCODE_SERVER_USERNAME=opencode
  #         OPENCODE_SERVER_PASSWORD=${config.sops.placeholder."opencode/server_password"}

  #         # v2 requires a default model. `opencode` / `big-pickle` are this
  #         # house's provider, not an example — the .env.example ships different
  #         # ones and copying those would point the bot at a provider that is not
  #         # configured here.
  #         OPENCODE_MODEL_PROVIDER=opencode
  #         OPENCODE_MODEL_ID=big-pickle
  #       '';
  #     };

  #     # Credentials for the recurring Filen bisync (./services.nix).
  #     #
  #     # Its own template rather than reusing one above, because EnvironmentFile
  #     # needs KEY=value lines while the secrets above feed a bot config with a
  #     # specific shape. Both are rendered at activation into /run/secrets/
  #     # rendered/, so no Filen credential exists as plaintext anywhere outside
  #     # this encrypted file and that root-owned runtime directory.
  #     #
  #     # Owner `username` (default would be root:root 0400): the bisync unit runs
  #     # as this user — it must write into ~/filen, which is that user's — and a
  #     # root-owned EnvironmentFile gives the unit "Permission denied" at start.
  #     templates."filen-sync.env" = {
  #       owner = username;
  #       mode = "0400";
  #       content = ''
  #         FILEN_CLI_EMAIL=${config.sops.placeholder."filen/email"}
  #         FILEN_CLI_PASSWORD=${config.sops.placeholder."filen/password"}
  #       '';
  #     };

  #     # NOTE 2026-10-18: the `notify-telegram.env` template used to be declared
  #     # here; it moved to modules/core/monitoring.nix when alerting became a
  #     # three-host thing (the token is fleet-wide, and the file that ships it
  #     # belongs with the script that reads it). See that module.
  #   };
}
