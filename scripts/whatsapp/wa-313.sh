#!/usr/bin/env bash
# Send the bare number 313 to the two ritual groups. That is the WHOLE job.
#
# His words, 2026-10-20: *"we have in both groups we send 313 at that
# specific time it means something to us so 3:13am and pm send 313 only to
# both groups nothing else is requried"* → *"u can add them to the allow list
# but u must!!!! not respond to anything anything this is a strong rule u
# must follow uu just type 313 and thats it never repsond or find other way"*.
#
# So this script sends exactly one thing -- the bare number 313 -- to exactly
# two groups, and nothing else ever goes there. No greeting, no reply, no
# reaction, no "[AI] " prefix: the ritual is the bare number, and the group
# members post the bare number too (rowid 202/196 in رحلة, 197/195 in فريق).
# His own manual send was a bare 313 as well (rowid 203).
#
# The "never respond" half is NOT left to care. wa-send refuses any message
# to these two JIDs whose text is not exactly "313", and refuses a "313"
# that does not carry the one-time ticket this script sets. So a reply to
# these groups is mechanically impossible, not merely forbidden -- the same
# shape as the MUTE rule for hassan and mohannad.
#
# wa-send is the only send path (log-first, records the text, refuses the
# stop flag). This script never talks to the bridge directly.
#
# The bridge may still be starting when the timer fires, so wait for it
# rather than firing a doomed send: a failed ritual post is worse than a
# post that arrives ten seconds late.
set -u

STATE="${WA_STATE:-$HOME/.local/state/opencode}"
LOG="$STATE/wa-313.log"

# The two groups, by JID. Names in comments: فريق غير جو and رحلة الأخوان
# في الله 2. The ritual is a group habit of theirs, not a duty of ours.
GROUP1="120363143658966777@g.us"
GROUP2="120363428386151315@g.us"

BRIDGE_URL="${WA_BRIDGE_URL:-http://127.0.0.1:8080}"
BRIDGE_DIR="${WA_BRIDGE_DIR:-$HOME/projects/whatsapp-mcp/whatsapp-bridge}"
TOKEN_FILE="$BRIDGE_DIR/store/.bridge-token"

mkdir -p "$STATE"

log() {
  printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG"
}

# Wait for the bridge to answer, up to ~90 s. A restart can land the timer
# right on top of a bridge that is not listening yet.
#
# THE TOKEN IS NOT OPTIONAL. /api/health is behind the same auth as every
# other route, so a plain probe gets 401 and `curl -f` turns that into a
# failure -- which is exactly what happened on 2026-10-21 03:13: the bridge
# was up and healthy the whole time, the probe never succeeded, and after
# 90 s the ritual was skipped with a "bridge did not answer" that was
# completely false. With the token the same probe returns 200.
wait_for_bridge() {
  local token
  if [ ! -f "$TOKEN_FILE" ]; then
    return 1
  fi
  token="$(cat "$TOKEN_FILE" 2>/dev/null)"
  if [ -z "$token" ]; then
    return 1
  fi
  local i=0
  while [ "$i" -lt 90 ]; do
    if curl -fsS --max-time 3 -H "Authorization: Bearer $token" \
         "$BRIDGE_URL/api/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    i=$((i + 1))
  done
  return 1
}

# The one-time ticket: wa-send's allow-list guard refuses a JID that is not
# on the send list, and the ticket permits exactly these two, for exactly
# this invocation. Nothing else in the tree can reach these groups.
TICKET="$GROUP1,$GROUP2"
WHY="the 313 ritual: the bare number at 3:13am and 3:13pm, his groups habit, nothing else"

if [ -e "$STATE/wa-stop" ]; then
  log "STOP flag present -- refusing to send 313"
  exit 1
fi

if ! wait_for_bridge; then
  log "bridge did not answer within 90s -- NOT sending 313"
  exit 1
fi

rc=0
for jid in "$GROUP1" "$GROUP2"; do
  if out="$(WA_ALLOW_ONCE="$TICKET" wa-send "$jid" "313" "$WHY" 2>&1)"; then
    log "sent 313 to $jid"
  else
    log "FAILED 313 to $jid: $out"
    rc=1
  fi
done

exit "$rc"
