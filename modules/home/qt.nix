{ pkgs, ... }:
{
  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
  };

  home.packages = with pkgs; [
    gruvbox-kvantum
  ];

  xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=Gruvbox-Dark-Green
  '';

  qt.qt5ctSettings = {
    Appearance = {
      style = "kvantum";
      icon_theme = "Papirus-Dark";
      standard_dialogs = "xdgdesktopportal";
    };
    Fonts = {
      fixed = "\"Maple Mono,14\"";
      general = "\"Maple Mono,14\"";
    };
  };

  qt.qt6ctSettings = {
    Appearance = {
      style = "kvantum";
      icon_theme = "Papirus-Dark";
      standard_dialogs = "xdgdesktopportal";
    };
    Fonts = {
      fixed = "\"Maple Mono,14\"";
      general = "\"Maple Mono,14\"";
    };
  };
}
