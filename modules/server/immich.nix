# Immich (photos) + auto-provisioned postgres/redis.
# Tailscale only (firewall stays shut, port 2283): http://asus:2283
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
