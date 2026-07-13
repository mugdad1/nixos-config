{...}: {
  # Deploy the repo's wallpapers into ~/Pictures/wallpapers/others so the
  # wallpaper picker / random-wallpaper / init-wallpaper scripts have content
  # on a fresh install.
  home.file."Pictures/wallpapers/others/gruvbox".source = ../../wallpapers/otherWallpaper/gruvbox;
  home.file."Pictures/wallpapers/others/nixos".source = ../../wallpapers/otherWallpaper/nixos;
}
