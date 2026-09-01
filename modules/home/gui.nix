{pkgs, ...}: let
  safeeyes-wrapped = pkgs.safeeyes.overridePythonAttrs (old: {
    propagatedBuildInputs =
      (old.propagatedBuildInputs or [])
      ++ (with pkgs.python3Packages; [
        pywayland
        croniter
      ]);
  });
  libreoffice-wrapped = pkgs.symlinkJoin {
    name = "libreoffice-wrapped";
    paths = [pkgs.libreoffice-stable];
    buildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/libreoffice \
        --set SAL_USE_VCLPLUGIN "gen"
    '';
  };
in {
  home.packages = (
    with pkgs; [
      ## Multimedia
      imv
      obs-studio
      pavucontrol
      vlc
      freetube
      ## Browsers (vanilla, un-nixified profiles: editable directly)
      chromium
      firefox
      tor-browser

      ## Office / Productivity
      onlyoffice-desktopeditors
      filen-desktop
      libreoffice-wrapped
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
