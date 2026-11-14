# TriliumNext (github.com/TriliumNext/Trilium) — hierarchical notes with a web
# frontend. nixpkgs ships the official server tarball (0.106.1) and a NixOS
# module, so there is no container and no updater to babysit: the version is
# whatever the flake's nixpkgs pins.
#
# The database is SQLite in /var/lib/trilium (machine state, not the flake),
# so it stays on the root SSD — 4 GiB of RAM is enough for node, and the
# platter is for bulk storage, not a live database.
{
  ...
}: {
  services.trilium-server = {
    enable = true;

    # Bind on every interface, keep the LAN out with the firewall (same shape
    # as study and blocky). The tailnet is the only way in.
    host = "0.0.0.0";
    port = 8080;

    # Authentication stays ON (the module default). The tailnet is not a
    # privacy boundary: phones and other people's nodes share it.
    #
    # Daily backups are on (module default, noBackup = false) and land in
    # /var/lib/trilium/backup.
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [8080];
}
