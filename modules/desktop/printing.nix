{pkgs, ...}: {
  services.printing = {
    enable = true;
    drivers = [
      pkgs.hplip
      pkgs.gutenprint
    ];
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.ipp-usb.enable = true;
}
