{
  pkgs,
  lib,
  host,
  ...
}: {
  home.packages = with pkgs;
    [
      ## C / C++
      gcc
      gdb
      gef
      cmake
      gnumake
      valgrind
      llvmPackages_latest.clang-tools

      ## Python
      python3
      python312Packages.ipython

      ## Tauri
      cargo-tauri
      webkitgtk_4_1
      openssl
      libsoup_3
      libappindicator-gtk3
      librsvg
    ]
    ++ lib.optionals (host == "rog") [
      mesa-demos
    ];
}
