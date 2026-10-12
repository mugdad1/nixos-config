#!/bin/sh
# sv-watch.sh - the only thing on this box that notices a dead runit unit or a
# dead container.
#
# WHY IT EXISTS (2026-10-08): the telegram duty channel was down for ~2 h (its
# launcher was deleted at 09:17) and nothing noticed. Uptime Kuma cannot see it
# - it has 0 monitors and only ever watches HTTP ports - and runit was throwing
# the failures at a discarded pipe. `sv status` every 60 s plus ONE push on a
# state CHANGE is the cheapest thing that can catch this. Alerts go to ntfy
# (stack entry 11, 127.0.0.1:8085 -> container :80), topic thinkcentre-alerts.
#
# SCOPE (2026-10-09): runit units, docker containers, and the published HTTP
# endpoints. Containers were added because a stopped container was invisible
# here - a stopped or crashed container would have been just as silent as the
# bot was. (The container that motivated this, immich_machine_learning, was
# removed from the stack entirely on 2026-10-09 - 19 containers now.) The HTTP sweep was added because the
# one thing Uptime Kuma could theoretically do that this could not - notice a
# port that answers but an app behind it that does not - and it does it without
# a 200 MB container, a login, or 0 monitors.
#
# Deliberate choices:
#   * a runit `down` file means the operator meant it, so that unit is skipped;
#   * a container with restart policy `no` means the same thing -> same skip
#     (generic: nothing exercises it right now, the ML container is gone);
#   * the state file holds only the current down-list, so a reboot (state lives
#     in /run) reports a still-down thing once and stays quiet afterwards;
#   * one script per run, looped by the runit service, so `sv-watch.sh` alone is
#     a testable single shot.
set -u

# SVDIR is gone: units live in systemd, swept via list-unit-files below.
STATE="${STATE:-/run/sv-watch.state}"
PENDING="${PENDING:-/run/sv-watch.http-pending}"
ENDPOINTS="${ENDPOINTS:-/etc/sv-watch/http-endpoints}"
NTFY="${NTFY:-http://127.0.0.1:8085/thinkcentre-alerts}"
# Persistent outbox: an alert that cannot be delivered is WRITTEN HERE instead
# of being lost. Deliberately not under /run - it has to survive the very
# reboot whose alert it is holding (2026-10-09 08:52:39, docker DOWN, ntfy a
# container that was 2 s old and not accepting connections yet).
OUTBOX="${OUTBOX:-/var/lib/sv-watch/outbox}"

now() { date '+%F %T'; }

# tokens: runit = bare unit name, container = docker:<name>, endpoint = url:<url>
sub()  { case "$1" in docker:*) printf '%s' docker ;; url:*) printf '%s' HTTP ;; dns:*) printf '%s' DNS ;; *) printf '%s' runit ;; esac; }
bare() { case "$1" in docker:*) printf '%s' "${1#docker:}" ;; url:*) printf '%s' "${1#url:}" ;; dns:*) printf '%s' "${1#dns:}" ;; *) printf '%s' "$1" ;; esac; }

push() {    # $1=priority $2=title $3=body
    # Delivery DISABLED 2026-10-12 on his "just rm notify": the ntfy container is
    # gone (subscribers=0 for its whole life, so it never reached a phone), and he
    # does not want a page at 3am. Returns 0 on purpose: the sweep still DETECTS
    # and still LOGS the state change below, it just no longer tries to deliver
    # anything and nothing can queue to the outbox forever.
    printf '%s NOTIFY(off): [%s] %s -- %s\n' "$(now)" "$1" "$2" "$3"
}

queue() {   # keep what could not be delivered: one TAB-separated line per message
    mkdir -p "$(dirname "$OUTBOX")" 2>/dev/null || true
    printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$OUTBOX" 2>/dev/null || true
}

flush() {   # deliver what an earlier sweep could not; runs before every check
    _work="$OUTBOX.work"
    if [ -f "$_work" ]; then         # a crash mid-flush must not lose those lines
        cat "$_work" >> "$OUTBOX" 2>/dev/null || true
        rm -f "$_work"
    fi
    [ -s "$OUTBOX" ] || return 0
    mv -f "$OUTBOX" "$_work" 2>/dev/null || return 0
    _ok=0
    while IFS="$(printf '\t')" read -r _p _t _b; do
        [ -n "$_t" ] || continue
        if push "$_p" "$_t" "$_b"; then
            _ok=$((_ok + 1))
        else
            printf '%s\t%s\t%s\n' "$_p" "$_t" "$_b" >> "$OUTBOX"
        fi
    done < "$_work"
    rm -f "$_work"
    [ "$_ok" -gt 0 ] && printf '%s OUTBOX delivered %s queued message(s)\n' "$(now)" "$_ok"
    return 0
}

alert() {   # $1 = priority (high|default|low)  $2 = title  $3 = body
    _try=1
    while [ "$_try" -le 3 ]; do
        if push "$1" "$2" "$3"; then
            printf '%s ALERT ok: %s\n' "$(now)" "$2"
            return 0
        fi
        printf '%s ALERT push %s/3 failed: %s\n' "$(now)" "$_try" "$2"
        _try=$((_try + 1))
        [ "$_try" -le 3 ] && sleep 5
    done
    queue "$1" "$2" "$3"
    printf '%s ALERT queued to outbox (retried every sweep): %s\n' "$(now)" "$2"
    return 1
}

detail() {  # one line of real state for the alert body
    case "$1" in
        docker:*) docker ps -a --filter "name=${1#docker:}" --format '{{.Names}} {{.Status}}' 2>/dev/null | head -1 ;;
        url:*)    _c=$(curl -4 -s -m 5 -o /dev/null -w '%{http_code}' "${1#url:}" 2>/dev/null) || _c=000
                  [ "$_c" = "000" ] && printf '%s' "no answer at all (curl 000)" || printf 'answering with HTTP %s' "$_c" ;;
        dns:*)    _s=$(dig +time=3 +tries=1 @"${DNSRESOLVER:-127.0.0.1}" "$(date +%s%N).$$.example.com" A 2>/dev/null \
                       | sed -n 's/.*status: \([A-Z0-9]*\),.*/\1/p' | head -1)
                  [ -n "$_s" ] && printf 'a fresh lookup came back %s' "$_s" || printf 'no answer at all (dig timed out)' ;;
        *)        systemctl status "$1" --no-pager -n 3 2>&1 | head -6 ;;
    esac
}

down="" skipped="" units=0 containers=0 endpoints=0

flush   # anything undeliverable from a previous sweep goes out first

# --- systemd units -----------------------------------------------------------
# runit's `sv status` + a `down` FILE map onto systemctl, and the mapping is
# actually cleaner: /var/service held symlinks to ENABLED units only, so the
# only thing a `down` file could express was "stopped on purpose". systemd
# says that natively with `is-enabled` — disabled/masked/static units are not
# meant to run on their own, so they are skipped by exactly the same rule.
# `list-unit-files --state=enabled` is therefore the direct successor of the
# `for d in "$SVDIR"/*` loop, not an approximation of it.
for unit in $(systemctl list-unit-files --type=service --state=enabled \
              --no-legend --no-pager 2>/dev/null | awk '{print $1}'); do
    name=${unit%.service}
    units=$((units + 1))
    st=$(systemctl is-active "$unit" 2>/dev/null) || st="unknown"
    case "$st" in
        active) : ;;
        *)      down="$down $name" ;;
    esac
done

# --- containers -------------------------------------------------------------
# Policy `no` = deliberately stopped, so it is skipped like a `down` file.
# Everything else that is not running gets paged, including the daemon itself
# being unreachable - if docker cannot answer, none of this is being watched.
if command -v docker >/dev/null 2>&1; then
    if ids=$(docker ps -aq 2>/dev/null); then
        if [ -n "$ids" ]; then
            # shellcheck disable=SC2086  # $ids is newline-separated ON PURPOSE:
            # quoting it would hand docker inspect every ID as ONE argument.
            if insp=$(docker inspect -f '{{.Name}} {{.State.Running}} {{.HostConfig.RestartPolicy.Name}}' $ids 2>/dev/null); then
                while read -r name running policy; do
                    [ -n "$name" ] || continue
                    name=${name#/}
                    containers=$((containers + 1))
                    [ "$running" = "true" ] && continue
                    if [ "$policy" = "no" ]; then
                        skipped="$skipped $name(container, restart=no)"
                    else
                        down="$down docker:$name"
                    fi
                done <<EOF
$insp
EOF
            else
                down="$down docker:inspect-failed"
            fi
        fi
    else
        down="$down docker:daemon-unreachable"
    fi
else
    down="$down docker:missing"
fi

# --- published HTTP endpoints ------------------------------------------------
# Two strikes before a page: a cold boot has containers still starting for a
# sweep or two, and paging on that would make every other alert untrustworthy.
# Strike one only lands in $PENDING; strike two moves the token into the main
# down-list, where the "only on a change" rule below stops it repeating every
# minute. Recovery needs no special case - the token simply stops being added,
# and the main loop sees it leave the down-list.
prev_pending=""
[ -f "$PENDING" ] && prev_pending=$(cat "$PENDING")
new_pending=""

if [ -f "$ENDPOINTS" ]; then
    while IFS= read -r line; do
        url=$(printf '%s' "$line" | sed 's/#.*//;s/[[:space:]]*$//')
        [ -n "$url" ] || continue
        endpoints=$((endpoints + 1))
        code=$(curl -4 -s -m 5 -o /dev/null -w '%{http_code}' "$url" 2>/dev/null) || code=000
        if [ "$code" = "000" ]; then
            new_pending="$new_pending $url"
            case " $prev_pending " in
                *" $url "*) down="$down url:$url" ;;   # second strike -> page via main loop
                *) : ;;                               # first strike -> hold, no page
            esac
        fi
    done < "$ENDPOINTS"
fi

# --- DNS resolution ----------------------------------------------------------
# The :3002 endpoint only proves AdGuard's WEB UI answers; it says nothing about
# whether a lookup resolves. If both upstreams die the UI stays green while the
# house has no internet - so every sweep asks for a FRESH random name under
# example.com (nobody can serve it from cache) and counts NOERROR/NXDOMAIN as
# working, since both mean an upstream replied. SERVFAIL, REFUSED or silence =
# down. Same two strikes as the endpoints, same pending file.
# DNSRESOLVER exists so this can be tested against a dead port, and exists
# only for that.
dnsname="$(date +%s%N).$$.example.com"
dnsst=$(dig +time=3 +tries=1 @"${DNSRESOLVER:-127.0.0.1}" "$dnsname" A 2>/dev/null \
        | sed -n 's/.*status: \([A-Z0-9]*\),.*/\1/p' | head -1)
case "$dnsst" in
    NOERROR|NXDOMAIN) : ;;                      # upstream answered -> resolution works
    *)  new_pending="$new_pending dns:resolver"
        case " $prev_pending " in
            *" dns:resolver "*) down="$down dns:resolver" ;;   # second strike -> page
            *) : ;;                                           # first strike -> hold
        esac ;;
esac
# shellcheck disable=SC2086  # $new_pending is space-separated; split it so the
# pending file gets one token per line, matching how prev_pending is re-read.
printf '%s\n' $new_pending > "$PENDING" 2>/dev/null || true

# normalise: one sorted line of space-separated tokens
# shellcheck disable=SC2086  # $down MUST word-split for sort -u to dedupe.
# Quoting it makes printf emit a single line, so sort -u becomes a no-op and
# duplicate tokens survive into the state file. Same idiom as the original
# Void script (byte-identical line, 2026-10-12).
down=$(printf '%s\n' $down | sort -u | tr '\n' ' ' | sed 's/ *$//')
[ -n "$skipped" ] && printf '%s intentionally down (not reported):%s\n' "$(now)" "$skipped"

prev=""
[ -f "$STATE" ] && prev=$(cat "$STATE")

# new down -> page high
for n in $down; do
    case " $prev " in
        *" $n "*) : ;;                                    # already reported
        *) alert high "$(sub "$n") DOWN: $(bare "$n")" "$(hostname) - $(bare "$n") is not running as of $(now). $(detail "$n")" ;;
    esac
done
# recovered -> page default
for n in $prev; do
    case " $down " in
        *" $n "*) : ;;
        *) alert default "$(sub "$n") back: $(bare "$n")" "$(hostname) - $(bare "$n") is running again as of $(now)." ;;
    esac
done

printf '%s\n' "$down" > "$STATE" || printf '%s cannot write state %s\n' "$(now)" "$STATE"
printf '%s checked %s units + %s containers + %s endpoints + dns(%s), down=[%s]\n' "$(now)" "$units" "$containers" "$endpoints" "${dnsst:-NONE}" "$down"
