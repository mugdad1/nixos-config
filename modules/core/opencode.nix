# opencode's nixpkgs package ships a stale node_modules FOD hash — every host
# fails to build. Added 2026-11-05, after a t480s build died with:
#
#   error: hash mismatch in fixed-output derivation
#     '/nix/store/kfdz406fa44wmh8bgiq2d7nnbxa19f0f-opencode-node_modules-2.2.5.drv':
#       specified: sha256-xfOVcw1+waLVNhFDwzOtzxrUSQEogvn88YomydOlhwc=
#          got:    sha256-prx9dX7kUvs/E3zopkaPk5LXh3xJAy5sZeum/W8L7cA=
#
# Root cause: nixpkgs bumped bun and bun's install output changed, but the
# outputHash in pkgs/by-name/op/opencode/package.nix was not updated with it.
# The fix ("opencode: fix hash", c399e1b7fb90789e3e032784ef8ad98ba9907169)
# landed on nixpkgs master on 2026-11-04 and is NOT on the nixos-unstable
# branch this flake follows as of 2026-11-05 — checked against
# raw.githubusercontent.com/NixOS/nixpkgs/nixos-unstable/.../opencode/package.nix,
# which still carries the xfOVcw hash verbatim. So `nix flake update nixpkgs`
# does NOT fix this yet.
#
# What this does: replaces ONLY opencode's inner node_modules derivation with
# an identical copy carrying the platform-specific hash from c399e1b. The FOD
# body below is copied 1:1 from the pinned nixpkgs source; the only intentional
# difference is outputHash. Linux takes the got-hash this machine actually
# produced; Darwin takes master's value, so this stays valid for a darwin
# builder. Nothing else in the package set moves.
#
# Why overrideAttrs reaches it: the FOD is bound inside the expression (a
# `let`), so it is unreachable from outside — except through the derivation's
# own `node_modules` attribute, which is what configurePhase consumes
# ($node_modules). Overriding that attribute is the whole trick; the fork in
# the commented hplip.nix rejects "patch the package" approaches, and this is
# not one — it is the upstream fix, applied verbatim, minus the wait for the
# branch merge.
#
# REVISIT WHEN nixos-unstable picks up c399e1b: if `nix build nixpkgs#opencode`
# succeeds against the locked nixpkgs, delete this file.
_: {
  nixpkgs.overlays = [
    (_final: prev: {
      opencode = prev.opencode.overrideAttrs (_finalAttrs: previousAttrs: {
        node_modules = prev.stdenv.mkDerivation {
          pname = "${previousAttrs.pname}-node_modules";
          inherit (previousAttrs) version src;

          __structuredAttrs = true;
          strictDeps = true;

          impureEnvVars =
            prev.lib.fetchers.proxyImpureEnvVars
            ++ [
              "GIT_PROXY_COMMAND"
              "SOCKS_SERVER"
            ];

          nativeBuildInputs = [
            prev.bun
            prev.writableTmpDirAsHomeHook
          ];

          dontConfigure = true;

          buildPhase = ''
            runHook preBuild

            export BUN_INSTALL_CACHE_DIR=$(mktemp -d)
            bun install \
              --cpu="*" \
              --filter './' \
              --filter './packages/cli' \
              --filter './packages/desktop' \
              --filter './packages/app' \
              --frozen-lockfile \
              --ignore-scripts \
              --no-progress \
              --os="*"

            bun --bun ./nix/scripts/canonicalize-node-modules.ts
            bun --bun ./nix/scripts/normalize-bun-binaries.ts

            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall

            mkdir -p $out
            find . -type d -name node_modules -exec cp -R --parents {} $out \;

            # opencode targets only Linux and Darwin (see meta.platforms), so the
            # Windows executables that "bun install --os=*" fetches are never
            # executed. Dropping them keeps the output reproducible on hosts whose
            # security endpoint agents scan the store, and removes the vulnerable
            # bundled 7za.exe that will be quarantined.
            find $out -type f -name '*.exe' -delete

            runHook postInstall
          '';

          # NOTE: Required else we get errors that our fixed-output derivation references store paths
          dontFixup = true;

          outputHash =
            if prev.stdenv.hostPlatform.isLinux
            then "sha256-prx9dX7kUvs/E3zopkaPk5LXh3xJAy5sZeum/W8L7cA="
            else if prev.stdenv.hostPlatform.isDarwin
            then "sha256-dIveiaiPFGSItwLyeMuPDxTE9gpvvnlTCB/+nG24qCc="
            else throw "Unsupported platform";
          outputHashMode = "recursive";
        };
      });
    })
  ];
}
