#!/usr/bin/env python3
"""Write the browser build's manifest.json from tools/web/files.txt.

    python3 tools/web/manifest.py --out zig-out/web/manifest.json [--soundfont SF2]

The page (web/noite.js) downloads every entry of `files` before the game
starts and serves the game's opens from them by `keys`:

    {"version": "<hash>",            # changes with the files
     "total": <bytes>,
     "files": [{"url": "assets/FASE1/X.BMP", "size": 1234}, ...],
     "keys": {"fase1/x.bmp": 0, ...}}  # DOS path, lower case, `/` -> files[i]

tools/web/stamp.py then adds each file's content `hash` (the page fetches
and caches it as `url?h=<hash>`) and recomputes `version` from them.

Identical files are downloaded once: a key whose content equals another
listed file's points at that file, and an `HD/` clip that is a copy of
`PAN/AVI/<name>` is fetched from there (the HD tree is a duplicate). The
SoundFont is `soundfont/<basename>` with key `soundfont.sf2`
(`$NOITE_SOUNDFONT` by default; tools/web/build-site.sh copies it there).
"""

import argparse
import hashlib
import json
import os
import pathlib
from urllib.parse import quote

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
ASSETS = ROOT / "assets"
FILES = ROOT / "tools" / "web" / "files.txt"


def digest(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--soundfont", default=os.environ.get("NOITE_SOUNDFONT"))
    args = ap.parse_args()

    rels = [line.strip() for line in FILES.read_text().splitlines() if line.strip()]
    by_hash = {}  # content -> canonical relative path
    source = {}  # listed path -> path its bytes are fetched from
    hashes = {rel: digest(ASSETS / rel) for rel in rels}
    # Non-HD files first, so they become the canonical copies.
    for rel in sorted(rels, key=lambda r: r.upper().startswith("HD/")):
        h = hashes[rel]
        if h not in by_hash and rel.upper().startswith("HD/"):
            twin = ASSETS / "PAN" / "AVI" / rel.split("/", 1)[1]
            if twin.is_file() and digest(twin) == h:
                by_hash[h] = twin.relative_to(ASSETS).as_posix()
        by_hash.setdefault(h, rel)
        source[rel] = by_hash[h]

    files, index, keys = [], {}, {}
    for rel in rels:
        src = source[rel]
        if src not in index:
            index[src] = len(files)
            files.append({"url": "assets/" + quote(src), "size": (ASSETS / src).stat().st_size})
        keys[rel.lower()] = index[src]
    if args.soundfont:
        sf2 = pathlib.Path(args.soundfont)
        keys["soundfont.sf2"] = len(files)
        files.append({"url": "soundfont/" + quote(sf2.name), "size": sf2.stat().st_size})

    version = hashlib.sha256("".join(f"{f['url']} {f['size']}\n" for f in files).encode()).hexdigest()[:16]
    manifest = {"version": version, "total": sum(f["size"] for f in files), "files": files, "keys": keys}
    pathlib.Path(args.out).write_text(json.dumps(manifest, separators=(",", ":")))


if __name__ == "__main__":
    main()
