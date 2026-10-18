#!/bin/sh
# notify-telegram.sh - THE delivery path for alerts on all three hosts.
#
# WHY IT EXISTS (2026-10-18): three things detect failures on this fleet -
# sv-watch (thinkcentre: units, containers, endpoints, DNS), smartd (disks, all
# three hosts) and systemd's own OnFailure= hooks (backup-daily) - and since
# 2026-10-12 not one of them delivered anything. The ntfy container left the
# stack on his "just rm notify", and sv-watch's push() became an unconditional
# printf. A box could lose a disk or a container and the only trace was
# journald - which is exactly the failure mode sv-watch was written to end.
# Telegram is the channel he already carries (the bot in hosts/thinkcentre/
# services.nix), so this posts to the Bot API directly instead of resurrecting
# a self-hosted relay nobody subscribed to.
#
# THE TOKEN IS NOT IN THIS FILE. The repo is public, so the token is ciphertext
# in secrets/fleet.sops.yaml and is rendered at activation into:
#     /run/secrets/rendered/notify-telegram.env    (root:root 0400)
# which is what this reads by default. Override with TELEGRAM_ENV_FILE, or by
# exporting TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID (what a test does).
#
# A HOST WITHOUT THE KEY IS NOT A FAILURE. Since 2026-10-18 all three hosts
# have the key (restored by hand, see the README), but a fresh install - or a
# host whose key was never placed - has no rendered file: the alert still lands
# in the journal with a NOTIFY(no-token) marker, and the exit status is 0. That matters because
# sv-watch's alert() QUEUES on a non-zero push and retries the queue every
# sweep - a host that can never deliver would fill /var/lib/sv-watch/outbox
# forever. Exit 1 is reserved for the honest case: a delivery was attempted and
# Telegram did not accept it, which is worth retrying.
#
# Usage:
#   notify-telegram "message"                  # text as arguments
#   echo body | notify-telegram                # text on stdin (smartd's hook)
#   notify-telegram --title "disk failing" "message"
#   notify-telegram --silent --title T body    # no phone sound (recoveries)
#   notify-telegram -i anything ...            # sendmail-compatible: -i ignored
#
# Exit: 0 delivered, or logged because no token is configured. 1 send failed.
set -u

ENV_FILE="${TELEGRAM_ENV_FILE:-/run/secrets/rendered/notify-telegram.env}"

title=""
silent="false"
while [ $# -gt 0 ]; do
    case "$1" in
        --title) title="${2:-}"; shift 2 ;;
        --silent) silent="true"; shift ;;
        # smartd calls a mailer as `<mailer> -i <recipient>` and pipes the mail
        # on stdin (see nixos/modules/services/monitoring/smartd.nix). The
        # recipient slot is meaningless here - the chat id is the secret - so it
        # is swallowed rather than treated as message text.
        -i|--identity) shift 2 ;;
        --) shift; break ;;
        -*) shift ;;   # unknown flag: ignore rather than die in a failure path
        *) break ;;
    esac
done

if [ $# -gt 0 ]; then
    msg="$*"
else
    msg=$(cat)
fi
[ -n "$msg" ] || { printf 'notify-telegram: empty message, nothing sent\n'; exit 0; }

# Recover smartd's subject line so a disk alert arrives with a real title
# instead of a wall of From:/To:/Subject: headers. The headers stay in the body
# on purpose: they name the host and the device, which is the useful part.
if [ -z "$title" ]; then
    title=$(printf '%s\n' "$msg" | sed -n 's/^Subject: //p' | head -n 1)
fi

# shellcheck source=/dev/null
[ -n "${TELEGRAM_BOT_TOKEN:-}" ] || { [ -r "$ENV_FILE" ] && . "$ENV_FILE"; }
TOKEN="${TELEGRAM_BOT_TOKEN:-}"
# TELEGRAM_ALLOWED_USER_ID is the same value under the name the bot's own
# template uses, so one template can serve both.
CHAT="${TELEGRAM_CHAT_ID:-${TELEGRAM_ALLOWED_USER_ID:-}}"

host=$(hostname 2>/dev/null || printf 'host')
if [ -n "$title" ]; then
    text="$host: $title
$msg"
else
    text="$host: $msg"
fi
# Telegram rejects a message over 4096 UTF-16 units. The one body whose size is
# not under our control is smartd's `smartctl -a` dump, so cut with room to
# spare rather than lose the alert to a length error.
text=$(printf '%s' "$text" | head -c 3500)

if [ -z "$TOKEN" ] || [ -z "$CHAT" ]; then
    printf 'NOTIFY(no-token): %s\n' "$text"
    printf 'notify-telegram: no token in %s or environment - logged only\n' "$ENV_FILE"
    exit 0
fi

if curl -4 -fsS -m 15 -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${CHAT}" \
        --data-urlencode "text=${text}" \
        --data-urlencode "disable_notification=${silent}" >/dev/null; then
    printf 'NOTIFY(sent): %s\n' "$text"
    exit 0
fi

printf 'NOTIFY(failed): %s\n' "$text"
exit 1
