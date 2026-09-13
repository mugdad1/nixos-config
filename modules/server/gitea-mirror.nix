# Pull-mirror RayLabsHQ/gitea-mirror into the local Gitea.
#
# One-time setup: create an admin token (Gitea UI -> Settings -> Applications)
# and write it to /var/lib/gitea-mirror/token on the server:
#   install -d -o root -g root -m 700 /var/lib/gitea-mirror
#   echo '<token>' > /var/lib/gitea-mirror/token && chmod 600 /var/lib/gitea-mirror/token
# The unit creates the mirror if missing and exits cleanly otherwise.
{pkgs, ...}: {
  systemd.services.gitea-mirror-raylabs = {
    description = "Mirror RayLabsHQ/gitea-mirror into local Gitea";
    after = ["gitea.service"];
    wantedBy = ["multi-user.target"];
    path = [pkgs.curl];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    script = ''
      set -eu
      TOKEN_FILE=/var/lib/gitea-mirror/token
      if [ ! -f "$TOKEN_FILE" ]; then
        echo "gitea-mirror: $TOKEN_FILE missing, skipping (see modules/server/gitea-mirror.nix)"
        exit 0
      fi
      TOKEN=$(cat "$TOKEN_FILE")
      API=http://127.0.0.1:3000/api/v1

      # wait for gitea (max ~60s)
      for _ in $(seq 1 30); do
        curl -fsS -o /dev/null "$API/version" && break
        sleep 2
      done

      # already mirrored?
      if curl -fsS -o /dev/null \
        -H "Authorization: token $TOKEN" \
        "$API/repos/mugdad/gitea-mirror"; then
        echo "gitea-mirror: already present, nothing to do"
        exit 0
      fi

      curl -fsS \
        -H "Authorization: token $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"clone_addr":"https://github.com/RayLabsHQ/gitea-mirror","repo_name":"gitea-mirror","repo_owner":"mugdad","mirror":true,"private":false,"description":"Mirror of RayLabsHQ/gitea-mirror"}' \
        "$API/repos/migrate"
      echo "gitea-mirror: mirror created"
    '';
  };
}
