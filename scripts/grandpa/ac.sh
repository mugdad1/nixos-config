#!/usr/bin/env bash
# ac — the AC, one command. His standing ask (2026-10-20): *"i will
# consitntly ask u so u must know how to do it easly / in same seconf"*.
#
# Why this exists: the token was lost the same day it was first used — it was
# driven from a long-lived HA token that was never written down, and the only
# copy left was inside the opencode session log. So the token lives in a file
# now (see TOKEN below) and this script never asks for it again.
#
#   ac                 status — power, temp, swing
#   ac on | off
#   ac 24              set the temperature (16..30, the protocol's real span)
#   ac up | ac down    nudge by one
#   ac up 3            nudge by three
#   ac swing on|off    swing
#
# Entities are plain switch/number, not climate — row 114: his rule *"name it
# on not cool"*, and the fan never shipped (row 113, no fan codes in the 17
# captures).
#
# Why every action compares last_updated before and after: a 200 from HA only
# means HA accepted the call, and HA is optimistic — it stores what was
# *commanded*, not what the unit took (row 164). Worse, when the entity
# already holds the target value the call registers NOTHING at all, so the old
# script printed "temp 24" three times in a row while the unit sat still,
# because HA had been reading 24.0 since an hour earlier. He had to change it
# in the app himself. So: send, then look, then say which happened. And when
# nothing registered, force it — nudging the temperature off its value and
# back, because the AC's IR word carries the whole state (power, temp, swing)
# so any real change re-transmits it.
set -euo pipefail

TOKEN_FILE="${AC_TOKEN_FILE:-$HOME/.local/state/opencode/ha-token}"
# Home Assistant runs on THIS box, so loopback is the endpoint. The default used
# to be http://100.88.29.31:8123 — the ThinkCentre's tailscale IP, dead since the
# box was returned to its owner (2026-10-22, decisions row 188), which left every
# bare `ac` call timing out after 10s. AC_HOST overrides it for pointing at
# another HA (the laptop reaches grandpa at http://100.106.116.60:8123).
HA="${AC_HOST:-http://127.0.0.1:8123}"

POWER="switch.bedroom_ac_control_ac"
SWING="switch.bedroom_ac_control_ac_swing"
TEMP="number.bedroom_ac_control_ac_temperature"

die() { echo "ac: $*" >&2; exit 1; }

[ -s "$TOKEN_FILE" ] || die "no token at $TOKEN_FILE — put a long-lived HA token there (HA > profile > Security > Long-Lived Access Tokens)."
TK=$(cat "$TOKEN_FILE")

api() { # api <service> <json>
  local code
  code=$(curl -s -m 10 -o /dev/null -w '%{http_code}' -X POST \
    -H "Authorization: Bearer $TK" -H 'Content-Type: application/json' \
    -d "$2" "$HA/api/services/$1")
  [ "$code" = 200 ] || die "$1 -> HTTP $code"
}

state() { # state <entity> -> just the state string
  curl -s -m 10 -H "Authorization: Bearer $TK" "$HA/api/states/$1" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin).get("state","?"))'
}

snap() { # snap <entity> -> HA last_updated, "" if it cannot be read
  curl -s -m 10 -H "Authorization: Bearer $TK" "$HA/api/states/$1" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin).get("last_updated",""))' \
    2>/dev/null || true
}

send() { # send <entity> <service> <json> -> "changed" | "unchanged"
  local ent="$1" before after i=0
  before=$(snap "$ent")
  api "$2" "$3"
  after="$before"
  while [ "$i" -lt 6 ] && [ "$after" = "$before" ]; do
    sleep 0.3
    after=$(snap "$ent")
    i=$((i + 1))
  done
  if [ -n "$after" ] && [ "$after" != "$before" ]; then
    echo changed
  else
    echo unchanged
  fi
}

# The set_* wrappers exist so the JSON payload is built in one place. Trying to
# write {"entity_id":"...","value":...} inline inside a $(...) nested in a [
# ] test is what shellcheck chokes on (SC1073); keeping it out of the call site
# is both parseable and readable.

set_power() { # set_power <on|off> -> "changed" | "unchanged"
  local body="{\"entity_id\":\"$POWER\"}"
  send "$POWER" "switch/turn_$1" "$body"
}

set_swing() { # set_swing <on|off> -> "changed" | "unchanged"
  local body="{\"entity_id\":\"$SWING\"}"
  send "$SWING" "switch/turn_$1" "$body"
}

set_temp() { # set_temp <value> -> "changed" | "unchanged"
  local body="{\"entity_id\":\"$TEMP\",\"value\":$1}"
  send "$TEMP" number/set_value "$body"
}

force() { # force — nothing registered, so re-send for real
  local t n
  t=$(state "$TEMP")
  case "$t" in ''|'?') return 0 ;; esac
  n=$(python3 -c "t=float('$t'); print(int(t-1) if t > 16 else int(t+1))")
  set_temp "$n" >/dev/null || true
  set_temp "$t" >/dev/null || true
}

cmd="${1:-status}"
case "$cmd" in
  status)
    printf 'power: %s\n' "$(state "$POWER")"
    printf 'temp:  %s\n' "$(state "$TEMP")"
    printf 'swing: %s\n' "$(state "$SWING")"
    ;;
  on)
    if [ "$(set_power on)" = changed ]; then
      echo "ac on"
    else
      force
      echo "ac on (HA already read on — nudged and re-sent so a frame actually went out)"
    fi
    ;;
  off)
    if [ "$(set_power off)" = changed ]; then
      echo "ac off"
    else
      force
      echo "ac off (HA already read off — nudged and re-sent so a frame actually went out)"
    fi
    ;;
  swing)
    case "${2:-}" in
      on|off)
        action="$2"
        if [ "$(set_swing "$action")" = changed ]; then
          echo "swing $action"
        else
          force
          echo "swing $action (HA already read $action — nudged and re-sent so a frame actually went out)"
        fi
        ;;
      *) die "usage: ac swing on|off" ;;
    esac
    ;;
  up|down|+|-)
    n="${2:-1}"
    case "$cmd" in up|+) dir=1 ;; *) dir=-1 ;; esac
    case "$n" in
      ''|*[!0-9]*) die "nudge must be a whole number, got '$n'" ;;
    esac
    cur=$(state "$TEMP")
    tgt=$(python3 -c "
c, d, n = float('$cur'), $dir, int('$n')
t = c + d * n
print(int(min(30, max(16, t))))")
    if [ "$(set_temp "$tgt")" = changed ]; then
      echo "temp $tgt"
    else
      force
      echo "temp $tgt (clamped — HA already read $tgt, nudged and re-sent so a frame actually went out)"
    fi
    ;;
  [0-9]*)
    case "$cmd" in
      1[6-9]|2[0-9]|30) ;;
      *) die "temp must be 16..30 (the protocol's real span)" ;;
    esac
    if [ "$(set_temp "$cmd")" = changed ]; then
      echo "temp $cmd"
    else
      force
      echo "temp $cmd (HA already read $cmd — nudged and re-sent so a frame actually went out)"
    fi
    ;;
  *)
    die "usage: ac [status|on|off|<16-30>|up [n]|down [n]|swing on|off]"
    ;;
esac
