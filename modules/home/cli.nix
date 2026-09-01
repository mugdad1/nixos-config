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
    btop
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

    ## Misc
    just # command runner
    opencode
    cliamp
    poweralertd
    lazygit # TUI git (pairs with the gh aliases above)
    rsync # sync/copy

    ## Nix
    nvd # Nix/NixOS package version diff tool
    nix-output-monitor # Processes output of Nix commands to show helpful and pretty information
  ];
}
