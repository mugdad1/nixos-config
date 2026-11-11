{pkgs, ...}: {
  home.packages = with pkgs; [
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

    ## Kernel / low-level build tooling
    bc
    bison
    flex
    dtc
    elfutils
    pahole
    cpio
    kmod

    ## Python
    (python3.withPackages (
      ps:
        with ps; [
          pip
          fpdf2
          ipython
          python-docx
        ]
    ))

    ## Web dev (PHP / SQL)
    php
    phpPackages.composer
    sqlite

    ## Web LSPs & formatters system-wide
    intelephense
    vtsls
    vscode-langservers-extracted
    typescript
    typescript-language-server
    bash-language-server
    prettierd
  ];

  # nixpkgs ships the PEP 668 marker; this opts one-off `pip --user` installs
  # back in. Prefer adding packages to withPackages above.
  home.sessionVariables = {
    PIP_BREAK_SYSTEM_PACKAGES = "1";
  };
}
