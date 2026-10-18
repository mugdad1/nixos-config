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
    # `nixos-generate-config --show-hardware-config`, and its UUIDs have moved
    # twice since as the disks were replaced/reformatted. **Re-checked against
    # the committed file 2026-10-18:** root ext4 `edd8dd39…`, ESP `876C-A703`
    # at /boot, **`swapDevices = [ ]`** — this comment said "root 93ea1189… on
    # sdb2, ESP 6D92-B60A, sdb3 swap" until today, which is the pre-`80c4652`
    # disk, and a comment that contradicts the file it sits above is worse than
    # no comment. The real file is the truth; read it, do not read this.
    # (The earlier hand-built Void/donor layout — root btrfs 839da341…, ESP
    # 646D-44FB at /boot/efi — would have mounted nothing on a reinstall.)
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
    # ./backup.nix — RE-ENABLED the same evening (2026-10-16): the disk came
    # back as /srv/backup ("use it as backup"), so the 03:17 timer has a real
    # target again. It had been disabled earlier today when the disk was
    # declared gone for grandpa (row 106). Mount, timer and the disk check in
    # checkup.sh (fstab-gated) all move together or not at all.
    ./backup.nix
    ./services.nix
    ./home-assistant.nix
    ./packages.nix
    ./overrides.nix
    # sops-nix wiring. Host-specific on purpose: the secrets FILE is
    # secrets/thinkcentre.sops.yaml, so importing this into modules/core would
    # hand the laptop a server secret path. Listed explicitly for the reason
    # written above — a directory module does not sweep up its siblings.
    ./secrets.nix
  ];

  # NixOS's default /boot, which is where this box actually mounts the ESP
  # (/dev/disk/by-uuid/876C-A703 on sda1 — matches the generated file; this
  # line said 6D92-B60A until 2026-10-18, which was the disk before 80c4652).
  # The donor Void
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
  # dialout: /dev/ttyUSB0 for the ESP8266 flashing (AC project, 2026-10-17) —
  # without it the CP210x serial port is root-only and every upload needs sudo.
  users.users.${username}.extraGroups = ["docker" "dialout"];

  # /srv/backup — BACK, the same day it was buried (2026-10-16 evening, his
  # order: *"use it as backup after formatting it to ext4"*). The disk never
  # went to grandpa: the ADATA SP550 240 GB was wiped in the afternoon
  # (wipefs + whole-disk blkdiscard, on his order "erease the 240 fuly"), then
  # reformatted GPT + one ext4 partition, label "backup", NEW UUID below —
  # found by SERIAL 2G3020002085, never by sdX (names swap across reboots:
  # sdb yesterday, sda today).
  #
  # THE LESSON OF THIS ENTRY (row 106): nofail alone did NOT let the box boot
  # when the disk was missing — systemd sat on the absent .device job and the
  # observed result was "nixos can't launch till i plug the 240gb". The
  # missing half is x-systemd.device-timeout: the device wait gives up after
  # 10 s, nofail skips the mount, boot continues. A missing backup disk is
  # now a 10-second delay, never a dead box.
  fileSystems."/srv/backup" = {
    device = "/dev/disk/by-uuid/6fd6f2eb-ebbf-4921-bf4d-befabf226626";
    fsType = "ext4";
    options = ["defaults" "nofail" "x-systemd.device-timeout=10s"];
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

  # CPU scheduler — sched_ext, added 2026-10-18 with the laptop (see
  # modules/desktop/services.nix for the argument that produced it).
  #
  # EEVDF stays the kernel's default; this loads a BPF scheduler over it at
  # runtime. Kernel here is 7.2.9, so the module's >= 6.12 requirement and its
  # ConditionPathIsDirectory=/sys/kernel/sched_ext both hold (verified live:
  # the directory exists, state=disabled before this).
  #
  # scx_bpfland because it classifies tasks by voluntary context-switch rate and
  # prioritizes the interactive queue, which is the right bias on THIS box: 18
  # containers (blocky on :53, home-assistant, opencode, the Telegram bot) answer
  # latency-sensitive requests, while 03:17 backups, docker builds and the study
  # site are throughput work that should yield. The 2.80 GHz i7-6700T is one
  # homogeneous 4c/8t Skylake cluster, so nothing here needs a hybrid-aware
  # scheduler.
  #
  # Host-specific, deliberately not modules/core: grandpa is a 2-core/4-thread
  # Sandy Bridge that idles at load ~0.0 — a BPF scheduler there buys nothing and
  # adds a moving part to the box he least wants to touch. The laptop carries its
  # own copy in modules/desktop/services.nix for a different reason (someone is
  # at the keyboard).
  #
  # Escape hatch, same as everywhere: `sudo systemctl stop scx` returns the box
  # to EEVDF immediately, no reboot, no rebuild.
  services.scx = {
    enable = true;
    scheduler = "scx_bpfland";
  };

  # hostname comes from core/network.nix: networking.hostName = host = "thinkcentre".
}
