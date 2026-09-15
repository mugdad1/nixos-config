{
  pkgs,
  variables,
  ...
}: let
  c = (import ../../lib/theme.nix variables).css;
in {
  programs.bat = {
    enable = true;
    config = {
      pager = "less -FR";
      theme = "gruvbox-dark";
    };
    extraPackages = with pkgs.bat-extras; [
      batman
      batpipe
    ];
  };

  programs.direnv = {
    enable = true;
    enableFishIntegration = true;
    nix-direnv.enable = true;
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    flags = ["--disable-up-arrow" "--disable-ctrl-r"];
    settings = {
      auto_sync = true;
      sync_frequency = "5m";
      search_mode = "fuzzy";
      filter_mode_shell = "host";
      filter_mode = "global";
      show_preview = true;
      secrets_filter = true;
    };
  };

  programs.fzf = {
    enable = true;
    enableFishIntegration = true;

    defaultCommand = "fd --hidden --strip-cwd-prefix --exclude .git";
    fileWidget = {
      options = [
        "--preview 'if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi'"
      ];
    };
    changeDirWidget = {
      command = "fd --type=d --hidden --strip-cwd-prefix --exclude .git";
      options = [
        "--preview 'eza --tree --color=always {} | head -200'"
      ];
    };

    ## Theme
    defaultOptions = [
      "--color=fg:-1,fg+:${c.fg0},bg:-1,bg+:${c.bg0}"
      "--color=hl:${c.accent},hl+:${c.bright_accent},info:${c.light_gray},marker:${c.orange}"
      "--color=prompt:${c.red},spinner:${c.aqua},pointer:${c.orange},header:${c.blue}"
      "--color=border:${c.bg3},label:${c.light_gray},query:${c.fg0}"
      "--border='double' --border-label='' --preview-window='border-sharp' --prompt='> '"
      "--marker='>' --pointer='>' --separator='─' --scrollbar='│'"
      "--info='right'"
      "--bind change:top"
    ];
  };
}
