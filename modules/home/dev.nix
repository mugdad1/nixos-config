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

    ## Python
    (python3.withPackages (
      ps:
      with ps; [
        pip
        fpdf2
        ipython
        python-docx # .docx generation (document/python-docx)
      ]
    ))

    ## Web dev (PHP / SQL)
    php
    phpPackages.composer
    sqlite
    dbeaver-bin

    ## Web LSPs & formatters system-wide (Mason-independent fallbacks)
    intelephense # PHP LSP
    vtsls # JS/TS LSP
    vscode-langservers-extracted # html/css/json LSPs
    typescript
    typescript-language-server
    bash-language-server
    prettierd

    ## Rust
    cargo-watch
    cargo-deny
    cargo-audit
    cargo-update
    cargo-edit
    cargo-outdated
    cargo-license
    cargo-tarpaulin
    cargo-cross
    cargo-zigbuild
    cargo-nextest
    cargo-spellcheck
    cargo-modules
    cargo-bloat
    cargo-sweep
    cargo-unused-features
    cargo-feature
    cargo-features-manager
    worker-build
    bacon
    evcxr
    rust-script
  ];

  # python3 is a Nix-built env: nixpkgs ships the PEP 668 EXTERNALLY-MANAGED
  # marker, so pip refuses to install even with `--user`. Prefer adding packages
  # to withPackages above (reproducible). This env var opts ONE-OFF user-space
  # pip installs back in (to ~/.local/lib/python3.x/site-packages).
  home.sessionVariables = {
    PIP_BREAK_SYSTEM_PACKAGES = "1";
  };
}
