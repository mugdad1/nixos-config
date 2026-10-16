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
    ./backup.nix
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

  # Docker engine only. The 12 compose projects live in ~/Projects/servers and
  # are deliberately OS-agnostic — they are restored by hand, not re-declared
  # here. Nothing in this flake starts a container on its own. The launcher is
  # systemd.services.docker-stack in ./services.nix; ./overrides.nix carries
  # the network posture.
  virtualisation.docker.enable = true;
  users.users.${username}.extraGroups = ["docker"];

  # /srv/backup — the ADATA SP550, **ext4**, labelled "backup".
  #
  # MOVED HERE from hardware-configuration.nix on 2026-10-13. It used to live in
  # that file, but nixos-generate-config only reports filesystems that are in the
  # LIVE fstab — and this one never is, because it is exactly the entry that
  # makes it. So regenerating on the box silently dropped it, backup-daily started
  # failing every night with "/srv/backup is not mounted", and sda sat unmounted.
  # Declaring it on the host means it survives every future regeneration.
  #
  # REFORMATTED btrfs -> ext4 on 2026-10-13 on his order ("rm the backup
  # completely so we start clean"), wiping the 11 Void-era snapshots after
  # checking they held only content already restored to ~/Projects by hand
  # (every home/void was ~600M of .local + Projects). backup-run.sh is plain
  # rsync with --link-dest — hardlinks and nothing else — so the filesystem
  # change costs the script nothing; there is no btrfs-specific call in it.
  #
  # nofail: a missing disk skips the mount instead of hanging boot — same as the
  # donor's fstab. Do NOT also port a backup-mount service: two mounters racing
  # the same UUID is how the donor double-mounted it.
  #
  # If the disk is ever reformatted again, mkfs regenerates the UUID, so this
  # line has to follow it — `blkid /dev/sda1` then update the value below.
  # REFORMATTED 2026-10-15 on his order ("erase fully / recreate it just ext4"):
  # the disk had lost its GPT while the ext4 superblock survived, so it held a
  # readable filesystem the kernel could not address. Wiped and rebuilt as one
  # GPT partition + mkfs.ext4 -L backup. New UUID 259b0fb9…; the old
  # 2ad7d4fc… is gone and this line must follow it or boot times out on a
  # device that no longer exists (the exact failure mode above). Before the
  # wipe, its only unmirrored content — ~/projects/servers, 13 compose
  # projects — was copied to the live path, since the box's own restore had
  # left it absent and this disk was its last copy.
  fileSystems."/srv/backup" = {
    device = "/dev/disk/by-uuid/259b0fb9-b9d1-40fd-a68c-9f6ebdd60a3c";
    fsType = "ext4";
    options = ["defaults" "nofail"];
  };

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
