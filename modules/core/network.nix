{
  pkgs,
  host,
  ...
}: {
  networking = {
    hostName = "${host}";
    networkmanager = {
      enable = true;
      wifi.backend = "iwd";
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [
        22
      ];
      allowedUDPPorts = [
        41641
      ];
    };
  };

  services.resolved = {
    enable = true;
    dnssec = "allow-downgrade";
    domains = ["~."];
    fallbackDns = [
      "9.9.9.9"
      "149.112.112.112"
    ];
  };

  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  environment.systemPackages = with pkgs; [networkmanagerapplet];
}
