{
  config,
  pkgs,
  ...
}: let
  g = import ../../../lib/gruvbox.nix;
  raw = g.raw;
in {
  programs.swaylock = {
    enable = true;
    # swaylock-effects, not vanilla swaylock — the settings below use
    # `fade-in` and `grace`, which vanilla 1.8.6 rejects as unrecognized
    # options (seen in the log 2026-10-14: "unrecognized option
    # '--fade-in=0.200000'"), so the lock command never even started.
    # effects 1.7.0.0 ships both flags (verified via --help).
    package = pkgs.swaylock-effects;
    settings = {
      color = raw.bg0_h;
      image = "${config.home.homeDirectory}/Pictures/wallpapers/wallpaper";
      scaling = "fill";
      font = "Iosevka Nerd Font";
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
