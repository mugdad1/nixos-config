{
  pkgs,
  lib,
  host,
  ...
}: {
  home.packages = with pkgs;
    [
      ## Nix
      alejandra
      nixd
      statix
      deadnix
      shfmt
      shellcheck
      treefmt

      ## C / C++
      gcc
      gdb
      gef
      cmake
      gnumake
      valgrind
      llvmPackages_latest.clang-tools

      ## Python
      (python3.withPackages (ps: with ps; [pip fpdf2]))
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
