# gitea-mirror — self-hosted GitHub→Gitea mirroring app (server-only; asus).
# Built from source via ./packages/gitea-mirror.nix — no upstream flake input.
#
# Tailnet-only service: the firewall is not opened; tailscale traffic bypasses
# ufw. The public URL is injected at runtime through EnvironmentFile (which
# overrides Environment=), so the tailnet IP never lands in this public repo.
#
# On asus, create /var/lib/gitea-mirror/env (root:root, 600) before first start:
#   BETTER_AUTH_URL=http://<tailnet-ip>:4321
#   BETTER_AUTH_TRUSTED_ORIGINS=http://<tailnet-ip>:4321
#   PUBLIC_BETTER_AUTH_URL=http://<tailnet-ip>:4321
{pkgs, ...}: let
  giteaMirror = pkgs.callPackage ../../packages/gitea-mirror.nix {};
in {
  users.users.gitea-mirror = {
    isSystemUser = true;
    group = "gitea-mirror";
    home = "/var/lib/gitea-mirror";
    createHome = true;
  };

  users.groups.gitea-mirror = {};

  systemd.tmpfiles.rules = [
    "d /var/lib/gitea-mirror 0750 gitea-mirror gitea-mirror -"
  ];

  systemd.services.gitea-mirror = {
    description = "gitea-mirror: GitHub to Gitea mirroring service";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    wants = ["network-online.target"];

    environment = {
      DATA_DIR = "/var/lib/gitea-mirror";
      HOST = "0.0.0.0";
      PORT = "4321";
      NODE_ENV = "production";
      # Placeholders, overridden by EnvironmentFile above.
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
}
