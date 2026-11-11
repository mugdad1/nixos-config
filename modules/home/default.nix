{lib, ...}: let
  inherit (import ../../lib {inherit lib;}) scanPaths;
in {
  # scanPaths is recursive, so every .nix under this tree is picked up.
  # scripts/ lives outside the directory and must stay explicit.
  imports =
    (scanPaths ./.)
    ++ [
      ../../scripts/default.nix
    ];
}
