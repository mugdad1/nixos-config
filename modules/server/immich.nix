# Immich + managed postgres/redis. ML stays CPU-only with 2 workers:
# 12GB RAM + 4 threads (i3-8145U) is the ceiling here.
# Reachable over Tailscale only: http://asus:2283
{
  services.immich = {
    enable = true;
    host = "0.0.0.0";
    port = 2283;
    mediaLocation = "/var/lib/immich";
    openFirewall = false;
    user = "immich";
    group = "immich";

    database = {
      enable = true;
      createDB = true;
    };

    redis.enable = true;

    machine-learning = {
      enable = true;
      environment = {
        MACHINE_LEARNING_WORKERS = "2";
        MACHINE_LEARNING_WORKER_TIMEOUT = "120";
        # silence the matplotlib cache warning (upstream issue #3821)
        MPLCONFIGDIR = "/var/cache/immich/matplotlib";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/cache/immich/matplotlib 0700 immich immich -"
  ];
}
