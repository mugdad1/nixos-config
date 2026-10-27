{
  host,
  lib,
  pkgs,
  ...
}:
# One command, several routes, no choices to remember: `bypass` tries each in
# order and stops at the first that answers. `bypass off` undoes it, `bypass
# status` says what is up.
#
#   1. zapret       DPI desync for ordinary HTTPS (websites that Fortinet
#                   blocks by SNI). Tailscale-safe by construction — see
#                   modules/core/zapret.nix.
#   2. snowflake    local Tor, no bridge line needed. Flaky: it reached 100%
#                   twice and stalled at 45% once, which is why it is not the
#                   only route.
#   3. home         Tor through grandpa's own daemon over the tailnet. The
#                   laptop stops its local tor and an ssh -L puts grandpa's
#                   SOCKS on 127.0.0.1:9050, so applications see the same
#                   address either way. WireGuard matches no DPI rule, so this
#                   is the route that survives a campus that blocks snowflake.
#
# Every route ends with 127.0.0.1:9050 live, so nothing downstream has to know
# which one won.
let
  dpi = builtins.elem host ["victus" "t480s"];

  bypass = pkgs.writeShellScriptBin "bypass" ''
    #!/usr/bin/env bash
    set -uo pipefail
    PATH=/run/current-system/sw/bin:/run/wrappers/bin:$PATH
    export PATH

    REMOTE="mugdad@100.106.116.60"
    # The tunnel is ssh, so it must run as the human, not as root: root has no
    # key for grandpa (the test on 2026-10-27 failed exactly there — the unit
    # died instantly and `systemctl is-active` said inactive). 9050 is above
    # 1024, so no privilege is needed to bind it.
    RUNAS="''${SUDO_USER:-}"
    [ -n "$RUNAS" ] || RUNAS=$(logname 2>/dev/null || id -un)

    say() { printf '%s\n' "$*"; }
    ok()  { printf '  ok    %s\n' "$*"; }
    bad() { printf '  fail  %s\n' "$*"; }

    tor_ok() {
      timeout 12 curl -fsS --max-time 8 --socks5-hostname 127.0.0.1:9050 \
        https://check.torproject.org/api/ip 2>/dev/null | grep -q '"IsTor":true'
    }

    tunnel_up() { systemctl is-active --quiet bypass-home; }

    tunnel_start() {
      systemctl stop bypass-home 2>/dev/null || true
      systemctl reset-failed bypass-home 2>/dev/null || true
      # --uid is the whole point: the service must use the human's ssh keys,
      # not /root/.ssh. No --collect, so a failure stays in `systemctl status
      # bypass-home` and `journalctl -u bypass-home` instead of vanishing.
      systemd-run --unit=bypass-home --quiet --uid="$RUNAS" \
        --property=Restart=on-failure --property=RestartSec=3 \
        "$(command -v ssh)" -N -o BatchMode=yes -o ExitOnForwardFailure=yes \
        -o ServerAliveInterval=15 -o ServerAliveCountMax=3 \
        -L 127.0.0.1:9050:127.0.0.1:9050 "$REMOTE" >/dev/null 2>&1 || return 1
      sleep 2
      tunnel_up
    }

    wait_bootstrap() {
      # Only lines written after this restart count; a stale 100% from earlier
      # in the same boot must not be mistaken for progress.
      local since=$1 i=0 last
      while [ "$i" -lt 22 ]; do
        last=$(journalctl -u tor -b --since "@$since" --no-pager -o cat 2>/dev/null \
               | grep -oE 'Bootstrapped [0-9]+%' | tail -1)
        [ "$last" = "Bootstrapped 100%" ] && return 0
        sleep 3
        i=$((i+1))
      done
      return 1
    }

    cmd_on() {
      say "trying routes ..."
      systemctl start zapret 2>/dev/null && ok "zapret (DPI desync)" || bad "zapret"

      # Test hook: BYPASS_SKIP_LOCAL=1 jumps straight to the home route, which
      # is the only way to exercise that branch from a network where snowflake
      # happens to be healthy today.
      if [ "''${BYPASS_SKIP_LOCAL:-0}" = 1 ]; then
        say "  ... skipping snowflake (BYPASS_SKIP_LOCAL=1)"
      else
        say "  ... local Tor via snowflake"
        local since
        since=$(date +%s)
        systemctl restart tor
        if wait_bootstrap "$since" && tor_ok; then
          ok "Tor via snowflake — 127.0.0.1:9050 is live"
          return 0
        fi
        bad "snowflake did not come up"
      fi

      say "  ... Tor through grandpa over the tailnet"
      if ! timeout 15 tailscale ping -c 1 100.106.116.60 >/dev/null 2>&1; then
        bad "tailscale cannot reach grandpa"
        say ""
        say "no route worked. Meanwhile: ordinary websites may still work — zapret is on."
        say "Tor needs a bridge line: put one in /var/lib/tor/bridges.conf, then rerun."
        return 1
      fi
      systemctl stop tor
      if tunnel_start && tor_ok; then
        ok "Tor via grandpa — 127.0.0.1:9050 is live"
        return 0
      fi
      bad "grandpa tunnel did not answer"
      systemctl stop bypass-home 2>/dev/null || true
      systemctl start tor 2>/dev/null || true
      say ""
      say "no route worked. Meanwhile: ordinary websites may still work — zapret is on."
      say "Tor needs a bridge line: put one in /var/lib/tor/bridges.conf, then rerun."
      return 1
    }

    cmd_off() {
      systemctl stop bypass-home 2>/dev/null || true
      systemctl stop zapret 2>/dev/null || true
      systemctl start tor 2>/dev/null || true
      say "zapret off, tunnel closed, local tor restarted"
    }

    cmd_status() {
      printf 'zapret:  %s\n' "$(systemctl is-active zapret 2>/dev/null || true)"
      printf 'tunnel:  %s\n' "$(systemctl is-active bypass-home 2>/dev/null || true)"
      printf 'tor:     %s\n' "$(systemctl is-active tor 2>/dev/null || true)"
      journalctl -u tor -b --no-pager -o cat 2>/dev/null \
        | grep -oE 'Bootstrapped [0-9]+% \([a-z_]+\)' | tail -1 | sed 's/^/         /'
      if tunnel_up; then
        ok "SOCKS works — route: grandpa over the tailnet"
      elif tor_ok; then
        ok "SOCKS works — route: local tor (snowflake)"
      else
        bad "SOCKS does not answer"
      fi
      printf 'dns:     example.com -> %s\n' "$(timeout 5 dig +short example.com | head -1)"
      printf '         doubleclick.net -> %s (0.0.0.0 = filtered)\n' "$(timeout 5 dig +short doubleclick.net | head -1)"
      timeout 10 tailscale ping -c 1 100.106.116.60 2>&1 | head -1 | sed 's/^/tailnet: /'
    }

    if [ "$(id -u)" -ne 0 ]; then exec sudo -- "$0" "$@"; fi

    case "''${1:-on}" in
      on|start) cmd_on ;;
      off|stop) cmd_off ;;
      status)   cmd_status ;;
      *) say "usage: bypass [on|off|status]"; exit 2 ;;
    esac
  '';
in
  lib.mkIf dpi {
    environment.systemPackages = [bypass];
  }
