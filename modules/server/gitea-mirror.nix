# Real gitea-mirror app (GitHub → Gitea mirroring service with a dashboard),
# NOT a raw-API oneshot. The flake module ships a systemd service, auto-generated
# secrets, SQLite, and a healthcheck timer.
#
# Tailnet-only access, matching Gitea/Immich: firewall stays closed
# (openFirewall = false). The public base URL is kept OUT of this public repo —
# set it in /var/lib/gitea-mirror/env on the server (untracked by git), e.g.:
#
#   BETTER_AUTH_URL=http://<tailnet-ip>:4321
#   BETTER_AUTH_TRUSTED_ORIGINS=http://<tailnet-ip>:4321
#   PUBLIC_BETTER_AUTH_URL=http://<tailnet-ip>:4321
#
# EnvironmentFile values win over the module's Environment= (verified live).
# First signup in the web UI becomes admin; then set up GitHub + Gitea there.
{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.gitea-mirror.nixosModules.default
  ];

  services.gitea-mirror = {
    enable = true;
    port = 4321;
    betterAuthUrl = "http://127.0.0.1:4321";
    betterAuthTrustedOrigins = "http://127.0.0.1:4321";
    environmentFile = "/var/lib/gitea-mirror/env";
    openFirewall = false;
  };
}
