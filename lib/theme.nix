# Facade for the active color palette.
#
# Usage (same shape as the old lib/gruvbox.nix):
#   c = (import ../../lib/theme.nix variables).css;
#   g = import ../../lib/theme.nix variables;   # g.raw, g.css, g.hexToRgba ...
#
# `variables.theme` selects the palette (see lib/themes); unknown names throw.
variables: let
  name = variables.theme or "gruvbox";
  themes = import ./themes;
  theme = themes.${name} or (throw "Unknown theme '${name}'. Available: ${toString (builtins.attrNames themes)}");

  # Semantic highlight color per theme (Omarchy-style: highlights follow
  # `accent`, never the `green` slot, so switching palettes retints them).
  accents = {
    gruvbox = {
      accent = "98971A";
      bright_accent = "B8BB26";
    };
    nord = {
      accent = "81A1C1";
      bright_accent = "88C0D0";
    };
    catppuccin = {
      accent = "CBA6F7";
      bright_accent = "F5C2E7";
    };
    tokyo-night = {
      accent = "7AA2F7";
      bright_accent = "7DA6FF";
    };
    rose-pine = {
      accent = "C4A7E7";
      bright_accent = "EBBCBA";
    };
  };
  accentTheme = accents.${name} or (throw "Unknown theme '${name}'. Available: ${toString (builtins.attrNames accents)}");
in rec {
  inherit (theme) raw;
  inherit (accentTheme) accent bright_accent;

  # CSS ready values (with leading #)
  css =
    (builtins.mapAttrs (_: v: "#${v}") raw)
    // {
      accent = "#${accent}";
      bright_accent = "#${bright_accent}";
    };

  hexVals = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "A" = 10;
    "B" = 11;
    "C" = 12;
    "D" = 13;
    "E" = 14;
    "F" = 15;
    "a" = 10;
    "b" = 11;
    "c" = 12;
    "d" = 13;
    "e" = 14;
    "f" = 15;
  };

  hexToDec = hex: let
    v = c: hexVals.${c};
    r = v (builtins.substring 0 1 hex) * 16 + v (builtins.substring 1 1 hex);
    g = v (builtins.substring 2 1 hex) * 16 + v (builtins.substring 3 1 hex);
    b = v (builtins.substring 4 1 hex) * 16 + v (builtins.substring 5 1 hex);
  in {inherit r g b;};

  hexToRgba = hex: alpha: let
    rgb = hexToDec hex;
  in "rgba(${toString rgb.r}, ${toString rgb.g}, ${toString rgb.b}, ${toString alpha})";
}
