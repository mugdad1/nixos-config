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

    ## FOSS free games (no Steam)
    supertuxkart # kart racing
    pkgs.zeroad # historical RTS (Age-of-Empires-like)
    luanti # voxel sandbox (Minecraft-like)
  ];
}
