# filen-desktop 3.0.53, wrapped from the official upstream AppImage (the
# nixpkgs build is broken on this box). The AppImage is fetched, not committed.
{
  lib,
  appimageTools,
  fetchurl,
}: let
  pname = "filen-desktop";
  version = "3.0.53";

  src = fetchurl {
    url = "https://cdn.filen.io/@filen/desktop/release/v${version}/Filen_linux_x86_64.AppImage";
    hash = "sha256-iIKY24L6Q9e+P+7rqGovdF28H/3x76vizKUUSplkYfI=";
  };

  extracted = appimageTools.extract {inherit pname version src;};
in
  appimageTools.wrapType2 {
    inherit pname version src;

    # Install the AppImage's own desktop entry and icon so rofi lists it.
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
