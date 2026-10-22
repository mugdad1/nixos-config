# systemPackages for grandpa — the headless-useful subset of thinkcentre's list
# (see hosts/thinkcentre/packages.nix for the full commentary on each group),
# plus git/gh, which he asked for by name.
#
# The list mirrors hosts/thinkcentre/packages.nix' basic CLI set exactly — his
# rule 2026-10-16: "see the thinkcentre" / "dont add anything from u". The ONLY
# gaps found by diffing the two files were python3, docker-compose and ffmpeg:
# python3 is in (a basic runtime, no reason to differ); docker-compose and
# ffmpeg are NOT — ffmpeg exists over there for the WhatsApp/media stack and
# nothing here needs it, and compose runs as the v2 plugin bundled with the
# docker engine this host gained on 2026-10-19, so a standalone docker-compose
# package is dead weight. The four WhatsApp writeTextFile entries were out for
# the same reason (WhatsApp was removed fleet-wide, row 107) — that changed
# 2026-10-22, when the whole service layer travelled here because the
# ThinkCentre is being returned to its owner: row 136 had already repealed
# row 107, so they are in the list again. opencode was deliberately omitted
# until 2026-10-16, when he asked for it by name ("fish opencode gh git mcli
# tailscale"). Secrets stay fleet-scope in modules/core (sops,
# secrets/fleet.sops.yaml, rows 121–122), NOT per-host — ./secrets.nix added
# 2026-10-22 carries only the two host-local *templates*
# (opencode-telegram.env, filen-sync.env) that moved with ./services.nix.
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
    # Wrapped with pyserial (Midea dongle probing, 2026-10-17) — withPackages
    # python3 is a strict superset of the bare interpreter, so this single
    # entry covers both roles; a second bare python3 would collide on bin/python3.
    # 2026-10-19, his word "add the things u need inside the nixos-config …
    # also grandpa": aioesphomeapi joins pyserial so the agent can drive the
    # ESP8266 AC (ac-control, 192.168.8.7) from this box too — same wrapped
    # entry, no second python3.
    (python3.withPackages (p: [p.pyserial p.aioesphomeapi]))

    # ── agent tooling, added 2026-10-19 ("all u need inside … also grandpa") ─
    # Mirrors hosts/thinkcentre/packages.nix — node for the study repo's gates
    # (`node --test`, scripts/check.sh; node missing from PATH = silent FAIL),
    # tcpdump for network debug (the "no tcpdump on the box" gap in the
    # unnumbered no-leak row of decisions.md, file line 146).
    nodejs
    tcpdump
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

    # ── usb/serial probing (Midea dongle work, 2026-10-17) ──────────────────
    # The Midea AC Wi-Fi dongle is not a USB device (no data lines — lsusb
    # stays empty in every port), so detection is: confirm that with lsusb,
    # then go in over the serial pair. usbutils for the bus view, picocom for
    # a human session at the module's 9600 baud, pyserial for scripted probes.
    picocom
    # pyserial rides on the wrapped python3 above (see its comment there)
    usbutils # lsusb / usb-devices

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

    # ── MOVED HERE from hosts/thinkcentre/packages.nix, 2026-10-22 ──────────
    # The ThinkCentre is being returned to its owner, so the WhatsApp / study /
    # opencode service layer moves with the rest of it. The header above still
    # records why these four entries were OUT while WhatsApp was removed
    # fleet-wide (row 107) — row 136 repealed that, and since 2026-10-22 they
    # belong here rather than nowhere. Keep them in step with
    # hosts/thinkcentre/packages.nix if that host ever returns.

    # ffmpeg — the whatsapp-mcp server shells out to it for audio conversion
    # and video previews (audio.py / media_preview.py); without it those tools
    # refuse and downloaded videos cannot be cut into readable frames
    # (decisions row 38's second gap, the one `xbps-install ffmpeg` closed on
    # Void).
    ffmpeg

    # The build toolchain for a fresh whatsapp-bridge: `go build` with cgo needs
    # a C compiler, and sqlite is the agent's own session DB (opencode.db) plus
    # the bridge's store/whatsapp.db — both read ad hoc without one.
    go
    gcc
    sqlite

    # ── WhatsApp tooling, nixified 2026-10-15 ───────────────────────────────
    # These four lived in ~/.local/bin, which is outside Nix and in practice
    # outside the backup: reinstalls on 2026-10-08 AND 2026-10-15 deleted them.
    # His word: "keep them in the nixos-config" so a reinstall cannot take them
    # again.
    #
    # They stay plain script files under scripts/whatsapp/ and are installed
    # VERBATIM -- writeTextFile with builtins.readFile, not writeShellScriptBin
    # and not inline heredocs in this file: what he reads and edits in the repo
    # is byte-for-byte what runs, with its own shebang and its own docstring
    # explaining why each rule exists. python3 resolves the interpreter.
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
    # The 313 ritual -- one script, one job: put the bare number 313 into two
    # groups at 3:13am and 3:13pm. His order 2026-10-20: "send 313 only to
    # both groups nothing else is requried" / "u must!!!! not respond to
    # anything anything this is a strong rule". The never-respond half is
    # enforced in wa-send (RITUAL), not here: only the bare number passes,
    # and only with this script's one-time ticket.
    (writeTextFile {
      name = "wa-313";
      destination = "/bin/wa-313.sh";
      executable = true;
      text = builtins.readFile ../../scripts/whatsapp/wa-313.sh;
    })
  ];
}
