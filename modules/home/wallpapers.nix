{pkgs, ...}: {
  # Deploy the repo's wallpapers FLAT into ~/Pictures/wallpapers/others so the
  # existing (flat) wallpaper-picker / random-wallpaper / init-wallpaper scripts
  # work unchanged on a fresh install.
  home.file."Pictures/wallpapers/others".source = pkgs.symlinkJoin {
    name = "wallpapers-others";
    paths = [
      ../../wallpapers/otherWallpaper/gruvbox
      ../../wallpapers/otherWallpaper/nixos
    ];
  };
}
