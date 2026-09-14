{
  config,
  variables,
  ...
}: {
  home.sessionVariables = {
    XDG_CURRENT_DESKTOP = "River";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "River";
    GRIMBLAST_HIDE_CURSOR = 0;

    # kwm/kwim have no keyboard layout config — river/xkbcommon read these
    XKB_DEFAULT_LAYOUT = variables.keyboardLayout;
    XKB_DEFAULT_OPTIONS = variables.keyboardOptions;

    NIXOS_OZONE_WL = 1;
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    GDK_BACKEND = "wayland";
    DIRENV_LOG_FORMAT = "";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = 1;
    QT_QPA_PLATFORM = "wayland";

    NH_FLAKE = "${config.home.homeDirectory}/nixos-config";

    WINEDLLOVERRIDES = "winemenubuilder.exe=d";
  };
}
