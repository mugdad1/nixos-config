# systemPackages for thinkcentre — split out of default.nix 2026-10-14.
# ONLY active because ./packages.nix is named in the `imports` list of
# ./default.nix: mkHost passes `./hosts/${host}`, and a directory module
# resolves to that directory's default.nix ONLY — it does not sweep up
# siblings. See the warning above the imports there before adding a file.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # ── baseline ─────────────────────────────────────────────────────────────
    curl
    # sv-watch's DNS sweep shells out to dig; not in NixOS's default path.
    # (pkgs.dnsutils provides dig — there is no pkgs.dig.)
    dnsutils
    docker-compose
    jq
    ripgrep
    rsync
    tmux
    vim

    # ── added 2026-10-12 on his word ─────────────────────────────────────────
    gh # gh api / gh repo view, same as on the laptop
    inxi # `mcli diag` shells out to it; without this that section prints
    # "inxi not installed" on a fresh box
    neovim # `nvim`; vim above stays as the bare-metal fallback
    # v2, not nixpkgs' stale v1 — modules/core/opencode.nix installs the
    # sst/opencode overlay, and thinkcentre imports core, so pkgs.opencode
    # here is already v2. Same reason hosts/thinkcentre/services.nix can
    # reference it as ocPath.
    opencode

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

    # ── added 2026-10-14 with the WhatsApp restore (decisions row 87) ────────
    # The whatsapp-mcp server shells out to ffmpeg for audio conversion and
    # video previews (audio.py / media_preview.py); without it those tools
    # refuse and downloaded videos cannot be cut into readable frames. This is
    # decisions.md row 38's second gap, the one `xbps-install ffmpeg` closed on
    # Void. systemPackages rather than a `nix profile add` so a reinstall brings
    # it back with the rest of the box (the imperative copy installed first,
    # while bringing the stack up, was dropped once this line landed).
    ffmpeg

    # ── added 2026-10-15 with the QR pairing page ─────────────────────────────
    # qr-serve.py is a hand-run script inside the whatsapp-mcp clone, and
    # without an interpreter on PATH the only way to run it is
    # `nix shell nixpkgs#python3 -c python3 …`. This makes the pairing command
    # a one-liner he can type himself. Not a system-wide dev environment: the
    # MCP server keeps its own venv in the repo, so this is just the runtime
    # the hand tools need.
    python3

    # ── server baseline, added 2026-10-13 ───────────────────────────────────
    # modules/home/terminal/cli.nix carries most of these on the laptop, but it
    # is a *home-manager* module (home.packages / programs.*) and this host is
    # headless, so it imports modules/core only and never sees that file. The
    # desktop half of cli.nix (brightnessctl, playerctl, wl-clipboard, udiskie,
    # poweralertd, pamixer, swappy…) is deliberately not mirrored here. This is
    # the headless-useful subset plus the box-admin tools it needs.
    git # THE missing one. This host is a git server — wiki, study and
    # nixos-config all live here and get pulled/pushed. Without this the repos
    # were unrunnable. It never came in because the laptop gets git from
    # home-manager (modules/home/apps/git.nix → programs.git), not
    # systemPackages. (It used to be listed twice — once here, once with no
    # comment; merged 2026-10-14, the comment is the part that matters.)

    # ── pulled across from modules/home/terminal/cli.nix (headless-useful only) ──
    binutils # objdump/strings/nm — for debugging containers & bins
    duf # df
    dust # du
    entr # run a command on file change
    eza # ls
    fd # find (fzf's backend)
    file
    glow # render markdown in the terminal (wiki / study notes)
    killall
    just # command runner
    ncdu # disk usage analyzer — this box has 3 filesystems to watch
    p7zip
    ripgrep-all # rga — grep inside pdfs/zips; useful for the study corpus
    socat
    strace
    tealdeer # tldr
    tree
    unzip
    wget
    zip

    # ── box admin: hardware + disks ─────────────────────────────────────────
    btop # cli.nix sets it up via programs.btop; here plain pkgs.btop
    gptfdisk # sgdisk — partition tables
    hdparm
    htop
    iotop
    lazygit # same — programs.lazygit on the laptop, bare package here
    lsof
    mtr
    parted
    smartmontools # SMART health for the ADATA + root drives
    traceroute
  ];
}
