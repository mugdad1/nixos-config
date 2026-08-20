{
  pkgs,
  variables,
  config,
  ...
}: let
  cursor = config.home.pointerCursor;
in ''
  -------------------
  ---- AUTOSTART ----
  -------------------

  hl.on("hyprland.start", function()
      hl.exec_cmd("dbus-update-activation-environment --all --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
      hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
      hl.exec_cmd("systemctl --user start nixos-fake-graphical-session.target")
      hl.exec_cmd("nm-applet")
      hl.exec_cmd("poweralertd")
      hl.exec_cmd("wl-clip-persist --clipboard both")
      hl.exec_cmd("wl-paste --watch cliphist store")
      hl.exec_cmd("${variables.bar}")
      hl.exec_cmd("swaync")
      hl.exec_cmd("udiskie --automount --notify --smart-tray")
      hl.exec_cmd("hyprctl setcursor ${cursor.name} ${toString cursor.size}")
      hl.exec_cmd("init-wallpaper")
      hl.exec_cmd("swayosd-server")
      hl.exec_cmd("${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1")
  end)
''
