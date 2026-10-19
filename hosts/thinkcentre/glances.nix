# GLANCES on thinkcentre — 2026-10-19, replacing the docker container.
#
# The old way was `docker run nicolargo/glances:latest-full` on :61208, and it
# lied about the host for its whole life: the container reads its OWN
# /etc/os-release, so the UI header read "735a294be91e / Alpine Linux 3.24.2
# 64bit" on a NixOS box (backlog row 10; his word: "glances is wrong /
# this isnt alpine"). This module is the same fix grandpa got the same day
# (hosts/grandpa/glances.nix): native `services.glances`, same port, so both
# boxes report what they actually are and the config survives a reinstall.
#
# The container was STOPPED, not deleted (`docker stop glances`; its
# unless-stopped policy keeps it stopped across daemon restarts), and the port
# is free for this service. To go back: `docker start glances` + disable this
# module's import in ./default.nix.
#
# MUST be listed in ./default.nix's imports — a directory module resolves to
# default.nix ONLY and does not sweep up siblings.
{...}: {
  services.glances = {
    enable = true;
    port = 61208;
    openFirewall = true;
  };
}
