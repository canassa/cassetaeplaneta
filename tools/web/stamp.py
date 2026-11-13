#!/usr/bin/env python3
"""Stamp a built site with content hashes, so only index.html revalidates.

    python3 tools/web/stamp.py SITE

Run by tools/web/build-site.sh on its output (and by tools/web/test.py on
a copy, to simulate a deploy). Every file the page loads gets a short
content hash (the first 16 hex digits of its SHA-256) and is requested as
`url?h=<hash>`, which the server marks immutable (docs/WEB.md, Caching):

- manifest.json: each entry of `files` gets `hash` (and `size`, `total`
  and `version` are recomputed from the files in SITE);
- index.html: its `<script src="noite.js…">` becomes
  `<script src="noite.js?h=…" data-wasm="noite.wasm?h=…"
  data-manifest="manifest.json?h=…">`, which noite.js reads.

Idempotent: stamping a stamped site again only updates the hashes.
"""

import hashlib
import json
import pathlib
import re
import sys
from urllib.parse import unquote

SCRIPT_TAG = re.compile(r'<script src="noite\.js[^"]*"[^>]*></script>')


def short_hash(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()[:16]


def replace(path, text):
    """Writes a new file over `path` (never through a hard link to it)."""
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(text)
    tmp.replace(path)


def stamp(site):
    site = pathlib.Path(site)
    manifest_path = site / "manifest.json"
    m = json.loads(manifest_path.read_text())
    for f in m["files"]:
        path = site / unquote(f["url"])
        f["size"] = path.stat().st_size
        f["hash"] = short_hash(path)
    m["total"] = sum(f["size"] for f in m["files"])
    m["version"] = hashlib.sha256("".join(f"{f['url']} {f['hash']}\n" for f in m["files"]).encode()).hexdigest()[:16]
    replace(manifest_path, json.dumps(m, separators=(",", ":")))

    tag = (f'<script src="noite.js?h={short_hash(site / "noite.js")}"'
           f' data-wasm="noite.wasm?h={short_hash(site / "noite.wasm")}"'
           f' data-manifest="manifest.json?h={short_hash(manifest_path)}"></script>')
    index = site / "index.html"
    html, n = SCRIPT_TAG.subn(tag, index.read_text())
    if n != 1:
        sys.exit(f"{index}: expected one <script src=\"noite.js\">, found {n}")
    replace(index, html)
    return m


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    stamp(sys.argv[1])
