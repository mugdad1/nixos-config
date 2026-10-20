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

# systemd's PATH is store paths for coreutils/grep/bash only — tmux, sqlite3,
# pgrep and sqlite3 live in /run/current-system/sw/bin, and all three checks
# below reported false negatives on the first run (12:03:47: "arms: unreadable",
# "tmux session: MISSING", "inject FAILED") for exactly that reason.
export PATH=/run/wrappers/bin:/run/current-system/sw/bin:$PATH

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

for u in whatsapp-bridge whatsapp-watcher; do
  if systemctl is-active --quiet "$u"; then log "unit $u: active"
  else log "unit $u: NOT ACTIVE — chain cannot work"; fi
done

# anchored on the poller itself (see the long note in scripts/checkup.sh):
# counting wa-armsup.sh names counts FORKS — the hit-capture and the wake both
# fork the script and keep its argv, so one arm showed up as 2-3 processes.
ARMS=$(pgrep -fc '(^|[[:space:]])(bash )?/run/current-system/sw/bin/watch-whatsapp\.py' 2>/dev/null || true)
ARMS=$(printf '%s' "$ARMS" | head -n 1)
case "$ARMS" in
  1) log "arms: 1 (one arm one writer holds)" ;;
  *) log "arms: ${ARMS:-unreadable} — WRONG" ;;
esac
log "last arm: $(grep '=== ARM' "$STATE/wa-watch.log" 2>/dev/null | tail -1)"

# server-agent is NOT in the chain any more, and that is deliberate: he
# removed the unit 2026-10-20 with "stop the server agent rm iit" / "cuz i
# will just use normal session". The wake never needed the tmux screen —
# `opencode run -s $WA_SESSION` reaches the same session without it — so the
# proof now ends at the reply, not at a tmux window.

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

# 90s, not 45: the agent is a model round trip behind the watcher, and a cold
# first call after boot took longer than the original 45s budget in testing.
sleep 90

# did the ARM itself see the row (independent of the agent answering)?
if grep -q "$ROWID" "$STATE/wa-watch.log" 2>/dev/null; then
  log "watcher: test row picked up"
else
  log "watcher: test row NOT seen in wa-watch.log — arm is not reading"
fi

REPLY=$(sqlite3 "$DB" \
  "select content from messages where chat_jid='$SELF' and rowid>$ROWID and is_from_me=1 order by rowid limit 1;" 2>/dev/null)
if [ -n "$REPLY" ]; then
  log "REPLY DETECTED: $REPLY"
  log "VERDICT: chain works — watcher woke the agent and he answered"
else
  log "VERDICT: NO REPLY in 90s — watcher or agent is not working"
fi
