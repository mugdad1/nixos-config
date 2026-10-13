{
  pkgs,
  lib,
  ...
}: {
  home.packages = (
    with pkgs; [
      ## Multimedia
      imv
      obs-studio
      pavucontrol
      vlc
      freetube

      ## Browsers (vanilla, un-nixified profiles: editable directly)
      # firefox → chromium → ungoogled-chromium, all on his word 2026-10-13:
      # "add chromium to this device and rm firefox / keep zen" then
      # "yes ofc i hate google". Same upstream version either way (155.0.8059.39),
      # so this is a drop-in swap, not an upgrade.
      # Firefox was the plain package with an un-nixified profile — it had no
      # programs.firefox block anywhere in the flake, so removing it drops no
      # declarative state. Zen is the one with the managed profile
      # (modules/home/browser.nix) and stays exactly as it was; this line was
      # never what provided it.
      ungoogled-chromium
      # chromium
      # firefox
      tor-browser

      ## Office / Productivity
      onlyoffice-desktopeditors
      filen-desktop
      libreoffice-stable
      # clickup  # DISABLED 2026-10-13 on his word. Commented, not deleted.
      ## System / Utility
      qbittorrent
      gnome-disk-utility
      localsend
      zenity
      kdePackages.polkit-kde-agent-1
      wlsunset

      ## Terminal
      kitty

      ## GNOME apps (PDF viewer, archive manager)
      evince
      file-roller

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
