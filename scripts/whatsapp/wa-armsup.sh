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
#
# ── THE WAKE (2026-10-20, his "he responds but tooo slow ... wtf") ───────────
# The watcher's exit on a hit has always been *the* signal -- packages.nix says
# so: "Exits on a hit: the completion is what wakes the agent." But this loop
# only logged the hit and slept 5 s, and nothing else woke him either: the
# bridge POSTs every message to localhost:8769 where NO listener existed
# (connection refused, per message, all day), so the only replies that ever
# happened came from a session that happened to be mid-turn on someone else's
# prompt -- which is also why they took 60-120 s: a bloated session grinding
# through another task, not a wake.
#
# So the wake lives HERE, next to the hit, the way the old shell-background
# method worked: watcher exits on rows -> one `opencode run` into the
# dedicated WhatsApp session (WA_SESSION, set by the unit) -> he answers.
# Serialised behind a flock so two hits can never interleave turns in one
# session, log-first into wa-wake.log (the same log-first shape wa-send has).
# stdout is captured instead of streamed, because the wake decision is made on
# it -- the watcher already writes the same hit lines to wa-watch.log itself,
# so nothing is lost to the journal that matters.
set -u

STATE="${WA_STATE:-$HOME/.local/state/opencode}"
STOP="$STATE/wa-stop"
WATCHLOG="$STATE/wa-watch.log"
WAKELOG="$STATE/wa-wake.log"
WAKELOCK="$STATE/wa-wake.lock"
# The dedicated session, minted by the app (opencode mini) and continued by
# CLI runs. Empty means "no wake target configured" -- logged, never guessed.
WA_SESSION="${WA_SESSION:-}"
CAP="${1:-1800}"

if [ -e "$STOP" ]; then
  echo "STOP flag present ($STOP) -- refusing to supervise" >&2
  exit 3
fi

mkdir -p "$STATE"

wake() {
  rows="$1"
  if [ -z "$WA_SESSION" ]; then
    printf '%s wake: WA_SESSION unset -- NOT waking, hit logged only\n' \
      "$(date '+%F %T')" >>"$WATCHLOG"
    return 0
  fi
  # flock serialises: a second hit arriving while the first turn is still
  # running queues behind it instead of racing into the same session. The
  # whole wake runs in the background so the re-arm never waits on a model.
  (
    flock 9 || exit 1
    {
      printf '%s wake -> %s\n' "$(date '+%F %T')" "$WA_SESSION"
      printf '%s\n' "$rows"
    } >>"$WAKELOG"
    opencode run --agent server -s "$WA_SESSION" "WA WAKE $(date '+%F %T') - the background watcher just exited on these rows (allow-list scoped, our own sends already filtered out). Answer them now in WhatsApp with wa-send: [AI] prefix, log-first, short first reply, investigating after. This is the wake prompt, not text typed by him in this session.

$rows" >>"$WAKELOG" 2>&1
    printf '%s wake done rc=%s\n' "$(date '+%F %T')" "$?" >>"$WAKELOG"
  ) 9>>"$WAKELOCK" &
}

while :; do
  out="$(watch-whatsapp.py "$CAP" 2>&1)"
  rc=$?
  printf 'armsup: watcher exited rc=%s %s\n' "$rc" "$(date '+%F %T')" >>"$WATCHLOG"
  if [ "$rc" = 3 ] || [ -e "$STOP" ]; then
    echo "armsup: standing down (stop flag)" >>"$WATCHLOG"
    exit 3
  fi
  if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'rowid='; then
    wake "$(printf '%s\n' "$out" | grep 'rowid=')"
  elif [ "$rc" != 0 ]; then
    printf 'armsup: watcher rc=%s: %s\n' "$rc" "$out" >>"$WATCHLOG"
  fi
  sleep 5
done
