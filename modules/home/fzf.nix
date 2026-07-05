{...}: let
  c = (import ../gruvbox.nix).raw;
in {
  programs.fzf = {
    enable = true;

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
      "--color=hl:${c.green},hl+:${c.bright_green},info:${c.light_gray},marker:${c.orange}"
      "--color=prompt:${c.red},spinner:${c.aqua},pointer:${c.orange},header:${c.blue}"
      "--color=border:${c.bg3},label:${c.light_gray},query:${c.fg0}"
      "--border='double' --border-label='' --preview-window='border-sharp' --prompt='> '"
      "--marker='>' --pointer='>' --separator='─' --scrollbar='│'"
      "--info='right'"
      "--bind change:top"
    ];
  };
}
