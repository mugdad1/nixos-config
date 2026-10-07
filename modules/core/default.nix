{lib, ...}: let
  inherit (import ../../lib {inherit lib;}) scanPaths;
in {
  imports =
    # blocky.nix deliberately NOT imported (his word, 2026-10-07: "just stop
    # blocky from being imported" — build errors reported "related to
    # blocky"). File kept for reference; network.nix's read of it is guarded.
    (builtins.filter (p: baseNameOf p != "blocky.nix") (scanPaths ./.))
    ++ [../desktop];
}
