{
  pkgs,
  variables,
  ...
}: let
  theme = variables.theme or "gruvbox";

  # --- GTK ---
  colloidGtk = pkgs.colloid-gtk-theme.override {
    colorVariants = ["dark"];
    themeVariants = ["green"];
    tweaks = [
      "gruvbox"
      "rimless"
      "float"
    ];
  };
  colloidNord = pkgs.colloid-gtk-theme.override {
    colorVariants = ["dark"];
    themeVariants = ["green"];
    tweaks = [
      "nord"
      "rimless"
      "float"
    ];
  };
  catppuccinGtk = pkgs.catppuccin-gtk.override {
    variant = "mocha";
    accents = ["mauve"];
  };

  gtkTheme =
    if theme == "gruvbox"
    then {
      name = "Colloid-Green-Dark-Gruvbox";
      package = colloidGtk;
    }
    else if theme == "nord"
    then {
      name = "Nordic";
      package = pkgs.nordic;
    }
    else if theme == "catppuccin"
    then {
      name = "catppuccin-mocha-mauve-standard";
      package = catppuccinGtk;
    }
    else if theme == "rose-pine"
    then {
      name = "rose-pine";
      package = pkgs.rose-pine-gtk-theme;
    }
    else {
      # tokyo-night: no dedicated port in nixpkgs, cool-toned colloid stands in
      name = "Colloid-Green-Dark-Nord";
      package = colloidNord;
    };

  # --- Qt / Kvantum ---
  gruvboxKvantum = pkgs.gruvbox-kvantum.override {variant = "Gruvbox-Dark-Green";};
  catppuccinKvantum = pkgs.catppuccin-kvantum.override {
    variant = "mocha";
    accent = "mauve";
  };

  kvantumTheme =
    if theme == "gruvbox"
    then {
      name = "Gruvbox-Dark-Green";
      package = gruvboxKvantum;
    }
    else if theme == "catppuccin"
    then {
      name = "catppuccin-mocha-mauve";
      package = catppuccinKvantum;
    }
    else if theme == "rose-pine"
    then {
      name = "rose-pine-pine";
      package = pkgs.rose-pine-kvantum;
    }
    else {
      # nord / tokyo-night have no dedicated kvantum port; neutral mocha stands in
      name = "catppuccin-mocha-mauve";
      package = catppuccinKvantum;
    };

  icon-theme-name = "Papirus-Dark";
  cursor-name = "Bibata-Modern-Amber";
in {
  # GTK
  gtk = {
    enable = true;
    font = {
      name = "Iosevka Nerd Font";
      size = 14;
    };
    theme = {
      name = gtkTheme.name;
      package = gtkTheme.package;
    };
    # HM 26.05+: gtk4 theme no longer mirrors gtk.theme, set explicitly
    gtk4.theme = {
      name = gtkTheme.name;
      package = gtkTheme.package;
    };
    iconTheme = {
      name = icon-theme-name;
      package = pkgs.papirus-icon-theme;
    };
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      gtk-theme = gtkTheme.name;
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

  # Qt / Kvantum (HM qt module installs qt5ct/qt6ct/kvantum plugins itself)
  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
    kvantum = {
      enable = true;
      settings.General.theme = kvantumTheme.name;
      themes = [kvantumTheme.package];
    };
  };

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
