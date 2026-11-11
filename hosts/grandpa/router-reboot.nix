# The scheduled half of router-reboot: daily at 03:13. The command itself is in
# modules/core so any host can run it; the timer is here so it fires once, not
# on all three machines.
_: {
  systemd.services.router-reboot = {
    description = "Reboot the house router (Huawei H122-373 at 192.168.8.1)";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      # Runs as him: the wrapper reads $HOME/.config/router-reboot/pass.
      User = "mugdad";
      Environment = ["HOME=/home/mugdad"];
      ExecStart = "/run/current-system/sw/bin/router-reboot";
      TimeoutStartSec = "5min";
    };
  };

  systemd.timers.router-reboot = {
    description = "Daily router reboot at 03:13";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 03:13:00";
      AccuracySec = "10s";
      # A missed run is skipped, never caught up during the day.
      Persistent = false;
      Unit = "router-reboot.service";
    };
  };
}
