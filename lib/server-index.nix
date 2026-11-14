# The fleet's service list, declared once and rendered to the HTML index that
# nginx serves on grandpa. Add a service here and a rebuild publishes it.
{
  g ? import ./gruvbox.nix,
}: let
  inherit (builtins) concatStringsSep filter length map;
  optionalString = cond: str:
    if cond
    then str
    else "";
  c = g.raw;

  # The boxes that host web pages, in the order their sections appear.
  # asus leads because `study` is the most-used URL.
  hosts = [
    {
      name = "asus";
      ip = "100.92.54.61";
    }
    {
      name = "grandpa";
      ip = "100.106.116.60";
    }
  ];

  # name · host · port · what it is.
  services = [
    {
      name = "study";
      host = "asus";
      port = "8091";
      desc = "the study PWA — chapters, glossary, day entries";
      first = true;
    }
    {
      name = "trilium";
      host = "asus";
      port = "8080";
      desc = "notes — triliumnext, hierarchical; syncs with the desktop app";
    }
    {
      name = "home assistant";
      host = "grandpa";
      port = "8123";
      desc = "local home automation — the ac, dashboards, sensors";
    }
    {
      name = "forgejo";
      host = "grandpa";
      port = "3000";
      desc = "git, self-hosted — replaced gitea";
    }
    {
      name = "gitea mirror";
      host = "grandpa";
      port = "4321";
      desc = "github → forgejo mirroring, native systemd";
      note = "tailnet only";
    }
    {
      name = "searxng";
      host = "grandpa";
      port = "8888";
      desc = "private metasearch, json api enabled — zen's search engine";
    }
  ];

  # `first = true` entries are hoisted to the top of their host's table, the
  # rest keep their order.
  sorted = entries:
    (filter (s: s.first or false) entries)
    ++ (filter (s: !(s.first or false)) entries);

  # `url` wins over the generated host:port when an entry needs an absolute link.
  row = h: s: let
    href = s.url or "http://${h.ip}:${s.port}";
  in ''<tr><td><a href="${href}">${s.name}</a></td><td>${s.desc}</td><td class="m">:${s.port}${optionalString (s ? note) " ${s.note}"}</td></tr>'';

  section = h: let
    entries = sorted (filter (s: s.host == h.name) services);
  in
    if entries == []
    then ""
    else ''
      <h2>${h.name} &mdash; ${h.ip}</h2>
      <table>
      ${concatStringsSep "\n" (map (row h) entries)}
      </table>'';

  tables = concatStringsSep "\n" (map section hosts);
in ''
  <!doctype html>
  <meta charset="utf-8">
  <title>server</title>
  <style>
   body{background:#${c.bg0_h};color:#${c.fg};font:15px/1.6 ui-monospace,SFMono-Regular,Menlo,monospace;max-width:760px;margin:48px auto;padding:0 20px}
   h1{color:#${c.bright_green};font-size:22px;font-weight:600}
   h2{color:#${c.bright_green};font-size:16px;font-weight:600;margin:28px 0 6px}
   a{color:#${c.bright_blue};text-decoration:none}
   a:hover{text-decoration:underline}
   td{padding:5px 18px 5px 0;vertical-align:top}
   .m{color:#${c.gray}}
   tr:first-child a{color:#${c.bright_yellow};font-weight:700}
   hr{border:0;border-top:1px solid #${c.bg2};margin:26px 0}
  </style>
  <h1>mugdad &mdash; Server</h1>
  <p class="m">generated from <b>~/nixos-config/lib/server-index.nix</b> &mdash; do not edit by hand; nginx on grandpa serves this page (a rebuild is the publish).</p>
  <p class="m">${toString (length services)} services have a page. Everything else is described below the tables &mdash; a link only appears here if the port actually answers.</p>
  ${tables}
  <hr>
  <p class="m"><b>filen-sync</b> &mdash; a systemd timer, not a web service: it bisyncs the Filen drive root into <b>~/filen</b> every 30 minutes. Check it with <b>systemctl status filen-sync.timer</b>.</p>
  <p class="m">tailscaled runs as a system service (systemd, <b>tailscaled.service</b>), no web ui.</p>
  <hr>
  <p class="m">blocky is dns on <b>0.0.0.0:53</b> on grandpa and asus — bound on every interface so loopback and the tailnet both answer; the firewall, not the bind, is what keeps the LAN out. Never web-published.</p>
''
