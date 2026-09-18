#!/usr/bin/env bash
set -euo pipefail

dir="$HOME/Videos/Recordings"
pidfile="${XDG_RUNTIME_DIR}/wf-recorder.pid"

notify() {
    notify-send -a record "Recording stopped → $1"
}

if [[ -f "$pidfile" ]]; then
    pid=$(cat "$pidfile")
    if kill -0 "$pid" 2>/dev/null; then
        kill -s SIGINT "$pid"
        for _ in $(seq 1 50); do
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.1
        done
    fi
    rm -f "$pidfile"
    notify "$dir"
    exit 0
fi

[[ -d "$dir" ]] || mkdir -p "$dir"
out="${dir}/Recording_$(date +'%Y_%m_%d_at_%Hh%Mm%Ss').mp4"

args=(-f "$out")
if sink=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -oP 'id \K[0-9]+' | head -1); then
    args=(--audio="$sink" "${args[@]}")
fi

# detach so wf-recorder outlives the launcher; remember its real PID
wf-recorder "${args[@]}" >/dev/null 2>&1 &
echo $! > "$pidfile"
notify-send -a record "Recording started → $out"