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

# Core units only. The WhatsApp units (whatsapp-bridge / whatsapp-watcher)
# went with the "no more whatsapp" removal on 2026-10-23. tailscaled and
# blocky stay: both have bitten, and an active unit proving nothing was
# learned the hard way (2026-10-16 -- backend stopped, unit green).
for u in tailscaled blocky; do
  if systemctl is-active --quiet "$u" 2>/dev/null; then ok "unit $u active"
  else bad "unit $u not active"; fi
done

# Timers — only ones this host actually INSTALLED. backup-daily.timer left with
# the 240GB on 2026-10-16 (row 106); demanding it here made checkup FAIL by
# design on a healthy box.
TIMERS=""
systemctl list-unit-files backup-daily.timer --no-legend 2>/dev/null | grep -q '^backup' && TIMERS="backup-daily.timer"
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

# 3) rule 4: this box must not serve the LAN. blocky deliberately binds
#    0.0.0.0:53 (decisions row 177 — the tailnet needs it, and the box itself
#    needs it on loopback), so the boundary is the FIREWALL, not the bind.
#    Port 53 may be accepted only on tailscale0.
#
#    Do NOT probe the LAN address from here to test this: a packet to our own
#    LAN IP is answered by local delivery and never enters the INPUT chain,
#    so it always succeeds and cannot reveal LAN exposure. This used to query
#    a hard-coded ThinkCentre address (192.168.8.225), which after the
#    2026-10-22 migration timed out and read "check the interface" — a false
#    alarm on a healthy box. Read the rule that actually enforces it instead.
SUDO_FW=""
for s_cand in /run/wrappers/bin/sudo "$(command -v sudo 2>/dev/null)"; do
  if [ -n "$s_cand" ] && [ -x "$s_cand" ]; then SUDO_FW="$s_cand"; break; fi
done
[ -n "$SUDO_FW" ] || SUDO_FW="sudo"
FW53=$("$SUDO_FW" -n iptables -S nixos-fw 2>/dev/null \
       | grep -E -- '--dport 53( |$)' | grep -v -- '-i tailscale0 ' || true)
if [ -n "$FW53" ]; then
  bad "rule 4: port 53 accepted off tailscale0 — the LAN can reach our DNS:"
  printf '%s\n' "$FW53" | sed 's/^/        /'
else
  ok "rule 4: :53 accepted on tailscale0 only (0.0.0.0 bind, firewalled off the LAN)"
fi

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

echo
if [ "$FAIL" = 1 ]; then echo "RESULT: FAIL (see lines above)"; else echo "RESULT: all clean"; fi
exit "$FAIL"
