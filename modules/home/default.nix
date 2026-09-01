{lib, ...}: let
  inherit (import ../../lib {inherit lib;}) scanPaths;
in {
  imports = (scanPaths ./.) ++ [
    ./waybar
    ./hyprland
    ./rofi/rofi.nix
    ./swaync/swaync.nix
    ./fastfetch/fastfetch.nix
    ./ghostty/ghostty.nix
    ../../scripts/scripts.nix
  ];
}
