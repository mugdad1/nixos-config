# Host-level OVERRIDES for grandpa — every value a shared module sets for the
# ThinkPad that this wired, headless box has to undo, plus the systemd-networkd
# posture that replaces NetworkManager. Same shape and reasoning as
# hosts/thinkcentre/overrides.nix; read that file for the long notes — this one
# keeps only what is specific to grandpa.
#
# ONLY active because ./overrides.nix is named in the imports list of
# ./default.nix — a directory module does not sweep up its siblings.
{lib, ...}: {
  # Headless: no games, no Wine, hence no 32-bit Mesa. modules/core/hardware.nix
  # sets this plainly for the machines that want it.
  hardware.graphics.enable32Bit = lib.mkForce false;

  # The disk is a single ext4 HDD — no btrfs, so the weekly scrub has nothing to
  # act on. mkForce (not a comment in core) so the laptop, whose root IS btrfs,
  # keeps scrubbing.
  services.btrfs.autoScrub.enable = lib.mkForce false;

  # ── network: NetworkManager out, systemd-networkd in ───────────────────────
  # Wired desktop: NM drags in iwd and ModemManager for hardware that is not
  # present. modules/core/network.nix gates that stack on `host != "thinkcentre"`,
  # so grandpa WOULD inherit it — these mkForce lines are what turn it back off.
  systemd.services.ModemManager.enable = lib.mkForce false;
  networking.networkmanager.enable = lib.mkForce false;
  networking.wireless.iwd.enable = lib.mkForce false;
  networking.useDHCP = false;
  networking.useNetworkd = true;
  # blocky owns /etc/resolv.conf (core/network.nix forces nameserver 127.0.0.1
  # when blocky is on); enabling networkd would otherwise pull in
  # systemd-resolved, which fights for the same file and fails evaluation.
  services.resolved.enable = lib.mkForce false;
  systemd.network.enable = true;
  # The NIC name on a custom-built desktop is unknowable until the box is here,
  # so match by link TYPE (every ethernet port) instead of a hard-coded name like
  # the ThinkCentre's eno1. docker bridges are type `bridge`, not `ether`, so
  # they are untouched.
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
}
