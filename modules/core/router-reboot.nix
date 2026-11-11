# `router-reboot` — reboot the Huawei H122-373 at 192.168.8.1.
# The command is shared so any host can bounce the router; grandpa owns the
# daily timer. The password lives in ~/.config/router-reboot/pass (mode 600).
{pkgs, ...}: let
  routerUrl = "http://192.168.8.1";
  routerUser = "admin";
  passFile = ".config/router-reboot/pass";

  py = pkgs.python3.withPackages (ps: [ps.huawei-lte-api]);

  reboot = pkgs.writeText "reboot-router.py" ''
    import os
    import sys
    import time
    import urllib.request

    from huawei_lte_api.Client import Client
    from huawei_lte_api.Connection import Connection
    from huawei_lte_api.enums.device import ControlModeEnum

    URL = ${builtins.toJSON routerUrl}
    USER = ${builtins.toJSON routerUser}
    PW = os.environ.get("HUAWEI_ROUTER_PASS", "")

    if not PW.strip():
        sys.exit("router-reboot: no password. Put it in ~/" + ${builtins.toJSON passFile})

    # Reachability first, so "wrong password" and "router unplugged" differ.
    try:
        urllib.request.urlopen(URL, timeout=6)
    except Exception as exc:
        sys.exit(f"router-reboot: {URL} unreachable ({exc}) — is the router up?")

    try:
        with Connection(URL, USER, PW, timeout=15) as conn:
            client = Client(conn)
            try:
                info = client.device.information()
                bits = [info[k] for k in ("ProductFamily", "HardwareVersion", "SoftwareVersion") if info.get(k)]
                print(f"router : {' / '.join(bits) or 'model unknown'} @ {URL}")
            except Exception:
                pass
            # Named constant, never a literal: ControlModeEnum.RESET is 2 and
            # would factory-reset the router.
            resp = client.device.set_control(control=ControlModeEnum.REBOOT)
            print(f"reboot : accepted ({resp})")
    except Exception as exc:
        sys.exit(f"router-reboot: {type(exc).__name__}: {exc}")

    print("waiting for it to return ...", flush=True)
    for i in range(24):
        time.sleep(5)
        try:
            urllib.request.urlopen(URL, timeout=5)
            print(f"back after ~{(i + 1) * 5}s")
            sys.exit(0)
        except Exception:
            continue
    sys.exit("router-reboot: NOT BACK after 120s — check it physically")
  '';

  routerReboot = pkgs.writeShellScriptBin "router-reboot" ''
    set -euo pipefail

    PASS_FILE="$HOME/${passFile}"

    if [ ! -f "$PASS_FILE" ]; then
      if [ -t 0 ]; then
        echo "router-reboot: first run — storing the router password once in" >&2
        echo "  $PASS_FILE (mode 600, not in git, never in a commit)." >&2
        mkdir -p "$(dirname "$PASS_FILE")"
        umask 077
        read -rsp "  router password: " PW; echo >&2
        if [ -z "$PW" ]; then
          echo "  empty — nothing saved." >&2
          exit 1
        fi
        printf '%s' "$PW" > "$PASS_FILE"
        unset PW
        echo "  saved." >&2
      else
        echo "router-reboot: no password file, and stdin is not a terminal." >&2
        echo "  run 'router-reboot' interactively once to record it," >&2
        echo "  or create $PASS_FILE yourself (chmod 600)." >&2
        exit 1
      fi
    fi
    if [ ! -s "$PASS_FILE" ]; then
      echo "router-reboot: $PASS_FILE exists but is empty." >&2
      exit 1
    fi

    # Exported so the password never appears in `ps`.
    export HUAWEI_ROUTER_PASS="$(cat "$PASS_FILE")"

    exec ${py}/bin/python3 ${reboot} "$@"
  '';
in {
  environment.systemPackages = [routerReboot];
}
