# core is the shared layer: every host gets it, headless or not. The desktop
# is NOT part of it — hosts that want one import ../../modules/desktop
# themselves (t480s does). Before 2026-10-12 this line hard-imported
# ../desktop, which meant adding any second host silently inherited greetd,
# sway, pipewire, portals and fonts; that is what blocked the ThinkCentre.
{lib, ...}: let
  inherit (import ../../lib {inherit lib;}) scanPaths;
in {
  imports = scanPaths ./.;
}
