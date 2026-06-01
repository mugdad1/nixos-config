{ lib, pkgs, config, ... }:
{
  services.asusd.enable = true;

  services.supergfxd = {
    enable = true;
    settings = {
      vfio_enable = true;
      always_reboot = false;
      no_logind = false;
    };
  };

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  systemd.tmpfiles.rules = [
    "d /etc/asusd 0755 root root"
  ];
}
