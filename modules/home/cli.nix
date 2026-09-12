{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.nix-index-database.homeModules.nix-index
  ];

  programs = {
    nix-index = {
      enable = true;
      symlinkToCacheHome = true;
      enableZshIntegration = true;
      enableFishIntegration = true;
    };

    nix-index-database.comma.enable = true;
  };

  home.packages = with pkgs; [
    ## File management
    eza # ls replacement
    ncdu # disk usage analyzer
    duf # friendlier `df`
    dust # faster `du`
    fd # find alternative (used by fzf)
    ripgrep # recursive grep (rg)
    ripgrep-all # search inside pdfs/zips/etc. (rga)
    dnsutils # dig / host
    file # show file type info
    ripdrag # drag-and-drop from terminal
    unzip
    wget
    vivid # LS_COLORS generator (gruvbox-dark wired in shell init)
    tealdeer # tldr man pages
    glow # render markdown in the terminal
    ## Media / processing
    ffmpeg
    yt-dlp
    deno
    nodejs
    pamixer # pulseaudio cli mixer
    playerctl # media player controller
    swappy # screenshot editor
    mimeo

    ## System / debugging
    binutils
    brightnessctl
    entr # run command on file change
    jq
    killall
    strace
    libnotify
    socat
    udiskie # auto-mounter
    wl-clipboard # wayland clipboard
    xdg-utils
    opencode
    ## Misc
    just # command runner
    cliamp
    poweralertd
    rsync # sync/copy

    ## Nix
    nvd # Nix/NixOS package version diff tool
    nix-output-monitor # Processes output of Nix commands to show helpful and pretty information
  ];

  programs.btop = {
    enable = true;
    settings = {
      color_theme = "gruvbox_material_dark";
      vim_keys = true;
    };
  };

  programs.lazygit = let
    gl = (import ../../lib/gruvbox.nix).raw;
    H = v: "#${v}";
  in {
    enable = true;
    settings = {
      gui = {
        theme = {
          activeBorderColor = [(H gl.bright_orange) "bold"];
          inactiveBorderColor = [(H gl.gray)];
          searchingActiveBorderColor = [(H gl.bright_orange) "bold"];
          optionsTextColor = [(H gl.bright_blue)];
          selectedLineBgColor = [(H gl.bg1)];
          cherryPickedCommitFgColor = [(H gl.bright_blue)];
          cherryPickedCommitBgColor = [(H gl.red)];
          markedBaseCommitFgColor = [(H gl.bright_blue)];
          markedBaseCommitBgColor = [(H gl.yellow)];
          unstagedChangesColor = [(H gl.red)];
          defaultFgColor = [(H gl.fg)];
        };
      };
    };
  };
}
