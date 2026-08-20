{pkgs, ...}: {
  # CUPS print server + HP drivers (covers both USB/wired and network/IP printers)
  services.printing = {
    enable = true;
    drivers = with pkgs; [hplip];
    # openFirewall = true;  # only if you want to print to/from other machines
  };

  # Auto-discover network/IP printers via mDNS. USB printers are detected too
  # (many modern HP expose IPP-over-USB). CUPS-browsed picks them up automatically.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # GUI printer manager
  programs.system-config-printer.enable = true;
}
