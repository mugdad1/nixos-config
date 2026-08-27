{...}: {
  programs.zsh = {
    shellAliases = {
      # Utils
      c = "clear";
      cd = "z";
      cat = "bat";

      diff = "delta --diff-so-fancy --side-by-side";
      less = "bat";
      copy = "wl-copy";
      py = "python3";
      ipy = "ipython";
      dsize = "du -hs";
      open = "xdg-open";
      space = "ncdu";
      man = "batman";

      l = "eza --icons -a --group-directories-first -1 --no-user --long --git"; # EZA_ICON_SPACING=2
      tree = "eza --icons --tree --group-directories-first";

      # disk / docs
      df = "duf";
      du = "dust";
      tldr = "tealdeer";

      # git / nix
      lg = "lazygit";
      nr = "nh os switch";
      nup = "nh os switch --update";
      hms = "nh home switch";

      # python
      piv = "python -m venv .venv";
      psv = "source .venv/bin/activate";

      # safe delete — uses trash-cli instead of permanent rm
      rm = "trash-put";
      rmrf = "trash-put";
      rmi = "rm -i";
      rmt = "trash-list"; # list trash contents
      rmr = "trash-restore"; # restore from trash
      rmempty = "trash-empty"; # empty the trash
    };
  };
}
