# hplip is pinned to a frozen nixpkgs — do not "clean this up" without reading why.
#
# 2026-10-20, the big flake update (nixpkgs 6510408 -> 09063bd) broke the t480s
# build entirely. The chain was:
#
#   hplip-3.26.4 fails to build
#     -> cups-progs   (1 dependency failed)
#       -> hwdb.bin
#         -> udev-rules.d
#           -> etc
#             -> nixos-system-t480s   ("Cannot build ... Reason: 1 dependency failed")
#
# so a single printer driver package took the WHOLE laptop down, with the box
# left un-switched and healthy on the old system.
#
# Root cause, read from the build log rather than guessed:
#
#   hplip> <stdin>:71:6: error: #error makeCWrapper: Unknown argument
#          /nix/store/...-dconf-0.49.0-lib/lib/gio/modules
#
# hplip's own expression sets `dontWrapGApps = true` and then manually appends
# "${gappsWrapperArgs[@]}" to its own makeQtWrapper call (pkgs/by-name/hp/
# hplip/package.nix). wrapGAppsHook3 — which is UNCONDITIONAL in that
# expression, unlike the withQt5-gated qt5.wrapQtAppsHook — puts a bare dconf
# gio/modules path into that array. The new makeCWrapper treats it as an
# unknown positional argument and #errors out.
#
# Two fixes were tried and REJECTED here, on purpose, so they are not retried:
#   1. Stripping the `"${gappsWrapperArgs[@]}"` token out of preFixup via
#      overrideAttrs — deleted the token mid-line and broke the shell quoting
#      ("missing terminating ' character", "--prefix takes 3 arguments"). String
#      surgery on nixpkgs internals; fragile and it made things worse.
#   2. withQt5 = false, and separately filtering wrapGAppsHook3 out of
#      nativeBuildInputs — the second one changed the error rather than fixing
#      it, which is the tell that the real problem is deeper in the hook's
#      environment setup than can be reached safely from outside.
#
# What DOES work: use the last known-good derivation. hplip 3.26.4 from rev
# 6510408 built and ran before the update, and it still comes straight from the
# binary cache (verified: `copying path '...hplip-3.26.4' from
# 'https://cache.nixos.org'`), so this costs no build time. The breakage is in
# the NEW makeCWrapper rejecting an argument hplip's expression passes, so the
# old expression built with the old wrapper machinery is exactly the right thing
# to restore — not a patch, just an older known-good package.
#
# Scope: the input is pinned to an exact rev, not a branch, because its entire
# job is to stay put. This overlay is global (modules/core is auto-imported into
# every host by scanPaths) but only affects consumers of pkgs.hplip, which today
# is just modules/desktop/printing.nix on the t480s. Revisit when nixpkgs ships
# a fixed hplip: if `nix build nixpkgs#hplip` succeeds again, delete this file
# and the nixpkgs-hplip input.
{inputs, ...}: {
  nixpkgs.overlays = [
    (final: prev: {
      hplip = inputs."nixpkgs-hplip".legacyPackages.${prev.stdenv.hostPlatform.system}.hplip;
    })
  ];
}
