{ pkgs, username, ... }:
{
  # Add user to libvirtd group
  users.users.${username}.extraGroups = [
    "libvirtd"
    "docker"
  ];

  # Install necessary packages
  environment.systemPackages = with pkgs; [
    virt-manager
    virt-viewer
    spice
    spice-gtk
    spice-protocol
    virtio-win
    win-spice
    adwaita-icon-theme
  ];

  # Manage the virtualisation services
  virtualisation = {
    docker = {
      enable = false;
    };
    libvirtd = {
      enable = false;
      qemu = {
        swtpm.enable = false;
      };
    };
    spiceUSBRedirection.enable = true;
  };
  services.spice-vdagentd.enable = false;
}
