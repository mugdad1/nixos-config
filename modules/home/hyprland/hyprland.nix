{pkgs, ...}: let
  settings = import ./settings.nix {};
  binds = import ./binds.nix {};
  rules = import ./windowrules.nix {};
  autostart = import ./exec-once.nix {inherit pkgs;};
in {
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

    hl.env("XCURSOR_SIZE", "24")
    hl.env("HYPRCURSOR_SIZE", "24")

    ${settings}

    ${binds}

    ${rules}

    ${autostart}
  '';
}
