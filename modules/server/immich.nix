# Immich (photos) + auto-provisioned postgres/redis.
# Tailscale only (firewall stays shut, port 2283): http://asus:2283
# SKIPPED for now: services.immich.backup is unwired in pinned nixpkgs;
# photos live on /var/lib/immich — snapshot via snapper or a manual
# pg_dumpall + rsync if you care about the library.
{
  services.immich = {
    enable = true;
    host = "0.0.0.0";
    port = 2283;
    database = {
      enable = true;
      createDB = true;
    };
    redis.enable = true;
  };
}