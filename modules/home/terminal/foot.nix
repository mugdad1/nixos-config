_: let
  c = (import ../../../lib/gruvbox.nix).raw;
in {
  # foot — Wayland-native terminal, the light fallback to Ghostty.
  programs.foot = {
    enable = true;

    settings = {
      main = {
        font = "Iosevka Nerd Font:size=12";
        pad = "4x4 center-when-maximized-and-fullscreen";
        initial-color-theme = "dark";
      };

      scrollback = {
        lines = 10000;
      };

      "colors-dark" = {
        background = c.bg0_h;
        foreground = c.fg0;
        # Two values: foreground (text) and background (cursor).
        cursor = "${c.fg0} ${c.fg2}";

        regular0 = c.bg0;
        regular1 = c.red;
        regular2 = c.green;
        regular3 = c.yellow;
        regular4 = c.blue;
        regular5 = c.purple;
        regular6 = c.aqua;
        regular7 = c.fg;

        bright0 = c.light_gray;
        bright1 = c.bright_red;
        bright2 = c.bright_green;
        bright3 = c.bright_yellow;
        bright4 = c.bright_blue;
        bright5 = c.bright_purple;
        bright6 = c.bright_aqua;
        bright7 = c.fg0;

        selection-background = c.bg2;
        selection-foreground = c.fg0;
      };
    };
  };
}
