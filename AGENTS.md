# AGENTS.md — maintainer rules for this repo

The assistant is responsible for keeping this config working, current, and
clean. Before changing versions/options, websearch current upstream docs
(NixOS + Home Manager release notes for the target release). Never guess at
option names or defaults — verify with `nix eval` or the manuals.

## Flake inputs

- Every input that has a `nixpkgs` input must set
  `inputs.nixpkgs.follows = "nixpkgs"`, unless upstream documents otherwise.
- Exception: `nix-flatpak` has no `nixpkgs` input — do not add a follows for it.
- No dead inputs: each input must be referenced somewhere under
  `hosts/`, `modules/`, or `scripts/`. Remove unused ones from both
  `flake.nix` and `flake.lock` via `nix flake lock`.
- After any input change: `nix flake lock`, then `nix flake check --no-build`.
- Binary caches (`modules/core/system.nix`): only caches that still serve
  unique paths. `ghostty.cachix.org` is obsolete (Ghostty is in nixpkgs —
  do not re-add). Keep `nix-community` + `hyprland`.

## NixOS 26.05+ compliance (re-verify per release via release notes)

- `system.stateVersion` / `home.stateVersion`: NEVER bump on upgrade. They pin
  the install release's compatibility behavior, not the current version.
  Both are `26.05` (fresh install) — leave them.
- `fileSystems.*`: always explicit `fsType` + stable device paths
  (`/dev/disk/by-uuid/...`), never `/dev/root` (systemd stage-1 has no
  `/dev/root` symlink).
- DNS split: Blocky owns `127.0.0.1:53`, so `network.nix` sets
  `networking.resolvconf.enable = false` exactly when Blocky is enabled and
  writes `environment.etc."resolv.conf"` itself. If you touch DNS, keep this
  pairing (resolvconf now defaults to `true` unconditionally upstream).
- coredump: use structured `systemd.coredump.settings.Coredump`
  (`extraConfig` was removed upstream).
- Wireless: `iw` is installed explicitly in `network.nix` (no longer
  implicit). Backend is `iwd` + NetworkManager; don't switch to
  `wpa_supplicant` without reason.
- `hardware-configuration.nix` is generated — never hand-edit (except via
  `nixos-generate-config` output). `install.sh` copies it in.

## Home Manager 26.05+ compliance

- `gtk.gtk4.theme` must be set explicitly — it no longer mirrors `gtk.theme`.
  Any future "no longer mirrors X" change in release notes needs the same
  treatment here (`modules/home/theme.nix`).
- `xdg.userDirs.extraConfig` keys must be bare names (`DESKTOP`), never
  `XDG_*_DIR` form.
- `programs.ssh.matchBlocks` is auto-migrated to `programs.ssh.settings`;
  prefer `settings` in new code.
- `programs.zsh.dotDir` now defaults to the XDG config dir on
  `stateVersion >= 26.05`. Don't assume `~/.zshrc`; absolute paths
  (e.g. `~/.p10k.zsh` source in `shell.nix`) still work — keep them absolute.

## Hyprland (0.55+, Lua)

- This repo does NOT use `wayland.windowManager.hyprland` (no HM module).
  Config is written directly to `xdg.configFile."hypr/hyprland.lua"` with the
  `hl.*` Lua API (`modules/home/hyprland/`). Keep it that way — the HM
  `settings` attrset generates deprecated hyprlang `hyprland.conf`.
- System side stays: `programs.hyprland.enable = true` in
  `modules/desktop/wayland.nix`.
- Validate Lua API calls (`hl.config`, `hl.curve`, `hl.animation`,
  `hl.gesture`, `hl.on`, `hl.exec_cmd`, `hl.env`) against
  https://wiki.hypr.land before changing them.

## Security module (`modules/core/security.nix`)

- AppArmor: `enable = true`, `enableCache = true`,
  `killUnconfinedConfinables = true` (SIGTERM-only to newly-profilable
  processes — safe), `packages = [apparmor-profiles]`.
- Do NOT override `systemd.services.apparmor.reloadIfChanged` or
  `ExecReload`, and do NOT write a custom `apparmor/parser.conf` — the
  upstream module manages `Include` lines for `packages`; a hand-written
  file drops them and silently breaks profiles.

## Code style & lints

- Formatter is `alejandra` (`nix fmt` / `formatter` flake output). Keep the
  tree `alejandra --check` clean; `treefmt.toml` excludes must stay minimal
  (no per-file carve-outs like the old `home/default.nix` exclusion).
- `statix` "repeated keys" warnings for merged `xdg.*` / `home.*` blocks are
  acceptable style here — do not churn working modules to silence them.
- `deadnix`: `self` in flake `outputs` and `pkgs` in generated
  `hardware-configuration.nix` are known-benign; fix all other hits.
- `shellcheck` on `install.sh` + `scripts/*.sh` must be warning-free except
  documented exceptions (unused color vars in `install.sh` are intentional).
- `scripts/default.nix`: derive bin names with `lib.removeSuffix ".sh"`,
  never blanket `replaceStrings` (mangles names containing `.sh` elsewhere).
- `install.sh`: quote flake refs (`."#${HOST}"`); the `mugdad` → username
  `sed` sweep is fragile by design — keep the tutamail fix-up line directly
  below it and don't extend the sweep to new dirs without checking.

## Verification (run before handing back)

1. `alejandra -q .` then `alejandra --check .` — clean.
2. `nix flake lock` (if inputs changed) + `nix flake check --no-build` —
   all checks pass.
3. `nix eval` spot-checks for touched options, e.g.:
   `. #nixosConfigurations.t480s.config.security.apparmor.enableCache`,
   `. #nixosConfigurations.t480s.config.system.stateVersion`.
4. Full build is the user's job (`sudo nixos-rebuild switch --flake .#t480s`)
   — do not run real builds unless asked; `--dry-run` eval only.

## Docs & commits

- `README.md` structure tree must match the real tree (notably
  `hosts/t480s/hardware-configuration.nix`, not `hardware.nix`).
- Commit style: `area: imperative summary` (`chore:`, `fix:`, `docs:`).
  Never commit, amend, or push unless explicitly asked.
