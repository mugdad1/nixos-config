{...}: {
  imports = [
    ./bat-direnv.nix # bat + direnv
    ./browser.nix # zen browser
    ./fastfetch/fastfetch.nix # fetch tool
    ./fzf.nix # fuzzy finder
    ./ghostty/ghostty.nix # terminal
    ./git.nix # version control
    ./gui.nix # gui apps + gnome apps
    ./hyprland # window manager
    ./nemo.nix # file manager
    ./p10k/p10k.nix
    ./theme.nix # gtk + qt / kvantum theme
    ./packages # other packages
    ./rofi/rofi.nix # launcher
    ../../scripts/scripts.nix # personal scripts

    ./swayosd.nix # brightness / volume widget
    ./swaync/swaync.nix # notification daemon
    ./waybar # status bar
    ./waypaper.nix # GUI wallpaper picker
    ./wallpapers.nix # deploy repo wallpapers into ~/Pictures/wallpapers
    ./xdg-mimes.nix # xdg config
    ./zsh # shell
  ];
}
