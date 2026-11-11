{
  username = "mugdad";
  timezone = "Asia/Riyadh";
  locale = "en_US.UTF-8";

  gitUser = "mugdad1";
  gitEmail = "mugdad02@tutamail.com";

  # No browser/terminal/launcher on purpose: this host is headless, and
  # modules/core/user.nix imports modules/home only when `variables ? browser`.
}
