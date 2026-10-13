{
  # Username stays "void" so /home/void does not move across the migration —
  # every compose bind mount, the tailscale state, the opencode session DB and
  # the backup sources are all keyed on that path.
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
