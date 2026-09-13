# NixOS minimal installer: Wi-Fi (iwd + AX210) + SSH enabled.
# Build: nix build .#installer → flash with dd/ventoy.
{...}: {
  nixpkgs.hostPlatform = "x86_64-linux";

  # Minimal ISO already ships NetworkManager (WiFi) + iwd fallback;
  # just open SSH for remote install.
  services.openssh.enable = true;
}
