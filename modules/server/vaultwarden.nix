# Vaultwarden (passwords). Served over tailscale HTTPS (SubtleCrypto requires
# a secure context): https://asus.tailbc99bb.ts.net — see serve command below.
# Signups closed after you create your account: flip SIGNUPS_ALLOWED to
# false and rebuild.
#
# On asus (once, persists across reboots):
#   sudo tailscale serve https / http://127.0.0.1:8222
{
  services.vaultwarden = {
    enable = true;
    config = {
      DOMAIN = "https://asus.tailbc99bb.ts.net";
      SIGNUPS_ALLOWED = true;
      ROCKET_ADDRESS = "0.0.0.0";
      ROCKET_PORT = 8222;
    };
  };
}
