{ pkgs, ... }:
{
  home.packages = with pkgs; [
    ## Better core utils
    duf # disk information
    eza # ls replacement
    fd # find replacement
    gping # ping with a graph
    gtrash # rm replacement, put deleted files in system trash
    hexyl # hex viewer
    man-pages # extra man pages
    ncdu # disk space
    ripgrep # grep replacement
    tldr

    ## Tools / useful cli
    opencode
    asciinema
    asciinema-agg
    broot # tree files view
    just # command runner (makefile like)
    scooter # Interactive find and replace in the terminal
    swappy # snapshot editing tool
    tdf # cli pdf viewer
    yt-dlp-light

    ## TUI
    epy # ebook reader

    ## Monitoring / fetch
    htop
    onefetch # fetch utility for git repo
    wavemon # monitoring for wireless network devices

    ## Multimedia
    imv
    lowfi
    mpv

    ## Utilities
    entr # perform action when file change
    ffmpeg
    file # Show file information
    jq # JSON processor
    killall
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
