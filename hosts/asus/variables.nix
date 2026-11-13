{
  username = "mugdad";
  timezone = "Asia/Riyadh";
  locale = "en_US.UTF-8";

  gitUser = "mugdad1";
  gitEmail = "mugdad02@tutamail.com";

  # No browser/terminal/launcher on purpose: modules/core/user.nix only pulls
  # in modules/home when those exist, and this host is headless.
}
