{ ... }:
{
  programs.zsh = {
    shellAliases = {
      # Utils
      c = "clear";
      cd = "z";
      tt = "gtrash put";
      cat = "bat";

      code = "codium";
      diff = "delta --diff-so-fancy --side-by-side";
      less = "bat";
      copy = "wl-copy";
      f = "superfile";
      py = "python";
      ipy = "ipython";
      icat = "kitten icat";
      dsize = "du -hs";
      pdf = "tdf";
      open = "xdg-open";
      space = "ncdu";
      man = "batman";

      l = "eza --icons -a --group-directories-first -1 --no-user --long --git"; # EZA_ICON_SPACING=2
      tree = "eza --icons --tree --group-directories-first";

      # Nixos
      rebuild = "nh-notify nh os switch";
      update = "nh-notify nh os switch --update";
      nft = "nh-notify nh os test";
      nc = "nh-notify nh clean all --keep 5";
      ns = "nom-shell --run zsh";
      nsp = "nom-shell --run zsh -p";
      nb = "nom build";
      nd = "nom develop --command zsh";
      cdnix = "cd ~/nixos-config && codium ~/nixos-config";
      nsearch = "nh search";

      # gpu
      gpu = "gpu-mode";

      # python
      piv = "python -m venv .venv";
      psv = "source .venv/bin/activate";
    };
  };
}
