# The reason this machine exists: a share and a backup target on the 1 TB
# platter, reachable from victus and t480s over the LAN or the tailnet.
{
  username,
  ...
}: {
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "asus";
        "security" = "user";
        "map to guest" = "Never";
        "server min protocol" = "SMB3";
        # Wi-Fi is the only uplink; do not let a stalled client pin it.
        "deadtime" = "15";
      };
      storage = {
        path = "/srv/storage";
        browseable = "yes";
        "read only" = "no";
        "valid users" = username;
        "force user" = username;
        "force group" = "users";
        "create mask" = "0644";
        "directory mask" = "0755";
      };
    };
  };

  # Restic repos are pushed over SSH (sftp backend), so the only thing needed
  # here is the directory tree with sane ownership.
  systemd.tmpfiles.rules = [
    "d /srv/storage/backups 0750 ${username} users -"
    "d /srv/storage/backups/victus 0750 ${username} users -"
    "d /srv/storage/backups/t480s 0750 ${username} users -"
    "d /srv/storage/media 0755 ${username} users -"
  ];
}
