# Home Assistant + ESPHome — the AC-control project. State lives in
# /var/lib/hass (machine state, not in the flake); dad's phone reaches the UI
# at http://100.106.116.60:8123 over the tailnet.
{pkgs, ...}: {
  services.home-assistant = {
    enable = true;

    # Must cover configuration.yaml's `default_config:` or HA fails the whole
    # component with "Could not setup dependencies".
    extraComponents = [
      "esphome"
      "ssdp"
      "dhcp"
      "go2rtc"
      "stream"
      "google_translate"
    ];
  };

  environment.systemPackages = [pkgs.esphome];

  # mDNS discovery for the ESPHome node.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    settings.publish."disable-publishing" = false;
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [8123];
}
