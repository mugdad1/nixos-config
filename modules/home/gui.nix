{pkgs, ...}: let
  safeeyes-wrapped = pkgs.safeeyes.overridePythonAttrs (old: {
    propagatedBuildInputs =
      (old.propagatedBuildInputs or [])
      ++ (with pkgs.python3Packages; [
        pywayland
        croniter
      ]);
  });
in {
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
      tor-browser

      ## Office / Productivity
      onlyoffice-desktopeditors
      filen-desktop
      libreoffice-stable
      odin
      ## System / Utility
      qbittorrent
      gnome-disk-utility
      localsend
      zenity
      kdePackages.polkit-kde-agent-1
      hyprsunset
      safeeyes-wrapped
      supertuxkart

      ## GNOME apps (PDF viewer, archive manager)
      evince
    ]
  );
}
