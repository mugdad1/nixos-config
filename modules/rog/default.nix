{ lib, pkgs, config, ... }:
{
  services.asusd.enable = true;

  services.supergfxd.enable = true;

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  systemd.tmpfiles.rules = [
    "d /etc/asusd 0755 root root"
  ];
}
