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
      rebuild = "nh os switch ~/nixos-config 2>&1 | nom";
      update = "nh os switch ~/nixos-config --update 2>&1 | nom";
      nft = "nh-notify nh os test";
      nc = "nh-notify nh clean all --keep 1";
      nsearch = "nh search";

      # python
      piv = "python -m venv .venv";
      psv = "source .venv/bin/activate";
    };
  };
}
