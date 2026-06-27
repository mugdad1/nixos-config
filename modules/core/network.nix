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
      settings.main."rc-manager" = "file";
      insertNameservers = ["127.0.0.1"];
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [
        22
      ];
    };
  };

  environment.systemPackages = with pkgs; [networkmanagerapplet];
}
