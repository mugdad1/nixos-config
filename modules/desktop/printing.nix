{pkgs, ...}: {
  services.printing = {
    enable = true;
    # Don't keep CUPS (and its daemons) resident; start on first job instead.
    startWhenNeeded = true;
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
