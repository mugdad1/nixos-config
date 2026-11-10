{
  config,
  variables,
  ...
}: {
  home.sessionVariables = {
    # XDG_CURRENT_DESKTOP / XDG_SESSION_TYPE / XDG_SESSION_DESKTOP are NOT set
    # here: home-manager session vars are shared by Sway and Hyprland, so a
    # hard-coded "sway" would leak into the Hyprland session. The greetd
    # session wrapper (modules/desktop/services.nix) exports the right values
    # for whichever desktop was picked at login.

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
