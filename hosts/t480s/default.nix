{
  pkgs,
  inputs,
  username,
  ...
}: {
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480s
    ./hardware-configuration.nix
    ../../modules/core
    # Desktop is opt-in per host, no longer dragged in by core (2026-10-12).
    # This laptop wants a desktop.
    ../../modules/desktop
  ];

  hardware.graphics = {
    extraPackages = with pkgs; [
      intel-media-driver
      intel-compute-runtime
    ];
  };

  boot.kernelParams = [
    "mem_sleep_default=deep"
    "psmouse.synaptics_intertouch=1"
    "nowatchdog"
    "psi=1"
    "rootflags=noatime"
    "fbcon=nodefer"
  ];

  # throttled (lenovo-throttling-fix) fights power-profiles-daemon over the
  # CPU governor on Intel HWP; PPD + platform_profile is sufficient on this
  # BIOS gen. tlp is likewise off — PPD is the single power daemon.
  services.throttled.enable = false;
  services.tlp.enable = false;
  services.power-profiles-daemon.enable = true;
  # WHPH — his productivity app (tasks/habits/timers), Linux bundle from
  # upstream releases, packaged in pkgs/whph.nix. GUI only makes sense here
  # (the t480s is the laptop with a display).
  environment.systemPackages = [
    pkgs.powertop
    pkgs.tmux
    (pkgs.callPackage ../../pkgs/whph.nix {})
  ];

  systemd.services.battery-threshold = {
    description = "Set battery charge threshold";
    after = ["multi-user.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'for bat in /sys/class/power_supply/BAT*; do [ -f \"$bat/charge_control_end_threshold\" ] && echo 85 > \"$bat/charge_control_end_threshold\"; done'";
      ProtectSystem = "strict";
      PrivateTmp = true;
      NoNewPrivileges = true;
      RestrictSUIDSGID = true;
    };
  };

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "ignore";
  };

  environment.etc."libinput/local-overrides.quirks".text = ''
    [Trackpoint Buttons Only]
    MatchName=*Elan TrackPoint*
    AttrEventCode=-REL_X;-REL_Y
  '';

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };

  # ── ship the service index to Caddy ────────────────────────────────────────
  #
  # WHY THIS IS A UNIT AND NOT A MANUAL COMMAND: lib/server-index.nix renders
  # the page, modules/home/apps/homepage.nix provides `push-server-index` to ship
  # it, and nobody ever ran it. The flake was corrected to 100.124.75.45 and
  # the served page kept printing 100.97.91.119 — plus a /etc/sv/tailscaled
  # path that no longer exists — because those are bytes on the SERVER's disk
  # inside Caddy's bind-mounted docroot. Fixing the source does not move them.
  # "Correct in the repo" and "correct on the wire" are two steps and only the
  # first was being taken; this takes the second one without being asked.
  #
  # The address is 100.88.29.31 as of 2026-10-15 — the ThinkCentre was
  # reinstalled and tailscale re-registered it, so the 100.124.75.45 in the
  # history above is dead. The remote path is lowercase `projects/` for the
  # same reinstall reason; see modules/home/apps/homepage.nix for that one.
  #
  # `restartTriggers` is the whole mechanism. NixOS hashes the rendered HTML
  # into the unit, and switch-to-configuration restarts a unit whose trigger
  # changed — so the push re-runs exactly when the page changes, costs nothing
  # when it did not, and cannot be forgotten the way it was before.
  #
  # Runs as `username`, not root: rsync needs the SSH key at ~/.ssh, which is
  # root's would not be. HOME is set explicitly because a system unit gets no
  # login environment and ssh would otherwise look in /root.
  systemd.services.push-server-index = {
    description = "Ship the rendered service index to Caddy's docroot";
    wants = ["network-online.target"];
    # Ordering only, not requires: if tailscaled is the thing that is broken
    # the push should still fail on its own merits, not be silently skipped.
    after = ["network-online.target" "tailscaled.service"];
    wantedBy = ["multi-user.target"];
    restartTriggers = [(import ../../lib/server-index.nix {})];
    path = with pkgs; [rsync openssh curl coreutils gnugrep];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = username;
      Environment = ["HOME=/home/${username}"];
      ExecStart = "${pkgs.writeShellScript "push-server-index" ''
        set -eu
        # -L --inplace are load-bearing, and the comment belongs to
        # modules/home/apps/homepage.nix — read it there rather than duplicating
        # the reasoning: Caddy has this file bind-mounted read-only, so only a
        # write-through of the existing inode is picked up without a restart.
        target=${username}@100.88.29.31:projects/servers/caddy/index.html
        src=${pkgs.writeText "server-index.html" (import ../../lib/server-index.nix {})}
        # Retried because tailscaled can be up-but-not-yet-connected for a few
        # seconds after a cold boot. One attempt would leave a permanently red
        # unit on a normal boot, and a monitor that cries wolf gets ignored.
        i=0
        until rsync -L --inplace "$src" "$target"; do
          i=$((i + 1))
          if [ "$i" -ge 6 ]; then
            echo "$(date '+%F %T') push-server-index: failed after 6 attempts" >&2
            exit 1
          fi
          sleep 10
        done
        echo "$(date '+%F %T') push-server-index: shipped, links served: $(curl -s --max-time 8 http://100.88.29.31/ | grep -c 'href=')"
      ''}";
    };
  };
}
