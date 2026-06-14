{...}: {
  programs.zsh = {
    shellAliases = {
      # Utils
      c = "clear";
      cd = "z";
      tt = "gtrash put";
      cat = "bat";

      diff = "delta --diff-so-fancy --side-by-side";
      less = "bat";
      copy = "wl-copy";
      py = "python";
      ipy = "ipython";
      dsize = "du -hs";
      pdf = "tdf";
      open = "xdg-open";
      space = "ncdu";
      man = "batman";

      l = "eza --icons -a --group-directories-first -1 --no-user --long --git"; # EZA_ICON_SPACING=2
      tree = "eza --icons --tree --group-directories-first";

      # Nixos
      rebuild = "cd ~/nixos-config && nix flake check && sudo nixos-rebuild switch --flake ~/nixos-config#rog";
      update = "cd ~/nixos-config && nix flake update && nix flake check && sudo nixos-rebuild switch --flake ~/nixos-config#rog";
      nft = "nh-notify nh os test";
      nc = "nh-notify nh clean all --keep 5";
      ns = "nom-shell --run zsh";
      nsp = "nom-shell --run zsh -p";
      nb = "nom build";
      nd = "nom develop --command zsh";
      nsearch = "nh search";

      # gpu
      gpu = "gpu-mode";

      # python
      piv = "python -m venv .venv";
      psv = "source .venv/bin/activate";
    };
  };
}
