# ─── Home Assistant + ESPHome — the AC-control project, MOVED HERE ───────────
# 2026-10-22, his order: "move the services from thinkcentre to grandpa … nix
# work only". The ThinkCentre is being returned to its owner, and this is the
# one service in the move that cannot simply be reinstalled: /var/lib/hass
# holds the account, the room, the AC, and the paired ESPHome device. Read
# hosts/thinkcentre/home-assistant.nix (commented out) for row 111's full
# history — Blynk-vs-HA, 2026-10-17, dad leaning Blynk for its phone widgets;
# the house got HA: local, tailnet-reachable, no cloud, no message caps.
#
# dad's phone reaches it at **http://100.106.116.60:8123** — the tailnet
# address of THIS box. The ThinkCentre's 100.88.29.31 stops being an answer
# the day the box leaves; anything pointed there (bookmark, widget) must be
# repointed to this one.
#
# STATE DOES NOT TRAVEL WITH THE FLAKE: /var/lib/hass is machine state, so it
# has to be copied across on the same day as the service — a fresh HA here
# would mean re-onboarding the account and re-adding the ESP32, and the AC
# controls would read dead until someone stood in front of it with a browser.
# The pairing itself is LAN-scoped: the ESP32 must reach THIS box the way it
# reached the old one.
#
# The shape, unchanged from the ThinkCentre: ESP32 + IR LED (driven through a
# transistor) sits in front of the AC, runs ESPHome firmware, joins the LAN,
# and appears in HA as a real `climate` device. An IR receiver next to the LED
# captures the original remote's codes, so no protocol guessing. First flash is
# USB, OTA after that — the flashing machine is now whatever sits on the same
# LAN as the ESP32, not the ThinkCentre.
{pkgs, ...}: {
  # The hub. The native NixOS module — NO docker (his rule for this house).
  # UI on :8123; config lives in /var/lib/hass, so first-run setup (create
  # the account, add the ESPHome device) happens in the browser as usual.
  services.home-assistant = {
    enable = true;
    # Pull each integration's python deps into the environment so no component
    # dies on import. This list must track configuration.yaml's `default_config:`
    # — 2026-10-25, post-reboot check: it only held "esphome", while
    # `default_config:` (line 2 of configuration.yaml, marked "Do not remove")
    # also demands ssdp, dhcp, go2rtc and stream. Their deps were therefore
    # absent, and HA fails them one by one and then fails `default_config`
    # ITSELF as a whole: "Setup failed for 'default_config': Could not setup
    # dependencies: ['dhcp','go2rtc','ssdp','stream']". Every component under
    # default_config goes with it — not just the four that started it.
    # Pre-existing, not a reboot casualty: the same two ModuleNotFoundErrors
    # appear on the previous boot as on this one.
    #   async_upnp_client -> ssdp      aiodhcpwatcher -> dhcp
    #   go2rtc_client      -> go2rtc   (stream rides along)
    extraComponents = [
      "esphome"
      "ssdp"
      "dhcp"
      "go2rtc"
      "stream"
    ];
  };

  # Builds and flashes the ESP32 firmware. Same YAML either way: the IR
  # transmitter, the receiver, and the `climate` block with the captured
  # remote codes.
  environment.systemPackages = [pkgs.esphome];

  # mDNS/zeroconf — how HA discovers the ESPHome node on the LAN (and how
  # things find each other generally). HA's discovery leans on it; without
  # avahi on a NixOS host it simply never shows up.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    # new-style since 667afc7 (the fleet's own fix, same day): publish.enable
    # was obsolete the whole time this lived on the ThinkCentre.
    settings.publish."disable-publishing" = false;
  };

  # 8123 on tailscale0 only. Setup is complete, and dad's phone already uses
  # the tailnet address; there is no reason to keep answering the flat LAN.
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [8123];
}
