{...}: let
  g = import ../../lib/gruvbox.nix;
  raw = g.raw;
in {
  programs.swaylock = {
    enable = true;
    settings = {
      color = raw.bg0_h;
      image = "~/Pictures/wallpapers/wallpaper";
      scaling = "fill";
      font = "JetBrainsMono Nerd Font";
      font-size = 32;
      indicator-radius = 100;
      indicator-thickness = 8;
      indicator-caps-lock = true;
      ring-color = raw.gray;
      ring-ver-color = raw.bright_blue;
      ring-wrong-color = raw.bright_red;
      ring-clear-color = raw.bright_green;
      key-hl-color = raw.bright_green;
      bs-hl-color = raw.bright_red;
      text-color = raw.fg4;
      text-ver-color = raw.fg4;
      text-wrong-color = raw.bg0;
      text-clear-color = raw.bg0;
      inside-color = raw.bg0_h;
      inside-ver-color = raw.bg0_h;
      inside-wrong-color = raw.bg0_h;
      inside-clear-color = raw.bg0_h;
      line-color = "#00000000";
      line-ver-color = "#00000000";
      line-wrong-color = "#00000000";
      line-clear-color = "#00000000";
      separator-color = "#00000000";
      fade-in = 0.2;
      grace = 2;
    };
  };
}
