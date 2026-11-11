# Shared system layer: every host imports this. The desktop is opt-in per host.
{lib, ...}: let
  inherit (import ../../lib {inherit lib;}) scanPaths;
in {
  imports = scanPaths ./.;
}
