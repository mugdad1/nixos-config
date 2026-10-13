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
          python-docx # .docx generation (document/python-docx)
        ]
    ))

    ## Web dev (PHP / SQL)
    php
    phpPackages.composer
    sqlite
    # dbeaver-bin  # DISABLED 2026-10-13 on his word. Commented, not deleted.

    ## Web LSPs & formatters system-wide (Mason-independent fallbacks)
    intelephense # PHP LSP
    vtsls # JS/TS LSP
    vscode-langservers-extracted # html/css/json LSPs
    typescript
    typescript-language-server
    bash-language-server
    prettierd

    ## ─── DISABLED 2026-10-13 on his word ───────────────────────────────────
    ## Rust tooling. He does not use Rust. These are the cargo-* helpers plus
    ## rust-script/bacon/evcxr — they only make sense alongside a toolchain,
    ## and the toolchain itself (modules/core/rust.nix) is disabled too.
    ## Commented out, not deleted: uncomment to re-enable.
    ##
    ## Note: rustc/cargo themselves are NOT listed here — they came from the
    ## toolchain in core/rust.nix, so turning that off is what removed them.
    ## `worker-build` (line 76 below) is a Leptos/Trunk helper that needs a
    ## Rust toolchain to do anything useful, so it is off as well.
    # cargo-watch
    # cargo-deny
    # cargo-audit
    # cargo-update
    # cargo-edit
    # cargo-outdated
    # cargo-license
    # cargo-tarpaulin
    # cargo-cross
    # cargo-zigbuild
    # cargo-nextest
    # cargo-spellcheck
    # cargo-modules
    # cargo-bloat
    # cargo-sweep
    # cargo-unused-features
    # cargo-feature
    # cargo-features-manager
    # worker-build
    # bacon
    # evcxr
    # rust-script
  ];

  # python3 is a Nix-built env: nixpkgs ships the PEP 668 EXTERNALLY-MANAGED
  # marker, so pip refuses to install even with `--user`. Prefer adding packages
  # to withPackages above (reproducible). This env var opts ONE-OFF user-space
  # pip installs back in (to ~/.local/lib/python3.x/site-packages).
  home.sessionVariables = {
    PIP_BREAK_SYSTEM_PACKAGES = "1";
  };
}
