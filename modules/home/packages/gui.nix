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
    mission-center
    zenity
    hyprpolkitagent

    ##creativity
    kdePackages.kdenlive

    ##
    filen-desktop

    ## Night light
    hyprsunset
  ];
}
