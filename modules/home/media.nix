{ pkgs
, lib
, ...
}:
let
  safeeyes-wrapped = pkgs.safeeyes.overridePythonAttrs (old: {
    propagatedBuildInputs =
      (old.propagatedBuildInputs or [ ])
      ++ (with pkgs.python3Packages; [
        pywayland
        croniter
      ]);
  });
  libreoffice-wrapped = pkgs.symlinkJoin {
    name = "libreoffice-wrapped";
    paths = [ pkgs.libreoffice-stable ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/libreoffice \
        --set SAL_USE_VCLPLUGIN "gen"
    '';
  };
in
{
  home.packages = (
    with pkgs; [
      ## Multimedia
      imv
      obs-studio
      pavucontrol
      vlc
      freetube

      ## Browsers (vanilla, un-nixified profiles: editable directly)
      firefox
      tor-browser

      ## Office / Productivity
      onlyoffice-desktopeditors
      filen-desktop
      libreoffice-wrapped
      ## System / Utility
      qbittorrent
      gnome-disk-utility
      localsend
      zenity
      kdePackages.polkit-kde-agent-1
      hyprsunset
      safeeyes-wrapped

      ## GNOME apps (PDF viewer, archive manager)
      evince

      ## File manager
      nemo-with-extensions
      nemo-fileroller
    ]
  );

  dconf.settings = {
    "org/nemo/preferences" = {
      always-use-browser = true;
      close-device-view-on-device-eject = true;
      date-font-choice = "auto-mono";
      date-format = "iso";
      last-server-connect-method = 3;
      quick-renames-with-pause-in-between = true;
      show-edit-icon-toolbar = false;
      show-full-path-titles = false;
      show-hidden-files = true;
      show-home-icon-toolbar = true;
      show-new-folder-icon-toolbar = true;
      show-open-in-terminal-toolbar = false;
      show-search-icon-toolbar = false;
      show-show-thumbnails-toolbar = false;
      thumbnail-limit = lib.gvariant.mkUint64 (100 * 1024 * 1024); # 100 mb
    };
    "org/nemo/preferences/menu-config" = {
      background-menu-open-as-root = false;
      selection-menu-open-as-root = false;
      selection-menu-open-in-terminal = false;
      selection-menu-scripts = false;
    };
    "org/nemo/search" = {
      search-reverse-sort = false;
      search-sort-column = "name";
    };
    "org/nemo/window-state" = {
      maximized = true;
      network-expanded = true;
      side-pane-view = "places";
      sidebar-bookmark-breakpoint = 2;
      sidebar-width = lib.gvariant.mkInt32 180;
      start-with-sidebar = true;
    };
  };
}
