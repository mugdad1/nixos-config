{pkgs, ...}: {
  home.packages = with pkgs; [
    ## Multimedia
    imv
    obs-studio
    pavucontrol
    vlc
    vscodium-fhs
    ## Browsers
    firefox-bin

    ## Office / Productivity
    onlyoffice-desktopeditors
    filen-desktop

    ## System / Utility
    gnome-disk-utility
    zenity
    kdePackages.polkit-kde-agent-1
    mission-center
    hyprsunset
  ];
}
