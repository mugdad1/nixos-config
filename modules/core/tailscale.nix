_: {
  services.tailscale = {
    enable = true;
    openFirewall = true;
    # Don't use Tailscale's DNS (MagicDNS) — Blocky owns 127.0.0.1:53
    # --ssh: enable Tailscale SSH (identity from tailnet ACLs, no server keys)
    extraUpFlags = [
      "--accept-routes"
      "--accept-dns=false"
      "--ssh"
    ];
  };

  # Allow Tailscale traffic through the firewall
  networking.firewall = {
    allowedUDPPorts = [41641]; # Tailscale's direct connections port
    # Tailscale uses WireGuard, allow its traffic
    checkReversePath = "loose";
  };
}
