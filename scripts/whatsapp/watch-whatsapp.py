#!/usr/bin/env python3
"""One-shot WhatsApp watcher: poll messages.db, print new in-scope rows, exit.

    watch-whatsapp.py [cap_seconds]      # default 1800

Every behaviour here is a scar, not a preference:

* scope is the SAME closed list as replies -- 11 chats. His words 2026-10-03:
  "also dont watch others" / "keep watching and replaying to the 10 only".
* a persistent rowid cursor, so re-arms continue exactly where the last
  stopped -- no dupes, and no gap that swallows an instruction between two
  arms (that gap ate "Are u here" once).
* it refuses to arm while the stop flag exists (exit 3) and disarms if the
  flag appears mid-run. "Stop" means stop, including for the thing that
  would otherwise re-arm itself.
* own sends are skipped by matching wa-sent-texts, NOT by is_from_me: the
  self-chat is the instruction channel and every message he types there is
  is_from_me=1, so that filter blinds the one channel that can instruct us.
* it EXITS when something arrives -- the completion is the wake-up. A watcher
  that keeps polling never wakes anything.
* every arm writes an ARM header to wa-watch.log: a pipe into an SSH session
  loses the report with the connection, which looks identical to being
  ignored, and that is the one failure he will not forgive.
* a cap with an EXPIRED line, so a silent timeout can be told apart from
  quiet.
"""

import json
import os
import sqlite3
import sys
import time
from datetime import datetime
from pathlib import Path

HOME = Path.home()
STATE = Path(os.environ.get("WA_STATE", str(HOME / ".local/state/opencode")))
STOP = STATE / "wa-stop"
CURSOR = STATE / "wa-watch-rowid"
SENT = STATE / "wa-sent-texts"
WATCHLOG = STATE / "wa-watch.log"
BRIDGE = Path(
    os.environ.get("WA_BRIDGE_DIR", str(HOME / "projects/whatsapp-mcp/whatsapp-bridge"))
)
DB = BRIDGE / "store" / "messages.db"

# Reply scope and watch scope are one list. Anything not here is not read.
WATCH = (
    "966551052452@s.whatsapp.net",  # self-chat -- the instruction channel
    "966554611442@s.whatsapp.net",  # mum
    "966503814854@s.whatsapp.net",  # dad
    "966503814854-1552717936@g.us",  # the family group
    "966567433284@s.whatsapp.net",  # horaa
    "966505560448@s.whatsapp.net",  # zahraa
    "966506836216@s.whatsapp.net",  # kawthar
    "966508615596@s.whatsapp.net",  # abood
    "966506370279@s.whatsapp.net",  # hassan
    "966565541131@s.whatsapp.net",  # mohannad
    "966577647909@s.whatsapp.net",  # ahmed al-khalifa (decisions row 88)
)


def log(text: str) -> None:
    STATE.mkdir(parents=True, exist_ok=True)
    with open(WATCHLOG, "a", encoding="utf-8", errors="replace") as fh:
        fh.write(text + "\n")


def read_sent() -> set:
    sent = set()
    if SENT.exists():
        for line in SENT.read_text(errors="replace").splitlines():
            try:
                sent.add(json.loads(line))
            except (ValueError, TypeError):
                continue
    return sent


def read_cursor() -> int:
    if not CURSOR.exists():
        return 0
    try:
        return int(CURSOR.read_text().strip() or 0)
    except ValueError:
        return 0


def main() -> int:
    cap = int(sys.argv[1]) if len(sys.argv) > 1 else 1800

    if STOP.exists():
        # Nothing written, deliberately: a refusal that leaves a line behind
        # can be mistaken for an arm later, and the documented contract is
        # rc=3 and silence.
        print("STOP flag present -- refusing to arm")
        return 3

    STATE.mkdir(parents=True, exist_ok=True)
    cursor = read_cursor()
    sent = read_sent()
    log(f"=== ARM {datetime.now():%Y-%m-%d %H:%M:%S} cap={cap} cursor={cursor} scope={len(WATCH)}")

    placeholders = ",".join("?" for _ in WATCH)
    query = (
        "select rowid, chat_jid, sender, content, timestamp, is_from_me, media_type "
        f"from messages where rowid > ? and chat_jid in ({placeholders}) order by rowid"
    )
    deadline = time.time() + cap

    while True:
        if STOP.exists():
            log(f"STOP flag present, disarming at rowid {cursor}")
            print(f"STOP flag present, disarming at rowid {cursor}")
            return 3

        try:
            conn = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
            rows = conn.execute(query, (cursor, *WATCH)).fetchall()
            conn.close()
        except sqlite3.Error as exc:
            log(f"db error: {exc}")
            print(f"db error: {exc}")
            return 2

        hits = []
        for row in rows:
            rowid, _jid, _sender, content = row[0], row[1], row[2], row[3]
            # Advance past our own sends as well, so a reply we made can never
            # wake us a second time.
            if content and content in sent:
                cursor = rowid
                continue
            hits.append(row)
            cursor = rowid

        if hits:
            CURSOR.write_text(str(cursor))
            log(f"HITS {len(hits)}")
            for rowid, jid, sender, content, ts, is_from_me, media in hits:
                flat = (content or "").replace("\n", "\\n")[:400]
                if not flat and media:
                    flat = f"[{media}]"
                line = f"{ts} | rowid={rowid} | {jid} | {sender} | {flat}"
                log(line)
                print(line)
            return 0

        if time.time() > deadline:
            CURSOR.write_text(str(cursor))
            log("EXPIRED")
            print("EXPIRED")
            return 0

        time.sleep(4)


if __name__ == "__main__":
    sys.exit(main())
