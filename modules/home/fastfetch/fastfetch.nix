{
  pkgs,
  lib,
  ...
}: let
  c = (import ../../../lib/gruvbox.nix).css;
in {
  home.packages = with pkgs; [fastfetch];

  # config.jsonc carries @TOKENS@ so the logo path + colors stay in one place:
  # logo source is the store path, colors come from lib/gruvbox.nix
  xdg.configFile."fastfetch/config.jsonc".text = lib.replaceStrings ["@LOGO@" "@C1@" "@C2@"] ["${./logo.txt}" c.blue c.red] (
    builtins.readFile ./config.jsonc
  );
}
