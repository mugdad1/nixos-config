{
  config,
  pkgs,
  lib,
  host,
  ...
}: let
  # AdGuard Home owns 127.0.0.1:53, so when it is enabled systemd-resolved is
  # disabled and the system DNS is pointed at AdGuard instead. With AdGuard
  # off, fall back to systemd-resolved (DNSSEC + Quad9).
  localDns = config.services.blocky.enable;
in {
  networking = {
    hostName = host;
    networkmanager = {
      enable = true;
      # iwd handles 802.11k/v/r and FT roaming far better than wpa_supplicant on
      # Intel: the t480s was flapping between two BSSIDs of one SSID after the
      # backend was switched to wpa_supplicant. iwd is also the NixOS default
      # for wifi. With Blocky on, NetworkManager does not manage DNS itself.
      wifi.backend = "iwd";
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [
        53317
      ];
      allowedUDPPorts = [
        53317
      ];
    };
  };

  # NetworkManager manages wifi via iwd (don't also run the legacy dhcpcd-style
  # wireless config). networking.wireless.iwd.enable is activated by the nixos
  # module when wifi.backend = "iwd".
  networking.wireless.iwd.enable = true;

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

  # When

  # When Blocky owns :53, let it be the system resolver end-to-end.
  networking.resolvconf.enable = lib.mkIf localDns false;
  environment.etc."resolv.conf".text = lib.mkIf localDns ''
    nameserver 127.0.0.1
    options edns0
  '';

  environment.systemPackages = with pkgs; [
    networkmanagerapplet
    iw # nl80211 wifi diagnostics
  ];
}
