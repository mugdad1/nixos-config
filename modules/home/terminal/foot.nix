_: let
  c = (import ../../../lib/gruvbox.nix).raw;
in {
  # foot — Wayland-native terminal, added 2026-11-02 as the light fallback to
  # Ghostty on the 8 GB T480s. Colours come from the same lib/gruvbox.nix the
  # rest of the desktop uses, so the palette cannot drift.
  #
  # foot 1.28 splits themes into [colors-dark] / [colors-light]; the old
  # [colors] section is gone. Only the dark theme is overridden and
  # initial-color-theme pins dark, so the light builtin is never selected.
  programs.foot = {
    enable = true;

    settings = {
      main = {
        font = "Iosevka Nerd Font:size=12";
        pad = "4x4 center-when-maximized-and-fullscreen";
        initial-color-theme = "dark";
      };

      # foot keeps its scrollback in a dedicated [scrollback] section
      # (foot.ini(5)); there is no [main] "scrollback-lines" option.
      scrollback = {
        lines = 10000;
      };

      "colors-dark" = {
        background = c.bg0_h;
        foreground = c.fg0;
        # foot expects TWO space-separated RRGGBB values here: the
        # foreground (text) and the background (cursor) color.
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
