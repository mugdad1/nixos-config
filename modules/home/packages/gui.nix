{pkgs, ...}: {
  home.packages = with pkgs; [
    ## Multimedia
    imv
    obs-studio
    pavucontrol
    vlc
    audacity

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

    vscodium-fhs
    ## Night light
    hyprsunset
  ];
}
