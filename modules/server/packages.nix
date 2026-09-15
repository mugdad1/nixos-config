# Lean server toolset. No Android SDK, no games, no GUI apps.
{pkgs, ...}: {
  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    btop
    eza
    fd
    ripgrep
    git
    usbutils
    pciutils
    lm_sensors
    smartmontools
    opencode
  ];
}
