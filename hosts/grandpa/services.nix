# grandpa-only systemd units. Shared units live in modules/core.
{
  pkgs,
  username,
  ...
}: {
  # study moved to asus 2026-11-14 (row 256); it is hosts/asus/study.nix now.

  # journald defaults to volatile unless /var/log/journal exists.
  services.journald.settings.Journal.Storage = "persistent";
}
