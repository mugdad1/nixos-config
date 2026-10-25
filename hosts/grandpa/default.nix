# Grandpa's custom desktop — Intel i3-2120 (Sandy Bridge, 2 cores / 4 threads),
# 6 GiB RAM, a GeForce GT 210, a single 298 GiB spinning HDD, UEFI. Headless: it
# is a server / CLI box, not a workstation, so it imports modules/core only and
# never modules/desktop.
#
# THE GT 210 (why there is no driver line anywhere in this host): it is a 2009
# Tesla-era card (GT218) whose only NVIDIA driver was the 340.x legacy branch,
# and that branch no longer exists in nixpkgs — nvidiaLegacy340/390 are gone
# (checked against this flake's nixpkgs 2026-10-16). It does not matter: a
# headless box wants no GPU driver at all, so nouveau/nvidia are blacklisted and
# the card sits idle. If a screen is ever wanted, the fix is a cheap GT 710/1030,
# never the dead 340 blob.
#
# ON THE HARDWARE SINCE 2026-10-16 — the placeholder warning this header used to
# carry is gone, because install day happened: system profiles system-1 (16:08)
# through system-4 (20:14) that day, and ./hardware-configuration.nix is the real
# generated file (root /dev/sda2 via UUID 06ff4257-…, ESP /dev/sda1 via UUID
# 0B56-3DF8), not a placeholder. Disk: one 298 GiB HDD — sda1 1 GiB vfat at
# /boot, sda2 297 GiB ext4 at /. Boot: systemd-boot 261.3 on UEFI 2.31 (AMI),
# Secure Boot off. Wired NIC enp3s0 (74:d4:35:23:e6:d5) at 192.168.8.254/24 by
# the type-matched networkd rule in ./overrides.nix; tailnet 100.106.116.60.
# Verified 2026-10-17: 0 failed units, booted from the current flake.lock
# (nixpkgs 6510408, 2026-10-10).
#
# A "Display" LINE THAT IS NOT A DISPLAY — read this before chasing it: `fastfetch`
# here reports `Display (Unknown-1): 1024x768` and lists the GT 210 as a "GPU".
# Both come from the firmware framebuffer, not from any monitor. At boot the UEFI
# firmware lights the card and hands the kernel a linear framebuffer; the builtin
# simpledrm driver binds it (card0's driver is simple-framebuffer), and its one
# connector — literally named Unknown-1 — always reports connected/enabled at the
# firmware's default mode with no EDID, which is also why the physical size is a
# guess. fastfetch then follows that card up to PCI 0000:01:00.0 and names the GPU
# behind it. Nothing is attached and nothing is wrong.
#
# WHAT IT IS (his word, 2026-10-16): a **lightweight server** — headless, and
# that part is a decision, not a placeholder. It runs the core set (sshd,
# tailscaled, blocky, systemd-networkd, systemd-timesyncd, zram) plus what he
# has chosen since: Forgejo + gitea-mirror, and since 2026-10-19 docker as the
# engine under them (see the block below).
#
# SINCE 2026-10-22 it is also the box the fleet's services live on: the
# ThinkCentre is being returned to its owner, so Home Assistant, opencode-serve,
# study and filen-sync all moved here ("move the services from thinkcentre to
# grandpa … nix work only"). Three things that travelled with them have since
# been removed at his order: the Telegram bot together with the entire alert
# path it carried (smartd's mailer, the notify-telegram@ OnFailure= hook, the
# `telegram/*` secrets, "no more telegram and whatsapp", 2026-10-23, row 207),
# WhatsApp (bridge/watcher/313 timer, "no more whatsapp", same day, the project
# itself already deleted from disk) and sv-watch (same day). opencode-serve is
# the one component of that stack he chose to KEEP when asked — it is what
# answers :13420 after a reboot, bot or no bot. The import list below names
# what remains;
# each file explains what it carries. Still absent by choice: no backup (the /srv/backup
# disk is physical and stays with the ThinkCentre — see hosts/thinkcentre/
# backup.nix), and adding anything further is his call, not an improvement to
# file.
{
  pkgs,
  username,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/core
    # Headless: deliberately NOT ../../modules/desktop — core stopped dragging
    # the desktop in on 2026-10-12.

    # MUST BE LISTED EXPLICITLY. mkHost passes ./hosts/${host} as its module, and
    # a NixOS module that is a *directory* resolves to that directory's
    # default.nix ONLY — it does not sweep up sibling .nix files. A previous
    # host learned this the expensive way; git history has the warning.
    ./packages.nix
    ./overrides.nix

    # ── THE SERVICE LAYER, MOVED FROM hosts/thinkcentre 2026-10-22 ──────────
    # His order: "move the services from thinkcentre to grandpa … nix work
    # only". The ThinkCentre went back to its owner, so what it was the server
    # of lives here now. Each file carries its own rationale for the move; the
    # old host's copies are in git history.
    #   home-assistant.nix  the AC hub (HA + ESPHome + avahi + :8123) — the
    #                       one thing that cannot simply be reinstalled, since
    #                       its state is paired hardware
    #   services.nix        opencode-serve, study, filen-sync,
    #                       journald persistent
    #   secrets.nix         the two host-local TEMPLATES those units read (filen,
    #                       searx); the secret values themselves stay fleet-scope
    #                       in modules/core/monitoring.nix
    #   searxng.nix         the house search engine — declared NIX-NATIVE the
    #                       same day ("Declare it inside grandpa") instead of
    #                       staying a ThinkCentre-only compose project that
    #                       would have died with the box
    ./home-assistant.nix
    ./services.nix
    ./secrets.nix
    ./searxng.nix
  ];

  # The ESP lives at /boot (systemd-boot writes there; NixOS's default is already
  # /boot, but keep it explicit so a regenerated hardware-configuration.nix that
  # mounts the ESP elsewhere cannot silently write to a non-ESP directory and
  # boot the old loader — a failure documented in git history).
  boot.loader.efi.efiSysMountPoint = "/boot";

  # No display is ever attached. Blacklist the whole NVIDIA stack so neither
  # nouveau nor the blob claims the text console or costs a few hundred MB of
  # 6 GiB for nothing; the console still comes up on efifb.
  boot.blacklistedKernelModules = [
    "nouveau"
    "nvidia"
    "nvidia_drm"
    "nvidiafb"
  ];

  # Time: a literal-IPv4 NTP list, so the clock can be fixed even when DNS is
  # down. The full deadlock reasoning is in git history. Nothing here assumes
  # the CMOS cell is missing — it is simply never worse than the pool hostname.
  services.timesyncd.enable = true;
  networking.timeServers = [
    "162.159.200.1" # time.cloudflare.com
    "216.239.35.0" # time.google.com
    "216.239.35.4"
  ];

  # zram, not a swap partition: the disk is a slow spinning HDD and RAM is only
  # 6 GiB, so compressed RAM swap buys far more than a swap file on the
  # platter. Same shape as the previous server.
  zramSwap = {
    enable = true;
    algorithm = "lz4";
    memoryPercent = 35;
    priority = 100;
  };

  # hostname comes from core/network.nix: networking.hostName = host = "grandpa".

  # ─── THE FIRST REAL SERVICE: Forgejo (2026-10-18) ────────────────────────
  # His order: "rm gitea and it mirror cuz its bad ... u can use forjero" —
  # gitea + gitea-mirror came off the thinkcentre (see its server-index and
  # README), and the git host role moves here. It was declared native at first
  # because this box had no docker; a day later he dockerized it (below). GitHub
  # stays the remote; this is the local web UI + LAN clone endpoint.
  #
  # Port 3000 is free again (gitea held it until today); git-ssh :2222 left
  # with gitea too.
  #
  # MOVED TO DOCKER same day (2026-10-19, his "i want forgero and mirror in
  # docker now") — compose file at ~/projects/servers/forgejo/, data still
  # /var/lib/forgejo bind-mounted at the same path. COMMENT OUT, DON'T DELETE:
  # this block is the record of the settings the container now carries in its
  # own compose file (tailnet ROOT_URL, signups open, sqlite, :3000).
  # services.forgejo = {
  #   enable = true;
  #   settings = {
  #     server = {
  #       DOMAIN = "100.106.116.60";
  #       ROOT_URL = "http://100.106.116.60:3000/";
  #       HTTP_PORT = 3000;
  #       LANDING_PAGE = "explore";
  #     };
  #     service = {
  #       DISABLE_REGISTRATION = false;
  #       REQUIRE_SIGNIN_VIEW = false;
  #     };
  #     repository.DEFAULT_BRANCH = "main";
  #   };
  #   database.type = "sqlite3";
  #   stateDir = "/var/lib/forgejo";
  # };

  # Docker engine, kept 2026-10-25: the seven compose projects and their data
  # were removed at his order that day ("rm data and config" → "a"), and the
  # `docker-stack` launcher went with them — nothing sweeps ~/projects/servers
  # any more, so no container comes back at boot or on a switch. The engine is
  # left installed deliberately: it was never on the removal list he confirmed,
  # and taking the runtime out is a separate decision from taking the stack out.
  virtualisation.docker.enable = true;
  users.users.${username}.extraGroups = ["docker"];
}
