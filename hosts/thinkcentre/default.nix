# Lenovo ThinkCentre M900x (machine type 10LY, board 30D0, i7-6700T / Skylake,
# 11 GiB RAM). Headless server: 17 Docker containers, blocky on 127.0.0.1:53,
# tailscale, sshd. It used to run Void + runit; this replaces all of it.
#
# The machine reports chassis_type = 3 ("Desktop") in SMBIOS, but it is the
# 1-litre Tiny chassis with no display attached (dmesg: "Cannot find any crtc
# or sizes"). Nothing here assumes a screen.
#
# SPLIT 2026-10-14 ("orgnize nixos-config it is a mess"): this file used to be
# ~313 lines. It now keeps only identity + boot + storage + time; the
# systemPackages list moved to ./packages.nix and every `lib.mkForce` (and the
# networkd posture) to ./overrides.nix. backup.nix / services.nix / secrets.nix
# were already siblings.
{username, ...}: {
  imports = [
    # REGENERATED ON THE BOX 2026-10-13 (commit 1c7883d) with
    # `nixos-generate-config --show-hardware-config`. It now describes the real
    # layout — root ext4 93ea1189… on sdb2, ESP 6D92-B60A at /boot, sdb3 swap —
    # instead of the hand-built Void/donor layout it used to carry (root btrfs
    # 839da341…, ESP 646D-44FB at /boot/efi), which would have mounted nothing
    # on a reinstall and kernel-panicked.
    # /srv/backup is deliberately NOT in that file — see the fileSystems entry
    # further down for why it cannot survive regeneration there.
    # Regenerate with nixos-generate-config at install time and diff.
    ./hardware-configuration.nix
    ../../modules/core
    # Deliberately NOT ../../modules/desktop — headless. Since 2026-10-12 core
    # no longer drags the desktop in, so this omission is all it takes.

    # MUST BE LISTED EXPLICITLY. mkHost passes `./hosts/${host}` as its module,
    # and a NixOS module that is a *directory* resolves to that directory's
    # default.nix ONLY — it does not sweep up sibling .nix files. So creating
    # backup.nix / services.nix / packages.nix / overrides.nix in here changes
    # nothing until they are named. (modules/ dirs work the other way — see
    # scanPaths in lib/default.nix — which is exactly why the rule is easy to
    # get wrong.)
    # This cost a full build cycle: the closure compiled clean, `nixos-rebuild`
    # would have reported success, and the box would have come up with no
    # 03:17 backup, no sv-watch, no Telegram bot and no study site. Verified by
    # probing `config.systemd.services.<name>` for each unit, which is the only
    # way to catch it — a green build proves nothing about files that were
    # never imported.
    # ./backup.nix — DISABLED 2026-10-16: its whole target /srv/backup left the
    # machine (ADATA 240 GB → grandpa, his order "there is no /srv/backup
    # anymore"), so the 03:17 timer could only fail nightly. Re-enable only
    # together with a mount point for it. Everything else stays:
    # ./backup.nix
    ./services.nix
    ./packages.nix
    ./overrides.nix
    # sops-nix wiring. Host-specific on purpose: the secrets FILE is
    # secrets/thinkcentre.sops.yaml, so importing this into modules/core would
    # hand the laptop a server secret path. Listed explicitly for the reason
    # written above — a directory module does not sweep up its siblings.
    ./secrets.nix
  ];

  # NixOS's default /boot, which is where this box actually mounts the ESP
  # (/dev/disk/by-uuid/6D92-B60A on sdb1 — matches fstab). The donor Void
  # layout put it at /boot/efi; if this value ever drifts from the fstab entry,
  # systemd-boot writes to a directory that is not the ESP and the machine
  # silently boots whatever was there before ("nothing happened").
  boot.loader.efi.efiSysMountPoint = "/boot";

  # Chip sensors (his "Sensors detect" 2026-10-16): `sensors-detect --auto`
  # found coretemp (CPU package/cores) and nct6683 (Nuvoton Super-I/O fan/
  # volt/temp header) and modprobe'd them — transient, gone on every reboot
  # unless named here. Declared so `sensors` works from a cold boot without
  # re-running detection; a module that finds no hardware binds to nothing,
  # so this is harmless on hosts without the chip (grandpa carries its own).
  boot.kernelModules = [
    "coretemp"
    "nct6683"
  ];

  # Docker engine only. The 12 compose projects live in ~/Projects/servers and
  # are deliberately OS-agnostic — they are restored by hand, not re-declared
  # here. Nothing in this flake starts a container on its own. The launcher is
  # systemd.services.docker-stack in ./services.nix; ./overrides.nix carries
  # the network posture.
  virtualisation.docker.enable = true;
  users.users.${username}.extraGroups = ["docker"];

  # /srv/backup — GONE as of 2026-10-16 on his order ("the thinkcentre is sda
  # 512 only, there is no /srv/backup anymore"). The ADATA SP550 240 GB moved
  # physically to grandpa, and this box's boot was observed blocking on the
  # missing device — "nixos can't launch till i plug the 240gb" — despite the
  # entry carrying nofail, so the mount stanza is removed outright rather than
  # left to fail. This host now has exactly one disk: the 512 GB WAVE.
  #
  # History (kept short): declared here (not in hardware-configuration.nix)
  # because nixos-generate-config only reports live-fstab filesystems; ext4,
  # label "backup", last wipe 2026-10-15 → UUID 259b0fb9… (now physically in
  # grandpa, UUID irrelevant here). The nightly backup service went with it —
  # see the ./backup.nix import below. Snapshots live ON that disk in
  # /srv/backup/snapshots and survive the move.

  # Time. The CMOS battery was removed 2026-10-04, so every AC-cut boot starts
  # at 2015-01-01 until NTP steps it (measured 10–20 s typical, >120 s once).
  # timesyncd is his recorded call ("u dont need chrony in nixos — there is an
  # ntp"). If the clock gate in ./backup.nix ever proves insufficient, the
  # alternative is services.chrony: its `makestep 1.0 3` steps an arbitrarily
  # large offset and `chronyc makestep` is a manual escape hatch timesyncd has
  # no equivalent for. Exactly one of the two may be enabled.
  services.timesyncd.enable = true;

  # NTP addressed by literal IPv4, NEVER by the pool hostname — the Void-era fix
  # (decisions row 24) ported: chrony there carried `server 162.159.200.1 iburst`
  # plus 216.239.35.0/.4 for exactly this reason, and this is the half timesyncd
  # was missing. With the cell gone the box boots at 2015-01-01, and at that clock
  # blocky's DoT/DoQ upstreams fail TLS validation, so DNS is dead too; a pool
  # hostname then has to be resolved by the resolver that is down, the clock can
  # never be fixed, and DNS never comes back. An IP needs no DNS, so NTP breaks
  # the deadlock from its own end. All three measured reachable here 2026-10-16.
  networking.timeServers = [
    "162.159.200.1" # time.cloudflare.com
    "216.239.35.0" # time.google.com
    "216.239.35.4"
  ];

  # Replaces Void's zramen runit unit (4 GiB, lz4, prio 100). zramSwap is
  # zram-generator underneath: create at boot, tear down at shutdown.
  zramSwap = {
    enable = true;
    algorithm = "lz4";
    memoryPercent = 35;
    priority = 100;
  };

  # hostname comes from core/network.nix: networking.hostName = host = "thinkcentre".
}
