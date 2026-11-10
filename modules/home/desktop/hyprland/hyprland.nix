{
  pkgs,
  variables,
  config,
  ...
}: let
  settings = import ./settings.nix {inherit variables;};
  binds = import ./binds.nix {inherit variables;};
  rules = import ./windowrules.nix {};
  autostart = import ./exec-once.nix {inherit pkgs config;};
in {
  home.packages = with pkgs; [
    awww
    nwg-displays
    wl-clip-persist
    wlopm
    cliphist
    glib
    wayland
  ];

  xdg.configFile."hypr/hyprland.lua".text = ''
    -- mugdad's Hyprland configuration
    -- generated from modules/home/desktop/hyprland/hyprland.nix
    -- https://github.com/mugdad1/nixos-config

    -------------------------
    ---- ENVIRONMENT VARS ----
    -------------------------

    hl.env("XCURSOR_THEME", "${config.home.pointerCursor.name}")
    hl.env("XCURSOR_SIZE", "${toString config.home.pointerCursor.size}")
    hl.env("HYPRCURSOR_SIZE", "${toString config.home.pointerCursor.size}")

    ${settings}

    ${binds}

    ${rules}

    ${autostart}
  '';
}
