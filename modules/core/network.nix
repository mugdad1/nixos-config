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
      # AdGuard Home owns 127.0.0.1:53 (modules/core/adguardhome.nix). `none`
      # stops NetworkManager from also writing resolver state from DHCP, so
      # nothing but AdGuard Home ever answers.
      dns = "none";
    };
    # No inbound ports are opened. Anything that needs one should open it in the
    # module that configures the service, not centrally here, so that a port
    # never outlives the service that needed it. (The two exceptions are opened
    # in modules/core/tailscale.nix: UDP 41641 for Tailscale's own transport.)
    firewall.enable = true;
  };

  # NetworkManager manages wifi via iwd (don't also run the legacy dhcpcd-style
  # wireless config). networking.wireless.iwd.enable is activated by the nixos
  # module when wifi.backend = "iwd".
  networking.wireless.iwd.enable = true;

  # systemd-resolved is OFF: it would bind the stub resolver on 127.0.0.53 and
  # become a second DNS layer in front of AdGuard Home. AdGuard Home is the one
  # and only resolver, on 127.0.0.1:53.
  services.resolved.enable = false;

  # Point /etc/resolv.conf straight at AdGuard Home. With resolved gone, let it
  # be the system resolver end-to-end (same pattern this repo used for Blocky).
  networking.resolvconf.enable = false;
  environment.etc."resolv.conf".text = ''
    nameserver 127.0.0.1
    options edns0
  '';

  environment.systemPackages = with pkgs; [
    networkmanagerapplet
    iw # nl80211 wifi diagnostics
  ];
}
