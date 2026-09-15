# Vaultwarden (passwords). Signups closed after you create your account:
# flip SIGNUPS_ALLOWED to false and rebuild. Tailscale only (port 8222):
# http://asus:8222
{
  services.vaultwarden = {
    enable = true;
    config = {
      DOMAIN = "http://asus:8222";
      SIGNUPS_ALLOWED = true;
      ROCKET_ADDRESS = "0.0.0.0";
      ROCKET_PORT = 8222;
    };
  };
}
