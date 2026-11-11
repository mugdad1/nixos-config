{config, ...}: {
  services.tailscale = {
    enable = true;
    openFirewall = true;

    # Blocky owns DNS; MagicDNS must never overwrite /etc/resolv.conf.
    extraUpFlags = ["--accept-dns=false"];
    extraSetFlags = ["--accept-dns=false"];
  };

  # A manual `tailscale up` resets accept-dns; re-assert it every few minutes.
  systemd.services.tailscale-accept-dns = {
    description = "Re-assert Tailscale accept-dns=false";
    wants = ["tailscaled.service"];
    after = ["tailscaled.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "-${config.services.tailscale.package}/bin/tailscale set --accept-dns=false";
    };
  };

  systemd.timers.tailscale-accept-dns = {
    description = "Periodically re-assert Tailscale accept-dns=false";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
    };
  };

  # tailscaled's WireGuard packets are asymmetric by design.
  networking.firewall.checkReversePath = "loose";
}
