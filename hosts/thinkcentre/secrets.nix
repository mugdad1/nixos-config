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
#   secrets/thinkcentre.sops.yaml   AES-256-GCM ciphertext, committed
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
#   2. `sops -e -i` it into secrets/thinkcentre.sops.yaml (or use `sops` on the
#      file to edit it in place — sops decrypts to your editor and re-encrypts)
#   3. declare it in `sops.secrets` below, then reference
#      `config.sops.placeholder."<name>"` from a template or a service
{config, username, ...}: {
  sops = {
    defaultSopsFile = ../../secrets/thinkcentre.sops.yaml;

    # Where the private key lives ON THE SERVER. Deliberately NOT
    # ~/.config/sops/age/keys.txt: sops-install-secrets runs early in boot,
    # before user homes are necessarily useful, and a root-owned path under
    # /var/lib states plainly that this is machine state, not user state.
    age.keyFile = "/var/lib/sops-nix/key.txt";

    secrets = {
      # Names map onto the YAML structure with `/` as the nesting separator,
      # so "telegram/bot_token" is `telegram: { bot_token: ... }`.
      "telegram/bot_token" = {};
      "telegram/allowed_user_id" = {};
      "opencode/server_username" = {};
      "opencode/server_password" = {};
    };

    # The whole bot config, rendered at activation into a file that never
    # exists on disk in plaintext outside the running system.
    #
    # This replaces ~/.config/opencode-telegram-bot/.env. That path was the
    # original plan and is what ConditionPathExists used to guard — but it was
    # unrecoverable by design (backup-run.sh's SOURCES never included
    # .config), it is outside the flake so a reinstall would not restore it,
    # and writing it by hand puts a token at a path a future `git add -A` or a
    # stray backup could pick up. A rendered template is declarative,
    # re-installable, and readable only by root and this unit.
    templates."opencode-telegram.env" = {
      # The unit runs as `username`, so it must be able to read the file.
      # Default is root:root 0400, which would give the unit an
      # "Access denied" and a crash loop that looks like a bot bug.
      owner = username;
      mode = "0400";
      content = ''
        TELEGRAM_BOT_TOKEN=${config.sops.placeholder."telegram/bot_token"}
        TELEGRAM_ALLOWED_USER_ID=${config.sops.placeholder."telegram/allowed_user_id"}

        # OpenCode v2. The bot defaults to v1 and CANNOT detect the version, so
        # every value here is load-bearing: v1's default port is 4096 and v2's
        # is 13420, and a stale port makes the wait-loop spin out and start a
        # bot that is permanently blind while every unit reads green.
        OPENCODE_SERVER_VERSION=v2
        OPENCODE_API_URL=http://127.0.0.1:13420
        OPENCODE_SERVER_USERNAME=${config.sops.placeholder."opencode/server_username"}
        OPENCODE_SERVER_PASSWORD=${config.sops.placeholder."opencode/server_password"}

        # v2 requires a default model. `opencode` / `big-pickle` are this
        # house's provider, not an example — the .env.example ships different
        # ones and copying those would point the bot at a provider that is not
        # configured here.
        OPENCODE_MODEL_PROVIDER=opencode
        OPENCODE_MODEL_ID=big-pickle
      '';
    };
  };
}
