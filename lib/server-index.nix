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
# hand-written `~/Projects/servers/caddy/index.html` had already drifted twice
# before this file took over: it was missing `study`, and it kept a line for a
# service that was deleted on 2026-10-08.
#
# COMMENT REPAIRED 2026-10-18: those two lines used to read as one broken
# sentence ("…was missing `study` (added today)" followed by "…line that was
# deleted on 2026-10-08."), the remains of an earlier edit that cut the middle
# out. The facts are the two drift cases named above; nothing was reworded to
# sound tidier than the record.
{
  g ? import ./gruvbox.nix,
  # The tailscale IP moved 100.124.75.45 -> 100.88.29.31 on 2026-10-15, the
  # day the ThinkCentre was reinstalled and re-registered on the tailnet. This
  # is the ONE place the address is a default rather than a literal — `row`
  # below builds every link from it — so it must match what `tailscale ip -4`
  # reports on the box, not what an older page remembers.
  host ? "http://100.88.29.31",
  # grandpa's tailnet IP — the second table's link base, same reasoning as
  # `host` above (must match `tailscale ip -4` on grandpa, 100.106.116.60
  # since it was registered 2026-10-16). His ask 2026-10-19: "in caddy can we
  # have 2 things / 1 for thinkcentre and 1 for grandpa".
  grandpa ? "http://100.106.116.60",
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
    # jellyfin moved thinkcentre -> grandpa 2026-10-21 (his "mv jellyfin"), the
    # same move metube made the day before. There was nothing to carry: the
    # config was 900K, the cache 12K and /home/mugdad/media was empty (8K) on
    # both boxes, so this was a config move, not a data migration — his word
    # "there is no account nor data so just clean and mv the nixfile u dont
    # haveto backup".
    #
    # WHAT WAS LOST, and it is worth writing down because it is silent: the
    # thinkcentre is a Skylake i7-6700T and its compose file passed
    # /dev/dri/card0 + /dev/dri/renderD128 through for VAAPI transcoding. Grandpa
    # is a Sandy Bridge i3-2120: it has card0 but NO renderD128, and Intel
    # dropped the i965 driver that Sandy Bridge needs, so there is no hardware
    # transcoding path on that box at all. Direct play still works; anything
    # that needs transcoding now falls to software on a 2011 CPU, which means
    # 1080p will not survive it. `machine = grandpa` switches the link base to
    # grandpa's tailnet IP.
    {
      name = "jellyfin";
      port = "8096";
      desc = "media server";
      machine = "grandpa";
    }
    # `url` overrides the generated host:port link — the vault is HTTPS-only
    # (web vault needs a secure context, decisions.md row 86) and reachable
    # only through tailscale serve, so its plain :8082 link would just throw
    # the Subtle Crypto error again.
    #
    # FIXED 2026-10-21: this url was `https://thinkcentre.tailbc99bb.ts.net`
    # with NO port, which means :443 — and Caddy owns 0.0.0.0:443 with
    # `auto_https off`, i.e. that listener speaks plain HTTP, not TLS. So the
    # link returned 000 forever, a dead password-manager link on the front
    # page. The comment above it was also a lie: it said the vault was
    # "reachable only through tailscale serve" when no such serve had ever
    # been configured — only vikunja had one (on :444, same reason).
    # Fixed by adding the missing serve, `tailscale serve --bg --https=8443
    # http://100.88.29.31:8082`, and pointing this row at :8443. Chose 8443
    # because :443 is Caddy's and :444 is vikunja's — tailscaled's listener
    # cannot bind over Caddy's (row 158). Verified live: :8443 returns 200
    # and serves "Vaultwarden", /api/config 200, while the old no-port link
    # still returns 000.
    #
    # GAP worth knowing: like vikunja's, this serve is set through the CLI and
    # lives in tailscaled's state, not in this repo — so it survives reboots
    # but NOT a fresh install, which is the one thing his "the same system
    # comes back" rule is for. Noted, not yet fixed.
    {
      name = "vaultwarden";
      port = "8082";
      desc = "password manager";
      url = "https://thinkcentre.tailbc99bb.ts.net:8443/";
      note = "tailnet https";
    }
    # vikunja, added 2026-10-20 with the task store's close (decisions.md row
    # 152). Same shape as vaultwarden: HTTPS-only, because his phone refused
    # cleartext to the tailnet IP ("err cleartext comm to ts ip not permiitted
    # by securtity policy"). Served by tailscale serve on :444, NOT :443 —
    # Caddy holds 0.0.0.0:443 and tailscaled's listener cannot bind over it
    # (row 158).
    {
      name = "vikunja";
      port = "3456";
      desc = "task store — caldav + web ui, synced from the phone";
      url = "https://thinkcentre.tailbc99bb.ts.net:444/";
      note = "tailnet https";
    }
    # gitea dropped 2026-10-18 ~15:55 — his word: "rm gitea and it mirror cuz its bad".
    # Forgejo on grandpa is the replacement git host; :3000/:2222 back in the pool.
    # grandpa's services, added the same day gitea died (2026-10-18). The
    # row generator defaults to thinkcentre's host, so both carry an explicit
    # `url` — grandpa's tailnet IP 100.106.116.60, which answers from anywhere
    # tailscale is up, same reason the HA link works.
    {
      name = "forgejo";
      port = "3000";
      desc = "git, self-hosted — replaced gitea, docker compose on grandpa";
      machine = "grandpa";
    }
    {
      name = "gitea mirror";
      port = "4321";
      desc = "github → forgejo mirroring, back on grandpa 2026-10-19";
      note = "tailnet only";
      machine = "grandpa";
    }
    # glances on grandpa, added the same day he asked for it (2026-10-19) —
    # NixOS-native service (hosts/grandpa/glances.nix), unlike the docker
    # container on thinkcentre. Both are :61208, one per table.
    {
      name = "glances";
      port = "61208";
      desc = "cpu / temp / mem / disk, live — on grandpa";
      machine = "grandpa";
    }
    # wiki (mkdocs-material on grandpa) dropped 2026-10-19 — row 128, the md
    # service was removed on his "idont care that much". Port 80 on grandpa
    # refuses now, so the row would ship a dead link. Read the wiki on GitHub.
    # uptime kuma dropped 2026-10-11 ~22:36 — his `ucan rm uptimekuma fully`,
    # hours after upgrading it v1 -> v2 (wiki row 74). Container gone, :3001
    # dead, so it came off this list too or the index ships a dead link.
    # stirling pdf · paperless · syncthing — all three dropped 2026-10-20, his
    # word: *"stirling and paperless i never used them u may remove them / im
    # not sure how will they be usefull / even syncting"*. Containers stopped
    # and removed; the compose files and ./data stay on disk untouched (the
    # mounts are bind mounts, so `docker compose down -v` only dropped scratch
    # volumes). Nothing was lost, and any of the three comes back by `up` in
    # its own directory.
    #   stirling pdf :8090 — never opened.
    #   paperless    :8000 — never opened; ./data/pg was empty (4K), i.e. the
    #                        document DB never held anything.
    #   syncthing    :8384 :22000 :21027 — configured but had NO folders at all,
    #                        so it never synced a single byte; and its web UI
    #                        had no auth on a LAN-exposed port. Study and wiki
    #                        sync by git over ssh, so nothing depended on it.
    # {
    #   name = "stirling pdf";
    #   port = "8090";
    #   desc = "merge / split / OCR pdfs locally";
    # }
    # {
    #   name = "paperless";
    #   port = "8000";
    #   desc = "document archive, arabic + english ocr search";
    # }
    # {
    #   name = "syncthing";
    #   port = "8384";
    #   desc = "laptop / phone &harr; box file sync";
    #   note = ":22000";
    # }
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
    # metube moved thinkcentre -> grandpa 2026-10-20 (his "mv metube to
    # grandpa"). Downloads go to grandpa's ~/media/videos now, not the
    # thinkcentre's; the old dir on the thinkcentre was empty (12K), so
    # nothing had to be carried over. `machine = grandpa` switches the link
    # base to grandpa's tailnet IP.
    {
      name = "metube";
      port = "8081";
      desc = "yt-dlp web ui, downloads to the box";
      machine = "grandpa";
    }
    # gitea mirror dropped 2026-10-18 — took it down with gitea ("it mirror cuz
    # its bad"). Its db held only job configs, no data of its own.
    {
      name = "caddy";
      port = "80";
      desc = "reverse proxy — and the host of this page";
    }
  ];

  # `first = true` entries are hoisted to the top, the rest keep their order.
  # The split is by `machine` (default = thinkcentre): two tables on one page —
  # his ask 2026-10-19 ("1 for thinkcentre and 1 for grandpa").
  isG = s: (s.machine or "") == "grandpa";
  tcServices = filter (s: !(isG s)) services;
  gpServices = filter isG services;
  sorted =
    (filter (s: s.first or false) tcServices)
    ++ (filter (s: !(s.first or false)) tcServices);

  # `url` wins over the generated host:port when an entry needs an absolute
  # link (vaultwarden → tailscale HTTPS, see its entry above). Otherwise the
  # link base follows the entry's machine — grandpa's rows get grandpa's IP.
  row = s: let
    href =
      s.url
      or "${
        if isG s
        then grandpa
        else host
      }:${s.port}";
  in ''<tr><td><a href="${href}">${s.name}</a></td><td>${s.desc}</td><td class="m">:${s.port}${optionalString (s ? note) " ${s.note}"}</td></tr>'';
  table = entries: concatStringsSep "\n" (map row entries);
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
  <h1>mugdad &mdash; servers</h1>
  <p class="m">generated from <b>~/nixos-config/lib/server-index.nix</b> &mdash; do not edit by hand, run <b>push-server-index</b> instead.</p>
  <h2>thinkcentre &mdash; 100.88.29.31</h2>
  <table>
  ${table sorted}
  </table>
  <h2>grandpa &mdash; 100.106.116.60</h2>
  <table>
  ${table gpServices}
  </table>
  <p class="m">tailscaled runs as a system service (systemd, <b>tailscaled.service</b>), no web ui.</p>
  <hr>
  <p class="m">blocky is dns on <b>127.0.0.1:53</b>, loopback only &mdash; never web-published.</p>
''
