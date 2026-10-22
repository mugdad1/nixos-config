{pkgs, ...}: let
  # Vikunja moved thinkcentre -> grandpa 2026-10-22 with the compose trio (his
  # "mv immich and vault and vik"), so the task store is live again and the
  # entry is re-enabled with grandpa's address. The HTTPS URL is the one his
  # phone already uses — `tailscale serve --bg --https=444 http://100.106.116.60:3456`
  # on grandpa — because his Tasks app refuses cleartext to a tailnet IP
  # (decisions.md row 152). Was `http://100.88.29.31:3456/` on the old box.
  #
  # Why web and not the Tasks.org Linux build: Tasks.org ships amd64 Linux,
  # but its desktop module sets thirdPartySyncRequiresPro = true
  # (composeApp/src/desktopMain/.../DesktopModule.kt:180), so adding our
  # CalDAV account would hit its subscription screen — $1/yr for what the web
  # UI gives for free. --app keeps it a window, not a tab farm.
  url = "https://grandpa.tailbc99bb.ts.net:444/";
in {
  xdg.desktopEntries.tasks = {
    name = "Tasks";
    genericName = "Task list";
    comment = "Vikunja tasks on grandpa (via Tailscale)";
    exec = "${pkgs.chromium}/bin/chromium --app=${url}";
    terminal = false;
    icon = "checkbox";
    categories = ["Office"];
    startupNotify = true;
  };
}
