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

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Ship the served tree (no VCS history).
tar -czf "$TMP/site.tgz" --exclude='.git' --exclude='.gitignore' --transform 's|^\./||' -C "$SRC" .
# Manifest = every shipped path (dirs + files).
tar -tzf "$TMP/site.tgz" | sed '/\/$/d' | sed 's|^|/|' | sort > "$TMP/manifest.txt"

# Step 1a: push the manifest (what SHOULD exist on the server).
timeout 60 tailscale ssh "$REMOTE" 'cat > /tmp/site-manifest.txt' < "$TMP/manifest.txt"

# Step 1b: extract the tarball (add/overwrite files).
timeout 120 tailscale ssh "$REMOTE" 'tar -xzf - -C /srv/site' < "$TMP/site.tgz" \
  || { echo "site sync FAILED (tar)" >&2; exit 1; }

# Step 2: prune server files not in the manifest, so deleted local files
# disappear from the site too (tar only ever adds/overwrites).
timeout 60 tailscale ssh "$REMOTE" 'sh -c "
cd /srv/site
find . -type f -printf \"%P\n\" | sort > /tmp/site-found.txt
comm -23 /tmp/site-found.txt <(sed \"s|^/||\" /tmp/site-manifest.txt | sort) > /tmp/site-extra.txt
if [ -s /tmp/site-extra.txt ]; then
  while IFS= read -r f; do rm -f \"/srv/site/\$f\"; done < /tmp/site-extra.txt
  echo \"pruned: \$(wc -l < /tmp/site-extra.txt) files\"
fi
find /srv/site -type d -empty -delete 2>/dev/null || true
"' 2>&1

echo "site synced to asus:$DEST"
command -v notify-send >/dev/null 2>&1 \
  && notify-send -a study "Site synced to asus" "http://asus:8081" \
  || true