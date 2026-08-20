{
  pkgs,
  variables,
  host,
  config,
  ...
}: let
  settings = import ./settings.nix {inherit variables;};
  binds = import ./binds.nix {inherit variables host;};
  rules = import ./windowrules.nix {};
  autostart = import ./exec-once.nix {inherit pkgs variables config;};
in {
  imports = [
    ./hyprlock.nix
    ./variables.nix
  ];

  home.packages = with pkgs; [
    awww
    grimblast
    hyprpicker
    nwg-displays
    wl-clip-persist
    cliphist
    glib
    wayland
  ];

  xdg.configFile."hypr/hyprland.lua".text = ''
    -- mugdad's Hyprland configuration
    -- Lua format (Hyprland 0.55+)
    -- https://github.com/mugdad1/nixos-config

    ------------------
    ---- MONITORS ----
    ------------------

    -- Managed by nwg-displays (ignore if missing — fresh install)
    pcall(dofile, os.getenv("HOME") .. "/.config/hypr/monitors.lua")

    -------------------------
    ---- ENVIRONMENT VARS ----
    -------------------------

    hl.env("XCURSOR_SIZE", "${toString config.home.pointerCursor.size}")
    hl.env("HYPRCURSOR_SIZE", "${toString config.home.pointerCursor.size}")

    ${settings}

    ${binds}

    ${rules}

    ${autostart}
  '';
}
