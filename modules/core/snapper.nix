{
  pkgs,
  lib,
  config,
  username,
  ...
}: let
  hasHome = config.services.snapper.configs ? home;
in {
  services.snapper = {
    snapshotInterval = "0/12:00:00";
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
        ALLOW_USERS = [username];
      };
    };
  };

  # snapper stores snapshots of a btrfs subvolume in $SUBVOLUME/.snapshots,
  # which must exist as a nested subvolume (a plain dir would be re-snapshotted
  # recursively). Create it idempotently before the timeline/cleanup units run.
  systemd.services.snapper-home-subvol = lib.mkIf hasHome {
    description = "Create /home/.snapshots subvolume for snapper";
    after = ["local-fs.target"];
    wants = ["local-fs.target"];
    before = ["snapper-timeline.service" "snapper-cleanup.service"];
    requiredBy = ["snapper-timeline.service" "snapper-cleanup.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c 'if ! [ -d /home/.snapshots ]; then ${pkgs.btrfs-progs}/bin/btrfs subvolume create /home/.snapshots; fi'";
    };
  };

  environment.systemPackages = with pkgs; [
    snapper
  ];
}
