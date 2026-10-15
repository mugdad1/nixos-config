{
  # Username is "mugdad" on BOTH hosts, and /home/mugdad on both.
  #
  # It was "void" on the ThinkCentre until the 2026-10-13 migration, and this
  # comment used to argue for keeping it that way so /home/void would not move.
  # That argument is settled the other way: the box was reinstalled as mugdad
  # (decisions.md row 78), so the path did move and everything keyed on it was
  # re-pointed in the same pass — compose bind mounts, the tailscale state, the
  # opencode session DB and backup-run.sh's SOURCES all read /home/mugdad now.
  # A stale copy of the old home survives under /srv/backup for reference only.
  username = "mugdad";
  timezone = "Asia/Riyadh";
  # Must be a locale NixOS actually generates (i18n.defaultLocale).
  locale = "en_US.UTF-8";

  # git identity — the wiki/nixos-config/study remotes use these.
  gitUser = "mugdad1";
  gitEmail = "mugdad02@tutamail.com";

  # NOTE: no browser / terminal / launcher / keyboardLayout fields, on purpose.
  # Those are read by modules/home (sway, waybar, rofi) and modules/core/user.nix
  # now imports that stack only when `variables ? browser`. A headless host
  # declares none, so it gets none. Do not add them "for shape parity".
}
