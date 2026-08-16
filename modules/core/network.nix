{
  pkgs,
  host,
  ...
}: {
  networking = {
    hostName = "${host}";
    networkmanager = {
      enable = true;
      wifi.backend = "wpa_supplicant";
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [
        22
      ];
      allowedUDPPorts = [];
    };
  };

  services.resolved = {
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

  environment.systemPackages = with pkgs; [networkmanagerapplet];
}
