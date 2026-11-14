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
  # asus is headless, but Wi-Fi is its only uplink, so it needs the same
  # NetworkManager + iwd stack as the laptops — just without the applet.
  wifiHost = laptop || host == "asus";
in {
  networking = {
    hostName = host;
    enableIPv6 = false;

    # grandpa is the only wired-only host.
    networkmanager = lib.mkIf wifiHost {
      enable = true;
      wifi.backend = "iwd";
      dns = lib.mkIf localDns "none";
    };

    # Ports are opened by the module that needs them, never centrally.
    firewall.enable = true;
  };

  networking.wireless.iwd.enable = lib.mkIf wifiHost true;

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
    lib.optionals laptop [networkmanagerapplet]
    ++ lib.optionals wifiHost [iw];
}
