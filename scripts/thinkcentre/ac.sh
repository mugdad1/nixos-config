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
set -euo pipefail

TOKEN_FILE="${AC_TOKEN_FILE:-$HOME/.local/state/opencode/ha-token}"
HA="${AC_HOST:-http://100.88.29.31:8123}"

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

cmd="${1:-status}"
case "$cmd" in
  status)
    printf 'power: %s\n'  "$(state "$POWER")"
    printf 'temp:  %s\n'  "$(state "$TEMP")"
    printf 'swing: %s\n'  "$(state "$SWING")"
    ;;
  on)
    api switch/turn_on "{\"entity_id\":\"$POWER\"}"
    echo "ac on"
    ;;
  off)
    api switch/turn_off "{\"entity_id\":\"$POWER\"}"
    echo "ac off"
    ;;
  swing)
    case "${2:-}" in
      on)  api switch/turn_on  "{\"entity_id\":\"$SWING\"}"; echo "swing on" ;;
      off) api switch/turn_off "{\"entity_id\":\"$SWING\"}"; echo "swing off" ;;
      *)   die "usage: ac swing on|off" ;;
    esac
    ;;
  up|down|+|-)
    n="${2:-1}"
    case "$cmd" in up|+)  dir=1 ;; *) dir=-1 ;; esac
    cur=$(state "$TEMP")
    tgt=$(python3 -c "
c, d, n = float('$cur'), $dir, int('$n')
t = c + d * n
print(int(min(30, max(16, t))))")
    api number/set_value "{\"entity_id\":\"$TEMP\",\"value\":$tgt}"
    echo "temp $tgt"
    ;;
  [0-9]*)
    case "$cmd" in
      1[6-9]|2[0-9]|30) ;;
      *) die "temp must be 16..30 (the protocol's real span)" ;;
    esac
    api number/set_value "{\"entity_id\":\"$TEMP\",\"value\":$cmd}"
    echo "temp $cmd"
    ;;
  *)
    die "usage: ac [status|on|off|<16-30>|up [n]|down [n]|swing on|off]"
    ;;
esac
