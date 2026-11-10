{lib, ...}: {
  # Hyprland is installed as a second session next to Sway. It is started
  # through the greetd session wrapper, not by uwsm, so UWSM stays off and the
  # sessions are launched with the same wrapper as Sway.
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = false;
  };

  # hyprlock authenticates through PAM (same idea as pam.services.swaylock).
  security.pam.services.hyprlock = {};

  # programs.hyprland + the wayland-session module only add some of the
  # session plumbing. Keep the same portal/desktop assumptions Sway gets.
  services.xserver.desktopManager.runXdgAutostartIfNone = lib.mkDefault true;
}
