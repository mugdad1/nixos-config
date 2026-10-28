{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.victus.batteryChargeLimit;

  # The EC has no percentage register.  This is a userspace policy loop around
  # HP's ACPI "Battery Health Manager" mode: SBCO 0x05 inhibits charging,
  # SBCO 0x00 restores normal charging.  GBCO reads the live mode back:
  # 0x04 means the firmware has actually stopped charging.
  #
  # This is deliberately NOT a TLP threshold and NOT a direct EC write.  It is
  # the same firmware path the out-of-tree hp-omen-dkms battery patch uses; the
  # board-specific test for 8A4F was:
  #   SBCO 0x05 -> status "Not charging", power_now 0, GBCO 0x04
  #   SBCO 0x00 -> status "Charging"
  batteryLimit = pkgs.writeShellScriptBin "victus-battery-limit" ''
    set -u

    CALL=/proc/acpi/call
    BAT=/sys/class/power_supply/BAT0
    AC=/sys/class/power_supply/ADP1
    STATE=/run/victus-battery-charge-limit.mode
    STOP=${toString cfg.stopAt}
    RESUME=${toString cfg.resumeAt}
    INTERVAL=${toString cfg.pollInterval}

    log() { echo "victus-battery-limit: $*"; }

    call() {
      printf '%s' "$1" > "$CALL" || return 1
      cat "$CALL" || return 1
    }

    gbco() {
      local out
      out="$(call '\_SB.WMID.GBCO' | tr -d '\000')" || return 1
      printf '%s\n' "$out" | sed -n 's/.*{0x\([0-9a-fA-F]*\),.*/\1/p' | head -n 1
    }

    set_mode() {
      local mode="$1" out
      out="$(call "\\_SB.WMID.SBCO BUFQ{0x00, 0x$mode, 0x00, 0x00}" | tr -d '\000')" || return 1
      case "$out" in
        "[0x0, 0x0,"*) return 0 ;;
        *)
          log "SBCO mode 0x$mode returned: $out"
          return 1
          ;;
      esac
    }

    ac_online() {
      if [ -r "$AC/online" ]; then
        [ "$(cat "$AC/online")" = 1 ]
      else
        [ "$(cat "$BAT/status")" != Discharging ]
      fi
    }

    remember() {
      printf '%s\n' "$1" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
    }

    status() {
      local cap mode
      cap="$(cat "$BAT/capacity")"
      if [ "$(id -u)" -eq 0 ]; then
        mode="$(gbco 2>/dev/null || true)"
      fi
      echo "AC:      $([ "$(cat "$AC/online" 2>/dev/null || echo 0)" = 1 ] && echo online || echo offline)"
      echo "Battery: $cap% ($(cat "$BAT/status"))"
      if [ "$(id -u)" -eq 0 ]; then
        echo "GBCO:    ''${mode:-unavailable}"
      else
        echo "GBCO:    requires root (use sudo)"
      fi
      echo "Policy:  stop at $STOP%, resume at $RESUME%"
      echo "State:   $(cat "$STATE" 2>/dev/null || echo unknown)"
    }

    tick() {
      local cap mode last
      if [ ! -e "$CALL" ]; then
        log "acpi_call is not loaded ($CALL missing)"
        return 1
      fi
      if [ ! -r "$BAT/capacity" ]; then
        log "$BAT/capacity is missing"
        return 1
      fi

      cap="$(cat "$BAT/capacity")"
      last="$(cat "$STATE" 2>/dev/null || true)"

      # HP's own firmware derives _BST partly from BDVO.  Never leave an
      # inhibit armed while unplugged; clear it once and otherwise stay out.
      if ! ac_online; then
        if [ "$last" != auto ]; then
          if set_mode 00; then
            remember auto
            log "on battery; cleared charge inhibit"
          fi
        fi
        return 0
      fi

      mode="$(gbco 2>/dev/null || true)"
      if [ "$cap" -ge "$STOP" ]; then
        if [ "$mode" = 04 ]; then
          [ "$last" = inhibit ] || remember inhibit
          return 0
        fi
        if set_mode 05; then
          remember inhibit
          log "AC $cap% >= $STOP%; charging inhibited"
        fi
      elif [ "$cap" -le "$RESUME" ]; then
        if [ "$last" = inhibit ] || [ "$mode" = 04 ]; then
          if set_mode 00; then
            remember auto
            log "AC $cap% <= $RESUME%; charging resumed"
          fi
        fi
      else
        log "AC $cap% between $RESUME% and $STOP%; leaving charging state alone"
      fi
    }

    daemon() {
      trap 'set_mode 00 >/dev/null 2>&1 || true; exit 0' TERM INT
      while :; do
        tick || true
        # Background sleep + wait so a TERM from systemd interrupts the wait
        # and the trap can restore auto mode promptly.
        sleep "$INTERVAL" &
        wait $! || true
      done
    }

    case "''${1:-daemon}" in
      daemon) daemon ;;
      status) status ;;
      auto)
        set_mode 00 && echo "charging restored to auto"
        ;;
      inhibit)
        if ! ac_online; then
          echo "refusing to inhibit: AC is offline" >&2
          exit 1
        fi
        set_mode 05 && echo "charging inhibited"
        ;;
      *)
        echo "usage: victus-battery-limit {status|auto|inhibit|daemon}" >&2
        exit 2
        ;;
    esac
  '';
in {
  options.services.victus.batteryChargeLimit = {
    enable = lib.mkEnableOption "HP Victus battery charge limiting via ACPI GBCO/SBCO";
    stopAt = lib.mkOption {
      type = lib.types.ints.between 20 100;
      default = 80;
      description = "Battery percentage at which AC charging is inhibited.";
    };
    resumeAt = lib.mkOption {
      type = lib.types.ints.between 1 99;
      default = 77;
      description = "Battery percentage at which AC charging resumes.";
    };
    pollInterval = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60;
      description = "Seconds between battery checks.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.extraModulePackages = [ config.boot.kernelPackages.acpi_call ];
    boot.kernelModules = [ "acpi_call" ];
    assertions = [
      {
        assertion = cfg.resumeAt < cfg.stopAt;
        message = "services.victus.batteryChargeLimit.resumeAt must be below stopAt";
      }
    ];

    environment.systemPackages = [batteryLimit];

    systemd.services.victus-battery-charge-limit = {
      description = "HP Victus battery charge limit (ACPI SBCO/GBCO)";
      wantedBy = ["multi-user.target"];
      after = ["systemd-modules-load.service"];
      wants = ["systemd-modules-load.service"];
      # acpi_call is out-of-tree and nixpkgs ships it without the .ko.cer
      # sidecar that NixOS's module-merging build expects, so load the exact
      # kernel-matched .ko directly instead of using boot.extraModulePackages.
      preStart = ''
        if ! grep -q '^acpi_call ' /proc/modules; then
          ${pkgs.kmod}/bin/modprobe acpi_call
        fi

      '';
      serviceConfig = {
        Type = "simple";
        ExecStart = "${batteryLimit}/bin/victus-battery-limit daemon";
        Restart = "on-failure";
        RestartSec = 15;
        TimeoutStopSec = 20;
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };
  };
}
