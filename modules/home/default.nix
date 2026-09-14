{
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
      ./river
      ../../scripts/default.nix
    ];
}
