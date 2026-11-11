# hplip is pinned to a frozen nixpkgs: 3.26.4 from the current channel fails to
# build ("makeCWrapper: Unknown argument .../dconf/gio/modules"), which takes
# cups-progs and the whole t480s system down with it. This overlay restores the
# last known-good derivation from the binary cache.
#
# Delete this file and the nixpkgs-hplip input once `nix build nixpkgs#hplip`
# succeeds again.
{inputs, ...}: {
  nixpkgs.overlays = [
    (_final: prev: {
      hplip = inputs."nixpkgs-hplip".legacyPackages.${prev.stdenv.hostPlatform.system}.hplip;
    })
  ];
}
