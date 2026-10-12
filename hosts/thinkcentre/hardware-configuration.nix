# DRAFT — hand-built by probing the live Void install (2026-10-07), NOT by
# nixos-generate-config. UUIDs and mount facts came straight from /etc/fstab:
#
#   sda2  btrfs  839da341-…  /            (subvolid=5, no compression)
#   ESP   vfat   646D-44FB    /boot/efi
#   sdb1  btrfs  67dc44db-…  /srv/backup  (ADATA SP550, nofail)
#   tmpfs          /tmp  nosuid,nodev
#   swapfile       /swap/swapfile
#
# Regenerate with nixos-generate-config at install time and diff against
# this file — the initrd module list is the one part inferred, not probed.
{
  config,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "usb_storage" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  # Root: single btrfs subvolume, faithful to the donor — compress=zstd:1
  # (the t480s setting) is a safe later upgrade: btrfs accepts it at mount
  # time and it only affects newly written files. Cutover stays identical.
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/839da341-d007-434b-9e71-981e82cbf250";
    fsType = "btrfs";
    options = ["defaults" "noatime"];
  };

  # ESP at /boot/efi (donor mounts it there; GRUB lived under EFI/void).
  # systemd-boot takes over — efiSysMountPoint set in ../thinkcentre/default.nix.
  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-uuid/646D-44FB";
    fsType = "vfat";
    options = ["fmask=0077" "dmask=0077"];
  };

  # Backup disk must never block boot — nofail, same as donor fstab.
  fileSystems."/srv/backup" = {
    device = "/dev/disk/by-uuid/67dc44db-b497-44e0-b45c-a70050558dd3";
    fsType = "btrfs";
    options = ["defaults" "nofail"];
  };

  fileSystems."/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = ["nosuid" "nodev"];
  };

  swapDevices = [{device = "/swap/swapfile";}];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
