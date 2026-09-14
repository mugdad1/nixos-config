# riztile — tiling window manager for river (the river 0.4 "rivertile" successor).
#
# Built with the exact same strategy nixpkgs uses for river 0.4.8:
#   zig_0_16 + zig.fetchDeps (fetches build.zig.zon git deps) and the
#   wayland/xkbcommon system libs link in build.zig.
# Protocol XMLs (river-*) are vendored in-repo and codegen'd by zig-wayland's
# scanner, so no wlroots check — riztile is just a river WM client.
{
  lib,
  stdenv,
  fetchFromCodeberg,
  pkg-config,
  wayland,
  wayland-scanner,
  wayland-protocols,
  libxkbcommon,
  zig_0_16,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "riztile";
  version = "0.0.2";

  src = fetchFromCodeberg {
    owner = "abhinaya-aryal";
    repo = "riztile";
    rev = "137e1b56e926aae65e9f649c0b90d9bcec6651b0";
    hash = "sha256-PNuM+Re74n+tHyBO6dgSYzjZdfhJOZh0jmnjFO0l2wY=";
  };

  nativeBuildInputs = [
    pkg-config
    wayland-scanner
    zig_0_16
  ];

  buildInputs = [
    wayland
    wayland-scanner
    wayland-protocols
    libxkbcommon
  ];

  strictDeps = true;

  zigDeps = zig_0_16.fetchDeps {
    inherit (finalAttrs) src pname version;
    fetchAll = true;
    hash = "sha256-ZJnPsOUaHrp3RPfbXi+czYiNsBVJwhBNqePvEdOcnac=";
  };

  postConfigure = ''
    ln -s ${finalAttrs.zigDeps} "$ZIG_GLOBAL_CACHE_DIR/p"
  '';

  meta = {
    description = "Tiling window manager for the river Wayland compositor (TOML config, live reload)";
    homepage = "https://codeberg.org/abhinaya-aryal/riztile";
    license = lib.licenses.gpl3Only;
    mainProgram = "riztile";
    platforms = lib.platforms.linux;
  };
})
