# Wi-Fi-first server networking (AX210 card). Tailscale bypasses the firewall,
# so only SSH stays open for LAN bootstrap (before `tailscale up` on fresh installs).
{
  pkgs,
  lib,
  host,
  ...
}: {
  networking = {
    hostName = host;
    enableIPv6 = false;
    networkmanager.enable = true;

    firewall = {
      enable = true;
      allowedTCPPorts = [22];
    };
  };

  # AX210 (Wi-Fi 6E) needs the redistributable iwlwifi firmware
  hardware.enableRedistributableFirmware = lib.mkDefault true;

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

  environment.systemPackages = with pkgs; [
    iw
    ethtool
  ];

  time.timeZone = lib.mkDefault "Asia/Riyadh";
}
