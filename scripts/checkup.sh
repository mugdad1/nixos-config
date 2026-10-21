#!/usr/bin/env bash
# checkup.sh — one-shot health sweep of the ThinkCentre, printed as findings.
#
#     checkup          # everything, tldr-style: only problems are loud
#     checkup -v       # also print the OK lines
#
# Built 2026-10-16 on his word ("check on him between times" + the tailscale
# stop that nobody noticed + the sdb SMART reading). Every section here has
# already bitten once:
#   * tailscaled active but the node STOPPED — a green systemctl meant nothing,
#     so the check is the interface + backend state, not the unit.
#   * /dev/sdb holds the ONLY local snapshots — its SMART trend is watched
#     (attr 5 was 45 on 2026-10-16; a moving number is the alarm, not 45).
#   * one watcher arm only — two arms starve each other on the shared cursor.
#   * repos shared between two hosts — ahead/behind both matter.
#
# Exit: 0 = all clean, 1 = at least one FAIL line (so it can gate a timer).
set -u

VERBOSE=0
[ "${1:-}" = "-v" ] && VERBOSE=1

FAIL=0
ok()  { [ "$VERBOSE" = 1 ] && printf '  ok    %s\n' "$*"; return 0; }
bad() { printf '  FAIL  %s\n' "$*"; FAIL=1; }
note() { printf '  ...   %s\n' "$*"; }

# ── units ───────────────────────────────────────────────────────────────────
FAILED_UNITS=$(systemctl list-units --failed --no-legend --plain 2>/dev/null | awk '{print $1}' | tr '\n' ' ')
if [ -n "$FAILED_UNITS" ]; then bad "failed units: $FAILED_UNITS"; else ok "no failed units"; fi

# The watcher is here because it became a unit on 2026-10-20 (services.nix):
# before that a hand-run supervisor's death was invisible to this loop and
# only the arm count below could catch it.
for u in whatsapp-bridge whatsapp-watcher tailscaled blocky; do
  if systemctl is-active --quiet "$u" 2>/dev/null; then ok "unit $u active"
  else bad "unit $u not active"; fi
done

# The bridge unit being active is NOT the bridge being connected. On
# 2026-10-21 11:59:57 WhatsApp sent "401 device_removed", whatsmeow deleted
# the session, and the bridge sat there RUNNING with no WhatsApp behind it
# for eleven minutes -- so this sweep would have said "all clean" while the
# whole duty was dead: no sends (they came back "Not connected to WhatsApp")
# and no inbound. Same class as the tailscaled line above: a green systemctl
# means nothing, the INTERFACE state is the truth.
#
# The health route is behind the same bearer auth as everything else, so the
# probe MUST carry the token -- an unauthenticated probe gets 401 and
# `curl -f` turns that into a failure, which is the same trap that made the
# 3:13am 313 fire report a false "bridge did not answer" and skip the ritual.
BRIDGE_TOKEN_FILE="${WA_BRIDGE_DIR:-$HOME/projects/whatsapp-mcp/whatsapp-bridge}/store/.bridge-token"
if [ -r "$BRIDGE_TOKEN_FILE" ]; then
  BRIDGE_TOKEN="$(cat "$BRIDGE_TOKEN_FILE" 2>/dev/null)"
  BRIDGE_HEALTH="$(curl -fsS --max-time 5 -H "Authorization: Bearer $BRIDGE_TOKEN" \
      http://127.0.0.1:8080/api/health 2>/dev/null)"
  case "$BRIDGE_HEALTH" in
    *'"connected":true'*) ok "bridge connected (whatsapp session live)" ;;
    *) bad "bridge NOT connected -- the unit may be active with no whatsapp session behind it (health: ${BRIDGE_HEALTH:-no answer})" ;;
  esac
else
  bad "bridge token not readable at $BRIDGE_TOKEN_FILE -- cannot tell whether whatsapp is connected"
fi
# Timers — only ones this host actually INSTALLED. backup-daily.timer left with
# the 240GB on 2026-10-16 (row 106); demanding it here made checkup FAIL by
# design on a healthy box.
TIMERS=""
systemctl list-unit-files backup-daily.timer --no-legend 2>/dev/null | grep -q '^backup' && TIMERS="backup-daily.timer"
TIMERS="$TIMERS sv-watch.timer"
for t in $TIMERS; do
  if systemctl is-active --quiet "$t" 2>/dev/null; then ok "timer $t active"
  else bad "timer $t not active"; fi
done

# ── containers (docker may legitimately be absent — grandpa-style posture) ──
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  DOWN=$(docker ps -a --filter 'status=exited' --filter 'status=created' \
         --filter 'status=dead' --filter 'status=restarting' \
         --format '{{.Names}}' 2>/dev/null | tr '\n' ' ')
  if [ -n "$DOWN" ]; then bad "containers not running: $DOWN"; else ok "all containers running"; fi
fi

# ── disks ───────────────────────────────────────────────────────────────────
while read -r USE MNT; do
  if [ "${USE%\%}" -ge 90 ]; then bad "disk $MNT at $USE"
  else ok "disk $MNT at $USE"; fi
done < <(df -h --output=pcent,target -x tmpfs -x devtmpfs -x overlay -x efivarfs 2>/dev/null \
         | tail -n +2 | awk '{gsub(/^ +/,"",$1); print $1, $2}')

# SMART of the BACKUP disk — found by what it IS (the fs mounted on
# /srv/backup), NEVER by a hard-coded sdX: after the 2026-10-16 reboot the
# names swapped (ADATA went sdb→sda, the system disk took sdb), and the old
# "/dev/sdb" check silently started watching the SYSTEM drive — visible only
# as attr5 mysteriously "dropping" 45→0, which no SMART counter ever does.
# sudo -n: this box's sudo is passwordless. But WHICH sudo matters: after the
# 2026-10-20 13:01 rebuild the bare `sudo` on PATH resolved to
# /run/current-system/sw/bin/sudo, a plain store symlink WITHOUT the setuid
# bit, and every privileged call died with "must be owned by uid 0 and have
# the setuid bit set". The setuid binary is /run/wrappers/bin/sudo (the wiki
# gotcha from row 132, hit again). The check then read the disk's SMART
# verdict as "unreadable" on a perfectly healthy ADATA -- a FAIL on a healthy
# box, the same class of lie as the efivarfs one (row 143). So: prefer the
# wrapper, fall back to bare sudo.
SUDO=""
for s_cand in /run/wrappers/bin/sudo "$(command -v sudo 2>/dev/null)"; do
  if [ -n "$s_cand" ] && [ -x "$s_cand" ]; then SUDO="$s_cand"; break; fi
done
[ -n "$SUDO" ] || SUDO="sudo"
BKPART=$(findmnt -no SOURCE /srv/backup 2>/dev/null | head -1)
if [ -n "$BKPART" ] && [ -b "$BKPART" ]; then
  PK=$(lsblk -no pkname "$BKPART" 2>/dev/null | head -1)
  if [ -n "$PK" ]; then BKDISK="/dev/$PK"; else BKDISK="$BKPART"; fi
  IDENT=$(lsblk -ndo MODEL,SERIAL "$BKDISK" 2>/dev/null | xargs)
  H=$("$SUDO" -n smartctl -H "$BKDISK" 2>/dev/null | awk -F: '/result/{print $2}')
  if echo "$H" | grep -qi PASSED; then ok "backup disk $BKDISK ($IDENT): SMART PASSED"
  else bad "backup disk $BKDISK ($IDENT): SMART verdict:${H:- unreadable}"; fi
  # attr 5 / 1 / 160 raw — trend is the story. Baseline 2026-10-16 (ADATA
  # SP550, serial 2G3020002085): 5=45, 1=0, 160=0
  read -r A1 A5 A160 <<<"$("$SUDO" -n smartctl -A "$BKDISK" 2>/dev/null \
    | awk '/^ *1 /{r1=$NF} /^ *5 /{r5=$NF} /^ *160 /{r160=$NF} END{print r1+0, r5+0, r160+0}')"
  if [ "${A1:-0}" -gt 0 ] || [ "${A160:-0}" -gt 0 ]; then
    bad "backup disk read errors creeping: attr1=$A1 attr160=$A160 (baseline 0/0)"
  else ok "backup disk read errors 0"; fi
  if [ "${A5:-0}" -gt 45 ]; then
    note "backup disk attr5 moved: $A5 (baseline 45 on 2026-10-16) — watch it, replace on fast growth"
  else ok "backup disk attr5=$A5 (baseline 45, ADATA)"; fi
elif grep -q '/srv/backup' /etc/fstab 2>/dev/null; then
  # Configured but not mounted = a REAL failure (the failure mode this check
  # was born for). Only reach here if fstab still wants the disk.
  bad "nothing mounted at /srv/backup — the backup disk is GONE (check lsblk for name swaps)"
else
  # fstab does not configure it at all: the disk moved to grandpa (2026-10-16).
  # An empty leftover mount-point directory must not scream.
  note "/srv/backup not configured on this host — backup-disk checks skipped"
fi

# ── DNS: three separate truths, each probed directly (2026-10-16: the old
#    check tested ONLY 127.0.0.1 and called it "DNS ok" while the house side
#    was invisible — he called it a lie, correctly) ──────────────────────────
# 1) this box's own resolver (blocky, 127.0.0.1)
L=$(dig +short +time=3 +tries=1 github.com @127.0.0.1 2>/dev/null | head -1)
if [ -n "$L" ]; then ok "blocky (127.0.0.1, this box's resolver) -> $L"
else bad "blocky NOT answering on 127.0.0.1"; fi

# 2) the HOUSE's DNS = the router (servers.md rule 4: this box never serves
#    the LAN; a house device that cannot resolve starts HERE)
R=$(dig +short +time=3 +tries=1 github.com @192.168.8.1 2>/dev/null | head -1)
if [ -n "$R" ]; then ok "router 192.168.8.1 (the house's DNS) -> $R"
else bad "ROUTER 192.168.8.1 NOT ANSWERING — the house has no DNS"; fi

# 3) this box on the LAN side — refused is CORRECT (rule 4), an answer would
#    be the surprise. Raw dig text decides; no shell one-liner guesswork.
Q=$(dig +time=3 +tries=1 github.com @192.168.8.225 2>&1)
case "$Q" in
  *"connection refused"*) ok "192.168.8.225:53 refused — correct: this box does not serve the LAN" ;;
  *"no servers could be reached"*) note "192.168.8.225:53 no reply (timeout) — not refused, check the interface" ;;
  *) note "192.168.8.225:53 ANSWERS — something binds the LAN; rule 4 says nothing should" ;;
esac

# ── tailscale: the UNIT being active proves nothing (2026-10-16: active but
#    BackendState=Stopped, no tailscale0) ─────────────────────────────────────
if [ -d /sys/class/net/tailscale0 ]; then
  TS=$(tailscale status 2>&1 | head -1)
  case "$TS" in
    "Tailscale is stopped"*|*"Logged out"*) bad "tailscale0 exists but: $TS" ;;
    *) ok "tailscale: $TS" ;;
  esac
else
  bad "tailscale0 missing — node is DOWN (sudo tailscale up --accept-dns=false)"
fi

# ── whatsapp duty ───────────────────────────────────────────────────────────
STATE="${WA_STATE:-$HOME/.local/state/opencode}"
if [ -e "$STATE/wa-stop" ]; then
  note "wa-stop PRESENT — sends and watcher are (deliberately) down"
else
  ok "guard lifted (wa-stop absent)"
fi
# ARMS ARE COUNTED AS watch-whatsapp.py PROCESSES — the poller that actually
# holds the rowid cursor, never the supervisor's name. Two lies stood here
# before, both real, both on 2026-10-20:
#  1) '[w]a-armsup\.sh' matched the WORDS "wa-armsup.sh 1800" inside an
#     agent's message text → "3 — TWO ARMS STARVE EACH OTHER" on a one-arm
#     box.
#  2) the path-anchored fix still lied: the hit-capture `out=$(...)` and the
#     background wake both FORK the script, and a fork keeps argv — so main +
#     capture wrapper + wake subshell = three processes named wa-armsup.sh
#     while exactly ONE cursor holder existed. Name-counting cannot tell
#     copies of one arm from a second arm; only the poller can.
# pgrep -c prints its count AND exits 1 when the count is 0 — the `|| true`
# then head keeps one clean number either way (2026-10-16: a "0\n0" made the
# script report TWO ARMS with a count of zero).
# Count ARMS, not ARGV MENTIONS. pgrep -f matches the whole command line, so
# any process that merely NAMES the poller counts as one -- and on 2026-10-20
# 13:08 an agent shell running a command that mentioned the path made this
# read "2 — TWO ARMS STARVE EACH OTHER" while exactly one poller existed
# (pid 7731, under whatsapp-watcher.service). That is the same class of lie
# as the 3-arms artifact before it: the pattern has to match the poller as
# an ARGUMENT, not as text anywhere on the line.
#
# An arm is a process whose argv holds the poller path as an ARGUMENT (argv[1]
# for `python3 /path/watch-whatsapp.py 1800`, argv[0] if it is exec'd
# directly). Anything else is a shell that happened to talk about it.
ARMS=0
for pid in $(pgrep -f 'watch-whatsapp' 2>/dev/null); do
  [ -r "/proc/$pid/cmdline" ] || continue
  a0=""; a1=""
  { IFS= read -r -d '' a0 || true; IFS= read -r -d '' a1 || true; } \
    < "/proc/$pid/cmdline" 2>/dev/null
  case "$a0" in */watch-whatsapp.py) ARMS=$((ARMS + 1)); continue ;; esac
  case "$a1" in */watch-whatsapp.py) ARMS=$((ARMS + 1)) ;; esac
done
ARMS=$(printf '%s' "$ARMS" | head -n 1)
case "$ARMS" in
  ""|*[!0-9]*) bad "watcher arms: unreadable count (pgrep broken?)" ;;
  0) bad "watcher NOT armed — since 2026-10-20 that is \`systemctl restart whatsapp-watcher\`, never a second wa-armsup.sh" ;;
  1) ok "watcher arms: 1" ;;
  *) bad "watcher arms: $ARMS — TWO ARMS STARVE EACH OTHER, kill one" ;;
esac
if [ "$ARMS" -ge 1 ] && [ -f "$STATE/wa-watch.log" ]; then
  ok "last arm: $(grep '=== ARM' "$STATE/wa-watch.log" | tail -1 | sed 's/^=== //')"
fi

# ── repos (two hosts share them: pull before push, always) ──────────────────
for R in "$HOME/projects/wiki" "$HOME/nixos-config"; do
  [ -d "$R/.git" ] || continue
  S=$(git -C "$R" status -sb 2>/dev/null | head -1)
  case "$S" in
    *"ahead "*) bad "$(basename "$R"): local commits not pushed — $S" ;;
    *"behind "*) bad "$(basename "$R"): behind remote — git pull first — $S" ;;
    *) ok "$(basename "$R"): $S" ;;
  esac
  D=$(git -C "$R" status --porcelain 2>/dev/null | head -1)
  [ -n "$D" ] && note "$(basename "$R"): uncommitted changes present"
done

# ── WhatsApp duty: session count, no unit to supervise ──────────────────────
# The duty used to sit in server-agent.service (a tmux screen holding
# `opencode mini --agent server`); he removed the unit 2026-10-20 — *"stop the
# server agent rm iit"*, *"cuz i will just use normal session"* — so the duty
# is the wake (wa-armsup -> `opencode run -s $WA_SESSION`) plus whatever normal
# session he opens himself. Nothing here FAILs on that: a missing screen is
# his order, not a fault. The count is only a note — 0 is the expected number
# until someone opens a session.
if command -v opencode >/dev/null 2>&1; then
  SERVER_SESS=$(timeout 10 opencode api get /api/session 2>/dev/null \
    | grep -o '"agent":"server"' | wc -l | tr -d ' ')
  note "server agent sessions open: ${SERVER_SESS:-0} (no unit since 2026-10-20 — wake + his own sessions)"
fi

echo
if [ "$FAIL" = 1 ]; then echo "RESULT: FAIL (see lines above)"; else echo "RESULT: all clean"; fi
exit "$FAIL"
