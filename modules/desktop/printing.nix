{pkgs, ...}: {
  # GUI printer setup; the CUPS web UI is at http://localhost:631.
  environment.systemPackages = [pkgs.system-config-printer];

  services.printing = {
    enable = true;
    # Start CUPS on first job instead of keeping it resident.
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

  # ipp-usb is intentionally off: HPLIP's `hp` backend already handles HP
  # printers over USB, and the module sets obsolete avahi options. Keep SANE
  # explicit so the scanner is not lost with it.
  hardware.sane = {
    enable = true;
    extraBackends = [pkgs.sane-airscan];
  };
}
