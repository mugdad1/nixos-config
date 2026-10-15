# nixos-config

**Not for public use.** This is my personal NixOS configuration.

Forked from [Frost-Phoenix/nixos-config](https://github.com/Frost-Phoenix/nixos-config).

## Hosts

Two hosts, both deploying from `main`:

| Host        | Role                                            | Platform            |
| ----------- | ----------------------------------------------- | ------------------- |
| `t480s`     | Laptop — Sway desktop, home-manager             | ThinkPad T480s      |
| `thinkcentre` | Headless server — Docker, blocky, tailscale, sshd | ThinkCentre M900x (10LY) |

The ThinkCentre imports **no** desktop and **no** home-manager stack: its
`variables.nix` declares no `browser`/`terminal`/`launcher`, and
`modules/core/user.nix` only imports `modules/home` when `variables ? browser`.

## Structure

```
nixos-config/
├── flake.nix                 # mkHost: ./hosts/${host} + sops-nix module
├── flake.lock
├── treefmt.toml              # treefmt (alejandra/shfmt/stylua/taplo)
├── rust-toolchain.toml
├── install.sh                # Guided installer (whiptail)
├── lib/
│   ├── default.nix           # scanPaths helper (RECURSIVE)
│   ├── gruvbox.nix           # Color palette
│   └── server-index.nix      # One declared list -> rendered service index
├── hosts/
│   ├── t480s/
│   │   ├── default.nix       # Laptop host config (explicit imports)
│   │   ├── hardware-configuration.nix   # generated — never hand-edited
│   │   └── variables.nix     # username, timezone, browser/terminal/launcher
│   └── thinkcentre/
│       ├── default.nix       # identity: imports, boot, /srv/backup, time, zram
│       ├── packages.nix      # environment.systemPackages (~90 lines)
│       ├── overrides.nix     # every lib.mkForce + the networkd posture
│       ├── backup.nix        # nightly 03:17 backup timer + clock gate
│       ├── services.nix      # opencode, telegram bot, study, docker-stack, sv-watch
│       ├── secrets.nix       # sops-nix wiring (host-specific file)
│       ├── hardware-configuration.nix
│       └── variables.nix
├── modules/
│   ├── core/                 # Shared system layer (14 files) — both hosts
│   ├── desktop/              # Desktop environment — t480s only
│   └── home/                 # Home-manager stack — only where variables declare a desktop
│       ├── default.nix       # scanPaths + ../../scripts/default.nix
│       ├── terminal/         # cli, dev, fish, shell, glow, lazyvim + fastfetch/, ghostty/, lazyvim-config/
│       ├── apps/             # browser, git, gui, homepage, vscodium, xdg
│       └── desktop/          # theme, osd, swaylock + sway/, waybar/, rofi/, swaync/
├── scripts/                  # Shell scripts (explicitly name-wrapped to PATH)
│   └── thinkcentre/          # backup-run.sh, sv-watch.sh, docker-stack.sh, http-endpoints
├── secrets/                  # ENCRYPTED sops files (committed, useless without a key)
└── assets/
    ├── fonts/                # SCHLBKB.TTF (century-schoolbook)
    └── wallpapers/           # wallpaper.png + otherWallpaper/{gruvbox,nixos,thinkpad}
```

## STRUCTURE — the two import rules

These are opposite on purpose, and getting them wrong fails *silently* (a green
build says nothing about a file that was never imported):

1. **`hosts/<name>/` — explicit imports only.** `mkHost` passes
   `./hosts/${host}` as the module, and a NixOS module that is a *directory*
   resolves to that directory's `default.nix` **only** — it does not sweep up
   sibling `.nix` files. **Any file created under `hosts/<name>/` must be named
   in the `imports` list of that directory's `default.nix`**, or it is dead
   weight. This cost a full build cycle once (see the comment above the
   imports in `hosts/thinkcentre/default.nix`). Verification: probe
   `config.systemd.services.<name>` — never trust the build result alone.

2. **`modules/{core,desktop,home}/` — `scanPaths`, no list to maintain.**
   `lib/default.nix`'s `scanPaths` is **recursive**: it imports every `.nix`
   file (except `default.nix`) and every subdirectory that has its own
   `default.nix`. Drop a file anywhere under those three directories and it is
   picked up. `modules/home/default.nix` adds only `../../scripts/default.nix`,
   which lives outside the directory and therefore cannot be scanned.

Also:

- **`scripts/`** — wrapped one by one in `scripts/default.nix`
  (`writeShellScriptBin` + `builtins.readFile`), so a new script needs an entry
  there. The ThinkCentre's four scripts are *read* from `hosts/thinkcentre/*.nix`
  instead (`../../scripts/thinkcentre/…`), because that host has no home-manager
  and never imports `scripts/default.nix`.
- **`assets/`** — raw files referenced by path (`modules/desktop/fonts.nix`,
  `modules/home/apps/xdg.nix`, `install.sh`). Nothing at the repo root is
  referenced by the running system any more.
- **`secrets/`** — never a plaintext credential in any file; see below.

## Rebuild

```bash
# Either machine — the host is derived from `hostname` by nh:
mcli rebuild                 # = nh os switch ~/nixos-config
mcli update                  # nix flake update + rebuild

# Or explicitly:
sudo nixos-rebuild switch --flake .#t480s
sudo nixos-rebuild switch --flake .#thinkcentre
```

`mcli` itself is repo-owned (`scripts/mcli.sh`) and installed as a system
package on **both** hosts — on `t480s` it also comes through
`home.packages`, on `thinkcentre` it is wired in `hosts/thinkcentre/packages.nix`
because that host deliberately imports no home-manager stack.

Other `mcli` commands: `diag`, `cleanup`, `trim`.

## sops secrets — bootstrap BEFORE the first switch

The repo is public, so no credential is ever written inline in Nix. The
encrypted file `secrets/thinkcentre.sops.yaml` and the **public** age
recipient in `.sops.yaml` are committed; the **private** key never is. On a
reinstall that key is the one thing a declarative system cannot restore for
itself — **copy it into place before `nixos-rebuild switch`, or activation
fails while decrypting:**

```bash
# ThinkCentre (server) — mode 600, root:root, BEFORE the first switch:
sudo install -m 600 -o root -g root age-key.txt /var/lib/sops-nix/key.txt

# Laptop — used by hand for `sops` edits, not by activation:
install -m 600 age-key.txt ~/.config/sops/age/keys.txt
```

Paths are enforced in `hosts/thinkcentre/secrets.nix`
(`sops.age.keyFile = "/var/lib/sops-nix/key.txt"`); the reasoning is in
`.sops.yaml`. Adding a secret: encrypt it into `secrets/thinkcentre.sops.yaml`
(`sops -e -i`), declare it in `sops.secrets`, read it as
`config.sops.placeholder."<name>"`.

## Development

```bash
nix develop          # alejandra, shfmt, stylua, taplo, statix, deadnix, shellcheck, nixd
nix fmt              # format everything (formatter = alejandra)
nix flake check      # evaluate all outputs
```

`install.sh` is a whiptail-guided installer for a fresh machine. It detects the
host from DMI (`product_name`/`product_family` — the ThinkCentre reports only
`10LYS02F00` in `product_name`), rewrites `username` in
`hosts/<host>/variables.nix`, copies `/etc/nixos/hardware-configuration.nix`
into the host directory, links `assets/wallpapers/wallpaper.png` into
`~/Pictures/wallpapers/`, then runs `nixos-rebuild switch --flake .#<host>`.
Regenerate `hardware-configuration.nix` on the target box at install time and
diff — never hand-write it. GPU is fixed to Intel in `hosts/t480s/default.nix`
and is not templated.

## Features

- **Two hosts from one flake**, desktop opt-in per host
- **Home Manager** for user packages and dotfiles (laptop only)
- **Sway** compositor (Wayland, gap-less tiling) with Waybar, Rofi, SwayNC
- **Gruvbox** theme throughout
- **Tailscale** tailnet, with MagicDNS explicitly refused (`--accept-dns=false`)
- **Blocky** as the local DNS resolver — `127.0.0.1:53`, upstreams raced in
  parallel. On the ThinkCentre only the two encrypted upstreams are shipped
  (`overrides.nix` forces the laptop's work resolvers out); on `t480s` the work
  resolvers race too. With Blocky on, systemd-resolved stays off and
  `/etc/resolv.conf` is a static `nameserver 127.0.0.1`. Tailnet names resolve
  via a Blocky `conditional` to MagicDNS `100.100.100.100`.
- **Nightly 03:17 backup** on the ThinkCentre (`backup.nix` + a bounded clock
  gate — the box has no CMOS battery, so a cold boot can start in 2015)
- **Security hardening** — kernel sysctl, AppArmor, coredumps disabled
- **sops-nix** secrets, encrypted at rest in a public repo

### Deliberately absent / stated on purpose

Worth knowing so they are not mistaken for oversights:

- **`t480s` is not a server, but it does answer ssh** — `modules/core/sshd.nix`
  is shared, so **both hosts** run sshd with `:22` open on every interface
  (changed 2026-10-13 on his word, *"allow ssh like normally, in lan, in
  both"*). Password auth is on since the same day; root stays locked out and
  `AllowUsers` is his account only. The firewall is enabled and the **only**
  opened TCP port in the whole flake is `22`.
- **No swap partition on either host** — `zramSwap` (RAM-backed, lz4) covers
  it: `modules/desktop/services.nix` for `t480s`,
  `hosts/thinkcentre/default.nix` for the server.
- **`thinkcentre`: no NetworkManager, iwd or ModemManager** — wired-only, DHCP
  via systemd-networkd (`hosts/thinkcentre/overrides.nix`).
- **`thinkcentre`: no 32-bit Mesa, no btrfs scrub, no `mandb`** — the shared
  core enables/assumes them for the laptop; the host forces each off, because
  a scrub or a 32-bit stack has nothing to act on there.

## History

The configuration covered `t480s` (laptop) and `asus` (a headless home server)
before September 2026; the `asus` host and everything that served it were
removed then. The ThinkCentre replaced it as the real second host — migrated
from Void + runit on 2026-10-13, with `modules/core` decoupled from the
desktop first (2026-10-12) so a headless host could import it.

The tree was reorganised 2026-10-14 ("orgnize nixos-config it is a mess"):
`hosts/thinkcentre/default.nix` split into `packages.nix` + `overrides.nix`,
`modules/home/` regrouped into `terminal/`, `apps/`, `desktop/` with `scanPaths`
made recursive, `fonts/` + `wallpapers/` moved under `assets/`, and the
ThinkCentre's four shell scripts moved to `scripts/thinkcentre/`.
