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

  # ipp-usb is deliberately NOT enabled. It is only needed for driverless
  # IPP-over-USB; HPLIP's own `hp` CUPS backend already handles HP printers
  # (including USB), and the ipp-usb NixOS module still sets the obsolete
  # `services.avahi.publish.*` options in 26.11, which produced two evaluation
  # warnings. `lpinfo -v` still lists `direct hp`, so HP printing is unchanged.
}
