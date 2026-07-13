{pkgs, ...}: {
  home.packages = with pkgs; [
    ## Multimedia
    imv
    obs-studio
    pavucontrol
    vlc
    vscodium-fhs
    ## Browsers

    ## Office / Productivity
    onlyoffice-desktopeditors
    filen-desktop
    libreoffice-fresh

    ## System / Utility
    gnome-disk-utility
    zenity
    kdePackages.polkit-kde-agent-1
    mission-center
    hyprsunset
  ];
}
