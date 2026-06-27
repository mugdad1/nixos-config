{pkgs, ...}: {
  home.packages = with pkgs; [
    awww
    grimblast
    hyprpicker
    nwg-displays
    grim
    slurp
    wl-clip-persist
    cliphist
    glib
    wayland
  ];
  systemd.user.targets.hyprland-session.Unit.Wants = [
    "xdg-desktop-autostart.target"
  ];
  wayland.windowManager.hyprland = {
    enable = true;
    package = null;
    portalPackage = null;

    configType = "hyprlang";

    xwayland = {
      enable = true;
    };
    systemd.enable = true;
  };
}
