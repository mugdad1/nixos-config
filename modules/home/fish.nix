{pkgs, ...}: let
  c = (import ../../lib/gruvbox.nix).css;
in {
  programs.fish = {
    enable = true;

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

      l = "eza --icons -a --group-directories-first -1 --no-user --long --git";
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

      # safe delete (trash-cli in modules/core/packages.nix — do not remove)
      rm = "trash-put";
      rmrf = "trash-put";
      rmi = "command rm -i";
      rmt = "trash-list";
      rmr = "trash-restore";
      rmempty = "trash-empty";
    };

    functions = {
      # Fish-native venv activate (bash activate is not sourceable in fish)
      psv = {
        description = "Activate .venv using its fish script";
        body = ''
          if test -f .venv/bin/activate.fish
            source .venv/bin/activate.fish
          else if test -f .venv/bin/activate
            echo "psv: .venv has no activate.fish (bash-only venv)"
            return 1
          else
            echo "psv: no .venv here (try piv first)"
            return 1
          end
        '';
      };
    };

    interactiveShellInit = ''
      set -g fish_greeting ""

      # Ctrl-E edits the command line in $EDITOR (nvim), like zsh
      bind \ce edit_command_buffer

      # fzf.fish previews mirror the zsh _fzf_comprun setup
      set -g fzf_preview_file_cmd 'bat -n --color=always --line-range :500'
      set -g fzf_preview_dir_cmd 'eza --tree --color=always | head -200'
      set -g fzf_fd_opts --hidden --strip-cwd-prefix --exclude .git

      # 'done' plugin: only notify for commands longer than 8s
      set -g __done_min_command_duration 8000
    '';

    plugins = [
      # gruvbox-dark theme for the shell itself
      {
        name = "gruvbox";
        src = pkgs.fishPlugins.gruvbox.src;
      }
      # auto-close brackets/quotes
      {
        name = "autopair-fish";
        src = pkgs.fishPlugins.autopair-fish.src;
      }
      # Ctrl-T / Ctrl-R / Alt-C fuzzy finders (PatrickF1)
      {
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish.src;
      }
      # colored man pages via bat
      {
        name = "colored-man-pages";
        src = pkgs.fishPlugins.colored-man-pages.src;
      }
      # auto-scrub typos/failed commands from history
      {
        name = "sponge";
        src = pkgs.fishPlugins.sponge.src;
      }
      # expand ... -> ../.., .... -> ../../.. etc.
      {
        name = "puffer";
        src = pkgs.fishPlugins.puffer.src;
      }
      # desktop notification when long commands finish
      {
        name = "done";
        src = pkgs.fishPlugins.done.src;
      }
      # run bash scripts with env capture: bass source script.sh
      {
        name = "bass";
        src = pkgs.fishPlugins.bass.src;
      }
    ];
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;

    settings = {
      palette = "gruvbox_dark";

      palettes.gruvbox_dark = {
        bg = c.bg0;
        fg = c.fg;
        black = c.bg1;
        red = c.bright_red;
        green = c.bright_green;
        yellow = c.bright_yellow;
        blue = c.bright_blue;
        purple = c.bright_purple;
        cyan = c.bright_aqua;
        white = c.fg0;
        orange = c.bright_orange;
        gray = c.gray;
      };

      # LEFT: dir -> git -> nix, newline; RIGHT: status -> duration -> jobs -> time
      format = "$directory$git_branch$git_status$nix_shell$line_break$character";
      right_format = "$status$cmd_duration$jobs$time";

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };

      directory = {
        truncation_length = 3;
        truncation_symbol = "…/";
        style = "bold blue";
        read_only = " 🔒";
        read_only_style = "red";
      };

      git_branch = {
        symbol = " ";
        style = "bold purple";
        truncation_length = 32;
      };

      git_status = {
        ahead = "⇡";
        behind = "⇣";
        diverged = "⇕";
        untracked = "?";
        modified = "!";
        staged = "+";
        stashed = "\\$";
        renamed = "»";
        deleted = "✘";
        style = "bold yellow";
      };

      nix_shell = {
        symbol = " ";
        format = "via [$symbol]($style)";
        style = "bold blue";
      };

      cmd_duration = {
        min_time = 1000;
        format = "took [$duration]($style)";
        style = "bold yellow";
      };

      jobs = {
        symbol = "✦";
        format = "[$symbol$number]($style)";
        style = "bold blue";
      };

      status = {
        disabled = false;
        success_symbol = "[✔](bold green)";
        symbol = "[✘](bold red)";
        map_symbol = true;
      };

      time = {
        disabled = false;
        format = "at [$time]($style)";
        time_format = "%H:%M";
        style = "bold gray";
      };

      line_break.disabled = false;
    };
  };
}
