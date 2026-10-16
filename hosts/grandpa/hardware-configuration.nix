# ⚠️  PLACEHOLDER — THIS FILE WAS *NOT* GENERATED ON THE BOX.
#
# hosts/grandpa has no hardware yet. On install day, ON THE BOX, run:
#
#     sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
#
# (or let the installer write /etc/nixos/hardware-configuration.nix and copy it
# here), then replace this file wholesale and diff. Everything below is a
# stand-in so the flake EVALUATES — NixOS requires fileSystems."/" to be set, so
# the file cannot simply be omitted. The device strings are deliberate nonsense;
# deploying this as-is would fail to mount root and drop to a rescue shell.
#
# Repo rule (from hosts/thinkcentre/default.nix, learned the hard way): this file
# is a GENERATED ARTIFACT — never hand-edit it. Anything that must survive a
# regeneration belongs in ./default.nix instead. So far that is nothing beyond
# root and the ESP.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Sandy Bridge (i3-2xxx): SATA + USB 3.0 + KVM. Confirm on the box.
  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "usb_storage" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  # ⚠️ PLACEHOLDER device values — regenerate with nixos-generate-config.
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/REGENERATE-ON-THE-BOX";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/REGENERATE-ON-THE-BOX";
    fsType = "vfat";
    options = ["fmask=0077" "dmask=0077"];
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
