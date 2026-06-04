{ pkgs, host, ... }:
{
  networking = {
    hostName = "${host}";
    networkmanager.enable = true;
    nameservers = [
      "94.140.14.14"
      "94.140.15.15"
    ];
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 ];
      allowedUDPPorts = [ ];
    };
  };

  environment.systemPackages = with pkgs; [ networkmanagerapplet ];
}
