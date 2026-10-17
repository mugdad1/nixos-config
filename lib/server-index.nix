# The ThinkCentre's service list, declared ONCE and rendered to an HTML index.
#
# Why this lives here and not on the server: Mugdad's rule, 2026-10-11 —
# *"i dont want thing that goes after i re install nix ok? this is the main
# idea of nixos the same system comes back"*. CORRECTED 2026-10-13: the
# premise under that quote was "the server is Void, so it cannot own this
# declaratively" — the server has been NixOS since that day's migration
# (decisions.md row 78), so that half of the argument is gone. The page stays
# here anyway, for the other half: the count is meant to follow the nix list,
# and a page generated from the same `services` value below cannot drift from
# it the way hand-written HTML does. `push-server-index` (see
# modules/home/apps/homepage.nix) ships the rendered page to Caddy's docroot.
# **Add a service to `services` below, run `push-server-index`, and the index
# matches reality again** — the old
# hand-written `~/Projects/servers/caddy/index.html` had already drifted: it
# was missing `study` (added today)
# line that was deleted on 2026-10-08.
{
  g ? import ./gruvbox.nix,
  # The tailscale IP moved 100.124.75.45 -> 100.88.29.31 on 2026-10-15, the
  # day the ThinkCentre was reinstalled and re-registered on the tailnet. This
  # is the ONE place the address is a default rather than a literal — `row`
  # below builds every link from it — so it must match what `tailscale ip -4`
  # reports on the box, not what an older page remembers.
  host ? "http://100.88.29.31",
}: let
  inherit (builtins) concatStringsSep filter map;
  optionalString = cond: str:
    if cond
    then str
    else "";
  c = g.raw;

  # name · port · what it is. `study` first on his word — *"its the most
  # importnt url btw"*.
  services = [
    {
      name = "study";
      port = "8091";
      desc = "the study PWA — chapters, glossary, day entries";
      first = true;
    }
    # home assistant, added 2026-10-17 with the AC project's close
    # (decisions.md row 114) — HA + ESPHome run natively on this box,
    # firewall :8123 on LAN + tailnet, so the tailnet link answers
    # from every host on the network.
    {
      name = "home assistant";
      port = "8123";
      desc = "local home automation — the ac, dashboards, sensors";
    }
    {
      name = "immich";
      port = "2283";
      desc = "photos &amp; video backup";
    }
    {
      name = "jellyfin";
      port = "8096";
      desc = "media server";
    }
    # `url` overrides the generated host:port link — the vault is HTTPS-only
    # (web vault needs a secure context, decisions.md row 86) and reachable
    # only through tailscale serve, so its plain :8082 link would just throw
    # the Subtle Crypto error again.
    {
      name = "vaultwarden";
      port = "8082";
      desc = "password manager";
      url = "https://thinkcentre.tailbc99bb.ts.net";
      note = "tailnet https";
    }
    {
      name = "gitea";
      port = "3000";
      desc = "git, self-hosted";
      note = "ssh :2222";
    }
    # uptime kuma dropped 2026-10-11 ~22:36 — his `ucan rm uptimekuma fully`,
    # hours after upgrading it v1 -> v2 (wiki row 74). Container gone, :3001
    # dead, so it came off this list too or the index ships a dead link.
    {
      name = "stirling pdf";
      port = "8090";
      desc = "merge / split / OCR pdfs locally";
    }
    {
      name = "paperless";
      port = "8000";
      desc = "document archive, arabic + english ocr search";
    }
    {
      name = "syncthing";
      port = "8384";
      desc = "laptop / phone &harr; box file sync";
      note = ":22000";
    }
    # ntfy dropped 2026-10-12 — wiki row 75, container removed together with ALL
    # alert delivery (its own stats showed subscribers=0 for its whole life).
    # :8085 answered 000 and the live index was still advertising it, i.e. the
    # exact drift this file exists to prevent, recurring a day after the
    # uptime-kuma entry was fixed in f1ebc12. Verified: every other port in
    # this list answers.
    {
      name = "glances";
      port = "61208";
      desc = "cpu / temp / mem / disk, live";
    }
    {
      name = "searxng";
      port = "8888";
      desc = "private metasearch, json api enabled — zen's search engine";
    }
    {
      name = "metube";
      port = "8081";
      desc = "yt-dlp web ui, downloads to the box";
    }
    {
      name = "gitea mirror";
      port = "4321";
      desc = "github &rarr; local gitea backup";
    }
    {
      name = "caddy";
      port = "80";
      desc = "reverse proxy — and the host of this page";
    }
  ];

  # `first = true` entries are hoisted to the top, the rest keep their order.
  sorted =
    (filter (s: s.first or false) services)
    ++ (filter (s: !(s.first or false)) services);

  # `url` wins over the generated host:port when an entry needs an absolute
  # link (vaultwarden → tailscale HTTPS, see its entry above).
  row = s: let
    href = s.url or "${host}:${s.port}";
  in ''<tr><td><a href="${href}">${s.name}</a></td><td>${s.desc}</td><td class="m">:${s.port}${optionalString (s ? note) " ${s.note}"}</td></tr>'';
in ''
  <!doctype html>
  <meta charset="utf-8">
  <title>server</title>
  <style>
   body{background:#${c.bg0_h};color:#${c.fg};font:15px/1.6 ui-monospace,SFMono-Regular,Menlo,monospace;max-width:760px;margin:48px auto;padding:0 20px}
   h1{color:#${c.bright_green};font-size:22px;font-weight:600}
   a{color:#${c.bright_blue};text-decoration:none}
   a:hover{text-decoration:underline}
   td{padding:5px 18px 5px 0;vertical-align:top}
   .m{color:#${c.gray}}
   tr:first-child a{color:#${c.bright_yellow};font-weight:700}
   hr{border:0;border-top:1px solid #${c.bg2};margin:26px 0}
  </style>
  <h1>mugdad &mdash; 100.88.29.31</h1>
  <p class="m">generated from <b>~/nixos-config/lib/server-index.nix</b> &mdash; do not edit by hand, run <b>push-server-index</b> instead.</p>
  <table>
  ${concatStringsSep "\n" (map row sorted)}
  </table>
  <p class="m">tailscaled runs as a system service (systemd, <b>tailscaled.service</b>), no web ui.</p>
  <hr>
  <p class="m">blocky is dns on <b>127.0.0.1:53</b>, loopback only &mdash; never web-published.</p>
''
