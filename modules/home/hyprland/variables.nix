{
  variables,
  config,
  ...
}: {
  home.sessionVariables = {
    # NOTE: $EDITOR is owned by programs.nixvim (modules/home/nvim.nix);
    # `variables.editor` only drives GUI launchers/hyprland binds.
    NIXOS_OZONE_WL = 1;
    GDK_BACKEND = "wayland";
    DIRENV_LOG_FORMAT = "";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = 1;
    QT_QPA_PLATFORM = "wayland";

    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "Hyprland";
    GRIMBLAST_HIDE_CURSOR = 0;

    # nh needs to know where the flake lives (no longer baked into nh.nix)
    NH_FLAKE = "${config.home.homeDirectory}/nixos-config";

    WINEDLLOVERRIDES = "winemenubuilder.exe=d";
  };
}
