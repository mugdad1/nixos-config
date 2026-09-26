{
  config,
  variables,
  ...
}: {
  home.sessionVariables = {
    XDG_CURRENT_DESKTOP = "sway";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "sway";

    # sway reads XKB_* env as fallback when the config has no match;
    # the config sets the layout explicitly (modules/home/sway/sway.nix).
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
