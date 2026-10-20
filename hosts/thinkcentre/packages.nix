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
    # sensors — chip temperatures/voltages/fans (his ask 2026-10-16; run
    # `sensors-detect` once if the chip needs probing, config lands in /etc)
    lm_sensors
    ripgrep
    rsync
    tmux
    vim

    # ── AC project, 2026-10-17 ("put all tools u need") ──────────────────────
    # Builds and flashes the ESP8266 NodeMCU from this box (the remote is
    # broken; dad said he can't do it — he's doing it). The esp8266:esp8266
    # core and the libraries (Blynk, DHT, IRremoteESP8266) are fetched by
    # arduino-cli itself into ~/.arduino15 on first setup — not nix packages,
    # so nothing else is needed here. Upload goes over /dev/ttyUSB0 (CP210x),
    # which the dialout group in default.nix unlocks.
    arduino-cli

    # ── health sweep, added 2026-10-16 on his word ("check between times") ──
    # Plain tracked file scripts/checkup.sh, installed verbatim (same
    # writeShellScriptBin shape as mcli): units, containers, disk use, the
    # backup disk's SMART trend (sdb attr5 baseline 45), blocky, tailscale
    # (interface + backend, NOT just the unit — active-but-stopped fooled
    # everyone once), the watcher's one-arm rule, both repos' ahead/behind,
    # and a count of muse-spark sessions. Prints findings, tldr; exit 1 on any
    # FAIL so a timer can gate on it later.
    (writeShellScriptBin "checkup" (builtins.readFile ../../scripts/checkup.sh))

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
    # 2026-10-19 ("add the things u need inside the nixos-config"): bare
    # python3 upgraded to a withPackages env — same interpreter, now with
    # aioesphomeapi so the agent can drive the ESP8266 AC (ac-control,
    # 192.168.8.7) directly instead of a throwaway nix-shell every time.
    # Superset of the old line: plain python3 still resolves.
    # 2026-10-20 ("add them to nixos config"): pillow joined it — image work
    # (recolouring a photo of the house, masks, crops) kept falling back to a
    # throwaway `nix shell nixpkgs#python3Packages.pillow` otherwise.
    (python3.withPackages (ps: [
      ps.aioesphomeapi
      ps.pillow
    ]))

    # ── added 2026-10-20, his word "add them to nixos config" ─────────────────
    # Every one of these was being pulled ad hoc through `nix shell` this
    # session, which is exactly the habit the 2026-10-19 "all u need inside"
    # row killed:
    #   sqlite   — the agent's own session DB is sqlite (opencode.db); reading
    #              or exporting anything out of it needed `nix shell nixpkgs#sqlite`
    #   go, gcc  — building the whatsapp-bridge binary (`go build`, cgo needs a
    #              C compiler) on a re-clone; the v0.7.0 build this session used
    #              both from a throwaway shell
    #   imagemagick — convert/identify for image work that pillow does not
    #              cover (the render pipeline: crop, compose, export)
    sqlite
    go
    gcc
    imagemagick

    # ── added 2026-10-19, his word "all u need inside" ────────────────────────
    # node: the study repo's gates run on `node --test` (scripts/check.sh,
    # 145 tests) — before this, every study push needed
    # `nix-shell -p nodejs` first, and the shell form silently FAILs the
    # config-sync checks when node is missing from PATH.
    nodejs

    # tcpdump — the wiki has flagged "there is no tcpdump on the box" in the
    # unnumbered no-leak row of decisions.md (file line 146) since 2026-10-09.
    # Network debug on a DNS/routing house needs it.
    tcpdump

    # ── WhatsApp tooling, nixified 2026-10-15 ─────────────────────────────────
    # These four lived in ~/.local/bin, which is outside Nix and in practice
    # outside the backup: reinstalls on 2026-10-08 AND 2026-10-15 deleted them,
    # and the 10-14 rebuild was lost with them because the nightly job never
    # produced a single snapshot. His word: "keep them in the nixos-config" so a
    # reinstall cannot take them again.
    #
    # They stay plain script files under scripts/whatsapp/ and are installed
    # VERBATIM -- writeTextFile with builtins.readFile, not writeShellScriptBin
    # and not inline heredocs in this file: what he reads and edits in the repo
    # is byte-for-byte what runs, with its own shebang and its own docstring
    # explaining why each rule exists. python3 above resolves the interpreter.
    (writeTextFile {
      name = "wa-send";
      destination = "/bin/wa-send";
      executable = true;
      text = builtins.readFile ../../scripts/whatsapp/wa-send;
    })
    # Log-first send through the bridge's /api/send (field is `recipient`, not
    # chat_jid -- the 2026-10-03 bug), refuses the stop flag, refuses a `|`
    # in the why, writes FAILED - (NOT SENT) itself, and records every sent
    # text so the watcher cannot wake on our own messages.
    (writeTextFile {
      name = "watch-whatsapp";
      destination = "/bin/watch-whatsapp.py";
      executable = true;
      text = builtins.readFile ../../scripts/whatsapp/watch-whatsapp.py;
    })
    # One-shot poller over store/messages.db with a persistent rowid cursor,
    # scoped to the same 11 chats as the reply allow-list. Exits on a hit:
    # the completion is what wakes the agent.
    (writeTextFile {
      name = "wa-armsup";
      destination = "/bin/wa-armsup.sh";
      executable = true;
      text = builtins.readFile ../../scripts/whatsapp/wa-armsup.sh;
    })
    # Supervisor -- one arm at a time (two arms starve each other on the shared
    # cursor), and it stands down rather than respawning a refusing watcher.
    (writeTextFile {
      name = "qr-serve";
      destination = "/bin/qr-serve.py";
      executable = true;
      text = builtins.readFile ../../scripts/whatsapp/qr-serve.py;
    })
    # Pairing page for the next re-pair: re-reads the freshest QR out of
    # store/bridge.log (a ~20 s code is dead the moment it is captured) and
    # serves it on the Tailscale IP, --print for a terminal with no browser.

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
