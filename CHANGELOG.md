# Changelog

## 2026-09-09 — maintenance pass (NixOS/HM 26.05, Hyprland 0.55 Lua)

### Added

- `AGENTS.md`: maintainer rules (input policy, 26.05 compliance checklist,
  Hyprland Lua notes, AppArmor rules, lint + verify loop).
- `CHANGELOG.md`: this file.
- `modules/home/theme.nix`: explicit `gtk.gtk4.theme` (HM 26.05 no longer
  mirrors `gtk.theme`, so GTK4 apps keep the Gruvbox theme).
- `flake.nix`: `nixpkgs.follows` for `nixos-hardware`, `zen-browser`,
  `rust-overlay` (dedupes 3 extra nixpkgs pins in `flake.lock`).

### Changed

- `modules/core/security.nix`: AppArmor now uses upstream
  `enableCache = true`; dropped the `reloadIfChanged = false` /
  empty-`ExecReload` override and the hand-written `parser.conf` (it was
  dropping upstream `Include` lines for `apparmor-profiles`).
- `modules/core/system.nix`: removed obsolete `ghostty.cachix.org`
  substituter + key (Ghostty ships in nixpkgs; cache comes from
  `cache.nixos.org`).
- `scripts/default.nix`: bin names via `lib.removeSuffix ".sh"` instead of
  blanket `replaceStrings` (old code mangled names containing `.sh`).
- `install.sh`: quoted flake ref (`."#${HOST}"`, shellcheck SC2086).
- `modules/core/network.nix`: fixed stale "AdGuard" comment → Blocky.
- `README.md`: structure tree now lists
  `hosts/t480s/hardware-configuration.nix` (was `hardware.nix`).
- Formatting: whole tree made `alejandra`-clean (12 files, mostly
  pre-existing drift); removed the `*/home/default.nix` carve-out from
  `treefmt.toml`.

### Removed

- `flake.nix` / `flake.lock`: unused `git-hooks` input (+ `flake-compat`).

### Verified

- `nix flake check --no-build`: all checks passed.
- `nix eval`: `apparmor.enableCache = true`,
  `gtk.gtk4.theme.name = "Colloid-Green-Dark-Gruvbox"`,
  `resolvconf.enable = false` (Blocky owns :53),
  `stateVersion = "26.05"`.
- `alejandra --check`: clean. Remaining `statix`/`deadnix` hits are
  documented benign exceptions (see `AGENTS.md`).

### Deliberately left alone

- `system.stateVersion` / `home.stateVersion = "26.05"` (install release —
  never bump on upgrade).
- Hyprland direct-`.lua` writer (already 0.55-native; HM `settings` would
  emit deprecated hyprlang).
- `killUnconfinedConfinables = true` (SIGTERM-only, safe).
- `networking`: `iwd` backend, BBR/cake sysctl, Blocky+Tailscale split-DNS.
