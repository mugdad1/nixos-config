{ pkgs, ... }:
{
  boot.tmp.cleanOnBoot = true;

  systemd.tmpfiles.rules = [
    "D /tmp 1777 root root 1d"
    "D /var/tmp 1777 root root 7d"
  ];

  systemd.timers."nh-clean" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  systemd.services."nh-clean" = {
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.nh}/bin/nh clean all";
    };
  };
}
