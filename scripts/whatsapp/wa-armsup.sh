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
  # LOG-FIRST, same rule wa-send has: the intent is written before anything
  # is spawned, so a box that dies mid-wake still shows a wake was issued and
  # which rows it carried.
  printf '%s wake -> %s\n%s\n' "$(date '+%F %T')" "$WA_SESSION" "$rows" >>"$WAKELOG"
  # NOT a subshell of this script, deliberately: a fork keeps this script's
  # argv, so the arm counter (and anyone reading ps) would see a second
  # "wa-armsup.sh" that is only a wake. `bash -c` overwrites argv on exec --
  # same reason the hit-capture below execs python instead of forking a
  # wrapper. flock serialises: two hits queue behind each other rather than
  # racing into one session.
  # shellcheck disable=SC2094  # WAKELOCK is passed as env AND opened for
  # flock; nothing reads it as data — it is an inter-process lock file
  WA_SESSION="$WA_SESSION" WAKELOG="$WAKELOG" WAKELOCK="$WAKELOCK" WA_ROWS="$rows" \
    bash -c '
      set -u
      flock 9 || exit 1
      # RE-CHECK THE ROWS AT DELIVERY TIME, not at arm time. The lock is held
      # for as long as the previous model turn takes (2026-10-20: up to four
      # minutes), so a row that was unanswered when the arm caught it can be
      # answered by the time this wake is actually delivered. Five such
      # stale wakes fired in a row that afternoon, each one a prompt to
      # answer a question already answered and each one holding the lock a
      # REAL message was queued behind -- the exact latency the wake exists
      # to remove. The poller knows how to tell our own sends apart (it
      # matches wa-sent-texts); this asks the same question of the DB at the
      # moment it matters and drops what is already answered.
      #
      # If the filter cannot run, the rows pass through unchanged: a
      # redundant wake is better than a missed message.
      pending="$(printf "%s\n" "$WA_ROWS" | watch-whatsapp.py --filter-answered 2>>"$WAKELOG" || printf "%s\n" "$WA_ROWS")"
      if [ -z "$pending" ]; then
        printf "%s wake: every carried row is already answered -- NOT waking\n" "$(date "+%F %T")" >>"$WAKELOG"
        exit 0
      fi
      opencode run --agent server -s "$WA_SESSION" "WA WAKE $(date "+%F %T") - the background watcher just exited on these rows (allow-list scoped, our own sends already filtered out). Answer them now in WhatsApp with wa-send: [AI] prefix, log-first, short first reply, investigating after. This is the wake prompt, not text typed by him in this session.

$pending" >>"$WAKELOG" 2>&1
      printf "%s wake done rc=%s\n" "$(date "+%F %T")" "$?" >>"$WAKELOG"
    ' 9>>"$WAKELOCK" &
}

while :; do
  # exec, not a plain $( ... ): a plain capture forks a copy of THIS script
  # (fork keeps argv) that lives as long as the poll — one arm then looks
  # like two wa-armsup.sh processes in every count. The subshell becomes the
  # poller itself; its stdout is what we capture.
  out="$(exec watch-whatsapp.py "$CAP" 2>&1)"
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
