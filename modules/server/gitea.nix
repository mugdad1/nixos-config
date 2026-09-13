# Gitea + shared postgres. No passwordFile: local socket + peer auth,
# provisioned automatically (user == dbname == "gitea" satisfies the module).
# Reachable over Tailscale only: http://asus:3000 (adjust ROOT_URL to your
# tailnet MagicDNS name if different).
{
  services.gitea = {
    enable = true;
    appName = "asus git";
    database.type = "postgres";
    settings = {
      server = {
        DOMAIN = "asus";
        ROOT_URL = "http://asus:3000/";
        HTTP_PORT = 3000;
        START_SSH_SERVER = false;
        LANDING_PAGE = "explore";
      };
      service.DISABLE_REGISTRATION = true;
    };
  };
}
