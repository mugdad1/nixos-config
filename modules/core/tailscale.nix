{
  pkgs,
  lib,
  ...
}: {
  services.tailscale = {
    enable = true;
    openFirewall = true;
    # Don't use Tailscale's DNS (MagicDNS) — Blocky owns 127.0.0.1:53
    extraUpFlags = [
      "--accept-routes"
      "--accept-dns=false"
    ];
  };

  # Allow Tailscale traffic through the firewall
  networking.firewall = {
    allowedUDPPorts = [41641]; # Tailscale's direct connections port
    # Tailscale uses WireGuard, allow its traffic
    checkReversePath = "loose";
  };
}
