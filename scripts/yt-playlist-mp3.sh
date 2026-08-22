#!/usr/bin/env bash
set -euo pipefail

# Create a file called playlists.txt with one playlist URL per line, or pass URLs as arguments.

OUTPUT_DIR="${YT_MUSIC_DIR:-$HOME/Music/YouTube}"

if [[ $# -gt 0 ]]; then
    urls=("$@")
elif [[ -f playlists.txt ]]; then
    mapfile -t urls < playlists.txt
else
    echo "Usage: $0 <url1> [url2] ..."
    echo "Or create playlists.txt with one URL per line and run: $0"
    exit 1
fi

for url in "${urls[@]}"; do
    echo "=== Downloading: $url ==="
    yt-dlp \
        --extract-audio \
        --audio-format mp3 \
        --audio-quality 0 \
        --embed-thumbnail \
        --add-metadata \
        --output "$OUTPUT_DIR/%(playlist_title)s/%(title)s.%(ext)s" \
        --yes-playlist \
        "$url"
done

echo "Done! Files saved to $OUTPUT_DIR"
