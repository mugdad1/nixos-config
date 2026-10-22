{pkgs, ...}: let
  # Vikunja was on the ThinkCentre (100.88.29.31:3456, tailnet only). The box
  # was returned to its owner 2026-10-22, and its vikunja compose dir + data
  # stayed on that disk — so the task store is OFFLINE until he decides
  # whether it moves to grandpa (comment-out, never delete; the URL below is
  # the old one, kept with the entry so a restore knows where it pointed).
  # When vikunja gets a grandpa home, change `url` to grandpa's tailnet IP
  # 100.106.116.60 and uncomment the block.
  #
  # Why web and not the Tasks.org Linux build: Tasks.org ships amd64 Linux,
  # but its desktop module sets thirdPartySyncRequiresPro = true
  # (composeApp/src/desktopMain/.../DesktopModule.kt:180), so adding our
  # CalDAV account would hit its subscription screen — $1/yr for what the web
  # UI gives for free. --app keeps it a window, not a tab farm.
  url = "http://100.88.29.31:3456/";
in {
  # xdg.desktopEntries.tasks = {
  #   name = "Tasks";
  #   genericName = "Task list";
  #   comment = "Vikunja tasks on the ThinkCentre (via Tailscale)";
  #   exec = "${pkgs.chromium}/bin/chromium --app=${url}";
  #   terminal = false;
  #   icon = "checkbox";
  #   categories = ["Office"];
  #   startupNotify = true;
  # };
}
