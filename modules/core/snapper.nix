{
  pkgs,
  username,
  ...
}: {
  services.snapper = {
    snapshotInterval = "12h";
    persistentTimer = true;
    cleanupInterval = "daily";

    configs = {
      home = {
        SUBVOLUME = "/home";
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_DAILY = 1;
        TIMELINE_LIMIT_WEEKLY = 0;
        TIMELINE_LIMIT_MONTHLY = 0;
        NUMBER_CLEANUP = true;
        NUMBER_LIMIT = 1;
        NUMBER_LIMIT_IMPORTANT = 1;
        ALLOW_USERS = [ username ];
      };
    };
  };

  environment.systemPackages = with pkgs; [
    btrfs-assistant
    snapper
  ];
}