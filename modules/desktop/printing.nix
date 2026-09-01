{pkgs, ...}: {
  # CUPS print server + HP drivers (covers both USB/wired and network/IP printers)
  services.printing = {
    enable = true;
    drivers = with pkgs; [hplip];
    # openFirewall = true;  # only if you want to print to/from other machines
  };

  # GUI printer manager
  programs.system-config-printer.enable = true;
}
