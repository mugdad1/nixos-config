# Host-local secret TEMPLATES — moved here 2026-10-22 from
# hosts/thinkcentre/secrets.nix with the service layer, because the ThinkCentre
# is being returned to its owner.
#
# WHAT IS AND IS NOT IN THIS FILE. The secret VALUES are fleet-scope and live
# in modules/core/monitoring.nix against secrets/fleet.sops.yaml (decisions
# rows 121–122) — every host already declares `telegram/*`, `filen/*` and
# `opencode/server_password` there, so this file does NOT touch sops.secrets.
# All it adds is the two *rendered templates* whose shapes are a property of
# the units that read them:
#
#   opencode-telegram.env   EnvironmentFile for systemd.services.opencode-telegram
#   filen-sync.env          EnvironmentFile for the filen-sync bisync unit
#
# Both are host-local because they name `owner = username` — the unit that
# reads them runs as that user. Putting them in modules/core would hand every
# host a template for a unit only this host runs, which is the same overreach
# the sops secrets were moved OUT of a host file to avoid. Read
# hosts/thinkcentre/secrets.nix for the full history of each value; only the
# wiring is repeated, not the reasoning.
#
# ON A REINSTALL the private key is still the bootstrap step a declarative
# system cannot do for itself: copy it to /var/lib/sops-nix/key.txt (mode 600,
# root:root) BEFORE `nixos-rebuild switch`, or activation fails while
# decrypting. The encrypted file and this wiring come back with the flake.
{
  config,
  username,
  ...
}: {
  sops = {
    # Defaulted fleet-wide in modules/core/monitoring.nix (mkDefault) — stated
    # here for the same reason thinkcentre's file states it, so a reader does
    # not have to go hunting for which module supplies it.
    defaultSopsFile = ../../secrets/fleet.sops.yaml;

    # Where the private key lives ON THE SERVER. Deliberately NOT
    # ~/.config/sops/age/keys.txt: sops-install-secrets runs early in boot,
    # before user homes are necessarily useful, and a root-owned path under
    # /var/lib states plainly that this is machine state, not user state.
    age.keyFile = "/var/lib/sops-nix/key.txt";

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
        # USERNAME IS A LITERAL, not a sops placeholder, and NOT "mugdad" — the
        # server rejects Basic auth unless it is exactly `opencode` (measured
        # live 2026-10-15: `opencode` returned 200 while `mugdad`, `root` and
        # the empty string each returned 401, same password throughout). It is
        # a constant of the server, not a credential, so it belongs in Nix where
        # a reviewer can see it, and it doubles as the bot's own fallback.
        OPENCODE_SERVER_USERNAME=opencode
        OPENCODE_SERVER_PASSWORD=${config.sops.placeholder."opencode/server_password"}

        # v2 requires a default model. `opencode` / `big-pickle` are this
        # house's provider, not an example — the .env.example ships different
        # ones and copying those would point the bot at a provider that is not
        # configured here.
        OPENCODE_MODEL_PROVIDER=opencode
        OPENCODE_MODEL_ID=big-pickle
      '';
    };

    # Credentials for the recurring Filen 2-WAY bisync (./services.nix).
    #
    # Its own template rather than reusing one above, because EnvironmentFile
    # needs KEY=value lines while the telegram template feeds a bot config with
    # a specific shape. Both render at activation into /run/secrets/rendered/,
    # so no Filen credential exists as plaintext outside this encrypted file
    # and that root-owned runtime directory.
    #
    # Owner `username` (default would be root:root 0400): the bisync unit runs
    # as this user — it must write into ~/filen, which is that user's — and a
    # root-owned EnvironmentFile gives the unit "Permission denied" at start.
    templates."filen-sync.env" = {
      owner = username;
      mode = "0400";
      content = ''
        FILEN_CLI_EMAIL=${config.sops.placeholder."filen/email"}
        FILEN_CLI_PASSWORD=${config.sops.placeholder."filen/password"}
      '';
    };

    # SearXNG's session key (2026-10-22, "Declare it inside grandpa"). The
    # VALUE is fleet.sops.yaml's `searx/secret_key` — it came from the old
    # docker-compose data/settings.yml, preserved so existing preference
    # cookies keep verifying rather than everyone re-saving their settings.
    # The name is searxng.env (not searx.env) to match searxng.nix's
    # environmentFile line; unlike the two above this one is consumed by a
    # module's own envsubst pass (searx-init), not by a unit here, so the
    # owner could be root — kept at `username` anyway for one rule instead of
    # two, since systemd reads EnvironmentFile as PID 1 either way.
    templates."searxng.env" = {
      owner = username;
      mode = "0400";
      content = ''
        SEARX_SECRET_KEY=${config.sops.placeholder."searx/secret_key"}
      '';
    };
  };
}
