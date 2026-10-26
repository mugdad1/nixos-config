# ─── router-reboot — one command to reboot the house router ──────────────────
#
# The COMMAND lives here, in modules/core, so every host gets it: being able to
# bounce the router from a laptop when the internet dies is exactly when it
# matters, and that is not a moment to be on the server. The SCHEDULED run does
# not live here — it is in hosts/grandpa/router-reboot.nix, because a timer in
# this file would fire on all three hosts at once, and two of them would lose
# the race and go red every night.
#
# His word, 2026-10-19, after I went hunting for credentials that were never
# lost: *"i just did it / simple run the cmd router-reboot no params"*. And
# 2026-10-26, *"bring it to grandpa"* — the original left with the ThinkCentre
# when that box was returned, taking the script with it (wiki row 133 records
# the original: a hand-rolled ~/.local/bin wrapper exporting HUAWEI_ROUTER_PASS
# inline, exec'ing a venv python at ~/projects/router-reboot/).
#
# WHAT CHANGED IN THE REBUILD, and why it is better:
#
#   1. NO VENV. The original pip-installed huawei_lte_api into a project venv.
#      nixpkgs carries it — python3Packages.huawei-lte-api 2.0.1 — so the
#      dependency is declarative and comes back with a reinstall instead of
#      needing a network fetch and a directory nobody remembers to recreate.
#   2. PASSWORD IS NOT IN GIT. The repo is PUBLIC (see .sops.yaml's header for
#      the reasoning), and the original had it inline in a wrapper that was
#      only safe because ~/.local/bin is not versioned. This reads it from
#      ~/.config/router-reboot/pass (mode 600) — still one command to run, but
#      the credential never enters the repository or its permanent history.
#      That preserves his actual requirement, which was "no secret hunt", not
#      "secrets in plaintext files I have to hunt for".
#
# THE DEVICE: Huawei H122-373 (5G CPE Pro 2) at 192.168.8.1. That address is
# the house's gateway and, per servers.md rule 4, the permanent second
# nameserver pinned on both machines — so a reboot here briefly interrupts
# resolution house-wide, not just the internet. The flake already treats it as
# unreachable-but-tolerated: checkup.sh pings it and reports by name.
#
# HOW THE API WORKS (found by reading the package, not guessed):
#   Connection(url, user, pass) logs in via UserSession on construction.
#   Device.set_control(control) POSTs device/control {"Control": <int>}.
#   ControlModeEnum.REBOOT = 1 — but the enum ALSO has RESET = 2, which is
#   FACTORY RESET. The call is spelled out with the named constant rather than
#   a bare 1 for exactly that reason: a transposed digit here wipes the router.
#
#   Probed live 2026-10-26 before writing any of this: GET api/device/basic_
#   information answers without auth, GET api/device/information returns
#   <error><code>100003</code> — i.e. "login required". So auth is mandatory
#   for the reboot path and the failure mode is a clear code, not a hang.
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

    # Reachability first: without it a typo'd host or a dead link reports as an
    # auth error, and "wrong password" and "router unplugged" need different
    # fixes.
    try:
        urllib.request.urlopen(URL, timeout=6)
    except Exception as exc:
        sys.exit(f"router-reboot: {URL} unreachable ({exc}) — is the router up?")

    try:
        with Connection(URL, USER, PW, timeout=15) as conn:
            client = Client(conn)
            # Cosmetic only, and strictly guarded: if a firmware revision
            # renames a field, that must NOT stop the reboot from firing.
            # Keys confirmed live 2026-10-26 against the real unit — the first
            # version asked for ProductName, which this device does not return,
            # so it would have logged "model unknown" every single night.
            try:
                info = client.device.information()
                bits = [info[k] for k in ("ProductFamily", "HardwareVersion", "SoftwareVersion") if info.get(k)]
                print(f"router : {' / '.join(bits) or 'model unknown'} @ {URL}")
            except Exception:
                pass
            # Named constant, never a literal — see the header: RESET is 2.
            resp = client.device.set_control(control=ControlModeEnum.REBOOT)
            print(f"reboot : accepted ({resp})")
    except Exception as exc:
        sys.exit(f"router-reboot: {type(exc).__name__}: {exc}")

    # The reboot takes ~40-60s. Wait it out and PROVE it came back rather than
    # printing "done" while the house still has no gateway — an unrecoverable
    # router is the one outcome worth the extra minute here.
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

    # ~ expansion at runtime, not at build: $HOME differs per user and a
    # build-time /home/mugdad would be wrong on the laptops.
    PASS_FILE="$HOME/${passFile}"

    # First run: ask once, save it, and from then on it is one command with
    # no params — which is the whole point of row 133 (*"simple run the cmd
    # router-reboot no params"*). Prompting here instead of demanding a
    # pre-made file means the credential is captured without ever being
    # typed into a chat, a commit, or a file outside $HOME.
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
        # printf, not echo: no trailing newline to trip over later, and no
        # shell interpretation of a password containing backslashes.
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

    # Exported rather than passed as an argv, so the password never appears
    # in `ps` output — which is the one way a credential leaks on a shared
    # box without anyone reading a file.
    export HUAWEI_ROUTER_PASS="$(cat "$PASS_FILE")"

    exec ${py}/bin/python3 ${reboot} "$@"
  '';
in {
  environment.systemPackages = [routerReboot];
}
