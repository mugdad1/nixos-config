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
    # new-style since 667afc7 (the fleet's own fix, same day): publish.enable
    # was obsolete the whole time this lived on the ThinkCentre.
    settings.publish."disable-publishing" = false;
  };

  # 8123, twice: LAN (setup while at home — his own network, and the first
  # visit creates the account) and tailnet (dad's phone anywhere, via the
  # Tailscale already on this box — the Blynk-cloud hole in one less place).
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [8123];
  networking.firewall.allowedTCPPorts = [8123]; # LAN — say the word and it
  # comes off, tailscale0-only is one delete away.
}
