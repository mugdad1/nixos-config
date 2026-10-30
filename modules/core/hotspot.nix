{
  host,
  lib,
  ...
}:
# Wi-Fi hotspot: share whatever uplink the box has (eno1) over wlan0, driven by
# NetworkManager's shared IPv4 mode. The profile itself is deliberately NOT
# declared here — its PSK would land in a public repo (see .sops.yaml), so it is
# created once, by hand, and lives in /etc/NetworkManager/system-connections:
#
#   nmcli connection add type wifi ifname wlan0 con-name Hotspot autoconnect no \
#     ssid "MyHotspot" 802-11-wireless.mode ap 802-11-wireless.band bg \
#     ipv4.method shared ipv6.method ignore \
#     wifi-sec.key-mgmt wpa-psk wifi-sec.psk "the-password"
#   nmcli connection up Hotspot
#
# Everything below is the part NM cannot do for itself.
lib.mkIf (host == "victus" || host == "t480s") {
  # `ipv4.method shared` turns this on while the AP is up, but it does not
  # survive a reboot with the hotspot down — and a hotspot that associates
  # without forwarding is the confusing kind of broken: clients get a 10.42.0.x
  # lease and a route to nothing.
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # NM's shared mode does DHCP (dnsmasq on 10.42.0.1:67/53) and NAT (its own
  # nftables table, `ip nm-shared-wlan0`, covering FORWARD and postrouting) —
  # but it adds nothing to INPUT. A client's DHCP DISCOVER and DNS queries
  # arrive as NEW packets on wlan0 and hit nixos-fw, which has no rule for them,
  # so the phone sits on "obtaining IP address" forever.
  #
  # Scoped to wlan0, and not via the two obvious shortcuts:
  #   - firewall.allowedUDPPorts = [ 53 67 ] would answer DHCP on every network
  #     this box joins (a rogue DHCP server on the LAN) and turn it into an open
  #     resolver on eno1;
  #   - trustedInterfaces = [ "wlan0" ] would also leave wlan0 unfiltered while
  #     it is a *client* on someone else's wifi.
  # extraCommands is iptables syntax because this config runs the iptables
  # backend; the nftables backend would want extraInputRules instead.
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -i wlan0 -p udp -m multiport --dports 53,67 -j nixos-fw-accept
    iptables -A nixos-fw -i wlan0 -p tcp --dport 53 -j nixos-fw-accept
  '';
}
