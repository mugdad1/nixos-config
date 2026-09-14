{
  variables,
  lib,
  ...
}: let
  inherit (import ../../lib {inherit lib;}) scanPaths;
in {
  imports =
    (scanPaths ./.)
    ++ [
      ./waybar
      ./rofi/rofi.nix
      ./swaync/swaync.nix
      ./fastfetch/fastfetch.nix
      ./ghostty/ghostty.nix
      ../../scripts/default.nix
    ]
    ++ (
      if variables.compositor == "river"
      then [./river]
      else [./hyprland]
    );
}
