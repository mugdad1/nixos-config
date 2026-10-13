#!/bin/sh
# ---------------------------------------------------------------------------
# backup-run.sh - snapshot selected sources from the OS disk onto the
# backup disk (ADATA SP550, btrfs label "backup", /srv/backup).
#
# NIXOS PORT (2026-10-07): verbatim copy of the donor Void script
# /usr/local/bin/backup-run.sh, minus the two runit-specific bits —
#   scheduling  runit loop /etc/sv/backup-daily -> backup-daily.timer (03:17,
#               After=time-sync.target, the clock guard's surviving piece)
#   logging     /var/log/backup-daily.log       -> the systemd journal
#   /etc/sv,/etc/runit in SOURCES               -> /var/lib/nixos (NixOS
#               service definitions live in the flake, covered by Projects)
# Run as root by backup-daily.service (oneshot), see backup.nix.
#
# EXCLUDED ON PURPOSE:
#   /var/lib/docker   ~32G of RE-PULLABLE docker image layers (overlay2 image
#                      cache + build cache). Image layers are cheap to
#                      re-pull and hold nothing of Mugdad's - only the named
#                      volumes matter, and those live under
#                      ~/Projects/servers/*/data which IS backed up. So the
#                      container storage root is skipped entirely.
#   **/node_modules   re-pullable npm dependency trees.
#   **/__pycache__, **/.cache, **/.npm   regenerable caches.
# KEPT ON PURPOSE:
#   **/.git/objects/pack  packed git objects - small, irrecoverable, kept.
#   ~/Projects/servers/data/immich/postgres  included ON PURPOSE (immich DB).
#
# NOTE: ~/Projects/servers/{data,paperless/data,gitea/data,vaultwarden/data,
#       syncthing/data} all live INSIDE ~/Projects, so the wholesale Projects
#       rsync already covers them - they are deliberately not listed twice.
# ---------------------------------------------------------------------------
set -u

PROG="backup-run"
SLOTS_DAILY=7      # daily-0 .. daily-6
SLOTS_WEEKLY=4     # weekly-0 .. weekly-3
ROOT="/srv/backup"
SNAP="$ROOT/snapshots"

log()  { printf '%s\n' "$*"; }
note() { printf '[%s] %s\n' "$PROG" "$*"; }
die()  { printf '[%s] FATAL: %s\n' "$PROG" "$*" >&2; exit 1; }

# --- preconditions ---------------------------------------------------------
[ "$(id -u)" -eq 0 ] || die "must run as root (invoke as: sudo -n $0)"
findmnt -rn "$ROOT" >/dev/null 2>&1 \
    || die "$ROOT is not mounted - check the /etc/fstab entry / run mount -a"
[ -d "$ROOT" ] || die "$ROOT does not exist"

mkdir -p "$SNAP" || die "cannot create $SNAP"
chmod 700 "$ROOT" || die "chmod 700 $ROOT failed"

# --- sources ---------------------------------------------------------------
# Each entry is one rsync source, mirrored into the snapshot at
# $SLOT/<absolute path with the leading slash stripped>.
SOURCES="
/home/mugdad/Projects
/home/mugdad/.local/state/opencode
/home/mugdad/.local/bin
/home/mugdad/.config/opencode-telegram-bot
/etc/fstab
/etc/docker
/var/lib/nixos
/var/lib/tailscale
"

# Read-back files: proof that real content landed on the backup disk.
#
# The middle one was `wa-send-log.md`, which stopped existing around 2026-10-09
# (the file was renamed to telegram-send-log.md). The snapshots from Oct 9–10
# contain their full content — the rotation and rsync both completed — but the
# unit still exited 1 at this verify step, so the health signal was red while
# the backup was actually fine. Pinned to prompt-history.jsonl instead: it is
# written by every opencode session and has been present in every snapshot
# inspected. Prefer a file that cannot be renamed away over one that matches
# today's log name.
READBACK="
/home/mugdad/Projects/wiki/AGENTS.md
/home/mugdad/.local/state/opencode/prompt-history.jsonl
/home/mugdad/Projects/servers/README.md
"

# NOTE: patterns use **/ so they match at ANY depth. A bare */foo only matches
# one directory level and silently under-excludes (that bug made the verify
# pass report a phantom mismatch).
EXCL_1='--exclude=**/node_modules'
EXCL_2='--exclude=**/__pycache__'
EXCL_3='--exclude=**/.cache'
EXCL_4='--exclude=**/.npm'
EXCL_5='--exclude=/var/lib/docker'

# --- rotation --------------------------------------------------------------
DOW=$(date +%w)          # 0 = Sunday
TODAY=$(date +%Y-%m-%d)

if [ "$DOW" -eq 0 ]; then
    FAMILY="weekly"; COUNT=$SLOTS_WEEKLY; REASON="Sunday -> weekly chain"
else
    FAMILY="daily";  COUNT=$SLOTS_DAILY;  REASON="day $DOW -> daily chain"
fi
TARGET="$SNAP/$FAMILY-0"
note "date=$TODAY day-of-week=$DOW ($REASON) target=$FAMILY-0"

# Shift the chain so slot 0 is free; oldest slot is evicted.
rotate_family() {
    fam="$1"; n="$2"
    last=$((n - 1))
    if [ -d "$SNAP/$fam-$last" ]; then rm -rf "$SNAP/$fam-$last" || return 1; fi
    i=$last
    while [ "$i" -gt 0 ]; do
        p=$((i - 1))
        if [ -d "$SNAP/$fam-$p" ]; then mv "$SNAP/$fam-$p" "$SNAP/$fam-$i" || return 1; fi
        i=$p
    done
    return 0
}
rotate_family "$FAMILY" "$COUNT" || die "rotation of $FAMILY chain failed"
mkdir -p "$TARGET" || die "cannot create $TARGET"
note "rotated $FAMILY chain; writing to $TARGET"

# Newest non-empty snapshot other than TARGET -> --link-dest (hardlinked copies).
PREV=""
for d in "$SNAP"/*; do
    [ -d "$d" ] || continue
    [ "$d" = "$TARGET" ] && continue
    [ -n "$(ls -A "$d" 2>/dev/null)" ] || continue
    if [ -z "$PREV" ] || [ "$d" -nt "$PREV" ]; then PREV="$d"; fi
done
if [ -n "$PREV" ]; then note "link-dest base=$PREV (resolved per source)"; else note "link-dest=none (first run, full copy)"; fi

# --- copy ------------------------------------------------------------------
RSYNC_FLAGS="-aXH --numeric-ids --delete --partial"

# --link-dest is resolved per-transfer against the transfer root, NOT against
# $TARGET, so it must be the mirror of the directory that RECEIVES the
# transfer's content inside $PREV. Getting this wrong silently disables
# hardlinking (every snapshot becomes a full copy).
link_dest_for() {
    _lsrc="$1"
    if [ -d "$_lsrc" ]; then
        echo "$PREV/${_lsrc#/}"                 # dir: contents land in $PREV/<src>
    else
        echo "$PREV/$(dirname "${_lsrc#/}")"    # file: lands in $PREV/<parent>/
    fi
}

copy_source() {
    _src="$1"; _dest="$2"
    _ld=$(link_dest_for "$_src")
    _ldflag=""
    if [ -n "$PREV" ] && [ -d "$_ld" ]; then
        _ldflag="--link-dest=$_ld"
    fi
    if [ -d "$_src" ]; then
        mkdir -p "$_dest" || return 1
        # trailing slash => copy the CONTENTS of _src into _dest.
        # Without it rsync (like cp -r) nests as _dest/<basename>.
        # shellcheck disable=SC2086
        rsync $RSYNC_FLAGS $_ldflag "$EXCL_1" "$EXCL_2" "$EXCL_3" "$EXCL_4" "$EXCL_5" -- "$_src/" "$_dest"
    else
        mkdir -p "$(dirname "$_dest")" || return 1
        # shellcheck disable=SC2086
        rsync $RSYNC_FLAGS $_ldflag "$EXCL_5" -- "$_src" "$_dest"
    fi
}

count_files() { find "$1" -type f 2>/dev/null | wc -l; }

# Files inside excluded directories, so SRC_FILES can be reconciled with
# SNP_FILES (the snapshot is a mirror MINUS these).
count_excluded() {
    _n=0
    while IFS= read -r _e; do
        [ -n "$_e" ] || continue
        _n=$((_n + $(find "$_e" -type f 2>/dev/null | wc -l)))
    done <<EOF
$(find "$1" \( -name node_modules -o -name __pycache__ -o -name .cache -o -name .npm \) -type d 2>/dev/null)
EOF
    echo "$_n"
}

COPIED=0
for src in $SOURCES; do
    if [ ! -e "$src" ]; then
        note "SKIP (missing): $src"
        continue
    fi
    dest="$TARGET/${src#/}"
    if copy_source "$src" "$dest"; then
        note "rsync OK: $src"
        COPIED=$((COPIED + 1))
    else
        die "rsync FAILED for $src (rc=$?)"
    fi
done
[ "$COPIED" -gt 0 ] || die "no sources were copied"

# --- verify: counts / bytes / read-back ------------------------------------
# Sources change while we run (whatsapp store, opencode logs), so if a count
# disagrees we re-rsync that source once and re-count. Still idempotent.
log ""
log "=== VERIFY: files and bytes, source vs snapshot ==="
printf '%-46s %10s %10s %10s %14s %14s\n' \
       "SOURCE" "SRC_FILES" "EXCLUDED" "SNP_FILES" "SRC_BYTES" "SNP_BYTES"

verify_counts() {   # sets: tot_* , bad_paths (list), bad_detail (message)
    tot_sf=0; tot_pf=0; tot_ef=0; tot_sb=0; tot_pb=0
    bad_paths=""; bad_detail=""
    for src in $SOURCES; do
        [ -e "$src" ] || continue
        dest="$TARGET/${src#/}"
        if [ -d "$src" ]; then
            sf=$(count_files "$src"); pf=$(count_files "$dest"); ef=$(count_excluded "$src")
            sb=$(du -sb "$src" 2>/dev/null | cut -f1)
            pb=$(du -sb "$dest" 2>/dev/null | cut -f1)
        else
            sf=1; ef=0
            if [ -e "$dest" ]; then pf=1; else pf=0; fi
            sb=$(stat -c %s "$src" 2>/dev/null || echo 0)
            pb=$(stat -c %s "$dest" 2>/dev/null || echo 0)
        fi
        printf '%-46s %10s %10s %10s %14s %14s\n' "$src" "$sf" "$ef" "$pf" "$sb" "$pb"
        tot_sf=$((tot_sf + sf)); tot_pf=$((tot_pf + pf)); tot_ef=$((tot_ef + ef))
        tot_sb=$((tot_sb + sb)); tot_pb=$((tot_pb + pb))
        if [ "$((sf - ef))" -ne "$pf" ]; then
            bad_paths="$bad_paths $src"
            bad_detail="$bad_detail $src(src=$sf,exc=$ef,snp=$pf)"
        fi
    done
    printf '%-46s %10s %10s %10s %14s %14s\n' \
           "TOTAL" "$tot_sf" "$tot_ef" "$tot_pf" "$tot_sb" "$tot_pb"
    printf 'RECONCILE: SRC_FILES(%s) - EXCLUDED(%s) = %s   SNP_FILES = %s\n' \
           "$tot_sf" "$tot_ef" "$((tot_sf - tot_ef))" "$tot_pf"
}

verify_counts
if [ -n "$bad_paths" ]; then
    log ""
    note "count mismatch:$bad_detail - re-running rsync for those sources"
    for src in $bad_paths; do
        copy_source "$src" "$TARGET/${src#/}" || die "re-rsync FAILED for $src"
    done
    log ""
    log "=== VERIFY (pass 2) ==="
    verify_counts
    [ -z "$bad_paths" ] || die "file count still mismatched after re-rsync:$bad_detail"
    note "counts match after re-rsync"
fi

log ""
log "=== VERIFY: read-back of 3 files from the snapshot ==="
failed=0
for f in $READBACK; do
    dest="$TARGET/${f#/}"
    if [ -f "$dest" ]; then
        printf 'OK   %8s bytes  %s\n' "$(stat -c %s "$dest")" "$f"
    else
        printf 'MISS            %s  (NOT IN SNAPSHOT)\n' "$f"
        failed=1
    fi
done
[ "$failed" -eq 0 ] || die "a required read-back file is missing from the snapshot"

log ""
shared=$(find "$TARGET" -type f -links +1 2>/dev/null | wc -l)
note "hardlinked against previous snapshot: $shared / $tot_pf files (0 = full copy)"
note "DONE slot=$TARGET sources=$COPIED files=$tot_pf bytes=$tot_pb"
exit 0
