# Mount by label so a reinstall does not invalidate this file. The installer
# sets the labels: ASUSBOOT (ESP), asus-root (SSD), asus-storage (1 TB HDD).
# Label-based mounts mean it does not matter whether the HDD sits in the 2.5"
# bay or in a USB enclosure — whichever disk carries the label gets mounted.
{
  config,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # ahci + sd_mod for the SATA SSD and the Seagate, xhci for the install stick.
  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "usb_storage" "sd_mod" "sdhci_pci"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-label/asus-root";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ASUSBOOT";
    fsType = "vfat";
    options = ["fmask=0077" "dmask=0077"];
  };

  fileSystems."/srv/storage" = {
    device = "/dev/disk/by-label/asus-storage";
    fsType = "ext4";
    # The box must still boot if the platter dies.
    options = ["nofail" "x-systemd.device-timeout=10"];
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
