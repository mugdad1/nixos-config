{ pkgs, lib, ... }:
{
  wayland.windowManager.hyprland.settings.exec-once =
    [
      "dbus-update-activation-environment --all --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
      "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"

      "hyprlock"

      "nm-applet &"
      "poweralertd &"
      "wl-clip-persist --clipboard both &"
      "wl-paste --watch cliphist store &"
      "waybar &"
      "swaync &"
      "udiskie --automount --notify --smart-tray &"
      "hyprctl setcursor Bibata-Modern-Ice 24 &"
      "init-wallpaper &"
      "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1 &"

      "monitor-watcher &"
    ];
}
