#!/usr/bin/env python3
"""One-shot WhatsApp watcher: poll messages.db, print new in-scope rows, exit.

    watch-whatsapp.py [cap_seconds]      # default 1800

Every behaviour here is a scar, not a preference:

* scope is the SAME closed list as replies -- 9 chats. His words 2026-10-03:
  "also dont watch others" / "keep watching and replaying to the 10 only".
  2026-10-16: hassan and mohannad dropped from the list -- "never watch, never
  read, never speak". The list is one thing, so the reply half follows the
  watch half; wa-send carries the matching refusal as MUTE.
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
import re
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
# 2026-10-16: hassan and mohannad are OUT -- his words: "never watch, never
# read, never speak". Not here means their rows are never even selected.
WATCH = (
    "966551052452@s.whatsapp.net",  # self-chat -- the instruction channel
    "966554611442@s.whatsapp.net",  # mum
    "966503814854@s.whatsapp.net",  # dad
    "966503814854-1552717936@g.us",  # the family group
    "966567433284@s.whatsapp.net",  # horaa
    "966505560448@s.whatsapp.net",  # zahraa
    "966506836216@s.whatsapp.net",  # kawthar
    "966508615596@s.whatsapp.net",  # abood
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


# A hit line looks like:
#   2026-10-20 13:31:44+03:00 | rowid=114 | 966551092452@s.whatsapp.net | 966551092452 | text
# The rowid and the chat are what matter; the text is free-form and may itself
# contain a pipe, so the pattern anchors on the two fixed fields.
ROW_RE = re.compile(r"rowid=(\d+)\s*\|\s*([^|]+?)\s*\|")


def filter_answered() -> int:
    """Print the rows on stdin that are still UNANSWERED.

    The wake is queued behind a lock for as long as the previous model turn
    takes, so by the time it is DELIVERED the rows it carries may already
    have an answer -- 2026-10-20: five stale wakes in a row, every one of
    them a prompt to answer a question already answered, and every one of
    them holding the lock a real message was waiting behind. This check runs
    at delivery time, which is the only moment the question means anything.

    A row counts as answered when a LATER row in the same chat is one of our
    sends: is_from_me=1 AND its text is in wa-sent-texts. The text test is
    what separates the two in the self-chat, where his own typing also
    carries is_from_me=1 and only the sent-set tells them apart.

    Fail-open: if the DB cannot be read, every row is printed. A redundant
    wake is better than a missed message.
    """
    sent = read_sent()
    kept = []
    for raw in sys.stdin.read().splitlines():
        line = raw.strip()
        if not line:
            continue
        m = ROW_RE.search(line)
        if not m:
            kept.append(line)
            continue
        rowid, jid = int(m.group(1)), m.group(2)
        try:
            conn = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
            later = conn.execute(
                "select content from messages "
                "where chat_jid = ? and rowid > ? and is_from_me = 1",
                (jid, rowid),
            ).fetchall()
            conn.close()
        except sqlite3.Error:
            kept.append(line)
            continue
        if not any(content and content in sent for (content,) in later):
            kept.append(line)
    if kept:
        print("\n".join(kept))
    return 0


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "--filter-answered":
        return filter_answered()
    cap = int(sys.argv[1]) if len(sys.argv) > 1 else 1800

    if STOP.exists():
        # Nothing written, deliberately: a refusal that leaves a line behind
        # can be mistaken for an arm later, and the documented contract is
        # rc=3 and silence.
        print("STOP flag present -- refusing to arm")
        return 3

    STATE.mkdir(parents=True, exist_ok=True)
    cursor = read_cursor()
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

        # Re-read our sent-texts on EVERY poll, not once per arm. The arm can
        # live for the whole cap (30 min), and the snapshot taken when it
        # started does not contain a send made seconds later -- so our own
        # reply came back as a hit, woke the agent, and the answer to that
        # wake was another send, and the arm saw THAT as a hit too: a loop
        # that spends a model minute per turn on our own voice (2026-10-20
        # 12:53, the wake fired on our own "[AI] ok"). Re-reading here is
        # cheap (a small text file) and closes the race by construction.
        sent = read_sent()

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
