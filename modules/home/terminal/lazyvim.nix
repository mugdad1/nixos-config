{
  lib,
  pkgs,
  ...
}: {
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # Runtime deps LazyVim expects on PATH.
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
  ];

  # ~/.config/nvim is a writable copy of the repo source, re-synced on every
  # rebuild. Edit the repo files, never ~/.config/nvim.
  home.activation.syncLazyVim = lib.hm.dag.entryAfter ["writeBoundary"] ''
    set -eu
    rm -rf "$HOME/.config/nvim"
    mkdir -p "$HOME/.config/nvim"
    cp -r ${./lazyvim-config}/. "$HOME/.config/nvim/"
    chmod -R u+w "$HOME/.config/nvim"
    echo "LazyVim config synced from nixos-config repo"
  '';
}
