# gitea-mirror — self-hosted GitHub → Forgejo mirroring app, native systemd
# service on grandpa (no docker here — row 103/112: grandpa stays containerless).
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
# The unit needs /var/lib/gitea-mirror/env (mode 600, owner gitea-mirror — the
# header used to say root:root, which was never true: it is uid 1001, and the
# uid is pinned below so the service can actually read it). It already exists
# on this box from the 2026-10-19 run, with:
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

    # PINNED TO 1001 — this is the fix for a real failure, not decoration.
    # NixOS allocates service uids dynamically, so when af010f2 removed this
    # module and 77069f1 brought it back, the id came back as 991 instead of
    # the 1001 the data was written under. The tmpfiles `d` rule below chowned
    # the top directory only — `d` is not recursive — so the service owned the
    # folder but not its contents, and the first start died with:
    #
    #   ln: failed to create symbolic link
    #       '/var/lib/gitea-mirror/.workdir/dist': Permission denied
    #
    # All 151 files under here are uid 1001, and 1001 was free, so pinning the
    # identity to the data costs no mutation at all — the alternative was a
    # chown -R that only papers over the next time the module is removed and
    # re-added. Considered systemd-tmpfiles' recursive `z` rule instead and
    # tested it against a scratch dir first: it changed nothing, so it is not
    # to be relied on here without evidence.
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

  # Tailnet-only — same interface-scoped pattern nowhere else in the fleet needs
  # yet, because everything else is either LAN-public (Forgejo) or headless.
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [4321];
}
