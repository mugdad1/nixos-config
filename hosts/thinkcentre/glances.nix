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
# The container was REMOVED at the end of the same day (`docker rm glances` —
# a stopped container stays in `docker ps -aq` forever, and sv-watch watches
# every container in that listing, so leaving it stopped meant a permanent
# "docker DOWN: glances" page). The image may still be in the local docker
# cache. To go back: disable this module's import in ./default.nix, rebuild,
# then `docker run` the image again on :61208.
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
