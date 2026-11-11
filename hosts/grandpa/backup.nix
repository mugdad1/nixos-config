# The second drive (sdb): 100G /srv/backup + 376G /srv/data, and the daily
# hardlinked-snapshot unit that mirrors everything irreplaceable onto it.
#
# It is a backup target, not fast storage: the board only has USB 2.0, so the
# drive runs at 33-40 MB/s. The irreplaceable set is ~1.1 GB, which is fine.
# nofail is load-bearing — this drive gets unplugged and must never block boot.
{pkgs, ...}: let
  dest = "/srv/backup";
  keepRuns = 3;

  # Only what cannot be rebuilt from git or the cloud.
  sources = [
    "/var/lib/hass"
    "/var/lib/forgejo"
    "/var/lib/wiki"
    "/var/lib/gitea-mirror"
    "/var/lib/docker"
    "/var/lib/sops-nix" # contains the age key — losing it loses every secret
    "/var/lib/tailscale"
    "/etc/ssh"
    "/etc/machine-id"
    "/home/mugdad/.ssh"
    "/home/mugdad/.gnupg"
    "/home/mugdad/.config/gh"
    "/home/mugdad/.gitconfig"
    "/home/mugdad/.local/share"
    "/home/mugdad/projects"
  ];

  # Built as Nix, not exported: the script indexes this as a shell array, and
  # an exported string would expand to a single word.
  sourcesArray = builtins.concatStringsSep " " (map (s: "\"${s}\"") sources);

  backup = pkgs.writeShellScript "grandpa-backup" ''
    set -euo pipefail

    DEST=${dest}
    KEEP=${toString keepRuns}
    SOURCES=(${sourcesArray})

    if ! mountpoint -q "$DEST"; then
      echo "$(date '+%F %T') ABORT: $DEST is not mounted — is sdb attached?" >&2
      exit 1
    fi
    if ! touch "$DEST/.writetest" 2>/dev/null; then
      echo "$(date '+%F %T') ABORT: $DEST not writable (read-only or full?)" >&2
      exit 1
    fi
    rm -f "$DEST/.writetest"

    # A source that has since vanished must not abort the run.
    EXISTING=()
    for s in "''${SOURCES[@]}"; do
      if [ -e "$s" ]; then
        EXISTING+=("$s")
      else
        echo "  skip (gone): $s"
      fi
    done
    if [ "''${#EXISTING[@]}" -eq 0 ]; then
      echo "$(date '+%F %T') ABORT: no sources exist" >&2
      exit 1
    fi

    PREV=$(readlink "$DEST/latest" 2>/dev/null || true)
    NEW="$DEST/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$NEW"

    LINK=()
    if [ -n "$PREV" ] && [ -d "$DEST/$PREV" ]; then
      LINK=(--link-dest="$DEST/$PREV")
    fi

    START=$(date +%s)
    FAILED=0
    for s in "''${EXISTING[@]}"; do
      # -R keeps full paths in the snapshot; one rsync per source keeps
      # --delete scoped to exactly one subtree.
      RC=0
      rsync -aR --delete "''${LINK[@]}" -- "$s" "$NEW/" || RC=$?
      if [ "$RC" -ne 0 ]; then
        echo "  FAILED ($RC): $s" >&2
        FAILED=1
      fi
    done
    ELAPSED=$(( $(date +%s) - START ))

    # Never rotate `latest` onto a partial snapshot.
    if [ "$FAILED" -ne 0 ]; then
      echo "$(date '+%F %T') INCOMPLETE — not rotating 'latest', keeping partial as $NEW" >&2
      exit 1
    fi

    ln -sfn "$(basename "$NEW")" "$DEST/latest"

    # Prune oldest-first by mtime, not by name.
    mapfile -t ALL < <(ls -1dt "$DEST"/[0-9]* 2>/dev/null)
    if [ "''${#ALL[@]}" -gt "$KEEP" ]; then
      for d in "''${ALL[@]:$KEEP}"; do
        echo "  pruning: $(basename "$d")"
        rm -rf -- "$d"
      done
    fi

    USED=$(du -sh "$NEW" | cut -f1)
    echo "$(date '+%F %T') ok: $USED in ''${ELAPSED}s -> $(basename "$NEW")"
    df -h "$DEST" | tail -1 | awk '{print "  disk: "$4" free of "$2}'
  '';

  status = pkgs.writeShellScript "grandpa-backup-status" ''
    set -euo pipefail
    DEST=${dest}
    if ! mountpoint -q "$DEST"; then
      echo "sdb: NOT MOUNTED — backups are not running. Plug it in, then:"
      echo "    sudo systemctl start grandpa-backup"
      exit 1
    fi
    echo "target : $DEST"
    df -h "$DEST" | tail -1 | awk '{print "  "$4" free of "$2}'
    echo "latest : $(readlink "$DEST/latest" 2>/dev/null || echo '(none yet)')"
    echo "runs   : $(ls -1d "$DEST"/[0-9]* 2>/dev/null | wc -l) of ${toString keepRuns} kept"
    echo
    if [ -d "$DEST/latest" ]; then
      echo "what is protected:"
      du -sh "$DEST/latest"/* 2>/dev/null | sort -rh | head -14 | sed 's/^/  /'
      echo
    fi
    echo "last runs:"
    journalctl -u grandpa-backup -n 6 --no-pager 2>/dev/null | sed 's/^/  /' || echo "  (none)"
  '';
in {
  # nofail: unplugging this drive must never block boot.
  fileSystems."/srv/backup" = {
    device = "/dev/disk/by-label/backup";
    fsType = "ext4";
    options = ["nofail" "noatime" "x-systemd.device-timeout=10s"];
  };

  fileSystems."/srv/data" = {
    device = "/dev/disk/by-label/data";
    fsType = "ext4";
    options = ["nofail" "noatime" "x-systemd.device-timeout=10s"];
  };

  systemd.services.grandpa-backup = {
    description = "Mirror irreplaceable state to the sdb backup partition";
    # Not wantedBy: the timer decides when this runs.
    path = with pkgs; [rsync coreutils findutils util-linux gawk gnugrep];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${backup}";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  systemd.timers.grandpa-backup = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "20m";
    };
  };

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "backup-now" ''
      if [ "$(id -u)" -eq 0 ]; then
        exec systemctl start grandpa-backup.service
      fi
      exec sudo systemctl start grandpa-backup.service
    '')
    (pkgs.writeShellScriptBin "backup-status" ''
      exec ${status}
    '')
  ];
}
