# WHPH 0.24.4 — "Work Hard Play Hard", his productivity app (tasks, habits,
# timers, notes) from github.com/ahmet-cetinkaya/whph, packaged from the
# upstream prebuilt Linux bundle (GPL-3.0, LICENSE file in the repo).
#
# WHY PREBUILT AND NOT buildFromSource: upstream publishes no tag-to-source
# build path for the Linux desktop target -- the release tarball is a Flutter
# `linux --release` bundle (launcher + engine + plugins). Building Flutter
# apps from source on NixOS means pinning the Flutter SDK, which nixpkgs'
# flutter package historically cannot do reproducibly for third-party apps.
# The bundle is reproducible by tag + sha256, same argument as filen-cli.
#
# WHY autoPatchelfHook IS REQUIRED HERE (and not in filen-cli.nix): the
# launcher and the 10 bundled plugin .so's are dynamically linked against
# /lib64/ld-linux-x86-64.so.2 and a wall of GTK3/X11/gstreamer/ayatana
# libraries that do not exist on NixOS. Verified with readelf on every ELF in
# the tarball: launcher needs SM/ICE/X11/Xext + GTK3 stack; libflutter needs
# epoxy + fontconfig; plugins need gstreamer (audioplayers), ayatana
# appindicator + dbusmenu (tray), and the rest of the GTK3 set.
#
# WHY A SHELL WRAPPER IN $out/bin AND NOT A SYMLINK: wrapGAppsHook3 wraps
# $out/bin/* with the GTK/schema environment; wrapping a symlink moves it.
# A tiny exec script wraps cleanly, and Flutter resolves lib/ and data/
# through /proc/self/exe, so the real bundle location ($out/lib/whph) is
# found regardless of how the launcher was started.
#
# BUNDLE LAYOUT (kept verbatim from the tarball, Flutter expects it):
#   $out/lib/whph/whph       launcher ELF
#   $out/lib/whph/lib/*.so   engine + plugins, rpath'd to their own dir
#   $out/lib/whph/data/      flutter_assets + icudtl.dat, read at runtime
#   $out/share/              .desktop, hicolor icons, dbus service
{
  lib,
  fetchurl,
  stdenv,
  autoPatchelfHook,
  wrapGAppsHook3,
  gtk3,
  glib,
  zlib,
  pango,
  cairo,
  atk,
  gdk-pixbuf,
  harfbuzz,
  fontconfig,
  libepoxy,
  xorg,
  gst_all_1,
  libayatana-appindicator,
  ayatana-ido,
  libayatana-indicator,
  libdbusmenu,
}:
stdenv.mkDerivation rec {
  pname = "whph";
  version = "0.24.4";

  src = fetchurl {
    url = "https://github.com/ahmet-cetinkaya/whph/releases/download/v${version}/whph-v${version}-linux.tar.gz";
    sha256 = "sha256-nKvxrohk0kHu3Wczkrj0AkRGHiZZwsVbELvrZpUjS1Q=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook3
  ];

  buildInputs = [
    gtk3
    glib
    zlib
    pango
    cairo
    atk
    gdk-pixbuf
    harfbuzz
    fontconfig
    libepoxy
    xorg.libSM
    xorg.libICE
    xorg.libX11
    xorg.libXext
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    libayatana-appindicator
    ayatana-ido
    libayatana-indicator
    libdbusmenu
  ];

  # The tarball has no single top-level dir (contents are ./whph, ./lib,
  # ./data, ./share directly), so unpackPhase's default would fail on
  # "multiple top-level directories"; point it at '.' instead of fighting it.
  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;
  doCheck = false;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/whph
    cp -r whph lib data $out/lib/whph/
    chmod +x $out/lib/whph/whph
    cp -r share $out/share

    mkdir -p $out/bin
    cat > $out/bin/whph <<EOF
    #!/bin/sh
    # WHPH resolves lib/ and data/ through /proc/self/exe, so the launcher
    # must run from its bundle dir; this wrapper only supplies the path.
    exec $out/lib/whph/whph "\$@"
    EOF
    chmod +x $out/bin/whph

    runHook postInstall
  '';

  # The bundled engine + plugin .so's live in $out/lib/whph/lib; the launcher
  # finds them through its own directory (/proc/self/exe), so both need that
  # dir on their rpath before autoPatchelf resolves the SYSTEM NEEDED entries.
  preFixup = ''
    addAutoPatchelfSearchPath "$out/lib/whph/lib"
  '';

  meta = {
    description = "WHPH — tasks, habits and time tracking (Work Hard Play Hard)";
    homepage = "https://github.com/ahmet-cetinkaya/whph";
    license = lib.licenses.gpl3Only;
    platforms = ["x86_64-linux"];
    mainProgram = "whph";
  };
}
