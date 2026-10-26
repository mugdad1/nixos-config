# ─── the second drive: sdb ───────────────────────────────────────────────────
#
# Added 2026-10-26, his word: "this is your second drive you can do whatever u
# want a backup extra storage etc". SK hynix SC311 512G, plugged in over USB.
#
# WHY BACKUP AND NOT STORAGE. Measured on this box: the drive does 33-40 MB/s
# because the board only has USB 2.0 ports — the enclosure identifies as
# "USB3.0 Super Speed" but the link negotiates 2.0 regardless of cable. The
# internal SATA disk does 108 MB/s. So this drive is SLOWER than the disk it
# would serve, which rules it out as scratch or as a place to make anything run
# faster. It does not rule out backups: sequential writes at 33 MB/s are plenty
# when the whole irreplaceable set is ~1.07 GB, i.e. about 33 seconds.
#
# TWO PARTITIONS, NOT ONE. /srv/backup is capped at 100G and /srv/data gets the
# other 376G. A single partition would let a runaway copy into /srv/data fill
# the disk and silently break every future backup — the backup space is walled
# off so that cannot happen. Root is only 19G used, so 100G is room to grow.
#
# nofail IS THE IMPORTANT OPTION. This is a USB drive; it will be unplugged.
# Without nofail a missing sdb would hold up boot waiting for it. With it,
# grandpa boots normally and the backup timer fails loudly in the journal.
# device-timeout=10s keeps that failure fast instead of the default 90s.
# Mounts are by LABEL, not UUID, so reformatting needs no edit here — only the
# label matters.
#
# WHAT IS IN THE LIST, AND WHY: everything that cannot be rebuilt. NixOS itself,
# the flake and the store are all reconstructible from github.com/mugdad1/
# nixos-config, so they are NOT backed up — that would be 19G of noise. What has
# no second copy anywhere else:
#
#   /var/lib/hass          the account, the room, the AC, the paired ESP32.
#                          home-assistant.nix says it outright: state does not
#                          travel with the flake, and a fresh HA means
#                          re-onboarding by hand with the AC controls dead.
#   /var/lib/forgejo       873M, the largest single thing here.
#   /var/lib/wiki          the wiki as served
#   /var/lib/gitea-mirror  mirror state
#   /var/lib/docker        container volumes (config is in Nix, data is not)
#   /var/lib/sops-nix      ★ key.txt — WITHOUT THIS THE REPO'S SECRETS CANNOT
#                          BE DECRYPTED AGAIN. .sops.yaml's whole design is
#                          "ciphertext in git, private key outside it"; losing
#                          this file loses every sops secret permanently.
#   /etc/ssh/ssh_host_*    imported by sops-install-secrets as an age key
#                          (seen during every rebuild), plus machine-id.
#   ~/.ssh ~/.gnupg        keys, and the gh token at ~/.config/gh — needed to
#   ~/.config/gh           push to github again after a reinstall.
#   ~/.local/share         lazygit/opencode state
#   ~/opencode.db          77M of session history, nothing else holds it
#   ~/projects             41M; wiki and study are in git, but uncommitted work
#                          would not be, and 41M is nothing to leave out over.
#
# DELIBERATELY EXCLUDED:
#   ~/filen     2.1G — a local mirror of CLOUD storage, so the cloud is the
#               backup; backing up a backup is waste.
#   /nix/store, /etc/nixos, ~/nixos-config — reproducible from git.
#   ~/.cache, /var/log — re-derivable.
#
# THE TRADEOFF IN ONE LINE: this stores private keys and the age key in plain
# ext4 on an unencrypted drive on a desk. That is the price of recovering at
# all; the alternative is a reinstall that cannot decrypt .sops.yaml and has to
# be hand-fixed. If the box ever leaves the house, the drive goes with it or
# gets encrypted.
#
# HOW THE SNAPSHOT WORKS. Each run writes a fresh dated directory, hardlinking
# unchanged files from the previous run (--link-dest). Same filesystem, so a
# day of no changes costs almost nothing and 7 days of a 1G tree is barely more
# than one copy. rsync runs ONCE PER SOURCE rather than once over all of them:
# --delete with several source arguments in a single invocation is a documented
# footgun (it can delete destination trees this transfer never touched), and
# one invocation per source makes --delete's scope exactly one subtree.
{pkgs, ...}: let
  dest = "/srv/backup";
  keepRuns = 7;

  sources = [
    "/var/lib/hass"
    "/var/lib/forgejo"
    "/var/lib/wiki"
    "/var/lib/gitea-mirror"
    "/var/lib/docker"
    "/var/lib/sops-nix"
    "/var/lib/tailscale"
    "/etc/ssh"
    "/etc/machine-id"
    "/home/mugdad/.ssh"
    "/home/mugdad/.gnupg"
    "/home/mugdad/.config/gh"
    "/home/mugdad/.gitconfig"
    "/home/mugdad/.local/share"
    "/home/mugdad/opencode.db"
    "/home/mugdad/projects"
  ];

  # DROPPED 2026-10-26 after the first real run, both of which printed
  # "skip (gone)" and would have done so every single day:
  #
  #   /var/lib/searxng          never existed. Searx is NOT a container and
  #                            NOT stateful here — :8888 is held by a wrapper
  #                            script, docker ps shows no containers and no
  #                            volumes, and /var/cache/searx is 0 bytes. Its
  #                            config lives in hosts/grandpa/searxng.nix, so it
  #                            is rebuilt from git like everything else. The
  #                            entry was written on the assumption it followed
  #                            the usual NixOS stateful-service shape.
  #   ~/.config/sops           the LAPTOP path for sops keys. On this box the
  #                            key is /var/lib/sops-nix/key.txt, which is in
  #                            the list above. .sops.yaml documents both.
  #
  # A source list is a claim about the machine, and every run re-checks it —
  # so a wrong claim does not corrupt anything, it just prints noise until
  # someone removes it. Left here rather than silently deleted because the
  # reasoning for each absence is the useful part.

  # Built as Nix, not passed through the environment: the script indexes the
  # list as a shell array ("''${SOURCES[@]}") and an exported variable is a
  # single string, which would expand to one word and be silently wrong.
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

    # The list is declared in Nix; a path that has since vanished must not
    # abort the run, so filter to what still exists.
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
      # -R (relative) is load-bearing: without it rsync strips the path to the
      # basename and /var/lib/hass lands at $NEW/hass — ambiguous the moment
      # two sources share a final component.
      #
      # || RC=$? because `set -e` would otherwise abort before the status is
      # captured, and the point of this check is to NOT rotate to a partial
      # snapshot. set -o pipefail does not apply here (no pipe), but the idiom
      # is worth the parens so nobody "cleans it up" into bare rsync.
      RC=0
      rsync -aR --delete "''${LINK[@]}" -- "$s" "$NEW/" || RC=$?
      if [ "$RC" -ne 0 ]; then
        echo "  FAILED ($RC): $s" >&2
        FAILED=1
      fi
    done
    ELAPSED=$(( $(date +%s) - START ))

    if [ "$FAILED" -ne 0 ]; then
      echo "$(date '+%F %T') INCOMPLETE — not rotating 'latest', keeping partial as $NEW" >&2
      exit 1
    fi

    ln -sfn "$(basename "$NEW")" "$DEST/latest"

    # Prune oldest-first by mtime, not name: the names sort correctly today and
    # would silently do the wrong thing if the naming scheme ever changed.
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
  # nofail: unplugging this drive must never block boot. See header.
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
    # Deliberately NOT wantedBy multi-user.target: the timer carries
    # Persistent=true, so a boot after a missed run still catches up, while an
    # ordinary reboot does not trigger a pointless full pass.
    path = with pkgs; [rsync coreutils findutils util-linux gawk gnugrep];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${backup}";
      # Succeeded is the common case; a failure shows red in the journal, which
      # is where this box already looks for trouble (row 216's rule).
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
    # systemctl start as a normal user needs polkit permission this box does not
    # grant, so drop to sudo rather than failing with a policy error nobody
    # would read as "you needed sudo".
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
