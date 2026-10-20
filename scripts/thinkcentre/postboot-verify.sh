#!/usr/bin/env bash
# Post-reboot end-to-end proof for the WhatsApp duty (2026-10-20).
#
# Installed as /etc/systemd/system/postboot-verify.service (oneshot, after
# multi-user.target) so the check runs ON ITS OWN after every boot that
# matters. Why this exists: his question after the restart was *"check if
# server is app and he responds to whatsapp"* — units showing `active` proves
# processes, not the chain. So this one pushes a message through the whole
# path (bridge store -> watcher arm -> agent reply) and writes the verdict.
#
# The test row is clearly labelled as an admin test, sent as an INCOMING row
# in the self-chat (his instruction channel, always allowed, English-only) —
# the server agent will read it as a test, not as a typed instruction.
set -u

STATE="$HOME/.local/state/opencode"
DB="$HOME/projects/whatsapp-mcp/whatsapp-bridge/store/messages.db"
OUT="$STATE/postboot-verify.md"
SELF="966551052452@s.whatsapp.net"
ts() { date '+%F %H:%M:%S'; }
log() { printf '%s %s\n' "$(ts)" "$*" >>"$OUT"; }

mkdir -p "$STATE"
printf '\n== post-boot verify, boot %s\n' "$(ts)" >>"$OUT"

# give the units their boot time (bridge first, watcher, agent last)
sleep 75

for u in whatsapp-bridge whatsapp-watcher server-agent; do
  if systemctl is-active --quiet "$u"; then log "unit $u: active"
  else log "unit $u: NOT ACTIVE — chain cannot work"; fi
done

ARMS=$(pgrep -fc '[w]a-armsup\.sh' 2>/dev/null || true)
ARMS=$(printf '%s' "$ARMS" | head -n 1)
case "$ARMS" in
  1) log "arms: 1 (one arm one writer holds)" ;;
  *) log "arms: ${ARMS:-unreadable} — WRONG" ;;
esac
log "last arm: $(grep '=== ARM' "$STATE/wa-watch.log" 2>/dev/null | tail -1)"

if tmux has-session -t server-agent 2>/dev/null; then
  log "tmux session server-agent: present"
else
  log "tmux session server-agent: MISSING"
fi

if [ ! -f "$DB" ]; then
  log "messages.db missing — aborting the inject"
  exit 0
fi

# --- end to end: inject one labelled test row and watch for a reply -------
ROWID=$(sqlite3 "$DB" \
  "insert into messages (id, chat_jid, sender, content, timestamp, is_from_me)
   values ('adminpostboot$(date +%s)', '$SELF', '$SELF',
           '[admin test] post-reboot chain check — if the watcher woke you and you are reading this, reply ok in this chat',
           datetime('now'), 0);
   select last_insert_rowid();" 2>/dev/null)
if [ -z "$ROWID" ]; then
  log "inject FAILED (sqlite3 missing or schema mismatch) — no end-to-end"
  exit 0
fi
log "injected test row rowid=$ROWID"

sleep 45

REPLY=$(sqlite3 "$DB" \
  "select content from messages where chat_jid='$SELF' and rowid>$ROWID and is_from_me=1 order by rowid limit 1;" 2>/dev/null)
if [ -n "$REPLY" ]; then
  log "REPLY DETECTED: $REPLY"
  log "VERDICT: chain works — watcher woke the agent and he answered"
else
  log "VERDICT: NO REPLY in 45s — watcher or agent is not working"
fi
