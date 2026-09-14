# kwim — input manager for kwm (river's libinput/xkb keyboard config).
#
# kwm calls `kwim` automatically at startup when built with -Dkwim=true
# (the default), applying the user rules from ~/.config/kwim/config.zon.
{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  wayland,
  wayland-scanner,
  wayland-protocols,
  libxkbcommon,
  zig_0_16,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "kwim";
  version = "0.2.1";

  src = fetchFromGitHub {
    owner = "kewuaa";
    repo = "kwim";
    rev = "becc1284ccc8c5abdfb8a117b561a97f4448e9dd";
    hash = "sha256-Ob59H1535EYReXMCERdlTNfhwv2GGBCSCmvfIeJzzzo=";
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
    hash = "sha256-rOZZu/Y/rZ7who3hl1qIBHXZtRP7s4FXo0+LNnM6dYo=";
  };

  postConfigure = ''
    ln -s ${finalAttrs.zigDeps} "$ZIG_GLOBAL_CACHE_DIR/p"
  '';

  meta = {
    description = "Input manager for the kwm tiling window manager (river Wayland compositor)";
    homepage = "https://github.com/kewuaa/kwim";
    license = lib.licenses.gpl3Only;
    mainProgram = "kwim";
    platforms = lib.platforms.linux;
  };
})
