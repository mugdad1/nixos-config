# ASUS i3-8th-gen home server: Gitea, Tailscale-only, no GUI.
#
# Reused from core (all server-safe, zero desktop):
#   system, boot, tailscale, nh, snapper, security (rtkit forced off below)
# Deliberately NOT imported: modules/core/default.nix (drags ../desktop),
#   modules/core/user.nix (desktop home-manager home), modules/core/packages.nix
#   (Android SDK, games), modules/core/network.nix (needs blocky + wifi applet).
{lib, ...}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/system.nix
    ../../modules/core/boot.nix
    ../../modules/core/tailscale.nix
    ../../modules/core/nh.nix
    ../../modules/core/snapper.nix
    ../../modules/core/security.nix
    ../../modules/server
  ];

  # No audio stack on a headless server
  security.rtkit.enable = lib.mkForce false;

  # Headless server: no bluetooth, no ROG armoury driver (non-ROG board).
  # Kills their dmesg probe noise and saves a little power.
  boot.blacklistedKernelModules = ["btusb" "bluetooth" "asus_armoury"];

  # Trim idle services: no modem on ethernet, no need to block boot on
  # network-online, and snapper timers are pointless with configs = {} below.
  systemd.services.ModemManager.enable = lib.mkForce false;
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  systemd.timers.snapper-timeline.enable = lib.mkForce false;
  systemd.timers.snapper-cleanup.enable = lib.mkForce false;

  # /home is a plain directory on the root subvolume, not a subvolume itself,
  # so snapper's `home` config can never snapshot it (timeline exits 1 hourly).
  # Drop snapper configs on the server entirely.
  services.snapper.configs = lib.mkForce {};

  # Longevity: bound SSD writes and store growth (always-on, rarely touched).
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  # nh's auto-clean (keep 1 gen / 1 day) conflicts with nix.gc and leaves no
  # rollback room on a remote box — nix.gc above wins.
  programs.nh.clean.enable = lib.mkForce false;
  services.journald.settings.Journal = {
    SystemMaxUse = "200M";
    RuntimeMaxUse = "100M";
  };

  # Idle power savings (less heat = longer life).
  powerManagement.powertop.enable = true;

  # Server barely changes: daily snapshots instead of every 12h.
  services.snapper.snapshotInterval = lib.mkForce "daily";

  # Real hardware-configuration.nix (from nixos-generate-config) sets this
  # itself; needed only while the placeholder above stands in.
  nixpkgs.hostPlatform = "x86_64-linux";
}
