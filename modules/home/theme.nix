{pkgs, ...}: let
  gtk-theme-name = "Colloid-Green-Dark-Gruvbox";
  gtk-theme = pkgs.colloid-gtk-theme.override {
    colorVariants = ["dark"];
    themeVariants = ["green"];
    tweaks = [
      "gruvbox"
      "rimless"
      "float"
    ];
  };
  icon-theme-name = "Papirus-Dark";
  cursor-name = "Bibata-Modern-Ice";
  gruvbox-kvantum-theme = pkgs.gruvbox-kvantum.override {variant = "Gruvbox-Dark-Green";};
in {
  # GTK
  gtk = {
    enable = true;
    font = {
      name = "Iosevka Nerd Font";
      size = 14;
    };
    theme = {
      name = gtk-theme-name;
      package = gtk-theme;
    };
    # HM 26.05+: gtk4 theme no longer mirrors gtk.theme, set explicitly
    gtk4.theme = {
      name = gtk-theme-name;
      package = gtk-theme;
    };
    iconTheme = {
      name = icon-theme-name;
      package = pkgs.papirus-icon-theme;
    };
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      gtk-theme = gtk-theme-name;
      icon-theme = icon-theme-name;
      color-scheme = "prefer-dark";
    };
  };

  home.pointerCursor = {
    enable = true;
    name = cursor-name;
    package = pkgs.bibata-cursors;
    size = 24;
  };

  # Qt / Kvantum
  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
  };

  home.packages = with pkgs; [
    gruvbox-kvantum-theme
    libsForQt5.qt5ct
    qt6Packages.qt6ct
    libsForQt5.qtstyleplugin-kvantum
    qt6Packages.qtstyleplugin-kvantum
  ];

  xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=Gruvbox-Dark-Green
  '';

  home.file.".local/share/Kvantum/Gruvbox-Dark-Green".source = "${gruvbox-kvantum-theme}/share/Kvantum/Gruvbox-Dark-Green";

  qt.qt5ctSettings = {
    Appearance = {
      style = "kvantum";
      icon_theme = "Papirus-Dark";
      standard_dialogs = "xdgdesktopportal";
    };
    Fonts = {
      fixed = "\"Iosevka Nerd Font,14\"";
      general = "\"Iosevka Nerd Font,14\"";
    };
  };

  qt.qt6ctSettings = {
    Appearance = {
      style = "kvantum";
      icon_theme = "Papirus-Dark";
      standard_dialogs = "xdgdesktopportal";
    };
    Fonts = {
      fixed = "\"Iosevka Nerd Font,14\"";
      general = "\"Iosevka Nerd Font,14\"";
    };
  };
}
