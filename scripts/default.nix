{pkgs, ...}: let
  script = name: pkgs.writeShellScriptBin name (builtins.readFile ./${name}.sh);
in {
  home.packages = [
    (script "hm-find")
    (script "init-wallpaper")
    (script "mcli")
    (script "power-menu")
    (script "random-wallpaper")
    (script "runbg")
    (script "screenshot")
    (script "toggle-mic")
    (script "toggle-nightlight")
    (script "toggle-rofi")
    (script "toggle-screen")
    (script "toggle-waybar")
    (script "wall-change")
    (script "wallpaper-picker")
    (script "web-search")
    (script "yt-audio")
    pkgs.inxi
  ];
}
