{pkgs, ...}: {
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;

    # Explicit per-desktop config: xdg-desktop-portal resolves
    # $XDG_CURRENT_DESKTOP to <name>-portals.conf. Sway gets wlr for
    # screencopy/screenshots, Hyprland gets its own backend for those.
    config = {
      common = {
        default = ["gtk"];
      };

      sway = {
        default = ["gtk" "wlr"];
        "org.freedesktop.impl.portal.ScreenCast" = ["wlr"];
        "org.freedesktop.impl.portal.Screenshot" = ["wlr"];
      };

      hyprland = {
        default = ["hyprland" "gtk"];
        "org.freedesktop.impl.portal.ScreenCast" = ["hyprland"];
        "org.freedesktop.impl.portal.Screenshot" = ["hyprland"];
        "org.freedesktop.impl.portal.GlobalShortcuts" = ["hyprland"];
        "org.freedesktop.impl.portal.InputCapture" = ["hyprland"];
      };
    };

    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-wlr
    ];
    # xdg-desktop-portal-hyprland is added by programs.hyprland
    # (modules/desktop/hyprland.nix).
  };
}
