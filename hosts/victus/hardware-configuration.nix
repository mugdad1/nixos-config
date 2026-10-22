# PLACEHOLDER. This is replaced at install time by install.sh, which copies the
# real machine-generated /etc/nixos/hardware-configuration.nix over it before
# the first build. Do not hand-edit on the laptop: run `nixos-generate-config`
# or re-run install.sh instead, or the UUIDs drift from the disk.
#
# The values below match the expected layout (NVMe, ESP on p1 mounted at /boot,
# ext4 root on p2, systemd-boot from modules/core/boot.nix) so the flake still
# evaluates before the machine exists.
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

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "usb_storage"
    "sd_mod"
    "rtsx_pci_sdmmc"
  ];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/0000-0000";
    fsType = "vfat";
    options = ["fmask=0077" "dmask=0077"];
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
