{...}: {
  imports = [
    ./bootloader.nix
    ./hardware.nix
    ./network.nix
    ./cleanup.nix
    ./fonts.nix
    ./nh.nix
    ./pipewire.nix
    ./program.nix
    ./security.nix
    ./services.nix
    ./system.nix
    ./printing.nix
    ./flatpak.nix
    ./user.nix
    ./wayland.nix
  ];
}
