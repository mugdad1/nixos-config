{...}: {
  imports = [
    ./bat.nix # better cat command
    ./browser.nix # firefox based browser
    ./direnv.nix
    ./fastfetch/fastfetch.nix # fetch tool
    ./fzf.nix # fuzzy finder
    ./ghostty/ghostty.nix # terminal
    ./git.nix # version control
    ./gnome.nix # gnome apps
    ./gtk.nix # gtk theme
    ./hyprland # window manager
    ./nemo.nix # file manager
    ./nvim.nix # neovim editor
    ./p10k/p10k.nix
    ./qt.nix # qt / kvantum theme
    ./packages # other packages
    ./rofi/rofi.nix # launcher
    ./../../scripts/scripts.nix # personal scripts

    ./superfile/superfile.nix # terminal file manager
    ./swayosd.nix # brightness / volume widget
    ./swaync/swaync.nix # notification daemon
    ./waybar # status bar
    ./waypaper.nix # GUI wallpaper picker
    ./xdg-mimes.nix # xdg config
    ./zsh # shell
  ];
}
