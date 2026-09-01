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
    (python3.withPackages (ps: with ps; [pip fpdf2]))
    python312Packages.ipython

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

    ## Tauri
    cargo-tauri
    webkitgtk_4_1
    openssl
    libsoup_3
    libappindicator-gtk3
    gtk3
    gobject-introspection
    gdk-pixbuf
    atk

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
}
