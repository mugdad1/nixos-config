{lib, ...}: let
  inherit (import ../../lib {inherit lib;}) scanPaths;
in {
  imports =
    # scanPaths is RECURSIVE (lib/default.nix), so every .nix under this tree
    # and every subdir carrying its own default.nix is imported on its own —
    # terminal/, apps/ and desktop/ below need no entries here. The old flat
    # list (./waybar, ./rofi/rofi.nix, …) went away with the 2026-10-14
    # regrouping; a NEW file just has to sit somewhere under here.
    #
    # scripts/ is outside this directory, so scanPaths cannot see it and it
    # stays explicit.
    (scanPaths ./.)
    ++ [
      ../../scripts/default.nix
    ];
}
