# Host overrides for grandpa: undo laptop defaults, and run the wired network
# with systemd-networkd instead of NetworkManager.
{lib, ...}: {
  hardware.graphics.enable32Bit = lib.mkForce false;

  # Guard against a future core default; this host is ext4 and has no btrfs.
  services.btrfs.autoScrub.enable = lib.mkForce false;

  # Wired-only: core only enables NetworkManager/iwd on the laptops.
  networking.useDHCP = false;
  networking.useNetworkd = true;
  services.resolved.enable = lib.mkForce false;
  systemd.network.enable = true;

  # Docker veths are also type `ether`; hand them back to docker before
  # 10-ethernet can claim them and strip the bridge master.
  systemd.network.networks."09-veth-unmanaged" = {
    matchConfig.Kind = "veth";
    linkConfig.Unmanaged = true;
  };
  systemd.network.networks."10-ethernet" = {
    matchConfig.Type = "ether";
    networkConfig = {
      DHCP = "ipv4";
      DNSDefaultRoute = false;
    };
    linkConfig.RequiredForOnline = "yes";
  };

  # No interactive man usage on a headless box; the unit only ever goes inactive.
  systemd.services.mandb.enable = lib.mkForce false;

  services.openssh.enable = true;
  security.sudo.wheelNeedsPassword = lib.mkForce false;

  # grandpa is at home, where DoT/DoQ are not blocked, so it keeps the
  # encrypted transports and races them itself.
  services.blocky.settings.upstreams.groups.default = lib.mkForce [
    "tcp-tls:cbf8aa.dns.nextdns.io:853"
    "quic:2b44bd66.d.adguard-dns.com"
  ];

  # Bound on every interface so loopback and the LAN both answer; the house
  # router points its DNS here.
  services.blocky.settings.ports.dns = lib.mkForce "0.0.0.0:53";

  networking.firewall.allowedTCPPorts = [53];
  networking.firewall.allowedUDPPorts = [53];
}
