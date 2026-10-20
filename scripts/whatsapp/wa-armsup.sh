#!/usr/bin/env bash
# Keep one WhatsApp watcher armed, one arm at a time.
#
#     wa-armsup.sh [cap_seconds]          # default 1800
#
# "One arm at a time" is load-bearing: two arms share the rowid cursor, so the
# second does not double-report -- it starves the first, which polls blind until
# EXPIRED. That is strictly worse than double reporting and it looks exactly
# like the duty being held.
#
# The stop flag is checked before arming and after every arm, so a "stop" takes
# down the supervisor as well as the watcher. Without that check the supervisor
# would simply respawn a watcher that refuses -- an infinite refuse loop that
# keeps the log moving and looks alive.
#
# Output goes to wa-watch.log rather than to whatever launched us: a watcher's
# stdout is only useful if the reader outlives it, and arms launched over SSH
# died with their connection three times on 2026-10-03.
set -u

STATE="${WA_STATE:-$HOME/.local/state/opencode}"
STOP="$STATE/wa-stop"
WATCHLOG="$STATE/wa-watch.log"
CAP="${1:-1800}"

if [ -e "$STOP" ]; then
  echo "STOP flag present ($STOP) -- refusing to supervise" >&2
  exit 3
fi

mkdir -p "$STATE"

while :; do
  watch-whatsapp.py "$CAP"
  rc=$?
  printf 'armsup: watcher exited rc=%s %s\n' "$rc" "$(date '+%F %T')" >>"$WATCHLOG"
  if [ "$rc" = 3 ] || [ -e "$STOP" ]; then
    echo "armsup: standing down (stop flag)" >>"$WATCHLOG"
    exit 3
  fi
  sleep 5
done
