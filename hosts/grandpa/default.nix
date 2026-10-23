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
# `telegram/*` secrets, "no more telegram and whatsapp", 2026-10-23, row 206),
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
}: let
  dockerStack = pkgs.writeShellApplication {
    name = "docker-stack";
    runtimeInputs = with pkgs; [docker coreutils gnugrep];
    # Same launcher thinkcentre uses — sweeps ~/projects/servers.
    text = builtins.readFile ../../scripts/thinkcentre/docker-stack.sh;
  };
in {
  imports = [
    ./hardware-configuration.nix
    ../../modules/core
    # Headless: deliberately NOT ../../modules/desktop — the same omission that
    # makes thinkcentre headless, since core stopped dragging the desktop in on
    # 2026-10-12.

    # MUST BE LISTED EXPLICITLY. mkHost passes ./hosts/${host} as its module, and
    # a NixOS module that is a *directory* resolves to that directory's
    # default.nix ONLY — it does not sweep up sibling .nix files. hosts/thinkcentre
    # learned this the expensive way (see the long warning in its default.nix).
    ./packages.nix
    ./overrides.nix
    # GLANCES (2026-10-19, his "can we have glances for grandpa") — NixOS-native
    # service on :61208, unlike thinkcentre's docker container. See glances.nix.
    ./glances.nix

    # ── THE SERVICE LAYER, MOVED FROM hosts/thinkcentre 2026-10-22 ──────────
    # His order: "move the services from thinkcentre to grandpa … nix work
    # only". The ThinkCentre is being returned to its owner, so what it was the
    # server of lives here now. Each file carries its own rationale for the
    # move; hosts/thinkcentre keeps its copies commented out as the record of
    # where this came from.
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

    # THE MD SERVICE (2026-10-18, removed same day on his "u can rm the md one
    # idont care that much"): mkdocs-material rendered ~/projects/wiki, nginx
    # served it, a timer pulled git. wiki.nix kept on disk with its rationale;
    # the git repo itself is untouched — only the renderer goes.
    # ./wiki.nix
    # GITEA-MIRROR (2026-10-19, his "lets have gitea mirror … on grandpa"):
    # native systemd service, tailnet-only :4321, pushes GitHub → Forgejo.
    # MOVED TO DOCKER same day on his "i want forgero and mirror in docker
    # now" — the module stays for its rationale; the compose file lives at
    # ~/projects/servers/gitea-mirror/ and docker-stack sweeps it.
    # ./gitea-mirror.nix
  ];

  # The ESP lives at /boot (systemd-boot writes there; NixOS's default is already
  # /boot, but keep it explicit so a regenerated hardware-configuration.nix that
  # mounts the ESP elsewhere cannot silently write to a non-ESP directory and
  # boot the old loader — the exact failure documented in
  # hosts/thinkcentre/default.nix).
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

  # Time, same posture as thinkcentre: a literal-IPv4 NTP list, so the clock can
  # be fixed even when DNS is down (the full deadlock reasoning lives in
  # hosts/thinkcentre/default.nix). Nothing here assumes the CMOS cell is missing
  # — it is simply never worse than the pool hostname.
  services.timesyncd.enable = true;
  networking.timeServers = [
    "162.159.200.1" # time.cloudflare.com
    "216.239.35.0" # time.google.com
    "216.239.35.4"
  ];

  # zram, not a swap partition: the disk is a slow spinning HDD and RAM is only
  # 6 GiB, so compressed RAM swap buys far more than a swap file on the
  # platter. Same shape as thinkcentre.
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

  # Docker (2026-10-19, his "why dont u dockerize grandpa" → "ok do it i want
  # forgero and mirror in docker now") — grandpa's "no docker" posture (row
  # 103) was a moment, not a rule (his own correction the same week). Same
  # shape as thinkcentre: engine only in Nix, compose files under
  # ~/projects/servers are the source of truth for what runs, docker-stack is
  # the boot launcher so nixos-rebuild + reboot brings the stack back.
  virtualisation.docker.enable = true;
  users.users.${username}.extraGroups = ["docker"];

  systemd.services.docker-stack = {
    description = "Bring the compose stack under ~/projects/servers up";
    requires = ["docker.service"];
    # tailscaled too: gitea-mirror publishes 100.106.116.60:4321, and a bind to
    # an address that does not exist yet is a dead container at boot.
    after = ["docker.service" "tailscaled.service"];
    wants = ["tailscaled.service"];
    wantedBy = ["multi-user.target"];
    unitConfig.ConditionPathExists = "/home/${username}/projects/servers";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = username;
      WorkingDirectory = "/home/${username}/projects/servers";
      ExecStart = "${dockerStack}/bin/docker-stack";
      TimeoutStartSec = "15min"; # first boot pulls the images
    };
  };

  # The module has no openFirewall (checked 2026-10-18 in nixpkgs 6510408), and
  # modules/core/network.nix turns the firewall on for every host — so without
  # this line forgejo listens but nobody can reach it. Verified live: active +
  # LISTEN :3000 with a curl from the thinkcentre still timing out (000/exit 28)
  # until the port was allowed. LAN-only box, plain http, same as gitea was.
  # Still :3000 after the docker move — the compose file publishes 3000.
  networking.firewall.allowedTCPPorts = [3000];

  # ── THE SERVICE INDEX PAGE (2026-10-22) ────────────────────────────────────
  #
  # His order: "mv immich and vault and vik and index page chnage it to new
  # stuff also rebuild". The page itself was never the problem — it is
  # generated from lib/server-index.nix — but its HOST left with the
  # ThinkCentre (Caddy on :80). nginx was already this box's web server until
  # the md service was removed on 2026-10-19 (wiki.nix, still on disk, not
  # imported), so this is that role coming back for a static page.
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
