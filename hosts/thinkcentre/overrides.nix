# Host-level OVERRIDES for the ThinkCentre — split out of default.nix
# 2026-10-14. Everything here is a `lib.mkForce` (a value shared
# modules/core sets for the ThinkPad that this headless box has to undo),
# plus the networkd posture that replaces NetworkManager and two belt-and-
# braces entries (sshd, sudo) whose reasoning belongs with the rest.
#
# ONLY active because ./overrides.nix is named in the `imports` list of
# ./default.nix — a directory module does NOT sweep up its siblings (see the
# warning there).
{lib, ...}: {
  # Headless: no games, no Wine, hence no 32-bit Mesa. modules/core/hardware.nix
  # sets this plainly for the laptop, so it needs mkForce to undo.
  hardware.graphics.enable32Bit = lib.mkForce false;

  # ── btrfs scrub ────────────────────────────────────────────────────────────
  # No btrfs here — this box runs ext4, so a btrfs scrub would have no
  # filesystem to act on. **CORRECTED 2026-10-18: this line is a guard, not a
  # fix, and the comment it carried was wrong on both counts.** Nothing in this
  # repo enables `services.btrfs.autoScrub` (grep it: zero hits outside these
  # two overrides), and the t480s — named below as the host that "needs it" —
  # has an **ext4** root as well (`/dev/disk/by-uuid/c0e89f41…`, ext4). So the
  # weekly scrub this comment claimed to be switching off for the servers never
  # ran on any host, and the mkForce changes nothing. It is kept as a
  # deliberate no-op: if scrubbing is ever enabled in core (a btrfs host, or a
  # future disk), a headless ext4 server must not inherit it, and a stated
  # intent is cheaper to keep than to re-derive.
  #
  # OPEN ITEM CLOSED 2026-10-13: it asked whether /srv/backup should be
  # scrubbed — a backup disk that silently rots is exactly where scrubbing
  # matters — but the disk is ext4, so btrfs scrub cannot touch it. Moot.
  #
  # hardware-configuration.nix was regenerated on the box 2026-10-13 (the full
  # story is above the imports in ./default.nix); its stale donor/btrfs UUIDs
  # are gone. It is still never edited by hand here — the real UUIDs only
  # exist on the box, and hand-writing them from the ThinkPad would ship wrong
  # ones and panic at boot.
  services.btrfs.autoScrub.enable = lib.mkForce false;

  # ── network: NetworkManager out, systemd-networkd in ───────────────────────
  # Wired-only box: NM pulls in iwd and ModemManager, neither of which belongs
  # here, and a wifi-less headless machine has no use for the whole stack. DHCP
  # on eno1 is now systemd-networkd's job instead: NixOS's intended shape for a
  # server with one ethernet uplink. The NM/iwd gate lives in modules/core/
  # network.nix (host != "thinkcentre") so the ThinkPad keeps NM + iwd untouched.
  #
  # ModemManager is what sv-watch kept flagging as idle — with NM gone it does
  # not get enabled at all, so it drops off the sweep as well. It is enabled
  # only as a side effect of the networkmanager module (no modem hardware
  # anyway), so removing NM is what removes it; the forced-off unit below
  # stops it surviving from the running system.
  systemd.services.ModemManager.enable = lib.mkForce false;
  networking.networkmanager.enable = lib.mkForce false;
  networking.wireless.iwd.enable = lib.mkForce false;
  networking.useDHCP = false;
  networking.useNetworkd = true;
  # Blocky owns /etc/resolv.conf on this box (forced to nameserver 127.0.0.1
  # in modules/core/network.nix). Without this, enabling networkd pulls in
  # systemd-resolved, which tries to own the same file and fails evaluation.
  services.resolved.enable = lib.mkForce false;
  # eno1 is the only non-loopback, non-tailscale, non-docker interface on this
  # box (`ip -br link` agreed). DHCP keeps the .225 address the router assigns;
  # blocky still owns /etc/resolv.conf, so no DNS option is requested — the
  # NixOS core forced the file to nameserver 127.0.0.1 on this host.
  systemd.network.enable = true;
  systemd.network.networks."10-eno1" = {
    matchConfig.Name = "eno1";
    networkConfig = {
      DHCP = "ipv4";
      DNSDefaultRoute = false;
    };
    linkConfig.RequiredForOnline = "yes";
  };

  # mandb (man-page index) is enabled on NixOS by default and is a
  # Type=simple unit that runs to completion and then goes inactive, so
  # sv-watch reports it as "down" every sweep — the only remaining false
  # positive after ModemManager. The box is headless and has no interactive
  # man usage that needs an up-to-date index at runtime, so the unit is
  # disabled rather than left as idle noise. The index can be regenerated
  # by hand with `mandb` if it is ever wanted.
  systemd.services.mandb.enable = lib.mkForce false;

  # ── sshd posture — OPEN ON THE LAN, and deliberately so ────────────────────
  # CORRECTED 2026-10-13: this used to say "modules/core/sshd.nix restricts
  # ssh to tailscale0 only", which stopped being true when core grew
  # `openFirewall = true` (commits 80af767 / dea0dbd). Core now opens :22 on
  # EVERY interface for BOTH hosts, so this line is redundant — core already
  # turns sshd on; it is kept because it states the host's own intent.
  # The LAN path is being kept on purpose, not tightened away: there is no
  # tailscale auth key on this node, so if /var/lib/tailscale is ever lost or
  # restored after tailscaled first starts, the node re-registers under a NEW
  # IP and a tailnet-only policy would leave no path in at all. It has now
  # survived cold boots. If this is ever revisited the knob is openFirewall in
  # modules/core/sshd.nix, not anything here.
  services.openssh.enable = true;

  # ── sudo posture ───────────────────────────────────────────────────────────
  # Passwordless sudo for wheel, so `sudo -n` works everywhere: the backup
  # script, every sv op, and every agent session on a box with nobody at a
  # keyboard.
  #
  # CORRECTED 2026-10-13: this comment claimed "core/security.nix sets true
  # for t480s". It does not — modules/core/security.nix sets
  # wheelNeedsPassword = false for every host, with no mkDefault, so this line
  # is belt-and-braces rather than an override. Kept because it states the
  # intent for a headless box where a password prompt is a lockout, and because
  # dropping it would silently depend on core never changing its mind.
  security.sudo.wheelNeedsPassword = lib.mkForce false;

  # ── blocky upstreams ───────────────────────────────────────────────────────
  # blocky.nix is shared with the laptop and carries its two work resolvers
  # (192.168.44.187/.188), which this box has never had and cannot reach. They
  # would lose the race here, but there is no reason to ship them at all — this
  # host races the encrypted pair alone, exactly as /etc/blocky/config.yml does
  # on the Void install.
  services.blocky.settings.upstreams.groups.default = lib.mkForce [
    "tcp-tls:cbf8aa.dns.nextdns.io:853"
    "quic:2b44bd66.d.adguard-dns.com"
  ];

  # ── blocky: reachable from the tailnet, plain DNS only ──────────────────────
  # His word, 2026-10-21: "i just want to set the tailscale ip as dns / inside
  # tailsclae / cuz on phone i must allow tailsclae dns", then "i will not use
  # dot / just plain tailscaleip as dns". So: no DoT, no 853, no cert, no
  # Private DNS — the phone points at 100.88.29.31 and the query travels inside
  # the tailnet.
  #
  # Why 0.0.0.0 rather than the tailnet address alone: core/network.nix points
  # /etc/resolv.conf at 127.0.0.1, because blocky IS this box's resolver, so
  # binding only the tailnet IP would take DNS away from the box itself. All
  # interfaces keeps loopback answering; what makes it tailnet-only is the
  # firewall rule below, which never opens the LAN.
  #
  # Measured before this change: dig @100.88.29.31 -> "connection refused"
  # while dig @127.0.0.1 -> NOERROR — ports.dns was "127.0.0.1:53" and
  # nothing else. This file is host-scoped on purpose so grandpa keeps its
  # loopback-only resolver and needs no rebuild of its own.
  services.blocky.settings.ports.dns = lib.mkForce "0.0.0.0:53";

  # tailscale0 only, the pattern home-assistant.nix (8123) and services.nix
  # (8877) already use. BOTH transports: tcp is what a resolver falls back to
  # when the answer is too big for one UDP packet — any large or DNSSEC-signed
  # response — so opening udp alone breaks the big answers and only then.
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [53];
  networking.firewall.interfaces."tailscale0".allowedUDPPorts = [53];
}
