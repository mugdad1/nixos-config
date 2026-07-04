{pkgs, ...}: {
  home.packages = with pkgs; [
    ## Better core utils
    eza # ls replacement
    ncdu # disk space

    ## Tools / useful cli
    just # command runner (makefile like)
    swappy # snapshot editing tool
    yt-dlp-light
    opencode
    cliamp
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
