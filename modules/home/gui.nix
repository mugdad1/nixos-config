{pkgs, ...}: {
  home.packages = (
    with pkgs; [
      ## Multimedia
      imv
      obs-studio
      pavucontrol
      vlc
      vscodium-fhs

      ## Office / Productivity
      onlyoffice-desktopeditors
      filen-desktop
      libreoffice-fresh

      ## System / Utility
      gnome-disk-utility
      localsend
      zenity
      kdePackages.polkit-kde-agent-1
      mission-center
      hyprsunset
      supertuxkart

      ## GNOME apps (PDF viewer, archive manager)
      evince
      file-roller
    ]
  );
}
