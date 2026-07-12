{pkgs, ...}: {
  home.packages = with pkgs; [
    ## File management
    eza # ls replacement
    ncdu # disk usage analyzer
    file # show file type info
    ripdrag # drag-and-drop from terminal
    unzip
    wget
btop
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
