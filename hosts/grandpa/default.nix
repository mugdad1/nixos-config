# Grandpa's custom desktop — Intel i3-2120 (Sandy Bridge, 2 cores / 4 threads),
# 6 GiB RAM, a single 298 GiB spinning HDD, UEFI, NO DISCRETE GPU. Headless: it
# is a server / CLI box, not a workstation, so it imports modules/core only and
# never modules/desktop.
#
# THE GT 210 WAS PULLED 2026-10-25 — physically removed, and that is the whole
# story of this paragraph. It could not be silenced: a 2-pin DC fan on the
# card's header has no PWM line, and with no driver bound there was no register
# to write, so no OS on earth could have stopped it — the answer to "can i from
# nixos" was no, and unplugging was the only lever. Nothing is connected to the
# card and nothing used it: its only NVIDIA driver, the nvidiaLegacy340 branch,
# no longer exists in nixpkgs (checked 2026-10-16), so it had never rendered a
# single frame here.
#
# WHAT CHANGED, all measured after that day's reboot: no 0x10de device on the
# bus any more (root port 0000:00:1c.0 logs "retraining failed" — an empty
# slot, not a fault); the display role moved to the CPU's own Intel HD 2000,
# i915 binds 0000:00:02.0, and /dev/dri gains card1 + renderD128. A render node
# did not exist before and is free now if anything ever wants one. /dev/fb0 is
# gone with the card (see the display note below).
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
# THERE IS NO DISPLAY LINE TO CHASE ANY MORE. The old note here spent nine lines
# explaining why `fastfetch` reported `Display (Unknown-1): 1024x768` with no
# monitor attached — that was the UEFI firmware's linear framebuffer, bound by
# the builtin simpledrm driver, gone with the card on 2026-10-25. Since then:
# no /dev/fb0, no card0, and one stale by-path symlink pointing at the old
# firmware framebuffer left dangling in /dev/dri/by-path/. What remains is
# i915's connector `card1-VGA-1` reporting `disconnected`, which is simply
# true. A headless box with no discrete GPU has no phantom display to
# apologise for.
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

    # The second drive (sdb): 100G /srv/backup + 376G /srv/data, and the daily
    # hardlinked-snapshot unit that mirrors everything irreplaceable onto it.
    # 2026-10-26. Listed here for exactly the reason above — it is a sibling
    # file and would otherwise be silently ignored. Header in that file explains
    # why this drive is a BACKUP target and not a performance one.
    ./backup.nix

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

  # boot.blacklistedKernelModules listed nouveau / nvidia / nvidia_drm /
  # nvidiafb until 2026-10-25, to keep the NVIDIA stack from claiming the text
  # console on a box that would never use it. Deleted WITH the card, not after:
  # four lines of config matching zero devices on the bus is noise, and the
  # next person reading this host would reasonably assume an NVIDIA card was
  # still fitted. (The old comment also credited `efifb` for the console — it
  # was simpledrm, and it went with the card.) If a GPU ever comes back,
  # blacklisting it again is one block, not one to preserve.

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

  # ── THE SERVICE INDEX PAGE ────────────────────────────────────────────────
  #
  # nginx, :80 on tailscale0, serving lib/server-index.nix. RESTORED
  # 2026-10-25 after being removed the same afternoon in the strip commit
  # (0d08aca), where the reasoning was "the index has no services left to
  # list". He hit the box in a browser, got ERR_CONNECTION_REFUSED and asked
  # for it back — *"bring it back nginx i want the stuff how can i access to my
  # services"*. The reasoning was right about the page and wrong about the
  # consequence: with no listener on :80 the box does not look sparse, it looks
  # DOWN, and there is no other place that tells him what is running. A short
  # honest index beats a silent port. He was offered caddy and declined it
  # explicitly ("i dont want caddy") — this box's web server has been nginx
  # since 2026-10-19 and stays that way.
  #
  # The page itself was rewritten in the same pass: the rows for the seven
  # removed containers and glances are commented out in lib/server-index.nix,
  # so what answers is study, home assistant and searxng, with blocky,
  # tailscaled, opencode-serve and filen-sync described in prose below the
  # table (they are services without a page — a row would be a dead link).
  #
  # DECLARATIVE ON PURPOSE, unlike the old `push-server-index` rsync: the page
  # is the store path below, so the index cannot drift from the service list —
  # a rebuild IS the publish. `push-server-index` stays on disk as the record
  # of how it used to ship (see modules/home/apps/homepage.nix).
  #
  # :80 on tailscale0 only — every link the page emits is a tailnet address,
  # so LAN exposure buys nothing (the standing "always Tailscale IPs" rule).
  services.nginx = {
    enable = true;
    virtualHosts.index = {
      default = true;
      root = pkgs.writeTextDir "index.html" (import ../../lib/server-index.nix {});
      extraConfig = "index index.html;";
    };
  };
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [80];
}
