# filen-cli 0.2.9 — the Rust build (filen-rs), packaged from the upstream
# prebuilt binary.
#
# WHY NOT nixpkgs' OWN `filen-cli`: nixpkgs carries 0.0.36, which is the OLD
# Go implementation — the 117 MB binary that was installed on this box by the
# filen-cli repo's curl|bash before 2026-10-15. He called it old and asked for
# the Rust one (github.com/FilenCloudDienste/filen-rs). Upstream tags the Rust
# build 0.2.9, matching filen-rs/filen-cli's Cargo.toml, and publishes it from
# the separate FilenCloudDienste/filen-cli-releases repo.
#
# WHY THE musl BUILD AND NOT gnu: the gnu asset is dynamically linked against
# /lib64/ld-linux-x86-64.so.2, which does not exist on NixOS — it would need
# patchelf to run at all. The musl asset is `static-pie linked` with no
# PT_INTERP and no NEEDED entries, so it carries its own libc and runs on any
# NixOS host unchanged. Verified 2026-10-15 with `readelf -d` (no NEEDED) and
# by running it directly. This is also why there is no `autoPatchelfHook` and
# no `makeWrapper` below: there is nothing to patch and nothing to wrap.
#
# WHY PREBUILT AND NOT `rustPlatform.buildRustPackage`: filen-rs pins
# nightly-2026-02-20 in its rust-toolchain.toml (it needs the
# `-Zhigher-ranked-assumptions` nightly flag, set in .cargo/config.toml), and
# its workspace wants clang + the `wild` linker + CMake for heif-decoder. That
# is a large toolchain to pull into the closure for one CLI, and the upstream
# binary is reproducible by tag. If he later wants it built from source, the
# pinned nightly is the thing to line up first.
{
  lib,
  fetchurl,
  stdenv,
}: let
  version = "0.2.9";
in
  stdenv.mkDerivation rec {
    pname = "filen-cli";
    inherit version;

    src = fetchurl {
      url = "https://github.com/FilenCloudDienste/filen-cli-releases/releases/download/${version}/filen-cli-${version}-x86_64-unknown-linux-musl";
      # pinned to the exact bytes of the 0.2.9 musl asset.
      sha256 = "9beec4db57991491f6464cb6eee8823bcf68a54a6b790133b6aa94717960ea8b";
    };

    dontUnpack = true;
    # No build phase: it is already a compiled static binary.
    dontConfigure = true;
    dontBuild = true;
    # No tests to run, and `filen --version` needs no network or config.
    doCheck = false;

    installPhase = ''
      runHook preInstall
      install -Dm755 "$src" "$out/bin/filen"
      runHook postInstall
    '';

    meta = {
      description = "Filen CLI — zero-knowledge cloud storage, Rust build (filen-rs)";
      homepage = "https://github.com/FilenCloudDienste/filen-rs";
      license = lib.licenses.agpl3Only;
      platforms = ["x86_64-linux"];
      mainProgram = "filen";
    };
  }
