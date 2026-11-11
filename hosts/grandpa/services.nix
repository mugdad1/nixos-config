# grandpa-only systemd units. Shared units live in modules/core.
{
  pkgs,
  username,
  ...
}: {
  # Runs from the checkout, not the store: serve.py derives its root from its
  # own path. ConditionPathExists keeps a missing checkout from failing the
  # whole rebuild.
  systemd.services.study = {
    description = "Study PWA no-cache static server";
    unitConfig.ConditionPathExists = "/home/${username}/projects/study";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    serviceConfig = {
      Type = "simple";
      User = username;
      WorkingDirectory = "/home/${username}/projects/study";
      ExecStart = "${pkgs.python3}/bin/python3 /home/${username}/projects/study/scripts/serve.py 8091 0.0.0.0";
      Restart = "always";
      RestartSec = "5s";
    };
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [8091];

  # journald defaults to volatile unless /var/log/journal exists.
  services.journald.settings.Journal.Storage = "persistent";
}
