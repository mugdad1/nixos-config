# grandpa — headless server: Intel i3-2120, 6 GiB RAM, one 298 GiB HDD, no
# discrete GPU. Imports modules/core only; never modules/desktop.
{
  pkgs,
  username,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/core
    # A directory module loads its default.nix only, so every sibling below
    # must be listed explicitly.
    ./packages.nix
    ./overrides.nix
    ./router-reboot.nix
    ./home-assistant.nix
    ./services.nix
    ./secrets.nix
    ./searxng.nix
    ./gitea-mirror.nix
  ];

  boot.loader.efi.efiSysMountPoint = "/boot";

  # Literal-IP NTP so the clock can be fixed even when DNS is down.
  services.timesyncd.enable = true;
  networking.timeServers = [
    "162.159.200.1" # time.cloudflare.com
    "216.239.35.0" # time.google.com
    "216.239.35.4"
  ];

  # Slow spinning disk and 6 GiB RAM: compressed RAM swap beats a swap file.
  zramSwap = {
    enable = true;
    algorithm = "lz4";
    memoryPercent = 35;
    priority = 100;
  };

  services.forgejo = {
    enable = true;
    settings = {
      server = {
        DOMAIN = "100.106.116.60";
        ROOT_URL = "http://100.106.116.60:3000/";
        HTTP_PORT = 3000;
        LANDING_PAGE = "explore";
      };
      service = {
        # Open so the first account becomes admin; close it after first login.
        DISABLE_REGISTRATION = false;
        REQUIRE_SIGNIN_VIEW = false;
      };
      repository.DEFAULT_BRANCH = "main";
    };
    # SQLite is enough for a handful of repos on a 6 GiB box.
    database.type = "sqlite3";
    stateDir = "/var/lib/forgejo";
  };
  networking.firewall.allowedTCPPorts = [3000];

  # Docker engine stays installed; the compose stack it used to run is gone.
  virtualisation.docker.enable = true;
  users.users.${username}.extraGroups = ["docker"];

  # The service index: nginx on :80 over the tailnet, rendered from
  # lib/server-index.nix so a rebuild is the publish.
  services.nginx = {
    enable = true;
    virtualHosts.index = {
      default = true;
      root = pkgs.writeTextDir "index.html" (import ../../lib/server-index.nix {});
      extraConfig = "index index.html;";
    };
  };
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [80];
}
