# Host-level OVERRIDES for grandpa — every value a shared module sets for the
# laptop that this wired, headless box has to undo, plus the systemd-networkd
# posture that replaces NetworkManager. The long notes live in git history;
# this file keeps only what is specific to grandpa.
#
# ONLY active because ./overrides.nix is named in the imports list of
# ./default.nix — a directory module does not sweep up its siblings.
{lib, ...}: {
  # Headless: no games, no Wine, hence no 32-bit Mesa. modules/core/hardware.nix
  # sets this plainly for the machines that want it.
  hardware.graphics.enable32Bit = lib.mkForce false;

  # The disk is a single ext4 HDD — no btrfs, so a scrub has nothing to act on.
  # **CORRECTED 2026-10-18:** the "the laptop, whose root IS btrfs, keeps
  # scrubbing" half of this comment was false — the t480s root is ext4 too
  # (`c0e89f41…`), and nothing in this repo enables `services.btrfs.autoScrub`
  # at all. So this is a guard against a future core default, not a host fix;
  # see the longer note in hosts/thinkcentre/overrides.nix.
  services.btrfs.autoScrub.enable = lib.mkForce false;

  # ── network: systemd-networkd in ───────────────────────────────────────────
  # Wired desktop: modules/core/network.nix enables NetworkManager/iwd only on
  # victus, so this host never inherits that stack or ModemManager.
  networking.useDHCP = false;
  networking.useNetworkd = true;
  # blocky owns /etc/resolv.conf (core/network.nix forces nameserver 127.0.0.1
  # when blocky is on); enabling networkd would otherwise pull in
  # systemd-resolved, which fights for the same file and fails evaluation.
  services.resolved.enable = lib.mkForce false;
  systemd.network.enable = true;
  # DOCKER'S VETHs — the trap the Type=ether match below fell into once docker
  # arrived (2026-10-19, forgejo + gitea-mirror moved to compose). A veth end is
  # ALSO type `ether`, so 10-ethernet claimed every docker veth the moment a
  # container started, and applying a .network file to it strips the bridge
  # master: dockerd creates the pair, enslaves it, networkd claims it, the port
  # falls out of the bridge — dmesg shows "entered promiscuous mode" then
  # "left promiscuous mode" seconds later, the bridge sits NO-CARRIER, and
  # every published port is a timeout from outside while `docker exec` and
  # wget INSIDE the container answer fine (the container never notices).
  # thinkcentre never hit this because its match is Name=eno1. networkd picks
  # the FIRST matching .network, so this one sorts before 10- and hands veths
  # straight back to docker, unmanaged.
  systemd.network.networks."09-veth-unmanaged" = {
    matchConfig.Kind = "veth";
    linkConfig.Unmanaged = true;
  };
  # The NIC name on a custom-built desktop is unknowable until the box is here,
  # so match by link TYPE (every ethernet port) instead of a hard-coded name like
  # the ThinkCentre's eno1. docker bridges are type `bridge`, not `ether`, so
  # they are untouched — the veths needed 09-veth-unmanaged above.
  systemd.network.networks."10-ethernet" = {
    matchConfig.Type = "ether";
    networkConfig = {
      DHCP = "ipv4";
      DNSDefaultRoute = false;
    };
    linkConfig.RequiredForOnline = "yes";
  };

  # mandb runs to completion then goes inactive — the one false positive a unit
  # monitor keeps flagging on a headless box. No interactive man usage here.
  systemd.services.mandb.enable = lib.mkForce false;

  # sshd on the LAN, and passwordless sudo. core already does both; stated here
  # for the same reason thinkcentre states them — a headless box with nobody at a
  # keyboard must not depend on core never changing its mind.
  services.openssh.enable = true;
  security.sudo.wheelNeedsPassword = lib.mkForce false;

  # blocky upstreams: drop the laptop's two work resolvers (192.168.44.187/.188),
  # which do not exist here. Race the encrypted pair alone — identical to
  # hosts/thinkcentre/overrides.nix.
  services.blocky.settings.upstreams.groups.default = lib.mkForce [
    "tcp-tls:cbf8aa.dns.nextdns.io:853"
    "quic:2b44bd66.d.adguard-dns.com"
  ];

  # ── blocky: reachable from the tailnet, plain DNS only ──────────────────────
  # MOVED HERE 2026-10-22 with the rest of the service layer: the ThinkCentre
  # is being returned to its owner, and it has held this since 2026-10-21
  # (decisions row 177). Same posture, new address.
  #
  # His word, 2026-10-21: "i just want to set the tailscale ip as dns / inside
  # tailsclae / cuz on phone i must allow tailsclae dns", then "i will not use
  # dot / just plain tailscaleip as dns". So: no DoT, no 853, no cert, no
  # Private DNS — the phone points at **100.106.116.60** and the query travels
  # inside the tailnet. The ThinkCentre's 100.88.29.31 stops being an answer
  # the day the box leaves; anything (phone Private DNS, a router, a second
  # box) still pointed there must be repointed to this one.
  #
  # Why 0.0.0.0 rather than the tailnet address alone: core/network.nix points
  # /etc/resolv.conf at 127.0.0.1, because blocky IS this box's resolver, so
  # binding only the tailnet IP would take DNS away from the box itself. All
  # interfaces keeps loopback answering; what makes it tailnet-only is the
  # firewall rule below, which never opens the LAN.
  services.blocky.settings.ports.dns = lib.mkForce "0.0.0.0:53";

  # tailscale0 only, the pattern home-assistant.nix (8123) already uses. BOTH
  # transports: tcp is what a resolver falls back to when the answer is too big
  # for one UDP packet — any large or DNSSEC-signed response — so opening udp
  # alone breaks the big answers and only then.
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [53];
  networking.firewall.interfaces."tailscale0".allowedUDPPorts = [53];
}
