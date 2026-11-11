{
  config,
  lib,
  pkgs,
  host,
  ...
}: let
  # When Blocky is on it owns :53, so resolved and resolvconf get out of the way.
  localDns = config.services.blocky.enable;
  laptop = host == "victus" || host == "t480s";
in {
  networking = {
    hostName = host;
    enableIPv6 = false;

    # NetworkManager + iwd are laptop-only; grandpa is wired-only.
    networkmanager = lib.mkIf laptop {
      enable = true;
      wifi.backend = "iwd";
      dns = lib.mkIf localDns "none";
    };

    # Ports are opened by the module that needs them, never centrally.
    firewall.enable = true;
  };

  networking.wireless.iwd.enable = lib.mkIf laptop true;

  services.resolved = lib.mkIf (!localDns) {
    enable = true;
    settings.Resolve = {
      DNSSEC = "allow-downgrade";
      Domains = ["~."];
      FallbackDNS = [
        "9.9.9.9"
        "149.112.112.112"
      ];
    };
  };

  networking.resolvconf.enable = lib.mkIf localDns false;
  environment.etc."resolv.conf".text = lib.mkIf localDns ''
    nameserver 127.0.0.1
    options edns0
  '';

  environment.systemPackages = with pkgs;
    lib.optionals laptop [
      networkmanagerapplet
      iw
    ];
}
