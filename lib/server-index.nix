# The fleet's service list, declared ONCE and rendered to an HTML index.
#
# THE 2026-10-25 STRIP. The box was cut down to the set he confirmed keeping —
# study, home assistant, searxng, blocky, tailscaled, opencode-serve,
# filen-sync — and the seven compose projects (forgejo, gitea-mirror, immich,
# jellyfin, metube, vaultwarden, vikunja) went out WITH their data and config
# ("rm data and config" → "a"), together with glances. So the live table is
# three rows now. That is a real number, not a broken page: the index exists to
# say what is running, and what is running is this much.
#
# Removed rows are COMMENTED, never deleted — same treatment stirling/paperless
# got on 2026-10-20 — because the date and the reason are the point of this
# file. What the port numbers were, and the day they stopped answering, stay.
#
# SERVICES WITH NO PAGE are prose under the table, not rows: blocky (DNS :53),
# tailscaled, opencode-serve (loopback-only :13420) and filen-sync (a timer).
# A row here is a promise that the link answers; prose cannot break that
# promise, which is the drift this file exists to prevent.
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
  # DEFAULT IS GRANDPA SINCE 2026-10-22 — the ThinkCentre was returned to its
  # owner, so 100.88.29.31 has no box behind it. `row` below builds every
  # link from this, so it must match what `tailscale ip -4` reports on
  # grandpa (100.106.116.60 since it was registered 2026-10-16), not what an
  # older page remembers.
  host ? "http://100.106.116.60",
  # `grandpa` is kept as the explicit name for the same base — `row` below
  # switches link bases by machine, and both point at grandpa now.
  grandpa ? "http://100.106.116.60",
}: let
  inherit (builtins) concatStringsSep filter length map;
  optionalString = cond: str:
    if cond
    then str
    else "";
  c = g.raw;

  # name · port · what it is. `study` first on his word — *"its the most
  # importnt url btw"*.
  #
  # study moved thinkcentre -> grandpa 2026-10-22 with the whole service
  # layer (the box is back with its owner) — the systemd unit is declared in
  # hosts/grandpa/services.nix now.
  services = [
    {
      name = "study";
      port = "8091";
      desc = "the study PWA — chapters, glossary, day entries";
      first = true;
      machine = "grandpa";
    }
    # home assistant, added 2026-10-17 with the AC project's close
    # (decisions.md row 114); moved thinkcentre -> grandpa 2026-10-22 with the
    # rest of the nix-native service layer — hosts/grandpa/home-assistant.nix,
    # firewall :8123 on tailscale0 only.
    {
      name = "home assistant";
      port = "8123";
      desc = "local home automation — the ac, dashboards, sensors";
      machine = "grandpa";
    }
    # REMOVED 2026-10-25 with the strip ("rm data and config" → "a"): the
    # compose dir, ./data and the 55M photo library under ~/projects/servers/data
    # are gone from disk, no backup anywhere on the box. immich had arrived here
    # 2026-10-22 from the ThinkCentre carrying NO data ("immich got 0 data"),
    # so it lived a few days as a fresh install and then took its library with
    # it. Was :2283.
    # {
    #   name = "immich";
    #   port = "2283";
    #   desc = "photos &amp; video backup";
    #   machine = "grandpa";
    # }
    # REMOVED 2026-10-25 with the strip — config, cache and image all deleted,
    # ~/media was empty anyway. Its record is worth keeping for one line: this
    # box is a Sandy Bridge i3-2120 with card0 but NO renderD128, and Intel
    # dropped the i965 driver Sandy Bridge needs, so grandpa never had a
    # hardware transcode path at all — anything needing transcoding fell to a
    # 2011 CPU. If media ever returns, that constraint is unchanged. Was :8096.
    # {
    #   name = "jellyfin";
    #   port = "8096";
    #   desc = "media server";
    #   machine = "grandpa";
    # }
    # REMOVED 2026-10-25 with the strip. The vault went with its data —
    # ~/projects/servers/vaultwarden/data/db.sqlite3 and rsa_key.pem are deleted
    # off the disk, no copy exists anywhere on this box. The passwords he had
    # saved there are gone; he read the read-back naming both files and answered
    # "a". Nothing to link to, and no `tailscale serve` route either: the
    # systemd.services.tailscale-serve unit that pinned these HTTPS routes was
    # removed in the same commit, so :8443 and :444 are dead listeners in
    # tailscaled's state until `tailscale serve reset`. Was https :8443.
    # {
    #   name = "vaultwarden";
    #   port = "8082";
    #   desc = "password manager";
    #   url = "https://grandpa.tailbc99bb.ts.net:8443/";
    #   note = "tailnet https";
    # }
    # REMOVED 2026-10-25 with the strip, along with the task DB (./db) and its
    # compose file. The phone's saved URL (https://grandpa.*:444/) is dead and
    # stays dead — the serve route that fronted it went with the
    # tailscale-serve unit. Was https :444.
    # {
    #   name = "vikunja";
    #   port = "3456";
    #   desc = "task store — caldav + web ui, synced from the phone";
    #   url = "https://grandpa.tailbc99bb.ts.net:444/";
    #   note = "tailnet https";
    # }
    # forgejo + gitea-mirror — REMOVED 2026-10-25 with the strip (compose dir
    # and images pruned), then RESTORED 2026-10-26 as native NixOS, at his
    # *"in the end i want clean system with forgero and giteamirror enalbed"*.
    # The data was never lost — 873M still at /var/lib/forgejo, last written
    # the day before the strip — so these point at live ports again. They are
    # nix-native now, not the compose project the original row described.
    {
      name = "forgejo";
      port = "3000";
      desc = "git, self-hosted — replaced gitea, native NixOS on grandpa";
      machine = "grandpa";
    }
    {
      name = "gitea mirror";
      port = "4321";
      desc = "github → forgejo mirroring, native systemd";
      note = "tailnet only";
      machine = "grandpa";
    }
    # REMOVED 2026-10-25 with the strip — hosts/grandpa/glances.nix deleted,
    # the module un-imported. It was the one nix-native monitoring view on this
    # box; with smartd out of modules/core the same day there is no monitoring
    # of any kind left on the fleet, by his order. Was :61208.
    # {
    #   name = "glances";
    #   port = "61208";
    #   desc = "cpu / temp / mem / disk, live — on grandpa";
    #   machine = "grandpa";
    # }
    # wiki (mkdocs-material on grandpa) dropped 2026-10-19 — row 128, the md
    # service was removed on his "idont care that much". Read the wiki on GitHub.
    # (The old note here said ":80 on grandpa refuses now" — true until
    # 2026-10-25, when nginx was restored and :80 began serving THIS page. A
    # live port still does not bring the wiki back; it is a repo, not a row.)
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
    # The thinkcentre's glances container row left with the box 2026-10-22;
    # its grandpa twin was removed 2026-10-25 (commented above), so no glances
    # is running anywhere in the fleet.
    # searxng moved thinkcentre -> grandpa 2026-10-22 — NIX-NATIVE now, not a
    # container: hosts/grandpa/searxng.nix (`services.searx`), port 8888,
    # tailscale-only bind. The old compose dir stayed on the ThinkCentre's
    # disk and ships with the box. This is the fleet's web-search endpoint
    # (AGENTS.md § Conventions).
    {
      name = "searxng";
      port = "8888";
      desc = "private metasearch, json api enabled — zen's search engine";
      machine = "grandpa";
    }
    # REMOVED 2026-10-25 with the strip — compose dir and config deleted;
    # ~/media was empty, so nothing was carried or lost. Was :8081.
    # {
    #   name = "metube";
    #   port = "8081";
    #   desc = "yt-dlp web ui, downloads to the box";
    #   machine = "grandpa";
    # }
    # caddy commented out 2026-10-22 — it reverse-proxied on the ThinkCentre
    # and was this page's host there; the box left the fleet. It has NO home
    # here and never had: when the page needed a host again on 2026-10-25 he
    # was asked caddy or nginx and said, verbatim, "i dont want caddy". nginx
    # serves :80. Leave this row commented — a caddy row would advertise a
    # reverse proxy this box does not run.
    # {
    #   name = "caddy";
    #   port = "80";
    #   desc = "reverse proxy — and the host of this page";
    # }
  ];

  # `first = true` entries are hoisted to the top, the rest keep their order.
  # Since 2026-10-22 every live row is grandpa's — the ThinkCentre left the
  # fleet — so one table serves the page; `isG`/`machine` stay in the shape
  # of the data so a future second box just sets `machine` again.
  isG = s: (s.machine or "") == "grandpa";
  tcServices = filter (s: !(isG s)) services;
  gpServices = filter isG services;
  sorted =
    gpServices
    ++ (filter (s: s.first or false) tcServices)
    ++ (filter (s: !(s.first or false)) tcServices);

  # `url` wins over the generated host:port when an entry needs an absolute
  # link. Otherwise the link base follows the entry's machine — everything
  # resolves against grandpa's tailnet IP by default now.
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
  <h1>mugdad &mdash; Server</h1>
  <p class="m">generated from <b>~/nixos-config/lib/server-index.nix</b> &mdash; do not edit by hand; nginx on grandpa serves this page (a rebuild is the publish).</p>
  <h2>grandpa &mdash; 100.106.116.60</h2>
  <p class="m">${toString (length sorted)} of the fleet's services have a page. Everything he keeps that does NOT is written out below the table &mdash; a link only appears here if the port actually answers.</p>
  <table>
  ${table sorted}
  </table>
  <hr>
  <p class="m"><b>filen-sync</b> &mdash; a systemd timer, not a web service: it bisyncs the Filen drive root into <b>~/filen</b> every 30 minutes (10 min after boot, 60 min cap per run). No port and no ui; check it with <b>systemctl status filen-sync.timer</b>.</p>
  <p class="m">tailscaled runs as a system service (systemd, <b>tailscaled.service</b>), no web ui.</p>
  <hr>
  <p class="m">blocky is dns on <b>0.0.0.0:53</b> on grandpa — bound on every interface so loopback and the tailnet both answer; the firewall, not the bind, is what keeps the LAN out. Never web-published.</p>
''
