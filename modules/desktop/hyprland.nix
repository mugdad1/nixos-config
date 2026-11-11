{lib, ...}: {
  # Hyprland is a second session next to Sway, started through the greetd
  # wrapper rather than uwsm.
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = false;
  };

  security.pam.services.hyprlock = {};

  services.xserver.desktopManager.runXdgAutostartIfNone = lib.mkDefault true;
}
