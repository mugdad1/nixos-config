# Host-local secret TEMPLATES — moved here 2026-10-22 from
# hosts/thinkcentre/secrets.nix with the service layer, because the ThinkCentre
# is being returned to its owner.
#
# WHAT IS IN THIS FILE: the sops.secrets declarations for the keys this host
# renders, plus the *templates* whose shapes are a property of the units that
# read them. The secret VALUES are ciphertext in secrets/fleet.sops.yaml
# (fleet-scope, decisions rows 121–122). The keys below used to be declared in
# hosts/thinkcentre/secrets.nix — that file is commented out with the rest of
# the box, so the declarations moved with the templates that consume them
# (a placeholder errors out at eval until its secret is declared, which is how
# this was caught: the grandpa rebuild failed on exactly that).
#
#   searxng.env             EnvironmentFile for the searxng container
#
# filen-sync.env MOVED to modules/core/filen-sync.nix on 2026-10-31, together
# with the unit that reads it: all three hosts run filen-sync now, so its keys
# and template are no longer grandpa-local.
#
# A third, opencode-telegram.env, went with the Telegram bot on 2026-10-23
# (row 207) — along with the `opencode/server_password` secret, which existed
# only to be mirrored into that template; the server reads its password from
# ~/.config/opencode/service-prod.json directly.
#
# They are host-local because they name `owner = username` — the unit that
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

    # Declared next to the templates that read them — `= {}` because the
    # values live in the encrypted file; this only says "decrypt this key for
    # this host". Moved here from hosts/thinkcentre/secrets.nix (now inert).
    secrets = {
      # filen/email + filen/password are declared in
      # modules/core/filen-sync.nix (all three hosts run it since 2026-10-31).
      "searx/secret_key" = {}; # searxng.env, added 2026-10-22
    };

    # Where the private key lives ON THE SERVER. Deliberately NOT
    # ~/.config/sops/age/keys.txt: sops-install-secrets runs early in boot,
    # before user homes are necessarily useful, and a root-owned path under
    # /var/lib states plainly that this is machine state, not user state.
    age.keyFile = "/var/lib/sops-nix/key.txt";

    # filen-sync.env moved to modules/core/filen-sync.nix on 2026-10-31, with
    # the unit that reads it. Its owner/template reasoning lives there now.

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
