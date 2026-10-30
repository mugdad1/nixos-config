{
  config,
  lib,
  pkgs,
  host,
  ...
}: let
  # Blocky owns 127.0.0.1:53, so when it is enabled systemd-resolved is
  # disabled and the system DNS is pointed at Blocky instead. With Blocky off,
  # fall back to systemd-resolved (DNSSEC + Quad9).
  localDns = config.services.blocky.enable;
in {
  networking = {
    hostName = host;
    enableIPv6 = false;
    # NetworkManager + iwd exist for the laptop only. grandpa is wired-only
    # (enp3s0 into the room switch), so NM is unwanted bloat there — it pulls
    # iwd and ModemManager along even though that box has no modem and no
    # 802.11 interface. The gate is keyed on host rather than on an option the
    # shared module cannot see.
    networkmanager = lib.mkIf (host == "victus" "t480s") {
      enable = true;
      # iwd handles 802.11k/v/r and FT roaming far better than wpa_supplicant
      # on Intel: the previous laptop was flapping between two BSSIDs of one
      # SSID after the backend was switched to wpa_supplicant. iwd is also the
      # NixOS default for wifi.
      wifi.backend = "iwd";
      # With Blocky on, NetworkManager must not write resolver state from DHCP —
      # nothing but Blocky answers.
      dns = lib.mkIf localDns "none";
    };
    # No inbound ports are opened. Anything that needs one should open it in the
    # module that configures the service, not centrally here, so that a port
    # never outlives the service that needed it. (One exception: Tailscale opens
    # UDP 41641 for its own transport, in modules/core/tailscale.nix.)
    firewall.enable = true;
  };

  # NetworkManager manages wifi via iwd (don't also run the legacy dhcpcd-style
  # wireless config). networking.wireless.iwd.enable is activated by the nixos
  # module when wifi.backend = "iwd". Off on grandpa — no wifi there.
  networking.wireless.iwd.enable = lib.mkIf (host == "victus") true;

  services.resolved = lib.mkIf (!localDns) {
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

  # When Blocky owns :53, let it be the system resolver end-to-end.
  networking.resolvconf.enable = lib.mkIf localDns false;
  environment.etc."resolv.conf".text = lib.mkIf localDns ''
    nameserver 127.0.0.1
    options edns0
  '';

  environment.systemPackages = with pkgs;
    lib.optionals (host == "victus") [
      networkmanagerapplet
      iw # nl80211 wifi diagnostics
    ];
}
