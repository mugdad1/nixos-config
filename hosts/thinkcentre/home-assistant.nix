# ─── Home Assistant + ESPHome — the AC-control project ──────────────────────
# His word, 2026-10-17: "Ok add all stuff i need in thinkcente" — after the
# Blynk-vs-HA comparison (dad leaned Blynk for its phone widgets; the house
# gets HA: local, tailnet-reachable, no cloud, no message caps). Decisions
# row 111. Grandpa never received it — row 103's "which services" stays open.
#
# The shape: ESP32 + IR LED (driven through a transistor) sits in front of
# the AC, runs ESPHome firmware, joins this LAN, and appears in HA as a real
# `climate` device. An IR receiver next to the LED captures the original
# remote's codes, so no protocol guessing. First flash is USB from this box,
# OTA after that.
{pkgs, ...}: {
  # The hub. The native NixOS module — NO docker (his rule for this house).
  # UI on :8123; config lives in /var/lib/hass, so first-run setup (create
  # the account, add the ESPHome device) happens in the browser as usual.
  services.home-assistant = {
    enable = true;
    # Pull the ESPHome integration's python deps into the environment so the
    # device can be added without a component-missing surprise.
    extraComponents = ["esphome"];
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
    publish.enable = true;
  };

  # 8123, twice: LAN (setup while at home — his own network, and the first
  # visit creates the account) and tailnet (dad's phone anywhere, via the
  # Tailscale already on this box — the Blynk-cloud hole in one less place).
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [8123];
  networking.firewall.allowedTCPPorts = [8123]; # LAN — say the word and it
  # comes off, tailscale0-only is one delete away.
}
