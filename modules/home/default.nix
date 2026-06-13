{...}: {
  imports = [
    ./bat.nix # better cat command
    ./browser.nix # firefox based browser
    ./cava.nix # audio visualizer
    ./direnv.nix
    ./fastfetch/fastfetch.nix # fetch tool
    ./fzf.nix # fuzzy finder
    ./ghostty/ghostty.nix # terminal
    ./git.nix # version control
    ./gnome.nix # gnome apps
    ./gtk.nix # gtk theme
    ./hyprland # window manager
    ./kitty.nix # terminal
    ./lazygit.nix
    ./nemo.nix # file manager
    ./nvim.nix # neovim editor
    ./obsidian.nix
    ./p10k/p10k.nix
    ./qt.nix # qt / kvantum theme
    ./packages # other packages
    ./pomo/pomo.nix # TUI Pomodoro timer
    ./rofi/rofi.nix # launcher
    ./../../scripts/scripts.nix # personal scripts
    ./ssh.nix # ssh config

    ./superfile/superfile.nix # terminal file manager
    ./swayosd.nix # brightness / volume wiget
    ./swaync/swaync.nix # notification deamon
    ./waybar # status bar
    ./waypaper.nix # GUI wallpaper picker
    ./xdg-mimes.nix # xdg config
    ./zsh # shell
  ];
}
