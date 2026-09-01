rec {
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

  raw = {
    bg0_h = "1D2021";
    bg0 = "282828";
    bg1 = "3C3836";
    bg2 = "504945";
    bg3 = "665C54";
    bg4 = "7C6F64";
    fg = "EBDBB2";
    fg0 = "FBF1C7";
    fg2 = "D5C4A1";
    fg3 = "BDAE93";
    fg4 = "A89984";
    gray = "A89984";
    dark_gray = "7C6F64";
    light_gray = "928374";
    red = "CC241D";
    green = "98971A";
    yellow = "D79921";
    blue = "458588";
    purple = "B16286";
    aqua = "689D69";
    orange = "D65D0E";
    bright_red = "FB4934";
    bright_green = "B8BB26";
    bright_yellow = "FABD2F";
    bright_blue = "83A598";
    bright_purple = "D3869B";
    bright_aqua = "8EC07C";
    bright_orange = "FE8019";
  };

  css = {
    bg0_h = "#1D2021";
    bg0 = "#282828";
    bg1 = "#3C3836";
    bg2 = "#504945";
    bg3 = "#665C54";
    bg4 = "#7C6F64";
    fg = "#EBDBB2";
    fg0 = "#FBF1C7";
    fg2 = "#D5C4A1";
    fg3 = "#BDAE93";
    fg4 = "#A89984";
    gray = "#A89984";
    dark_gray = "#7C6F64";
    light_gray = "#928374";
    red = "#CC241D";
    green = "#98971A";
    yellow = "#D79921";
    blue = "#458588";
    purple = "#B16286";
    aqua = "#689D69";
    orange = "#D65D0E";
    bright_red = "#FB4934";
    bright_green = "#B8BB26";
    bright_yellow = "#FABD2F";
    bright_blue = "#83A598";
    bright_purple = "#D3869B";
    bright_aqua = "#8EC07C";
    bright_orange = "#FE8019";
  };
}
