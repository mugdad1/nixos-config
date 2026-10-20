{pkgs, ...}: let
  # The fleet's task store: Vikunja on the ThinkCentre, bound to the tailnet
  # address only (100.88.29.31:3456, never a LAN IP — his standing rule:
  # "always tailscale ip ... so i can access from anyplace"). This entry is
  # the t480s face of it; the phone runs Tasks.org (F-Droid) over CalDAV.
  #
  # Why web and not the Tasks.org Linux build: Tasks.org ships amd64 Linux,
  # but its desktop module sets thirdPartySyncRequiresPro = true
  # (composeApp/src/desktopMain/.../DesktopModule.kt:180), so adding our
  # CalDAV account would hit its subscription screen — $1/yr for what the web
  # UI gives for free. --app keeps it a window, not a tab farm.
  url = "http://100.88.29.31:3456/";
in {
  xdg.desktopEntries.tasks = {
    name = "Tasks";
    genericName = "Task list";
    comment = "Vikunja tasks on the ThinkCentre (via Tailscale)";
    exec = "${pkgs.chromium}/bin/chromium --app=${url}";
    terminal = false;
    icon = "checkbox";
    categories = ["Office"];
    startupNotify = true;
  };
}
