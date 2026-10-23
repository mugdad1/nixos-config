# systemPackages for grandpa — the headless-useful subset of thinkcentre's list
# (see hosts/thinkcentre/packages.nix for the full commentary on each group),
# plus git/gh, which he asked for by name.
#
# The list mirrors hosts/thinkcentre/packages.nix' basic CLI set exactly — his
# rule 2026-10-16: "see the thinkcentre" / "dont add anything from u". The ONLY
# gaps found by diffing the two files were python3, docker-compose and ffmpeg:
# python3 is in (a basic runtime, no reason to differ); docker-compose and
# ffmpeg are NOT — compose runs as the v2 plugin bundled with the docker engine
# this host gained on 2026-10-19, so a standalone docker-compose package is
# dead weight, and ffmpeg was here only for the WhatsApp media stack.
#
# WHATSAPP IS OUT, for good this time. The WhatsApp writeTextFile entries and
# the ffmpeg / go / gcc the bridge needed travelled here on 2026-10-22 with the
# rest of the ThinkCentre service layer (rows 136 repealing 107), and are
# removed 2026-10-23 on his "no more whatsapp" — ~/projects/whatsapp-mcp is
# already deleted from the box, so the bridge could not have started anyway.
# `sqlite` is the one survivor of that group: it was listed as the bridge's
# store/whatsapp.db reader AND as the agent's own session DB (opencode.db),
# and the second use is still live.
#
# opencode was deliberately omitted until 2026-10-16, when he asked for it by
# name ("fish opencode gh git mcli tailscale"). Secrets stay fleet-scope in modules/core (sops,
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

    # ── `ac` — one command for the AC (his standing ask, decisions row 164) ──
    # writeShellApplication, NOT writeShellScriptBin, for the two reasons row 164
    # chose it: runtimeInputs pins curl/python3 so `ac` never depends on what
    # happens to be on $PATH, and shellcheck runs as a build gate so a broken
    # script fails the build instead of failing at 1am when he types `ac on`.
    #
    # It was wired into hosts/thinkcentre/packages.nix (row 164) — that host was
    # deleted on 2026-10-22 (row 193), and the declaration went with it, leaving
    # `ac` off PATH entirely with only an unreferenced script behind it. Re-declared
    # here (scripts/grandpa/ac.sh, moved out of scripts/thinkcentre/) so the tool
    # lives on the box whose HA answers it.
    (writeShellApplication {
      name = "ac";
      runtimeInputs = [curl python3];
      text = builtins.readFile ../../scripts/grandpa/ac.sh;
    })

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

    sqlite

  ];
}
