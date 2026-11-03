# filen-desktop 3.0.53 — the official upstream AppImage, NOT nixpkgs'
# `filen-desktop`.
#
# WHY THE APPIMAGE: nixpkgs builds the same 3.0.53 from source, but that build
# is broken here (his report 2026-11-03: "in nixpkgs there is a filen-desktop
# but it is broken"). The AppImage is the artefact he actually downloaded and
# runs, so this wraps exactly those bytes instead of substituting a build.
#
# The 369 MB file is NOT committed: fetchurl pins the versioned CDN URL and the
# hash. `latest` was resolved on 2026-11-03 to v3.0.53 with the same
# content-length (368973202) as the file in ~/Downloads, so the versioned path
# is what is pinned below — a moving `latest` would silently change the hash.
#
# WHAT THIS DOES: appimageTools.wrapType2 extracts the squashfs once and wraps
# the bundled AppRun in an FHS environment carrying the libraries Electron
# expects. That is the supported way to run an AppImage on NixOS: no FUSE
# mount, no autoPatchelf, and the app's own bundled Electron/rclone stay
# intact.
#
# ROFI NEEDS A DESKTOP ENTRY, and the wrapper alone does not install one. The
# `extraInstallCommands` below copy the AppImage's own Filen.desktop and icon
# into $out/share and rewrite `Exec=AppRun` to the wrapped binary, so drun
# lists it like any other app. The icon keeps the name `Filen` because that is
# what the desktop file references.
{
  lib,
  appimageTools,
  fetchurl,
}: let
  pname = "filen-desktop";
  version = "3.0.53";

  src = fetchurl {
    url = "https://cdn.filen.io/@filen/desktop/release/v${version}/Filen_linux_x86_64.AppImage";
    # sha256 of the 368973202-byte v3.0.53 asset.
    hash = "sha256-iIKY24L6Q9e+P+7rqGovdF28H/3x76vizKUUSplkYfI=";
  };

  extracted = appimageTools.extract {inherit pname version src;};
in
  appimageTools.wrapType2 {
    inherit pname version src;

    extraInstallCommands = ''
      mkdir -p $out/share/applications
      cp ${extracted}/Filen.desktop $out/share/applications/filen-desktop.desktop
      substituteInPlace $out/share/applications/filen-desktop.desktop \
        --replace-fail 'Exec=AppRun' 'Exec=${pname}'

      mkdir -p $out/share/icons/hicolor/1024x1024/apps
      cp ${extracted}/usr/share/icons/hicolor/1024x1024/apps/Filen.png \
        $out/share/icons/hicolor/1024x1024/apps/Filen.png
    '';

    meta = {
      description = "Filen Desktop Client (official upstream AppImage)";
      homepage = "https://filen.io/products/desktop";
      license = lib.licenses.agpl3Only;
      platforms = ["x86_64-linux"];
      mainProgram = pname;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
