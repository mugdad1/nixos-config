# gitea-mirror — GitHub → Forgejo mirroring, native systemd on grandpa.
# Tailnet-only on :4321; the unit reads /var/lib/gitea-mirror/env.
{pkgs, ...}: let
  giteaMirror = pkgs.callPackage ../../pkgs/gitea-mirror.nix {};
in {
  users.users.gitea-mirror = {
    isSystemUser = true;
    group = "gitea-mirror";
    home = "/var/lib/gitea-mirror";
    createHome = true;
    # Pinned: the existing data is owned by uid 1001, and NixOS would otherwise
    # allocate a new id when this module is removed and re-added.
    uid = 1001;
  };

  users.groups.gitea-mirror = {
    gid = 1001;
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/gitea-mirror 0750 gitea-mirror gitea-mirror -"
  ];

  systemd.services.gitea-mirror = {
    description = "gitea-mirror: GitHub to Forgejo mirroring service";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    wants = ["network-online.target"];

    environment = {
      DATA_DIR = "/var/lib/gitea-mirror";
      HOST = "0.0.0.0";
      PORT = "4321";
      NODE_ENV = "production";
      # Placeholders, overridden by EnvironmentFile below.
      BETTER_AUTH_URL = "http://127.0.0.1:4321";
      BETTER_AUTH_TRUSTED_ORIGINS = "http://127.0.0.1:4321";
      PUBLIC_BETTER_AUTH_URL = "http://127.0.0.1:4321";
    };

    serviceConfig = {
      Type = "simple";
      User = "gitea-mirror";
      Group = "gitea-mirror";
      ExecStart = "${giteaMirror}/bin/gitea-mirror";
      EnvironmentFile = "/var/lib/gitea-mirror/env";
      Restart = "always";
      RestartSec = "10s";
      WorkingDirectory = "/var/lib/gitea-mirror";
      TimeoutStopSec = "30s";
      KillMode = "mixed";
      KillSignal = "SIGTERM";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = ["/var/lib/gitea-mirror"];
    };
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [4321];
}
