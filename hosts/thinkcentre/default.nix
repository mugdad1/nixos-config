# Lenovo ThinkCentre M900x (machine type 10LY, board 30D0, i7-6700T / Skylake,
# 11 GiB RAM). Headless server: 17 Docker containers, blocky on 127.0.0.1:53,
# tailscale, sshd. It used to run Void + runit; this replaces all of it.
#
# The machine reports chassis_type = 3 ("Desktop") in SMBIOS, but it is the
# 1-litre Tiny chassis with no display attached (dmesg: "Cannot find any crtc
# or sizes"). Nothing here assumes a screen.
{
  pkgs,
  lib,
  username,
  ...
}: {
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
    # backup.nix / services.nix in here changes nothing until they are named.
    # This cost a full build cycle: the closure compiled clean, `nixos-rebuild`
    # would have reported success, and the box would have come up with no
    # 03:17 backup, no sv-watch, no Telegram bot and no study site. Verified by
    # probing `config.systemd.services.<name>` for each unit, which is the only
    # way to catch it — a green build proves nothing about files that were
    # never imported.
    ./backup.nix
    ./services.nix
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

  # Headless: no games, no Wine, hence no 32-bit Mesa. modules/core/hardware.nix
  # sets this plainly for the laptop, so it needs mkForce to undo.
  hardware.graphics.enable32Bit = lib.mkForce false;

  # No btrfs here — this box runs ext4, so the weekly scrub that
  # modules/core/system.nix enables (for the laptop, which IS btrfs) has no
  # filesystem to act on. Same mkForce pattern as enable32Bit above: the core
  # module enables it unconditionally, so the host has to force it off.
  #
  # Deliberately scoped to THIS host only. services.btrfs.autoScrub lives in
  # the shared modules/core, and commenting it out there would have silently
  # disabled scrubbing on the t480s, whose root is btrfs and needs it. An
  # override here leaves the laptop untouched.
  #
  # hardware-configuration.nix was REGENERATED on the box 2026-10-13 (see the
  # note above the imports). The stale donor/btrfs UUIDs are gone from it. It is
  # still never edited by hand here: the real UUIDs only exist on the box itself,
  # and hand-writing entries from the ThinkPad would ship wrong UUIDs and panic
  # at boot. Regenerate with nixos-generate-config and diff.
  #
  # Root is ext4, so the weekly scrub in modules/core/system.nix has no root
  # filesystem to act on — hence mkForce off, same override shape as
  # enable32Bit above. Scoped to THIS host: core enables it unconditionally, and
  # the t480s root IS btrfs and needs it. Commenting it out in core would have
  # silently disabled scrubbing on the laptop.
  #
  # OPEN ITEM CLOSED 2026-10-13: it asked whether /srv/backup should be scrubbed,
  # since a backup disk that silently rots is exactly where scrubbing matters.
  # Moot now — the disk is ext4, so btrfs scrub cannot touch it.
  #
  # Left in place because the t480s IS btrfs and needs the force-off here: the
  # shared module sets autoScrub.enable, and without this line it would try to
  # scrub a root that has no btrfs on this host. autoScrub.fileSystems evaluates
  # to ["/"] on the t480s but [] here, and nothing in this repo sets it — so
  # flipping enable without also naming the mount is a guess about what gets
  # scrubbed.
  services.btrfs.autoScrub.enable = lib.mkForce false;

  # Docker engine only. The 12 compose projects live in ~/Projects/servers and
  # are deliberately OS-agnostic — they are restored by hand, not re-declared
  # here. Nothing in this flake starts a container on its own.
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
  # completely so we start clean"), wiping the 11 Void-era snapshots. They held
  # the only surviving copy of that history and were checked for content first:
  # every home/void was ~600M of .local + Projects, all of which had already
  # been restored to ~/Projects by hand. Nothing unrecoverable was lost.
  # backup-run.sh is plain rsync with --link-dest, which needs hardlinks and
  # nothing else, so the change of filesystem costs the script nothing — no
  # btrfs-specific call exists in it.
  #
  # nofail: a missing disk skips the mount instead of hanging boot — same as the
  # donor's fstab. Do NOT also port a backup-mount service: two mounters racing
  # the same UUID is how the donor double-mounted it.
  #
  # If the disk is ever reformatted again, mkfs regenerates the UUID, so this
  # line has to follow it — `blkid /dev/sda1` then update the value below.
  fileSystems."/srv/backup" = {
    device = "/dev/disk/by-uuid/2ad7d4fc-9c1d-4baa-a3fd-b05bc0248f28";
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

  # sshd posture — OPEN ON THE LAN, and deliberately so.
  #
  # CORRECTED 2026-10-13: this comment used to say "modules/core/sshd.nix
  # restricts ssh to tailscale0 only", which stopped being true when core grew
  # `openFirewall = true` (commits 80af767 / dea0dbd). Core now opens :22 on
  # EVERY interface for BOTH hosts, so the services.openssh.enable below is
  # redundant — core already turns sshd on. The LAN path is being kept on
  # purpose, not tightened away, and the reason still holds: there is no
  # tailscale auth key on this node, so if /var/lib/tailscale is ever lost or
  # restored after tailscaled first starts, the node re-registers under a NEW
  # IP and a tailnet-only policy would leave no path in at all. It has now
  # survived cold boots, so if this is ever revisited the knob is
  # openFirewall in modules/core/sshd.nix, not anything here.
  services.openssh.enable = true;

  # Passwordless sudo for wheel, so `sudo -n` works everywhere: the backup
  # script, every sv op, and every agent session on a box with nobody at a
  # keyboard.
  #
  # CORRECTED 2026-10-13: the comment here claimed "core/security.nix sets true
  # for t480s". It does not — modules/core/security.nix sets
  # wheelNeedsPassword = false for every host, with no mkDefault, so this line
  # is belt-and-braces rather than an override. Kept because it states the
  # intent for a headless box where a password prompt is a lockout, and because
  # dropping it would silently depend on core never changing its mind.
  security.sudo.wheelNeedsPassword = lib.mkForce false;

  # Replaces Void's zramen runit unit (4 GiB, lz4, prio 100). zramSwap is
  # zram-generator underneath: create at boot, tear down at shutdown.
  zramSwap = {
    enable = true;
    algorithm = "lz4";
    memoryPercent = 35;
    priority = 100;
  };

  # blocky.nix is shared with the laptop and carries its two work resolvers
  # (192.168.44.187/.188), which this box has never had and cannot reach. They
  # would lose the race here, but there is no reason to ship them at all — this
  # host races the encrypted pair alone, exactly as /etc/blocky/config.yml does
  # on the Void install.
  services.blocky.settings.upstreams.groups.default = lib.mkForce [
    "tcp-tls:cbf8aa.dns.nextdns.io:853"
    "quic:2b44bd66.d.adguard-dns.com"
  ];

  environment.systemPackages = with pkgs; [
    tmux
    curl
    jq
    ripgrep
    vim
    rsync
git
    docker-compose
    # sv-watch's DNS sweep shells out to dig; not in NixOS's default path.
    # (pkgs.dnsutils provides dig — there is no pkgs.dig.)
    dnsutils

    # ── added 2026-10-12 on his word ─────────────────────────────────────────
    gh # gh api / gh repo view, same as on the laptop
    neovim # `nvim`; vim above stays as the bare-metal fallback
    # v2, not nixpkgs' stale v1 — modules/core/opencode.nix installs the
    # sst/opencode overlay, and thinkcentre imports core, so pkgs.opencode
    # here is already v2. Same reason hosts/thinkcentre/services.nix can
    # reference it as ocPath.
    opencode
    inxi # `mcli diag` shells out to it; without this that section prints
    # "inxi not installed" on a fresh box

    # mcli is repo-owned, not a nixpkgs package. It lives in scripts/mcli.sh
    # and is normally installed through home.packages (scripts/default.nix),
    # but thinkcentre is headless and deliberately does not import
    # modules/home — so it is wired in here directly instead, same
    # writeShellScriptBin shape that module uses.
    #
    # Already host-aware, so nothing needed changing for the server:
    # `mcli rebuild` runs `nh os switch ~/nixos-config`, and nh derives the
    # host from `hostname`, so it resolves to #thinkcentre here and #t480s on
    # the laptop with no branch in the script.
    (writeShellScriptBin "mcli" (builtins.readFile ../../scripts/mcli.sh))

    # ── server baseline, added 2026-10-13 ───────────────────────────────────
    # modules/home/cli.nix carries most of these on the laptop, but it is a
    # *home-manager* module (home.packages / programs.*) and this host is
    # headless, so it imports modules/core only and never sees that file. The
    # desktop half of cli.nix (brightnessctl, playerctl, wl-clipboard, udiskie,
    # poweralertd, pamixer, swappy…) is deliberately not mirrored here. This is
    # the headless-useful subset plus the box-admin tools it needs.

    git # THE missing one. This host is a git server — wiki, study and
    # nixos-config all live here and get pulled/pushed. Without this the repos
    # were unrunnable. It never came in because the laptop gets git from
    # home-manager (modules/home/git.nix → programs.git), not systemPackages.

    # ── pulled across from modules/home/cli.nix (headless-useful only) ──────
    eza # ls
    fd # find (fzf's backend)
    ripgrep-all # rga — grep inside pdfs/zips; useful for the study corpus
    file
    tree
    wget
    unzip
    zip
    p7zip
    ncdu # disk usage analyzer — this box has 3 filesystems to watch
    duf # df
    dust # du
    tealdeer # tldr
    glow # render markdown in the terminal (wiki / study notes)
    entr # run a command on file change
    killall
    strace
    socat
    binutils # objdump/strings/nm — for debugging containers & bins
    just # command runner

    # ── box admin: hardware + disks ─────────────────────────────────────────
    smartmontools # SMART health for the ADATA + root drives
    gptfdisk # sgdisk — partition tables
    parted
    hdparm
    lsof
    htop
    btop # cli.nix sets it up via programs.btop; here plain pkgs.btop
    lazygit # same — programs.lazygit on the laptop, bare package here
    iotop
    mtr
    traceroute
  ];

  # hostname comes from core/network.nix: networking.hostName = host = "thinkcentre".
}
