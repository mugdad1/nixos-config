{ ... }:
{
  boot.tmp.cleanOnBoot = true;

  systemd.tmpfiles.rules = [
    "D /tmp 1777 root root 1d"
    "D /var/tmp 1777 root root 7d"
  ];

}
