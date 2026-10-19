#!/bin/sh
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
DISABLED='
# uptime-kuma
# glances — retired from compose 2026-10-19: the native NixOS service
# (hosts/thinkcentre/glances.nix) owns :61208 now. This entry stops the stack
# from re-creating the container on every boot — a recreated-but-not-started
# container still sits in `docker ps -aq`, which sv-watch sweeps, so the page
# "docker DOWN: glances" came back after every reboot.
glances
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
