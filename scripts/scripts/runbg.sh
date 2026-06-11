#!/usr/bin/env bash
set -e

[ $# -eq 0 ] && {
    echo "$(basename "$0"): missing command" >&2
    exit 1
}
prog="$(which "$1")"
[ -z "$prog" ] && {
    echo "$(basename "$0"): unknown command: $1" >&2
    exit 1
}
shift
tty -s && exec < /dev/null
tty -s <&1 && exec > /dev/null
tty -s <&2 && exec 2>&1
"$prog" "$@" &
