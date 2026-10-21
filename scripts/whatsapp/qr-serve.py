#!/usr/bin/env python3
"""Serve the freshest WhatsApp pairing QR on http://127.0.0.1:8877/.

Why this exists rather than a screenshot: whatsmeow hands out a new QR roughly
every 20 seconds, so any captured image is stale before the phone camera gets
focus. The bridge keeps appending each generation to store/bridge.log, so the
page re-reads the log every request and the browser re-fetches every second.
The live code on screen is therefore always a scannable one.

Run by hand while pairing only -- it is not a service.
"""

import os
import sys
from html import escape
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

# The log lives in the BRIDGE's store, not next to this script. Resolving it
# as __file__/store/bridge.log pointed at /run/current-system/sw/bin/store/
# (installed) and ~/nixos-config/scripts/whatsapp/store/ (source) -- neither
# of which exists -- so the page always said "No QR in store/bridge.log yet"
# and --print said the same. That is why the web pairing page never worked.
# Same resolution wa-send uses, so the two cannot disagree.
BRIDGE = Path(
    os.environ.get(
        "WA_BRIDGE_DIR",
        str(Path.home() / "projects/whatsapp-mcp/whatsapp-bridge"),
    )
)
LOG = BRIDGE / "store" / "bridge.log"
# The Tailscale IP, not 0.0.0.0: binding the LAN-wide address would make the
# pairing code readable from the house wifi as well, and this code links a
# device to his WhatsApp account. Pinning the tailnet address keeps it off the
# LAN entirely -- the port only ever answers on tailscale0.
HOST, PORT = "100.88.29.31", 8877
# Half-block glyphs -- one cell is one QR module, so the cell must stay square
# or the camera cannot lock on. font-size == line-height is what keeps it so.
PAGE = """<!doctype html>
<meta charset="utf-8">
<meta http-equiv="refresh" content="1">
<title>WhatsApp QR</title>
<style>
 body{{background:#0b0e11;color:#8b949e;margin:0;display:flex;align-items:center;
 justify-content:center;min-height:100vh;font:14px/1.5 system-ui}}
 main{{text-align:center}}
 pre{{font-size:{fs}px;line-height:{lh}px;background:#fff;color:#000;
 padding:16px;border-radius:12px;display:inline-block;margin:.6em 0}}
 .stale{{color:#d29922}}
</style>
<main>
 <pre>{qr}</pre>
 <div>{status}</div>
</main>"""


def newest_qr() -> str:
    """Pull the last QR block out of the log.

    The code is always the run of half-block lines immediately above the
    "Waiting for QR code scan" marker, so we walk backwards from the newest
    marker and keep lines that still look like QR pixels.
    """
    try:
        lines = LOG.read_text(errors="replace").splitlines()
    except OSError:
        return ""
    markers = [i for i, ln in enumerate(lines) if "Waiting for QR code scan" in ln]
    if not markers:
        return ""
    end = markers[-1]
    # Spaces are light modules inside a row, so they must stay legal -- only a
    # row that is empty after stripping counts as the end of the block.
    row = set("█▀▄ ")
    block = []
    for ln in reversed(lines[:end]):
        stripped = ln.rstrip()
        if stripped and set(stripped) <= row:
            block.insert(0, stripped)
        elif block:
            break  # blank line or log text: end of this QR generation
    return "\n".join(block)


def stale() -> bool:
    try:
        return LOG.stat().st_mtime < __import__("time").time() - 45
    except OSError:
        return True


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):  # noqa: N802 - stdlib naming
        if self.path not in ("/", "/qr.png", "/favicon.ico"):
            self.send_error(404)
            return
        if self.path == "/favicon.ico":
            self.send_error(204)
            return
        qr = newest_qr()
        if not qr:
            body = "<!doctype html><meta charset=utf-8><body style='background:#0b0e11;color:#8b949e;display:grid;place-items:center;height:100vh'><p>No QR in the log yet.<br>Is <code>whatsapp-bridge</code> running and unpaired?</p>"
        else:
            rows = len(qr.splitlines())
            width = max((len(r) for r in qr.splitlines()), default=1)
            # Scale so the code is phone-scannable on any screen, never so big
            # that it overflows and forces the browser to resample it.
            fs = max(2, min(18, int(560 / width)))
            status = "Waiting for scan&hellip; this code expires in ~20s."
            if stale():
                status = "<span class='stale'>The bridge log has gone quiet -- "
                status += "the code may be dead. Check the unit.</span>"
            body = PAGE.format(qr=escape(qr), fs=fs, lh=fs, status=status, rows=rows)
        payload = body.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *_):
        pass  # pairing is one-shot; a request log only adds noise


def print_qr() -> int:
    """Dump the current code to the terminal -- for SSH, where there is no
    browser to open :8877 on. Same extraction the page uses, so the two never
    disagree."""
    qr = newest_qr()
    if not qr:
        print("No QR in store/bridge.log yet -- is whatsapp-bridge up and unpaired?")
        return 1
    print(qr)
    if stale():
        print("\n! log is quiet -- this code may already be dead; restart the unit")
    else:
        print("\nScan with WhatsApp > Linked devices. Expires in ~20s, rerun to refresh.")
    return 0


if __name__ == "__main__":
    if "--print" in sys.argv:
        raise SystemExit(print_qr())
    print(f"QR on http://{HOST}:{PORT}/  (Ctrl-C to stop)")
    HTTPServer((HOST, PORT), Handler).serve_forever()
