{pkgs, lib, ...}: {
  home.packages = with pkgs; [swaynotificationcenter];

  xdg.configFile."swaync/style.css".source = ./style.css;
  xdg.configFile."swaync/config.json".source = ./config.json;

  systemd.user.services.swaync = {
    Unit = {
      ConditionPathExists = "/dev/null-should-not-exist";
    };
    Service = {
      ExecStart = lib.mkForce "/dev/null";
    };
    Install = {
      WantedBy = lib.mkForce [];
    };
  };
}
