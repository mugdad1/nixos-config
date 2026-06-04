{ pkgs, ... }:
{
  home.packages = with pkgs; [
    ## Multimedia
    audacity
    gimp
    obs-studio
    pavucontrol
    vlc

    ## Office
    libreoffice
    gnome-calculator

    ## Utility
    gnome-disk-utility
    mission-center # GUI resources monitor
    zenity

    ## Level editor
    tiled
    #creativity
    kdePackages.kdenlive
  ];
}
