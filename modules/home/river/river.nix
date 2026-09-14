# river session packages. WM config lives in kwm.nix (window manager)
# and kwim.nix (input rules); the session launches kwm via
# modules/desktop/services.nix.
{pkgs, ...}: let
  kwm = pkgs.callPackage ../../../packages/kwm.nix {};
  kwim = pkgs.callPackage ../../../packages/kwim.nix {};
in {
  home.packages = with pkgs; [
    kwm
    kwim
    river
    awww
    grimblast
    wlr-randr
    wdisplays
    kanshi
    wl-clip-persist
    cliphist
    grim
    glib
    wayland
  ];
}
