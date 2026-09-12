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

      # gruvbox file colors everywhere (ls/eza/fd/fzf)
      set -gx LS_COLORS (vivid generate gruvbox-dark)
      set -gx EZA_COLORS $LS_COLORS
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

      # Official starship gruvbox-rainbow preset, palette sourced from lib/gruvbox.nix
      palettes.gruvbox_dark = {
        color_fg0 = c.fg0;
        color_bg1 = c.bg1;
        color_bg3 = c.bg3;
        color_blue = c.blue;
        color_aqua = c.aqua;
        color_green = c.green;
        color_orange = c.orange;
        color_purple = c.purple;
        color_red = c.red;
        color_yellow = c.yellow;
      };

      format = ''
        [](color_orange)$os$username[](bg:color_yellow fg:color_orange)$directory[](fg:color_yellow bg:color_aqua)$git_branch$git_status[](fg:color_aqua bg:color_blue)$c$cpp$rust$golang$nodejs$bun$php$java$kotlin$haskell$python[](fg:color_blue bg:color_bg3)$docker_context$conda$pixi[](fg:color_bg3 bg:color_bg1)$time[ ](fg:color_bg1)$line_break$character'';

      # Kept from your p10k taste on top of the preset: status/duration/jobs right
      right_format = "$status$cmd_duration$jobs";

      os = {
        disabled = false;
        style = "bg:color_orange fg:color_fg0";
        format = "[$symbol ]($style)";
        symbols = {
          Windows = "󰍲";
          Ubuntu = "󰕈";
          SUSE = "";
          Raspbian = "󰐿";
          Mint = "󰣭";
          Macos = "󰀵";
          Manjaro = "";
          Linux = "󰌽";
          Gentoo = "󰣨";
          Fedora = "󰣛";
          Alpine = "";
          Amazon = "";
          Android = "";
          AOSC = "";
          Arch = "󰣇";
          Artix = "󰣇";
          EndeavourOS = "";
          CentOS = "";
          Debian = "󰣚";
          Redhat = "󱄛";
          RedHatEnterprise = "󱄛";
          Pop = "";
          NixOS = "";
        };
      };

      username = {
        show_always = true;
        style_user = "bg:color_orange fg:color_fg0";
        style_root = "bg:color_orange fg:color_fg0";
        format = "[ $user ]($style)";
      };

      directory = {
        style = "fg:color_fg0 bg:color_yellow";
        format = "[ $path ]($style)";
        truncation_length = 3;
        truncation_symbol = "…/";
        substitutions = {
          Documents = "󰈙 ";
          Downloads = " ";
          Music = "󰝚 ";
          Pictures = " ";
          Developer = "󰲋 ";
        };
      };

      git_branch = {
        symbol = "";
        style = "bg:color_aqua";
        format = "[[ $symbol $branch ](fg:color_fg0 bg:color_aqua)]($style)";
      };

      git_status = {
        style = "bg:color_aqua";
        format = "[[($all_status$ahead_behind )](fg:color_fg0 bg:color_aqua)]($style)";
      };

      nodejs = {
        symbol = "";
        style = "bg:color_blue";
        format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
      };

      bun = {
        symbol = "";
        style = "bg:color_blue";
        format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
      };

      c = {
        symbol = " ";
        style = "bg:color_blue";
        format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
      };

      cpp = {
        symbol = " ";
        style = "bg:color_blue";
        format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
      };

      rust = {
        symbol = "";
        style = "bg:color_blue";
        format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
      };

      golang = {
        symbol = "";
        style = "bg:color_blue";
        format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
      };

      php = {
        symbol = "";
        style = "bg:color_blue";
        format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
      };

      java = {
        symbol = "";
        style = "bg:color_blue";
        format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
      };

      kotlin = {
        symbol = "";
        style = "bg:color_blue";
        format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
      };

      haskell = {
        symbol = "";
        style = "bg:color_blue";
        format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
      };

      python = {
        symbol = "";
        style = "bg:color_blue";
        format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
      };

      docker_context = {
        symbol = "";
        style = "bg:color_bg3";
        format = "[[ $symbol( $context) ](fg:#83a598 bg:color_bg3)]($style)";
      };

      conda = {
        style = "bg:color_bg3";
        format = "[[ $symbol( $environment) ](fg:#83a598 bg:color_bg3)]($style)";
      };

      pixi = {
        style = "bg:color_bg3";
        format = "[[ $symbol( $version)( $environment) ](fg:color_fg0 bg:color_bg3)]($style)";
      };

      # Not in the preset — your  segment, styled into the env (bg3) block
      nix_shell = {
        symbol = " ";
        style = "bg:color_bg3";
        format = "[[ $symbol ](fg:color_fg0 bg:color_bg3)]($style)";
      };

      time = {
        disabled = false;
        time_format = "%R";
        style = "bg:color_bg1";
        format = "[[  $time ](fg:color_fg0 bg:color_bg1)]($style)";
      };

      line_break.disabled = false;

      character = {
        disabled = false;
        success_symbol = "[](bold fg:color_green)";
        error_symbol = "[](bold fg:color_red)";
        vimcmd_symbol = "[](bold fg:color_green)";
        vimcmd_replace_one_symbol = "[](bold fg:color_purple)";
        vimcmd_replace_symbol = "[](bold fg:color_purple)";
        vimcmd_visual_symbol = "[](bold fg:color_yellow)";
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
    };
  };
}
