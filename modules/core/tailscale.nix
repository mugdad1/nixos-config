{config, ...}: {
  services.tailscale = {
    enable = true;
    # Opens UDP 41641 in the module that needs it (see README's firewall rule).
    openFirewall = true;

    # Tailscale must never own DNS: blocky holds 127.0.0.1:53 via blocky.nix and
    # systemd-resolved is off (network.nix). MagicDNS overwriting
    # /etc/resolv.conf with 100.100.100.100 does two things at once — it points
    # the box at the tailnet resolver instead of blocky, and silently stops the
    # DNS filtering on that host. This was found live on 2026-10-16: grandpa had
    # drifted to true while thinkcentre was still false, so the two boxes that
    # are supposed to share one DNS posture had quietly stopped matching.
    #
    # Two flags, because they cover different moments:
    #   extraUpFlags    - passed to `tailscale up`, so a fresh login is born with
    #                     DNS off (only applied when services.tailscale.authKeyFile
    #                     is set, kept for that case).
    #   extraSetFlags   - `tailscale set` runs after every tailscaled start.
    #
    # extraSetFlags is NOT sufficient on its own, despite what this comment used
    # to say. `tailscale up` — the command run by hand whenever a node
    # re-authenticates — resets every flag it was not given back to its default,
    # accept-dns included, and nothing restarts tailscaled afterwards to re-apply
    # this. The timer below is what actually closes that gap.
    extraUpFlags = ["--accept-dns=false"];
    extraSetFlags = ["--accept-dns=false"];
  };

  # Re-assert accept-dns=false every few minutes. `tailscale set` is idempotent,
  # so in the steady state this does nothing at all; the one moment it matters is
  # after a manual `tailscale up` reset the pref. That turns the exposure window
  # from "until the next reboot" into "under five minutes".
  systemd.services.tailscale-accept-dns = {
    description = "Re-assert Tailscale accept-dns=false (guards a manual `tailscale up`)";
    wants = ["tailscaled.service"];
    after = ["tailscaled.service"];
    serviceConfig = {
      Type = "oneshot";
      # Leading '-' = systemd deliberately ignores the exit status. Before the
      # node is logged in (fresh install, or after `tailscale logout`) there is
      # nothing to set yet, and that must not leave a red unit behind.
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

  # tailscaled builds its own WireGuard interface, so packets from peers are
  # asymmetric by design: strict rpfilter drops them once subnet routes or exit
  # nodes are in play. `loose` is Tailscale's documented requirement.
  networking.firewall.checkReversePath = "loose";
}
