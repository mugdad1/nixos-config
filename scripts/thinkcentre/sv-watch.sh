#!/bin/sh
# sv-watch.sh - the only thing on this box that notices a dead systemd unit or
# a dead container.
#
# WHY IT EXISTS (2026-10-08): the telegram duty channel was down for ~2 h (its
# launcher was deleted at 09:17) and nothing noticed. Uptime Kuma cannot see it
# - it has 0 monitors and only ever watches HTTP ports - and at the time runit
# was throwing the failures at a discarded pipe. `systemctl` every 60 s plus
# ONE push on a state CHANGE is the cheapest thing that can catch this.
#
# **ALERT DELIVERY IS LIVE AGAIN SINCE 2026-10-18**, and it goes to Telegram -
# never back to ntfy (the container he had me remove on 2026-10-12; it had zero
# subscribers for its whole life). push() below shells out to the shared
# `notify-telegram` script (pkgs/notify-telegram.nix) instead of the printf it
# was between 2026-10-12 and today, which means the queue/flush machinery below
# it is reachable again: a delivery that actually fails is retried every sweep
# from /var/lib/sv-watch/outbox.
#
# SCOPE (2026-10-09): systemd units, docker containers, and the published HTTP
# endpoints. Containers were added because a stopped container was invisible
# here - a stopped or crashed container would have been just as silent as the
# bot was. (The container that motivated this, immich_machine_learning, was
# removed from the stack entirely on 2026-10-09.) The HTTP sweep was added
# because the one thing Uptime Kuma could theoretically do that this could not
# - notice a port that answers but an app behind it that does not - and it does
# it without a 200 MB container, a login, or 0 monitors.
#
# Deliberate choices:
#   * a systemd unit left disabled/stopped means the operator meant it, so it
#     is skipped rather than paged;
#   * a container with restart policy `no` means the same thing -> same skip;
#   * the state file holds only the current down-list, so a reboot (state lives
#     in /run) reports a still-down thing once and stays quiet afterwards;
#   * one script per run, driven by sv-watch.timer, so `sv-watch.sh` alone is
#     a testable single shot.
set -u

# SVDIR is gone: units live in systemd, swept via list-unit-files below.
STATE="${STATE:-/run/sv-watch.state}"
PENDING="${PENDING:-/run/sv-watch.http-pending}"
ENDPOINTS="${ENDPOINTS:-/etc/sv-watch/http-endpoints}"
# The ntfy URL that used to live here is GONE, not merely commented: delivery
# moved to Telegram through `notify-telegram` (see push() below), and leaving a
# dead URL in place is how the previous alerting outage stayed invisible.
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
    # REAL DELIVERY, 2026-10-18 onward: one shared script (pkgs/notify-telegram
    # .nix) posts to the Telegram Bot API with the sops-rendered token, so this
    # sweep, smartd and backup-daily's OnFailure= hook all deliver the same way,
    # through one place to fix when Telegram's API or the token changes.
    #
    # The exit status is LOAD-BEARING. alert() retries three times, then queues
    # the message to $OUTBOX, and flush() re-sends that queue at the top of
    # every sweep - so a send that actually failed must return non-zero, or the
    # outbox degenerates into a write-only file. A host with no sops key does
    # NOT fail: it logs NOTIFY(no-token) and exits 0 (see the script), which is
    # what keeps the outbox from growing forever where delivering is impossible.
    #
    # Priority maps to the phone deliberately: high = buzz (a real DOWN),
    # default/low = silent. Recovery lines arrive on their own schedule, and
    # they were half the reason a 3am page was unwelcome in the first place.
    #
    # `notify-telegram` comes from the unit's runtimeInputs (hosts/thinkcentre/
    # services.nix); when this is run by hand on a box that lacks it, say so in
    # the journal rather than dying and skipping the state-change bookkeeping.
    if ! command -v notify-telegram >/dev/null 2>&1; then
        printf '%s NOTIFY(missing): [%s] %s -- %s\n' "$(now)" "$1" "$2" "$3"
        return 0
    fi
    _rc=0
    if [ "$1" = "high" ]; then
        notify-telegram --title "$2" "$3" || _rc=$?
    else
        notify-telegram --silent --title "$2" "$3" || _rc=$?
    fi
    return "$_rc"
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
#
# TWO MORE SKIPS, added 2026-10-13 once the sweep could actually see units
# (it reported "checked 0 units" for weeks because gawk was missing from
# runtimeInputs). runit had no oneshot concept, so this is not part of the
# mapping above — it is where the mapping stops:
#
#   * Type=oneshot units are RUN TO COMPLETION and then go inactive. They are
#     enabled and healthy while reporting `is-active` = inactive, so flagging
#     them produced 22 false "down" units on the first real sweep —
#     sshd-keygen, systemd-machine-id-commit, tailscaled-set (which logs
#     status=0/SUCCESS), and so on. That is worse than the silence it
#     replaced: a list that is 22/22 noise makes a real down unit invisible.
#   * Template units (getty@tty1.service) are instantiations of a template
#     that is enabled but whose instances are started on demand.
for unit in $(systemctl list-unit-files --type=service --state=enabled \
              --no-legend --no-pager 2>/dev/null | awk '{print $1}'); do
    case "$unit" in
        *@*.service) continue ;;    # template, not an instance
    esac
    if [ "$(systemctl show -p Type --value "$unit" 2>/dev/null)" = "oneshot" ]; then
        continue
    fi
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
# The `|| :` is load-bearing. writeShellApplication prepends `set -o errexit`
# and `set -o pipefail` on top of this script's own `set -u`, and when the
# resolver is actually down `dig` exits non-zero (no reply -> 9). With pipefail
# that fails the whole pipeline, and a failing command substitution trips
# errexit — so the script died here, the state file was never written, and no
# down or recovery was reported. It aborted in precisely the one situation the
# sweep exists to catch, and marked the unit failed while doing it. The `*)`
# branch below turns the empty result into the "resolver is dead" signal, which
# is what this line is for.
dnsst=$(dig +time=3 +tries=1 @"${DNSRESOLVER:-127.0.0.1}" "$dnsname" A 2>/dev/null \
        | sed -n 's/.*status: \([A-Z0-9]*\),.*/\1/p' | head -1 || :)
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
