{pkgs, ...}: {
  home.packages = with pkgs; [
    ## Better core utils
    btop # system monitor
    duf # disk information
    eza # ls replacement
    fd # find replacement
    gtrash # rm replacement, put deleted files in system trash
    ncdu # disk space
    ripgrep # grep replacement
    tldr
    xcp # faster cp written in Rust

    ## Tools / useful cli
    broot # tree files view
    just # command runner (makefile like)
    swappy # snapshot editing tool
    tdf # cli pdf viewer
    yt-dlp-light

    ## Multimedia
    imv
    ## Utilities
    binutils # GNU binary tools (strings, objdump, etc.)
    entr # perform action when file change
    ffmpeg
    file # Show file information
    jq # JSON processor
    killall
    ripdrag # drag and drop files from terminal
    strace # system call tracer
    libnotify
    mimeo
    openssl
    pamixer # pulseaudio command line mixer
    playerctl # controller for media players
    poweralertd
    socat
    udiskie # Automounter for removable media
    unzip
    wget
    wl-clipboard # clipboard utils for wayland (wl-copy, wl-paste)
    xdg-utils
  ];
}
