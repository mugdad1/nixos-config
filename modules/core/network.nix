{
  pkgs,
  host,
  ...
}: {
  networking = {
    hostName = "${host}";
    resolvconf.enable = false;
    networkmanager = {
      enable = true;
      wifi.backend = "iwd";
      dns = "none";
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [
        22
      ];
    };
  };

  environment.etc."resolv.conf".text = "nameserver 127.0.0.1\n";
  environment.systemPackages = with pkgs; [networkmanagerapplet];
}
