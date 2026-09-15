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
in rec {
  inherit (theme) raw;

  # CSS ready values (with leading #)
  css = builtins.mapAttrs (_: v: "#${v}") raw;

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
