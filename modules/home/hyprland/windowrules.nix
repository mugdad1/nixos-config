{ ... }:
{
  wayland.windowManager.hyprland.settings = {
    windowrule = [
      "float, class:^(imv)$"
      "float, class:^(mpv)$"
      "float, class:^(zenity)$"
      "float, class:^(waypaper)$"
      "float, class:^(.sameboy-wrapped)$"
      "float, class:^(org.gnome.Calculator)$"
      "float, class:^(org.gnome.FileRoller)$"
      "float, class:^(org.pulseaudio.pavucontrol)$"

      "pin, class:^(rofi)$"
      "pin, class:^(waypaper)$"

      "tile, class:^(Aseprite)$"

      "size 850 500, class:^(zenity)$"

      "size 700 450, title:^(Volume Control)$"
      "move 40 55%, title:^(Volume Control)$"

      "pin, title:^(Picture-in-Picture)$"
      "float, title:^(Picture-in-Picture)$"

      "workspace 1, class:^(zen-beta)$"
      "workspace 3, class:^(codium)$"
      "workspace 4, class:^(Gimp-2.10)$"
      "workspace 4, class:^(Aseprite)$"
      "workspace 5, class:^(spotify)$"
      "workspace 8, class:^(com.obsproject.Studio)$"
      "workspace 10, class:^(discord)$"
      "workspace 10, class:^(WebCord)$"

      "idle_inhibit focus, class:^(mpv)$"
      "idle_inhibit focus, class:^(zen-beta)$, title:^(.*YouTube.*)$"
      "idle_inhibit fullscreen, class:^(zen)$"

      "dim_around, class:^(xdg-desktop-portal-gtk)$"

      "rounding 0, xwayland:true"

      "border_size 0, float:0, workspace:w[tv1]"
      "rounding 0, float:0, workspace:w[tv1]"
      "border_size 0, float:0, workspace:f[1]"
      "rounding 0, float:0, workspace:f[1]"
    ];

    layerrule = [
      "dim_around, namespace:rofi"
      "dim_around, namespace:swaync-control-center"
    ];

    # No gaps when only
    workspace = [
      "w[tv1], gapsout:0, gapsin:0"
      "f[1], gapsout:0, gapsin:0"
    ];
  };
}
