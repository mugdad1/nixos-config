# GLANCES on grandpa — 2026-10-19, his word "can we have glances for grandpa".
#
# The thinkcentre runs glances as a docker container (nicolargo/glances:
# latest-full, :61208) — which is also why that one reports "Alpine Linux" as
# the OS: the container reads its own image's /etc/os-release, not the host's
# (backlog row 10, his "glances is wrong / this isnt alpine"). This one is
# NixOS-native, so it reports the box it is actually on. Same port the
# dashboard already uses for glances, and openFirewall makes :61208 answer on
# LAN + tailnet the same way the container's published port does.
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
