#!/usr/bin/env bash
# Find and remove stale Home Manager backup files that block rebuilds

set -euo pipefail

BACKUP_EXT="hm-backup"
FOUND=0

echo "Scanning for stale $BACKUP_EXT files in home..."

while IFS= read -r -d '' file; do
  echo "  Found: $file"
  FOUND=$((FOUND + 1))
done < <(find "$HOME" -maxdepth 5 -name "*.$BACKUP_EXT" -print0 2>/dev/null)

if [ "$FOUND" -eq 0 ]; then
  echo "No stale backup files found."
  exit 0
fi

echo ""
echo "Found $FOUND stale backup file(s)."
read -rp "Remove them all? [y/N] " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
  find "$HOME" -maxdepth 5 -name "*.$BACKUP_EXT" -delete 2>/dev/null
  echo "Removed $FOUND file(s)."
else
  echo "Aborted."
fi
