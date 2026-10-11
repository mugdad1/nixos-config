{
  pkgs,
  host,
  ...
}: {
  networking = {
    hostName = host;
    enableIPv6 = false;
    networkmanager = {
      enable = true;
      # iwd handles 802.11k/v/r and FT roaming far better than wpa_supplicant on
      # Intel: the t480s was flapping between two BSSIDs of one SSID after the
      # backend was switched to wpa_supplicant. iwd is also the NixOS default
      # for wifi.
      wifi.backend = "iwd";
    };
    # No inbound ports are opened. Anything that needs one should open it in the
    # module that configures the service, not centrally here, so that a port
    # never outlives the service that needed it. (One exception: Tailscale opens
    # UDP 41641 for its own transport, in modules/core/tailscale.nix.)
    firewall.enable = true;
  };

  # NetworkManager manages wifi via iwd (don't also run the legacy dhcpcd-style
  # wireless config). networking.wireless.iwd.enable is activated by the nixos
  # module when wifi.backend = "iwd".
  networking.wireless.iwd.enable = true;

  # systemd-resolved is the one and only resolver. DNS points at the AdGuard
  # Home on the thinkcentre server over the tailnet (100.97.91.119), so this
  # laptop gets AGH's filtering wherever it is. `Domains = ~.` routes every
  # query there. Tailscale refuses MagicDNS (--accept-dns=false in
  # tailscale.nix), so nothing else touches /etc/resolv.conf.
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = ["100.97.91.119"];
      DNSSEC = "allow-downgrade";
      Domains = ["~."];
      # If the tailnet or the server is down, fall back to Quad9 rather than
      # losing resolution entirely.
      FallbackDNS = [
        "9.9.9.9"
        "149.112.112.112"
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    networkmanagerapplet
    iw # nl80211 wifi diagnostics
  ];
}
