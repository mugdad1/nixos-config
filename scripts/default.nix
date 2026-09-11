{pkgs, ...}: let
  script = name: pkgs.writeShellScriptBin name (builtins.readFile ./${name}.sh);
in {
  home.packages = [
    (script "hm-find")
    (script "init-wallpaper")
    (script "mcli")
    (script "nh-notify")
    (script "power-menu")
    (script "random-wallpaper")
    (script "runbg")
    (script "screenshot")
    (script "toggle-display")
    (script "toggle-float")
    (script "toggle-mic")
    (script "toggle-nightlight")
    (script "toggle-opacity")
    (script "toggle-rofi")
    (script "toggle-waybar")
    (script "wall-change")
    (script "wallpaper-picker")
    (script "web-search")
    (script "yt-audio")
    pkgs.inxi
  ];
}
