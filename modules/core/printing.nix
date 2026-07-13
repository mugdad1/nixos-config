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

  # Declarative printers (optional). Fill in after running:
  #   lpinfo -v            # -> deviceUri (usb://... or socket://IP:9100)
  #   lpinfo -m | grep hp  # -> model ppd
  # hardware.printers = {
  #   ensurePrinters = [
  #     {
  #       name = "hp-usb";
  #       location = "Desk (USB)";
  #       deviceUri = "usb://HP/...";
  #       model = "drv:///hp/hpcups.drv/hp-..._series.ppd";
  #       ppdOptions = { PageSize = "A4"; };
  #     }
  #     {
  #       name = "hp-network";
  #       location = "Network (IP)";
  #       deviceUri = "socket://192.168.1.50:9100";
  #       model = "drv:///hp/hpcups.drv/hp-..._series.ppd";
  #       ppdOptions = { PageSize = "A4"; };
  #     }
  #   ];
  #   ensureDefaultPrinter = "hp-network";
  # };
}
