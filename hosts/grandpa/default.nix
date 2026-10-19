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
# that part is a decision, not a placeholder. Which services it runs is still the
# open question: it runs the core set only (sshd, tailscaled, blocky,
# systemd-networkd, systemd-timesyncd, zram), and nothing service-specific
# (docker, backup, WhatsApp, extra blocky upstreams beyond the shared pair) is
# pre-wired. Add it here when a service is actually chosen.
{...}: {
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
    # THE MD SERVICE (2026-10-18, removed same day on his "u can rm the md one
    # idont care that much"): mkdocs-material rendered ~/projects/wiki, nginx
    # served it, a timer pulled git. wiki.nix kept on disk with its rationale;
    # the git repo itself is untouched — only the renderer goes.
    # ./wiki.nix
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
  # README), and the git host role moves here as the native NixOS service
  # rather than a compose dir: this box has no docker, and the whole point of
  # grandpa is that nixos-rebuild brings it back. GitHub stays the remote; this
  # is the local web UI + LAN clone endpoint.
  #
  # Port 3000 is free again (gitea held it until today); git-ssh :2222 left
  # with gitea too.
  services.forgejo = {
    enable = true;
    settings = {
      server = {
        # Tailnet canonical (his pick 2026-10-18): he browses forgejo as
        # 100.106.116.60:3000, and the old LAN pin threw Forgejo's "you are
        # viewing through a different URL" banner on every page. Tailnet IP
        # answers from every box on the network, LAN included.
        DOMAIN = "100.106.116.60";
        ROOT_URL = "http://100.106.116.60:3000/";
        HTTP_PORT = 3000;
        LANDING_PAGE = "explore";
      };
      service = {
        # Same posture gitea had on day one: signups open so the FIRST account
        # becomes admin, then close it — his README rule: "create, then close
        # it". Flip DISABLE_REGISTRATION to true right after first login.
        DISABLE_REGISTRATION = false;
        REQUIRE_SIGNIN_VIEW = false;
      };
      repository.DEFAULT_BRANCH = "main";
    };
    # SQLite: 6 GiB box, a handful of repos — no postgres, no redis.
    database.type = "sqlite3";
    stateDir = "/var/lib/forgejo";
  };

  # The module has no openFirewall (checked 2026-10-18 in nixpkgs 6510408), and
  # modules/core/network.nix turns the firewall on for every host — so without
  # this line forgejo listens but nobody can reach it. Verified live: active +
  # LISTEN :3000 with a curl from the thinkcentre still timing out (000/exit 28)
  # until the port was allowed. LAN-only box, plain http, same as gitea was.
  networking.firewall.allowedTCPPorts = [ 3000 ];
}
