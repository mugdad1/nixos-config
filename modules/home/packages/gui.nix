{pkgs, ...}: {
  home.packages = with pkgs; [
    ## Multimedia
    obs-studio
    pavucontrol
    vlc

    ## Office
    libreoffice

    ## Utility
    gnome-disk-utility
    zenity
    kdePackages.polkit-kde-agent-1

    ## Creativity
    kdePackages.kdenlive

    ##
    filen-desktop

    ## Night light
    hyprsunset
  ];
}
