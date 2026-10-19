# gitea-mirror — self-hosted GitHub → Forgejo mirroring app on grandpa.
# NATIVE, THEN MOVED TO DOCKER THE SAME DAY (2026-10-19): written as a native
# systemd service because grandpa was containerless ("no docker here — row
# 103"), then his *"i want forgero and mirror in docker now"* landed within the
# day — the import in default.nix is commented out and the live thing is
# ~/projects/servers/gitea-mirror/docker-compose.yml (image
# ghcr.io/raylabshq/gitea-mirror, data /var/lib/gitea-mirror bind-mounted, port
# bound to 100.106.116.60:4321 because docker bypasses the nftables interface
# rules). This file stays for its rationale and the env setup below.
# Restored 2026-10-19 on his *"lets have gitea mirror its faster easier"* — the
# same build the fleet ran before, git-resurrected from `adfa060`:
#   - package: ../../packages/gitea-mirror.nix (RayLabsHQ/gitea-mirror, built
#     from source with our own nixpkgs; no upstream flake input)
#   - module shape: hosts were asus's `modules/server/gitea-mirror.nix`,
#     dropped from the tree in `d6205b4`; adapted here for grandpa.
#
# Tailnet-only: port 4321 opens on tailscale0 only, not on the LAN — the app
# has a login (Better Auth) and no reason to answer the flat network.
#
# BEFORE FIRST START create /var/lib/gitea-mirror/env (root:root, 600):
#   BETTER_AUTH_URL=http://100.106.116.60:4321
#   BETTER_AUTH_TRUSTED_ORIGINS=http://100.106.116.60:4321
#   PUBLIC_BETTER_AUTH_URL=http://100.106.116.60:4321
# (tailnet IP is already in this file's predecessor modules; no secret.)
# The unit requires the file — a missing one is a failed start, not a silent
# default to localhost, which would break origin checks once you browse it.
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

  # Tailnet-only — same interface-scoped pattern nowhere else in the fleet needs
  # yet, because everything else is either LAN-public (Forgejo) or headless.
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [4321];
}
