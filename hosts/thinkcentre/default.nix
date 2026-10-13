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
    # Hand-built from the live Void install and independently verified against
    # the box (blkid / findmnt / lsblk, 2026-10-12): root btrfs 839da341…,
    # ESP 646D-44FB at /boot/efi, backup btrfs 67dc44db… on the ADATA.
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
  ];

  # The ESP is mounted at /boot/efi on this disk (donor's layout), not NixOS's
  # default /boot. Wrong here and systemd-boot writes to a directory that is
  # not the ESP — the machine then boots the old Void GRUB and "nothing happened".
  boot.loader.efi.efiSysMountPoint = "/boot";

  # Headless: no games, no Wine, hence no 32-bit Mesa. modules/core/hardware.nix
  # sets this plainly for the laptop, so it needs mkForce to undo.
  hardware.graphics.enable32Bit = lib.mkForce false;

  # Docker engine only. The 12 compose projects live in ~/Projects/servers and
  # are deliberately OS-agnostic — they are restored by hand, not re-declared
  # here. Nothing in this flake starts a container on its own.
  virtualisation.docker.enable = true;
  users.users.${username}.extraGroups = ["docker"];

  # /srv/backup is declared in hardware-configuration.nix with nofail, so a
  # missing disk skips the mount instead of hanging boot — same as the donor's
  # runit unit, without the unit. Do NOT also port a backup-mount service:
  # two mounters racing the same UUID is how the donor double-mounted it.

  # Time. The CMOS battery was removed 2026-10-04, so every AC-cut boot starts
  # at 2015-01-01 until NTP steps it (measured 10–20 s typical, >120 s once).
  # timesyncd is his recorded call ("u dont need chrony in nixos — there is an
  # ntp"). If the clock gate in ./backup.nix ever proves insufficient, the
  # alternative is services.chrony: its `makestep 1.0 3` steps an arbitrarily
  # large offset and `chronyc makestep` is a manual escape hatch timesyncd has
  # no equivalent for. Exactly one of the two may be enabled.
  services.timesyncd.enable = true;

  # sshd posture — OPEN ON THE LAN FOR NOW, and deliberately so.
  # modules/core/sshd.nix restricts ssh to tailscale0 only. That is right for
  # the laptop, but on a headless box it is a lockout risk during migration:
  # there is NO tailscale auth key on this node (verified 2026-10-12), so if
  # /var/lib/tailscale is lost or restored after tailscaled first starts, the
  # node re-registers with a NEW IP and tailnet-only ssh leaves no path in at
  # all. Keep the LAN path until tailscale has survived two cold boots, then
  # tighten it here.
  services.openssh.enable = true;

  # The whole Void house runs on `sudo -n` with a passwordless void — the
  # backup script, every sv op. NixOS defaults wheel to prompt, which on a
  # passwordless account means sudo is simply impossible (caught in the first
  # guest rehearsal: poweroff denied). core/security.nix sets true for t480s.
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
