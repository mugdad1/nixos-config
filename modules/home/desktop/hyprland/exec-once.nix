{
  pkgs,
  config,
  ...
}: let
  cursor = config.home.pointerCursor;
  polkitAgent = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
in ''
  -------------------
  ---- AUTOSTART ----
  -------------------

  -- Same startup list as the sway config. swaync and hypridle are
  -- home-manager systemd user units; nixos-fake-graphical-session.target
  -- starts them, so they are deliberately not exec'd here.
  hl.on("hyprland.start", function()
      hl.exec_cmd("dbus-update-activation-environment --all --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
      hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
      hl.exec_cmd("systemctl --user start nixos-fake-graphical-session.target")
      hl.exec_cmd("nm-applet")
      hl.exec_cmd("poweralertd")
      hl.exec_cmd("wl-clip-persist --clipboard both")
      hl.exec_cmd("wl-paste --watch cliphist store")
      hl.exec_cmd("waybar -c " .. os.getenv("HOME") .. "/.config/waybar/config-hypr")
      hl.exec_cmd("init-wallpaper")
      hl.exec_cmd("swayosd-server")
      hl.exec_cmd("hyprctl setcursor ${cursor.name} ${toString cursor.size}")
      hl.exec_cmd("${polkitAgent}")
  end)
''
