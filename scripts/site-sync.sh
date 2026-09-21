#!/usr/bin/env bash
# Sync the PRIVATE site source to the asus server (tailnet-only).
# Deploys $HOME/projects/<site> -> asus:/srv/site over tailscale ssh.
# Run AFTER the server has `sudo nixos-rebuild switch --flake .#asus`, and
# re-run whenever site content changes. Nothing here leaves the tailnet.
set -euo pipefail

SRC="${SITE_SRC:-$HOME/projects/study}"
REMOTE="mugdad@asus"
DEST="/srv/site"

if [[ ! -d "$SRC" ]]; then
  echo "site source not found: $SRC" >&2
  exit 1
fi

cd "$SRC"
# Ship the served tree, no VCS history needed on the server.
tar -czf - --exclude='.git' --exclude='.gitignore' . \
  | tailscale ssh "$REMOTE" "tar -xzf - -C $DEST"
echo "site synced to asus:$DEST"
echo "tailnet-only URL: http://asus:8081"