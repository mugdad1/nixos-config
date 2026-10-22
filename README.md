# nixos-config

**Not for public use.** This is my personal NixOS configuration.

Forked from [Frost-Phoenix/nixos-config](https://github.com/Frost-Phoenix/nixos-config).

## Hosts

Two active hosts, both deploying from `main`:

| Host        | Role                                            | Platform            |
| ----------- | ----------------------------------------------- | ------------------- |
| `victus`    | Laptop — Sway desktop, home-manager, Intel + RTX 3050 | HP Victus 15 (i5-12th gen H) |
| `grandpa`   | Headless lightweight server — blocky, tailscale, sshd, no Docker | Custom i3-2120 box |

Installed: `grandpa` (NixOS since 2026-10-16), `victus` (2026-10-22, took over
the laptop role from the ThinkPad). The ThinkCentre M900x that used
to be the second server went back to its owner on 2026-10-22 and its host is
gone from the flake — git history is the record. The server imports **no**
desktop and **no** home-manager stack: its `variables.nix` declares no
`browser`/`terminal`/`launcher`, and `modules/core/user.nix` only imports
`modules/home` when `variables ? browser`.

`grandpa` is deliberately the smallest — no Docker, no backup disk, no sops
key. Adding a service there is a decision, not a default; see
`hosts/grandpa/default.nix`.

`victus` is the ThinkPad's config minus everything ThinkPad-specific (battery
threshold unit, TrackPoint quirk, `mem_sleep_default=deep`, throttled/tlp) plus
the NVIDIA stack: open kernel modules, modesetting, PRIME offload and a
three-way `gpu-mode` switch (Intel only / hybrid / NVIDIA only).

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
│   ├── victus/
│   │   ├── default.nix       # Laptop host config: NVIDIA + Intel, gpu-mode switch
│   │   ├── hardware-configuration.nix   # placeholder until install.sh copies the real one
│   │   └── variables.nix     # username, timezone, browser/terminal/launcher
│   └── grandpa/
│       ├── default.nix       # identity: imports, boot, zram, no docker/no secrets
│       ├── packages.nix      # headless subset of the old ThinkCentre list
│       ├── overrides.nix     # 32-bit Mesa off, networkd posture, sshd
│       ├── hardware-configuration.nix
│       └── variables.nix
├── modules/
│   ├── core/                 # Shared system layer (15 files) — every host
│   ├── desktop/              # Desktop environment — the laptops only
│   └── home/                 # Home-manager stack — only where variables declare a desktop
│       ├── default.nix       # scanPaths + ../../scripts/default.nix
│       ├── terminal/         # cli, dev, fish, shell, glow, lazyvim + fastfetch/, ghostty/, lazyvim-config/
│       ├── apps/             # browser, git, gui, homepage, vscodium, xdg
│       └── desktop/          # theme, osd, swaylock + sway/, waybar/, rofi/, swaync/
├── pkgs/                     # callPackage files: filen-cli.nix, notify-telegram.nix
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
   imports in `hosts/grandpa/default.nix`). Verification: probe
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
  there. grandpa *reads* `scripts/thinkcentre/*.sh` from its own host files
  instead (`../../scripts/thinkcentre/…`), because that host has no
  home-manager and never imports `scripts/default.nix`.
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
sudo nixos-rebuild switch --flake .#victus
sudo nixos-rebuild switch --flake .#grandpa
```

`mcli` itself is repo-owned (`scripts/mcli.sh`) and installed as a system
package on **every** host — on the laptops it also comes through
`home.packages`, on `grandpa` it is wired in `hosts/grandpa/packages.nix`
because that host deliberately imports no home-manager stack.

Other `mcli` commands: `diag`, `cleanup`, `trim`.

## sops secrets — bootstrap BEFORE the first switch

The repo is public, so no credential is ever written inline in Nix. The
encrypted file `secrets/fleet.sops.yaml` and the **public** age
recipient in `.sops.yaml` are committed; the **private** key never is. On a
reinstall that key is the one thing a declarative system cannot restore for
itself — **copy it into place before `nixos-rebuild switch`, or activation
fails while decrypting:**

```bash
# EVERY host — mode 600, root:root, BEFORE the first switch:
sudo install -m 600 -o root -g root age-key.txt /var/lib/sops-nix/key.txt

# Laptop ONLY, in addition — used by hand for `sops` edits, not by activation:
install -m 600 age-key.txt ~/.config/sops/age/keys.txt
```

Every host uses the same path
(`sops.age.keyFile = "/var/lib/sops-nix/key.txt"`, set as a fleet default in
`modules/core/monitoring.nix`);
the reason it is not a home directory is that `sops-install-secrets` runs early
in boot, before homes are necessarily useful, and a root-owned path under
`/var/lib` states plainly that this is machine state. **The key was placed on
`t480s` and `grandpa` on 2026-10-18**, and it is the one thing `install.sh`
cannot fetch for a new host: it looks for `~/age-key.txt` / `./age-key.txt`,
installs it at that path, and refuses to start the build if neither exists.
`victus` is the deliberate exception: it installs with no key, because its
secrets are gated off by hostname (`sops = lib.mkIf (host != "victus")` in
`modules/core/monitoring.nix`) so a missing key cannot fail the first switch.

**The key is also what turns alerting on**, and since 2026-10-18 that is true
on `grandpa`; `victus` sends no Telegram alerts until the key is placed at
`/var/lib/sops-nix/key.txt` and that gate is dropped. `notify-telegram` (`modules/core/monitoring.nix`) reads its bot
token from the sops-rendered `/run/secrets/rendered/notify-telegram.env` —
root:root 0400, because every caller (smartd, sv-watch, `notify-telegram@`) runs
as root. The token and the template that ships it are declared **fleet-wide in
`modules/core/monitoring.nix`**, not in a per-host `secrets.nix`, so a host gets
alerting the moment its key is in place and nothing else has to change. A host
that has lost its key fails closed: it logs `NOTIFY(no-token)` to journald and
**exits 0**, so a box that cannot deliver never grows an outbox.

The ciphertext file is `secrets/fleet.sops.yaml` (renamed from
`thinkcentre.sops.yaml` on 2026-10-18 — a fleet-wide secret in a file named
after one host was drift; nothing was re-encrypted, the name is not in the
ciphertext). **`sops` is installed on every host** as a system package
(`modules/core/packages.nix`, 2026-10-18) — it was on none of them until then,
which made these instructions un-runnable on the box they were written for. It
is not needed to *decrypt*: activation does that through
`sops-install-secrets` and the age key. It is the interactive half. Adding a
secret: `sops secrets/fleet.sops.yaml` (opens the ciphertext in `$EDITOR`,
re-encrypts on save), declare it in `sops.secrets`, read it as
`config.sops.placeholder."<name>"`.

## Development

```bash
nix develop          # alejandra, shfmt, stylua, taplo, statix, deadnix, shellcheck, nixd
nix fmt              # format everything (formatter = alejandra)
nix flake check      # evaluate all outputs
```

`install.sh` is a whiptail-guided installer for a fresh machine. It detects the
host from DMI (`product_name`/`product_family`: `victus`/`HP` → `victus`,
anything unrecognised → `victus`, since that is the only machine in the house
being installed; `HOST=grandpa ./install.sh` overrides, and a ThinkPad DMI is
refused outright since that host left the flake on 2026-10-22), rewrites
`username` in `hosts/<host>/variables.nix`, installs the sops age key from
`age-key.txt` if it is lying around, copies
`/etc/nixos/hardware-configuration.nix` into the host directory, links
`assets/wallpapers/wallpaper.png` into `~/Pictures/wallpapers/`, then runs
`nixos-rebuild switch --flake .#<host>`. Regenerate
`hardware-configuration.nix` on the target box at install time and diff — never
hand-write it. `hosts/victus/` ships a placeholder that install.sh overwrites.
GPU is fixed per host, not templated: Intel + NVIDIA on `victus`.

## Features

- **Two active hosts from one flake** (`grandpa`, `victus`), desktop opt-in
  per host
- **Home Manager** for user packages and dotfiles (laptops only)
- **Intel + NVIDIA hybrid** on `victus` — open modules, PRIME offload, and
  `gpu-mode intel|hybrid|nvidia` to switch what renders
- **Sway** compositor (Wayland, gap-less tiling) with Waybar, Rofi, SwayNC
- **Gruvbox** theme throughout
- **Tailscale** tailnet, with MagicDNS explicitly refused (`--accept-dns=false`)
- **Blocky** as the local DNS resolver — `127.0.0.1:53`, upstreams raced in
  parallel (NextDNS DoT + AdGuard DoQ + the work resolvers, which simply lose
  the race at home). With Blocky on, systemd-resolved stays off and
  `/etc/resolv.conf` is a static `nameserver 127.0.0.1`. Tailnet names resolve
  via a Blocky `conditional` to MagicDNS `100.100.100.100`.
- **Security hardening** — kernel sysctl, AppArmor, coredumps disabled
- **sops-nix** secrets, encrypted at rest in a public repo

### Deliberately absent / stated on purpose

Worth knowing so they are not mistaken for oversights:

- **Every host answers ssh** — `modules/core/sshd.nix` is shared, so all of
  them run sshd with `:22` open on every interface (changed 2026-10-13 on his
  word, *"allow ssh like normally, in lan, in both"*). Password auth is on
  since the same day; root stays locked out and `AllowUsers` is his account
  only. The firewall is enabled and the shared core opens **no** TCP port
  except `22`; Tailscale opens UDP `41641` (`modules/core/tailscale.nix`,
  `openFirewall = true`). Home Assistant on grandpa opens `8123` on
  `tailscale0` and on the LAN (`hosts/grandpa/home-assistant.nix`).
- **No swap partition on any host** — `zramSwap` (RAM-backed, zstd) covers it:
  `modules/desktop/services.nix` for the laptops, `hosts/grandpa/default.nix`
  for the server.
- **`grandpa`: no NetworkManager, iwd or ModemManager** — wired-only, DHCP via
  systemd-networkd (`hosts/grandpa/overrides.nix`).
- **No btrfs anywhere** — every root is ext4, so nothing enables
  `services.btrfs.autoScrub`; the `mkForce false` lines in grandpa's overrides
  are guards, not host fixes.
- **`grandpa`: no 32-bit Mesa, no `mandb`** — the shared core enables/assumes
  them for the laptops; the host forces each off, because a 32-bit stack has
  nothing to act on there.
- **`victus`: no MUX, no vendor tool** — the internal panel is wired to the
  Intel iGPU, so `gpu-mode nvidia` makes the RTX 3050 render but the iGPU still
  scans the panel out. The three modes are described at the top of
  `hosts/victus/default.nix`.

## History

The configuration covered `t480s` (laptop) and `asus` (a headless home server)
before September 2026; the `asus` host and everything that served it were
removed then. The ThinkCentre replaced it as the real second host — migrated
from Void + runit on 2026-10-13, with `modules/core` decoupled from the
desktop first (2026-10-12) so a headless host could import it. **A third host
joined on 2026-10-16: `grandpa`** (i3-2120, headless, core set only — no
Docker, no secrets, no backup), installed and verified headless the next day.

**2026-10-22: the fleet shrank back to two and changed laptops.** The
ThinkCentre went back to its owner, so `hosts/thinkcentre/` was deleted and its
services moved to grandpa. **`victus`** (HP Victus 15, i5-12th-gen H + RTX
3050) is the new daily laptop and takes over the desktop role, with the NVIDIA
stack and the three-way GPU switch described above. The ThinkPad arrived at the
end of the day and its host was removed at once ("rm thinkpad"), so the flake
declares exactly two machines; its home directory survives as a backup at
`grandpa:~/backup/t480s/`.

The tree was reorganised 2026-10-14 ("orgnize nixos-config it is a mess"):
`hosts/thinkcentre/default.nix` split into `packages.nix` + `overrides.nix`,
`modules/home/` regrouped into `terminal/`, `apps/`, `desktop/` with `scanPaths`
made recursive, `fonts/` + `wallpapers/` moved under `assets/`, and the
ThinkCentre's four shell scripts moved to `scripts/thinkcentre/`.
