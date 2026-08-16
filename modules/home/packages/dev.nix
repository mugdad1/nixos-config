{
  pkgs,
  lib,
  host,
  ...
}: {
  home.packages = with pkgs;
    [
      ## Nix
      alejandra # nix formatter (matches the flake formatter)
      nixd
      nixfmt
      statix # nix lints
      deadnix # find dead nix code
      shfmt
      shellcheck # shell lints
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
