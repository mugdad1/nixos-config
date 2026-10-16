# systemPackages for grandpa — the headless-useful subset of thinkcentre's list
# (see hosts/thinkcentre/packages.nix for the full commentary on each group),
# plus git/gh, which he asked for by name.
#
# The list mirrors hosts/thinkcentre/packages.nix' basic CLI set exactly — his
# rule 2026-10-16: "see the thinkcentre" / "dont add anything from u". The ONLY
# gaps found by diffing the two files were python3, docker-compose and ffmpeg:
# python3 is in (a basic runtime, no reason to differ); docker-compose and
# ffmpeg are NOT, because they exist over there for docker and the WhatsApp
# stack, and neither runs here. The four WhatsApp writeTextFile entries are out
# for the same reason. opencode was deliberately omitted until 2026-10-16, when
# he asked for it by name ("fish opencode gh git mcli tailscale"). There is no
# ./services.nix and no ./secrets.nix on this host for the same "what it hosts
# is undecided" reason.
#
# ONLY active because ./packages.nix is named in the imports list of
# ./default.nix — a directory module does not sweep up its siblings.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # ── baseline ─────────────────────────────────────────────────────────────
    curl
    dnsutils # dig — no pkgs.dig; dnsutils provides it
    jq
    # sensors — same as thinkcentre (mirror rule, decisions row 103): chip
    # temperatures/voltages/fans, useful on a spinning-HDD box
    lm_sensors
    ripgrep
    rsync
    tmux
    vim

    # Health sweep — the same script thinkcentre runs (installed verbatim;
    # sections that don't apply here — sdb, docker — say so instead of failing)
    (writeShellScriptBin "checkup" (builtins.readFile ../../scripts/checkup.sh))

    # ── asked for by name ────────────────────────────────────────────────────
    gh
    git
    # v2 via the sst/opencode overlay that modules/core/opencode.nix installs —
    # same reason hosts/thinkcentre/packages.nix can reference it bare.
    # packages.nix's header used to say "the agent is not part of a bare CLI
    # box"; he decided otherwise 2026-10-16.
    opencode
    # The one real gap against thinkcentre's list (his "see the thinkcentre"):
    # the runtime for hand tools and quick scripts, same as on the server.
    python3
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
