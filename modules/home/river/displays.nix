# Displays: runtime-managed output config (no rebuild needed).
#
# - wdisplays: GUI for arranging outputs (wlr-randr frontend).
# - kanshi: hotplug daemon reading ~/.config/kanshi/config.
#
# The kanshi config is seeded ONCE by nix (baseline below); the seed never
# overwrites — edit the file freely, kanshi reloads it live on save.
# Unlisted outputs are left alone when no profile matches; when a profile
# matches, outputs not in it are turned off (kanshi semantics).
{
  pkgs,
  lib,
  ...
}: let
  baseline = pkgs.writeText "kanshi-baseline" ''
    # seeded by nix once (modules/home/river/displays.nix) — edit freely.
    # kanshi watches this file and applies changes live. nix never
    # overwrites it; delete it to re-seed on next rebuild.
    # GUI alternative: wdisplays (no config file involved).
    profile laptop {
        output eDP-1 enable scale 1.2
    }
  '';
in {
  home.activation.seedKanshiConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -f "$HOME/.config/kanshi/config" ]; then
      $DRY_RUN_CMD mkdir -p "$HOME/.config/kanshi"
      $DRY_RUN_CMD cp ${baseline} "$HOME/.config/kanshi/config"
      $DRY_RUN_CMD chmod 600 "$HOME/.config/kanshi/config"
    fi
  '';
}
