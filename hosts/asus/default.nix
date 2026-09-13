# ASUS i3-8th-gen home server: Gitea + Immich, Tailscale-only, no GUI.
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

  # Real hardware-configuration.nix (from nixos-generate-config) sets this
  # itself; needed only while the placeholder above stands in.
  nixpkgs.hostPlatform = "x86_64-linux";
}
