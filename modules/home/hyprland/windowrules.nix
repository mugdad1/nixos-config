{...}: {
  wayland.windowManager.hyprland.settings = {
    windowrule = [
      "match:class ^(imv)$, float on"
      "match:class ^(zenity)$, float on"
      "match:class ^(waypaper)$, float on"
      "match:class ^(org.gnome.FileRoller)$, float on"
      "match:class ^(org.pulseaudio.pavucontrol)$, float on"

      "match:class ^(rofi)$, pin on"
      "match:class ^(waypaper)$, pin on"

      "match:class ^(zenity)$, size 850 500"

      "match:title ^(Volume Control)$, size 700 450"
      "match:title ^(Volume Control)$, move 40 55%"

      "match:title ^(Picture-in-Picture)$, pin on"
      "match:title ^(Picture-in-Picture)$, float on"

      "match:class ^(com.obsproject.Studio)$, workspace 8"

      "match:class ^(xdg-desktop-portal-gtk)$, dim_around on"

      "match:xwayland true, rounding 0"

      "match:float 0, match:workspace w[tv1], border_size 0"
      "match:float 0, match:workspace w[tv1], rounding 0"
      "match:float 0, match:workspace f[1], border_size 0"
      "match:float 0, match:workspace f[1], rounding 0"
    ];

    layerrule = [
      "match:namespace rofi, dim_around on"
      "match:namespace swaync-control-center, dim_around on"
    ];

    workspace = [
      "w[tv1], gapsout:0, gapsin:0"
      "f[1], gapsout:0, gapsin:0"
    ];
  };
}
