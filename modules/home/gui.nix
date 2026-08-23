{pkgs, ...}: {
  home.packages = (
    with pkgs; [
      ## Multimedia
      imv
      obs-studio
      pavucontrol
      vlc

      ## Browsers (vanilla, un-nixified profiles: editable directly)
      chromium
      firefox

      ## Office / Productivity
      onlyoffice-desktopeditors
      filen-desktop
      libreoffice-fresh

      ## System / Utility
      gnome-disk-utility
      localsend
      zenity
      kdePackages.polkit-kde-agent-1
      hyprsunset
      supertuxkart

      ## GNOME apps (PDF viewer, archive manager)
      evince
    ]
  );
}
