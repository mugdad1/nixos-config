{
  pkgs,
  lib,
  host,
  ...
}: {
  home.packages = with pkgs;
    [
      ## Nix
      nixd
      nixfmt
      shfmt
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
      python3
      python312Packages.ipython
    ]
    ++ lib.optionals (host == "rog") [
      mesa-demos
    ];
}
