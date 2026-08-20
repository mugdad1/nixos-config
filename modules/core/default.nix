{...}: {
  imports = [
    ./bootloader.nix
    ./hardware.nix
    ./adguardhome.nix
    ./network.nix
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
    ./kernel-blacklist.nix
    ./rust.nix
  ];
}
