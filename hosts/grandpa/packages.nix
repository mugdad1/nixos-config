# systemPackages for grandpa — the headless-useful subset of thinkcentre's list
# (see hosts/thinkcentre/packages.nix for the full commentary on each group),
# plus git/gh, which he asked for by name.
#
# DELIBERATELY NOT COPIED from thinkcentre: docker-compose (no docker here yet),
# ffmpeg / python3 and the four WhatsApp writeTextFile entries (no WhatsApp
# here), and opencode (the agent is not part of a bare CLI box — add it if it is
# ever wanted). There is no ./services.nix and no ./secrets.nix on this host for
# the same "what it hosts is undecided" reason.
#
# ONLY active because ./packages.nix is named in the imports list of
# ./default.nix — a directory module does not sweep up its siblings.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # ── baseline ─────────────────────────────────────────────────────────────
    curl
    dnsutils # dig — no pkgs.dig; dnsutils provides it
    jq
    ripgrep
    rsync
    tmux
    vim

    # ── asked for by name ────────────────────────────────────────────────────
    gh
    git
    # mcli is repo-owned (scripts/mcli.sh), not a nixpkgs package. Normally
    # installed through home.packages, but this host is headless and imports no
    # home stack, so it is wired in here — the same shape thinkcentre uses.
    # Already host-aware: `mcli rebuild` runs `nh os switch ~/nixos-config` and
    # nh derives the host from `hostname`, so it resolves to #grandpa here with
    # no branch in the script.
    (writeShellScriptBin "mcli" (builtins.readFile ../../scripts/mcli.sh))

    # ── cli, ported from modules/home/terminal/cli.nix (headless-useful only) ─
    binutils # objdump/strings/nm
    duf # df
    dust # du
    entr # run a command on file change
    eza # ls
    fd # find (fzf's backend)
    file
    glow # render markdown in the terminal
    killall
    just # command runner
    ncdu # disk usage analyzer
    neovim
    p7zip
    ripgrep-all # rga — grep inside pdfs/zips
    socat
    strace
    tealdeer # tldr
    tree
    unzip
    wget
    zip

    # ── box admin: hardware + disks ─────────────────────────────────────────
    btop
    gptfdisk # sgdisk
    hdparm
    htop
    inxi # mcli diag shells out to it
    iotop
    lazygit
    lsof
    mtr
    parted
    smartmontools # SMART health for the HDD
    traceroute
  ];
}
