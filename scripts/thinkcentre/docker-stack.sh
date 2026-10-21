#!/bin/sh
# shellcheck disable=SC2016
#   SC2016 ("expressions don't expand in single quotes") is disabled for this
#   whole file ON PURPOSE. The DISABLED list below is single-quoted precisely
#   so that nothing in it expands — its contents are literal project directory
#   names, and one of them legitimately contains a comment with prose in it.
#   Switching it to double quotes would be the bug. This directive was needed
#   as of 2026-10-20 because the derivation had only ever been served from
#   cache: the moment the file was edited it rebuilt, shellcheck ran as the
#   writeShellApplication gate for the first time in a long while, and the
#   build failed on this pre-existing line.
# docker-stack.sh - bring the compose stack up, declaratively.
#
# WHY THIS EXISTS (2026-10-13): the ThinkCentre moved from Void + runit to
# NixOS. `nixos-rebuild switch` brings the box back after a reinstall — sshd,
# blocky, tailscaled, the backups, OpenCode — but it did nothing for the 18
# containers, because they are compose files under ~/Projects/servers and not
# NixOS services. For a few hours after the migration the honest status was
# "the stack is restored as files, running nothing, and nothing survives a
# reboot". That is exactly the gap Mugdad's rule closes: *"i dont want thing
# that goes after i re install nix ok? this is the main idea of nixos the same
# system comes back."*
#
# WHY NOT nixify the containers themselves: decided 2026-10-13, explicitly, to
# keep them as compose — they are upstream images with their own update cadence
# and env files, and rewriting 13 projects as NixOS services would be a large,
# breakable migration that buys little. The durable half is the LAUNCHER: one
# unit that sweeps the stack directory at boot. The compose files stay the
# source of truth for *what* runs; this decides *when*.
#
# WHAT IT IS NOT: an orchestrator. It has no health logic (sv-watch does that),
# it does not stop anything, and it will not start a directory that has no
# compose file. It runs `docker compose up -d`, which is idempotent — already
# running projects are left alone and cost one API call.
#
# run as: docker-stack.service (a oneshot at boot), or by hand for a re-stack.
set -u

# CASE 2026-10-15: ~/Projects -> ~/projects (lowercase), matching the
# reinstall's restored layout and the guard in services.nix. The default below
# only ever applies when STACK_DIR is unset; the unit does not set it, so this
# is what actually decides where the launcher looks.
STACK_DIR="${STACK_DIR:-/home/${USER:-mugdad}/projects/servers}"

# Deliberately not started at boot.
#
# COMMENT OUT, DON'T DELETE — house rule. Add a directory name on its own line
# to park it; uncomment nothing here to start everything. A commented line is
# documentation that the project still exists and was switched off on purpose,
# which is the whole point: `# uptime-kuma` reads as a decision, an absent line
# reads as an oversight.
#
# The directive below must sit here and NOT at the top of the file:
# writeShellApplication prepends its own preamble (set -euo pipefail, PATH)
# before this text, so a file-level directive at the top of this file lands
# after those commands and stops applying file-wide. Scoping it to the
# assignment is what actually works.
# shellcheck disable=SC2016
DISABLED='
# uptime-kuma
# glances — retired from compose 2026-10-19: the native NixOS service
# (hosts/thinkcentre/glances.nix) owns :61208 now. This entry stops the stack
# from re-creating the container on every boot — a recreated-but-not-started
# container still sits in docker ps -aq, which sv-watch sweeps, so the page
# came back after every reboot.
glances
# ─── dropped 2026-10-20 on his word ──────────────────────────────────────────
# "stirling and paperless i never used them u may remove them / im not sure
# how will they be usefull / even syncting" and "mv metube to grandpa".
#
# READ THIS BEFORE REMOVING ANOTHER SERVICE BY HAND. The first attempt at
# these four was `docker compose down` in each directory, and it WORKED — the
# containers were gone and verified gone. Then the next `nixos-rebuild switch`
# restarted THIS unit (WantedBy=multi-user.target, so it runs at every boot
# and every switch), which walked ~/projects/servers and brought all four
# straight back. They sat there healthy for over an hour while the front page
# said they were removed — the index was lying again, for the second time
# tonight. `docker compose down` alone is NOT a removal on this box; this
# list is what makes it stick.
#
# metube moved thinkcentre -> grandpa; it is live there (100.106.116.60:8081,
# its own docker-stack brings it up). Listed here so it is not also run here.
stirling-pdf
paperless
syncthing
metube
# ─── ntfy: parked here 2026-10-21 ────────────────────────────────────────────
# His 2026-10-12 `just rm notify` (wiki row 75) removed the CONTAINER but not
# ~/projects/servers/ntfy/docker-compose.yml — correct under comment-out,
# never delete. So the next boot of this unit re-created the container at
# 2026-10-15T13:10:15Z and it ran unnoticed for six days until he spotted it in
# `docker ps` on 2026-10-21 and said "i dont host such stuff".
#
# This is the same hole row 170 describes — it simply opened BEFORE that
# comment was written, so the 2026-10-20 fix for stirling/paperless/syncthing/
# metube never covered it. A removal is only real when the name is on this
# list. Compose file and data/ stay on disk; this line is the removal.
ntfy
'

# ─── host-scoped holds ────────────────────────────────────────────────────────
#
# WHY THIS EXISTS (2026-10-21): DISABLED above is shared verbatim by BOTH
# machines — hosts/thinkcentre/services.nix:171 and hosts/grandpa/default.nix:51
# readFile this same file. That is fine while every hold means "removed
# everywhere" (ntfy, paperless). It breaks the moment a service MOVES: jellyfin
# went thinkcentre -> grandpa on his "mv jellyfin", and one shared list cannot
# say "off here, on there" — the launcher has no way to tell the boxes apart.
#
# The first design mistake this file already recorded (2026-10-20) was thinking
# `docker compose down` was a removal; the second would have been parking
# jellyfin in DISABLED, which would have disabled it on the box it was MOVED TO.
# Same rule as above — comment out, don't delete — but keyed by hostname, and
# the format is literally `<hostname>:<project-dir>`.
#
# The directive must sit here for the same reason it sits above DISABLED.
# shellcheck disable=SC2016
DISABLED_HOST='
thinkcentre:jellyfin
'

have_compose() {
    [ -f "$1/docker-compose.yml" ] || [ -f "$1/compose.yml" ] ||
    [ -f "$1/docker-compose.yaml" ] || [ -f "$1/compose.yaml" ]
}

if ! docker info >/dev/null 2>&1; then
    echo "$(date '+%F %T') docker-stack: docker daemon not answering, nothing started"
    exit 1
fi

started=0 held=0 failed=0

for d in "$STACK_DIR"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")

    if printf '%s\n' "$DISABLED" | grep -qx "$name"; then
        echo "$(date '+%F %T') docker-stack: $name is disabled, skipped"
        held=$((held + 1))
        continue
    fi

    # Host-scoped holds: same "disabled, skipped" outcome, but only on the box
    # named on the line. Matched against `uname -n`, which is coreutils — the
    # flake's host key on both machines (thinkcentre / grandpa).
    #
    # NOT `hostname`: that is inetutils and is NOT in writeShellApplication's
    # PATH, so the first version of this line died with "hostname: command not
    # found" on grandpa's 2026-10-21 rebuild and the hold silently did nothing.
    # `date` below is coreutils, which is why uname is safe here.
    if printf '%s\n' "$DISABLED_HOST" | grep -qx "$(uname -n):$name"; then
        echo "$(date '+%F %T') docker-stack: $name is disabled on $(uname -n), skipped"
        held=$((held + 1))
        continue
    fi

    # `data/` holds the bind-mounted volumes shared by several projects and is
    # not a compose project itself — reported as no-compose, not as a failure.
    if ! have_compose "$d"; then
        continue
    fi

    if (cd "$d" && docker compose up -d) >/tmp/docker-stack.$$ 2>&1; then
        started=$((started + 1))
    else
        echo "$(date '+%F %T') docker-stack: FAILED $name"
        sed 's/^/    /' /tmp/docker-stack.$$
        failed=$((failed + 1))
    fi
done

rm -f /tmp/docker-stack.$$

# Non-zero only on a real failure, so the unit lands in `systemctl --failed`
# and sv-watch sees it. Held/disabled projects are a choice, not a fault, and
# must never mark the unit failed — otherwise a parked project produces a
# permanently red unit that everybody learns to ignore.
echo "$(date '+%F %T') docker-stack: $started up, $held disabled, $failed failed; $(docker ps -q | wc -l) containers now running"

[ "$failed" -eq 0 ]
