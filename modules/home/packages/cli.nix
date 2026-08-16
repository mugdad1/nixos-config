{pkgs, ...}: {
  home.packages = with pkgs; [
    ## File management
    eza # ls replacement
    ncdu # disk usage analyzer
    duf # friendlier `df`
    dust # faster `du`
    fd # find alternative (used by fzf)
    ripgrep # recursive grep (rg)
    ripgrep-all # search inside pdfs/zips/etc. (rga)
    yazi # terminal file manager
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
    yt-dlp-light
    pamixer # pulseaudio cli mixer
    playerctl # media player controller
    swappy # screenshot editor
    mimeo

    ## System / debugging
    binutils
    entr # run command on file change
    jq
    killall
    strace
    libnotify
    openssl
    socat
    udiskie # auto-mounter
    wl-clipboard # wayland clipboard
    xdg-utils

    ## Misc
    just # command runner
    opencode
    cliamp
    poweralertd
  ];
}
