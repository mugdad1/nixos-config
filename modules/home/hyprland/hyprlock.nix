{...}: let
  g = import ../../gruvbox.nix;
  rgba = g.hexToRgba;
  raw = g.raw;
in {
  programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        hide_cursor = true;
        ignore_empty_input = true;
        fractional_scaling = 0;
      };

      background = [
        {
          path = "${../../../wallpapers/otherWallpaper/gruvbox/forest_road.jpg}";

          color = rgba raw.bg0_h "255";
          blur_passes = 2;
          vibrancy_darkness = 0.0;
        }
      ];

      shape = [
        # User box
        {
          size = "300, 50";

          rounding = 0;
          border_size = 2;
          color = rgba raw.bg3 "0.33";
          border_color = rgba raw.gray "0.95";

          position = "0, 270";
          halign = "center";
          valign = "bottom";
        }
      ];

      label = [
        # Time
        {
          text = ''cmd[update:1000] echo "$(date +'%k:%M')"'';

          font_size = 115;
          font_family = "Iosevka Nerd Font Bold";

          shadow_passes = 3;
          color = rgba raw.fg "0.9";

          position = "0, -150";
          halign = "center";
          valign = "top";
        }
        # Date
        {
          text = ''cmd[update:1000] echo "- $(date +'%A, %B %d') -" '';

          font_size = 18;
          font_family = "Iosevka Nerd Font";

          shadow_passes = 3;
          color = rgba raw.fg "0.9";

          position = "0, -350";
          halign = "center";
          valign = "top";
        }
        # Username
        {
          text = "  $USER";

          font_size = 15;
          font_family = "Iosevka Nerd Font Bold";

          color = rgba raw.fg "1";

          position = "0, 284";
          halign = "center";
          valign = "bottom";
        }
      ];

      input-field = [
        {
          size = "300, 50";
          rounding = 0;
          outline_thickness = 2;

          dots_spacing = 0.4;

          font_color = rgba raw.fg "0.9";
          font_family = "Iosevka Nerd Font Bold";

          outer_color = rgba raw.gray "0.95";
          inner_color = rgba raw.bg3 "0.33";
          check_color = rgba raw.green "0.95";
          fail_color = rgba raw.red "0.95";
          capslock_color = rgba raw.yellow "0.95";
          bothlock_color = rgba raw.yellow "0.95";

          hide_input = false;
          fade_on_empty = false;
          placeholder_text = ''<i><span foreground="#${raw.fg0}">Enter Password</span></i>'';

          position = "0, 200";
          halign = "center";
          valign = "bottom";
        }
      ];

      animation = ["inputFieldColors, 0"];
    };
  };
}
