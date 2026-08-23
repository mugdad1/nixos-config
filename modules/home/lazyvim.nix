{
  lib,
  pkgs,
  ...
}: {
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # runtime deps LazyVim expects on PATH: git for lazy.nvim, rg/fd/fzf for
  # telescope+snacks, gcc/make/tree-sitter for building parsers, nodejs/unzip/
  # curl/wget for mason downloads (nix-ld makes those binaries runnable).
  home.packages = with pkgs; [
    neovim
    git
    lazygit
    ripgrep
    fzf
    fd
    gcc
    gnumake
    tree-sitter
    unzip
    curl
    wget
    cargo
  ];

  # ~/.config/nvim is a writable copy of the repo source
  # (modules/home/lazyvim-config/) and is RE-SYNCED on every rebuild.
  # Edit the repo files, run nh os switch - never edit ~/.config/nvim
  # directly, local changes there are overwritten.
  home.activation.syncLazyVim = lib.hm.dag.entryAfter ["writeBoundary"] ''
    rm -rf "$HOME/.config/nvim"
    mkdir -p "$HOME/.config/nvim"
    cp -r ${./lazyvim-config}/. "$HOME/.config/nvim/"
    chmod -R u+w "$HOME/.config/nvim"
    echo "LazyVim config synced from nixos-config repo"
  '';
}
