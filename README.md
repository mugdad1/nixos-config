# nixos-config

**Not for public use.** This is my personal NixOS configuration.

Forked from [Frost-Phoenix/nixos-config](https://github.com/Frost-Phoenix/nixos-config).

## Hosts

Three active hosts, all deploying from `main`:

| Host        | Role                                            | Platform            |
| ----------- | ----------------------------------------------- | ------------------- |
| `victus`    | Laptop — Sway desktop, home-manager, Intel + RTX 3050, Ollama | HP Victus 15 (i5-12th gen H) |
| `t480s`     | Laptop — Sway desktop, home-manager, Intel iGPU only | ThinkPad T480s |
| `grandpa`   | Headless lightweight server — Docker, blocky, tailscale, sshd, sops | Custom i3-2120 box |

Installed: `t480s` (NixOS since 2026-10-11 — **removed 2026-10-22, restored
2026-10-25**), `grandpa` (2026-10-16), `victus` (2026-10-22). The ThinkCentre
M900x that used
to be the second server went back to its owner on 2026-10-22 and its host is
gone from the flake — git history is the record. The server imports **no**
desktop and **no** home-manager stack: its `variables.nix` declares no
`browser`/`terminal`/`launcher`, and `modules/core/user.nix` only imports
`modules/home` when `variables ? browser`.

`grandpa` is deliberately the smallest — Docker is enabled, but there is no
backup disk; the sops key and the service layer are present. Adding a service
there is a decision, not a default; see `hosts/grandpa/default.nix`.

`victus` is the old laptop config minus everything ThinkPad-specific (battery
threshold unit, TrackPoint quirk, `mem_sleep_default=deep`, throttled/tlp) plus
the NVIDIA stack: open kernel modules, modesetting, PRIME offload and a
three-way `gpu-mode` switch (Intel only / hybrid / NVIDIA only). It also runs
**Ollama** (`hosts/victus/ollama.nix`) on `:11434`, tailnet-only, with the
CUDA build and a small model set pulled in the background on activation. GPU
inference needs `gpu-mode hybrid` — Cardwire's default `intel` mode removes the
RTX 3050 from the PCI bus, so CUDA cannot see it.

## Structure

```
nixos-config/
├── flake.nix                 # mkHost: ./hosts/${host} + sops-nix module
├── flake.lock
├── treefmt.toml              # treefmt (alejandra/shfmt/stylua/taplo)
├── install.sh                # Guided installer (whiptail)
├── lib/
│   ├── default.nix           # scanPaths helper (RECURSIVE)
│   ├── gruvbox.nix           # Color palette
│   └── server-index.nix      # One declared list -> rendered service index
├── hosts/
│   ├── victus/
│   │   ├── default.nix       # Laptop host config: NVIDIA + Intel, gpu-mode switch
│   │   ├── hardware-configuration.nix   # real generated file; install.sh overwrites it
│   │   └── variables.nix     # username, timezone, browser/terminal/launcher
│   ├── t480s/
│   │   ├── default.nix       # ThinkPad host config: intel iGPU, throttled/tlp off, battery threshold
│   │   ├── hardware-configuration.nix   # generated — never hand-edited (re-check the UUIDs if the disk moved)
│   │   └── variables.nix     # username, timezone, browser/terminal/launcher
│   └── grandpa/
│       ├── default.nix       # identity: imports, boot, zram, Docker stack, index
│       ├── packages.nix      # headless subset of the old ThinkCentre list
│       ├── overrides.nix     # 32-bit Mesa off, networkd posture, sshd
│       ├── hardware-configuration.nix
│       └── variables.nix
├── modules/
│   ├── core/                 # Shared system layer — every host
│   ├── desktop/              # Desktop environment — the laptops only
│   └── home/                 # Home-manager stack — only where variables declare a desktop
│       ├── default.nix       # scanPaths + ../../scripts/default.nix
│       ├── terminal/         # cli, dev, fish, shell, glow, lazyvim + fastfetch/, ghostty/, lazyvim-config/
│       ├── apps/             # browser, git, gui, homepage, vscodium, xdg
│       └── desktop/          # theme, osd, swaylock + sway/, waybar/, rofi/, swaync/
├── pkgs/                     # callPackage files: filen-cli.nix
├── scripts/                  # Shell scripts (explicitly name-wrapped to PATH)
│   ├── *.sh                  # checkup, mcli, hm-find, desktop helpers
│   └── grandpa/              # ac.sh — grandpa's own
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
  there. grandpa *reads* `scripts/grandpa/*.sh` from its own host files instead
  (`../../scripts/grandpa/…`), because that host has no home-manager and never
  imports `scripts/default.nix`.
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
sudo nixos-rebuild switch --flake .#t480s
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

**Alerting is gone, and the key no longer implies any.** Until 2026-10-23 the
key's second job was turning Telegram on: `notify-telegram` read a bot token
from the sops-rendered `/run/secrets/rendered/notify-telegram.env` and both
`smartd` and a `notify-telegram@` OnFailure= hook called it. That whole path
went at his order ("no more telegram and whatsapp") — script, template unit,
`telegram/*` secrets and every caller in one commit — after the ntfy container
had already gone and WhatsApp with it. The age key is therefore now only about
decrypting the credentials that remain (`filen`, `searx`, `opencode`), and what
is left of failure reporting is **the journal and `systemctl --failed`**: a
failing disk or unit is **logged, not telephoned**. Even `smartd`'s `wall`
notification went on 2026-10-25, once it had no transport left — see the
history below. Restoring a
transport is his call; when it happens it should bring back both halves, not
just one.

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
`thinkpad`/`t480s`/`20L8` → `t480s`, anything unrecognised → `victus`, since
that is the machine in the house most likely being installed; `HOST=grandpa
./install.sh` overrides. **A ThinkPad DMI was refused outright from 2026-10-22
to 2026-10-25**, while `hosts/t480s/` was out of the flake and the sed on its
`variables.nix` would have failed after the whiptail prompt — it detects
normally again now the host is back), rewrites
`username` in `hosts/<host>/variables.nix`, installs the sops age key from
`age-key.txt` if it is lying around, copies
`/etc/nixos/hardware-configuration.nix` into the host directory, links
`assets/wallpapers/wallpaper.png` into `~/Pictures/wallpapers/`, then runs
`nixos-rebuild switch --flake .#<host>`. Regenerate
`hardware-configuration.nix` on the target box at install time and diff — never
hand-write it. `hosts/victus/` ships the real generated file; install.sh
overwrites it on a fresh install. GPU is fixed per host, not templated: Intel
on `t480s` (Intel iGPU only, no NVIDIA branch for that machine), Intel +
NVIDIA on `victus`.

## Features

- **Three active hosts from one flake** (`grandpa`, `victus`, `t480s`), desktop
  opt-in per host
- **Home Manager** for user packages and dotfiles (laptops only)
- **Intel + NVIDIA hybrid** on `victus` — open modules, PRIME offload, and
  `gpu-mode intel|hybrid|nvidia` to switch what renders
- **Ollama** on `victus` — CUDA on the RTX 3050, `:11434` on the tailnet only,
  models declared in `hosts/victus/ollama.nix` and pulled after the server
  starts
- **OpenCode v2** installed system-wide on every host
  (`modules/core/packages.nix`)
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
  only. `fail2ban` is enabled (5 failures, 1 hour); key-only login is still
  blocked because victus has no `authorized_keys` yet. The firewall is enabled;
  shared core opens **no** TCP port except `22`, and Tailscale opens UDP
  `41641` (`modules/core/tailscale.nix`, `openFirewall = true`). grandpa opens
  its service ports explicitly, and Docker-published ports bypass the NixOS
  firewall entirely.
- **grandpa service boundaries** — short since 2026-10-25, because the box lost
  seven of its services that day. What remains: **the index page is nginx on
  `:80`, bound to `tailscale0` only**; **`opencode-serve` binds
  `127.0.0.1:13420`** and is reached with `ssh -L`, never a published port;
  Home Assistant `:8123`, study `:8091` and SearXNG `:8888` answer over the
  tailnet; blocky is DNS `:53`. **Everything the old bullet listed is gone** —
  Vaultwarden `:8082`/`:8443`, Forgejo, Immich, metube, Glances and Jellyfin
  were destroyed with their data that day — and so is the mechanism, not just
  the entries: `systemd.services.tailscale-serve` no longer exists, and the
  two stale CLI routes it left behind (`:444`, `:8443`, both pointing at
  deleted targets) were reset by hand. Zero containers means the
  Docker-publishes-bypass-the-firewall caveat below is currently a note about
  nothing.
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
joined on 2026-10-16: `grandpa`** (i3-2120, headless, core set plus Docker and
sops, no backup), installed and verified headless the next day.

**2026-10-22: the fleet shrank back to two and changed laptops.** The
ThinkCentre went back to its owner, so `hosts/thinkcentre/` was deleted and its
services moved to grandpa. **`victus`** (HP Victus 15, i5-12th-gen H + RTX
3050) is the new daily laptop and takes over the desktop role, with the NVIDIA
stack and the three-way GPU switch described above. The ThinkPad arrived at the
end of the day and its host was removed at once ("rm thinkpad"), so the flake
declares exactly two machines; its home directory survives as a backup at
`grandpa:~/backup/t480s/`.

**2026-10-25: grandpa was stripped to eight things — and brought nginx back
within the hour.** Started from his *"rm all services keep home assistant
only"*, which churned until it settled on home-assistant, blocky, tailscaled,
study, searx, opencode-serve and filen-sync (openssh/fail2ban kept silently, so
he could not lock himself out). **Seven compose projects — forgejo, gitea-mirror,
immich, jellyfin, metube, vaultwarden, vikunja — were destroyed with their
data** on his *"rm data and config"* → `a`, and there is no backup of any of it
on that box; four more units went (`docker-stack`, `tailscale-serve`, `glances`,
`smartd`). **nginx went with them and was restored the same hour**: with no
listener on `:80` the index page answered `ERR_CONNECTION_REFUSED`, and from a
browser a sparse box and a dead box are the same picture — his *"bring it back
nginx i want the stuff how can i access to my services"*. **The docker engine
deliberately stays**: `virtualisation.docker.enable` was never on the list he
confirmed, and pulling a runtime out is a different decision from pulling a
stack out. The same day the **GT 210 was physically removed** from that machine
(a 2-pin fan no OS could stop), taking the four `boot.blacklistedKernelModules`
lines and the whole phantom-display note in `hosts/grandpa/default.nix` with it.

**2026-10-25: the ThinkPad came back and the fleet is three again.** His word,
in two parts: *"thinkpad is coming back"* then *"bring him back to nixos-config
and he will be aside with victus"* — i.e. a peer of `victus`, not a replacement
for it, so `hosts/t480s/` was restored from `c1bb20e^` with `git checkout`,
`t480s = mkHost "t480s"` re-added, and `install.sh` flipped from refusing this
DMI back to detecting it. **Nothing was rewritten by hand** — the whole host
came back out of history, which is the point of having deleted it as a commit
rather than as an edit. The one thing worth re-checking before a build *on that
machine* is `hardware-configuration.nix`: it still carries the UUIDs generated
on 2026-10-11, and if the ThinkPad was reinstalled since, a perfectly valid
eval would build a system that cannot find its root.

**2026-10-30: Ollama on the Victus, OpenCode on every host.** His ask: *"add
ollama to victus with open to tailscale and others … also add opencode to all
hosts"*. Ollama lives in `hosts/victus/ollama.nix` — the CUDA package, bound to
`0.0.0.0:11434` but firewalled to `tailscale0` only, with `lfm3:1.7b`,
`granite4.2:3b`, `qwen3.5:2b`, `nemotron-3-nano:4b` and
`nemotron-3.5-bolt` declared for the model loader. The GPU half was verified on
the box, not assumed: `nvidia-smi` reports the RTX 3050 Laptop (4 GiB, driver
595.112.07, CUDA 13.2) once `gpu-mode hybrid` removes Cardwire's PCI block.
OpenCode moved into `modules/core/packages.nix`, which is the one layer all
three hosts import; nixpkgs already carries v2 (2.1.4 in this lock), so the old
`sst/opencode` overlay references are now history.

The tree was reorganised 2026-10-14 ("orgnize nixos-config it is a mess"):
`hosts/thinkcentre/default.nix` split into `packages.nix` + `overrides.nix`,
`modules/home/` regrouped into `terminal/`, `apps/`, `desktop/` with `scanPaths`
made recursive, `fonts/` + `wallpapers/` moved under `assets/`, and the
ThinkCentre's shell scripts moved to `scripts/thinkcentre/`; after the host was
retired, `docker-stack.sh` moved to `scripts/grandpa/` and the rest were
removed. **`docker-stack.sh` was then deleted on 2026-10-25** along with its
unit — the compose stack it launched was destroyed with its data that day, so
the launcher had nothing left to launch.
