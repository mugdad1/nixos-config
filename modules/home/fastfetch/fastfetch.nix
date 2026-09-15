{
  pkgs,
  lib,
  variables,
  ...
}: let
  c = (import ../../../lib/theme.nix variables).css;
in {
  home.packages = with pkgs; [fastfetch];

  # config.jsonc carries @TOKENS@ so the logo path + colors stay in one place:
  # logo source is the store path, colors come from lib/theme.nix
  xdg.configFile."fastfetch/config.jsonc".text = lib.replaceStrings ["@LOGO@" "@C1@" "@C2@"] ["${./logo.txt}" c.bright_orange c.fg] (
    builtins.readFile ./config.jsonc
  );
}
