#!/usr/bin/env bash
# Sync the PRIVATE site source to the asus server (tailnet-only).
# Deploys $HOME/projects/study -> asus:/srv/site over tailscale ssh.
# Triggered automatically by a post-push hook in the site repo; works fine
# when run manually too. Requires the server to have been rebuilt once
# (`sudo nixos-rebuild switch --flake .#asus`) so /srv/site exists.
# Nothing here leaves the tailnet.
set -euo pipefail

SRC="${SITE_SRC:-$HOME/projects/study}"
REMOTE="mugdad@asus"
DEST="/srv/site"

if [[ ! -d "$SRC" ]]; then
  echo "site source not found: $SRC" >&2
  exit 1
fi

# Server not rebuilt yet? Skip silently (the post-push hook fires before any
# first rebuild). This also guards against a dead tailnet link.
if ! timeout 15 tailscale ssh "$REMOTE" "test -d $DEST" 2>/dev/null; then
  echo "site: server not ready ($DEST missing) — run 'sudo nixos-rebuild switch --flake .#asus' first"
  exit 0
fi

cd "$SRC"
# Ship the served tree, no VCS history needed on the server.
if tar -czf - --exclude='.git' --exclude='.gitignore' . \
  | timeout 120 tailscale ssh "$REMOTE" "tar -xzf - -C $DEST"; then
  echo "site synced to asus:$DEST"
  command -v notify-send >/dev/null 2>&1 \
    && notify-send -a study "Site synced to asus" "http://asus:8081" \
    || true
else
  echo "site sync FAILED" >&2
  command -v notify-send >/dev/null 2>&1 \
    && notify-send -a study -u critical "Site sync FAILED" "check tailscale" \
    || true
  exit 1
fi
echo "tailnet-only URL: http://asus:8081"