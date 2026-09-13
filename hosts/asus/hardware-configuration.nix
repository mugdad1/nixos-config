# PLACEHOLDER — DO NOT DEPLOY AS-IS.
#
# Install NixOS on the ASUS, then run:
#   nixos-generate-config --show-hardware-config > hosts/asus/hardware-configuration.nix
# and commit the real file. Fake UUIDs below evaluate fine but will NOT boot.
{...}: {
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-REAL-UUID";
    fsType = "btrfs";
  };

  swapDevices = [];
}
