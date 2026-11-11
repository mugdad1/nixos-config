# filen-cli 0.2.9 (Rust build) from the upstream static musl binary. nixpkgs
# still ships the old 0.0.36 Go implementation.
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
      sha256 = "9beec4db57991491f6464cb6eee8823bcf68a54a6b790133b6aa94717960ea8b";
    };

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
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
