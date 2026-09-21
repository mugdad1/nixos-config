# Immich (photos) + auto-provisioned postgres/redis.
# Tailscale only (firewall stays shut, port 2283): http://asus:2283
# SKIPPED for now: services.immich.backup is unwired in pinned nixpkgs;
# photos live on /var/lib/immich — snapshot via snapper or a manual
# pg_dumpall + rsync if you care about the library.
{
  services.immich = {
    # Disabled 2026-09-21: not set up yet, and it adds baseline heat on a
    # chassis-less box that hit 98C. Re-enable (with database/redis) when
    # actually serving photos.
    enable = false;
    host = "0.0.0.0";
    port = 2283;
  };
}