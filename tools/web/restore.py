#!/usr/bin/env python3
"""Restore a snapshot of the web game ("Estado completo") in headless Chromium.

    nix develop .#web -c python3 tools/web/restore.py SNAPSHOT.noitesnap \\
        [--site DIR | --url URL | --ssh HOST] [--ms MS] [--input FILE] \\
        [--report FILE|-] [--dump-every MS] [--out DIR] [--headed]

A snapshot (web/noite.js, docs/WEB.md) is the wasm's whole memory plus a
JSON header naming the build it came from: the release id (the server's
releases/<id>), the commit and the wasm's content hash. It can only be
restored into that same noite.wasm, so the tool first finds a page that
runs it, in this order:

- `--site DIR`, a built site (tools/web/build-site.sh), if its wasm hash
  matches (else it stops: rebuild the snapshot's commit);
- zig-out/site, if it matches;
- without `--ssh`, the live site (`--url`, default
  https://cassetaeplaneta.canassa.com/), if its current release is the
  snapshot's (its files stay in zig-out/restore/profile, Chromium's Cache
  Storage, between runs). Only `current` is served, and a `?h=` URL with
  another hash gets the current file, so an older release can't be
  fetched from there;
- `--ssh HOST` (the deploy target of tools/deploy-web.sh): the
  release's index.html, noite.js, noite.wasm and manifest.json are copied
  from /var/www/cassetaeplaneta/releases/<id>/ into zig-out/restore/<id>/,
  next to the disc files of a local site (`--assets-site`, default
  zig-out/site; the disc never changes).

A local site is served on a random port. The page is opened with
`?snapshot`, the snapshot goes to its file picker and the game runs on
for `--ms` milliseconds of game time (default 3000), or to the end of an
`--input` script if that is later. The script is the harness's format
(src/platform/script.zig), times counted from the restore (game time:
the page's clock, so not deterministic as the headless harness is), with
the commands move, click, rclick, ldown, lup, rdown, rup, key, hold, dump
[NAME], report FILE, snapshot FILE (the page's own "Estado completo"),
wait SCENE [MS], expect SCENE, state, log, quit; input goes through the
page as real mouse and key events (points below the client area, y > 458,
go to its last row). Frames: `dump`
lines and `--dump-every MS` write the canvas as PNG (638x459) to --out
(default zig-out/restore/out). `--report FILE` writes the page's report
(the Relatório JSON) at the end; `-` prints its game state to stdout.
Exits non-zero on a page error, a failed `expect` or `wait`.
"""

import argparse
import base64
import gzip
import hashlib
import http.server
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import threading
import time
import urllib.request
from urllib.parse import urlsplit

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
MAGIC = b"NOITESNAP1\n"
LIVE = "https://cassetaeplaneta.canassa.com/"
REMOTE_BASE = "/var/www/cassetaeplaneta/releases"


def read_header(path):
    """The snapshot's JSON header (the file is gzip, or already inflated)."""
    raw = path.read_bytes()[:2]
    opener = gzip.open if raw == b"\x1f\x8b" else open
    with opener(path, "rb") as f:
        if f.read(len(MAGIC)) != MAGIC:
            sys.exit(f"{path}: not a Noite Animal snapshot")
        n = int.from_bytes(f.read(4), "little")
        return json.loads(f.read(n))


def short_hash(data):
    return hashlib.sha256(data).hexdigest()[:16]


def site_build(site):
    wasm = site / "noite.wasm"
    return short_hash(wasm.read_bytes()) if wasm.exists() else None


def live_build(url):
    try:
        html = urllib.request.urlopen(url, timeout=20).read().decode()
    except OSError as e:
        print(f"  {url}: {e}")
        return None
    m = re.search(r'data-wasm="noite\.wasm\?h=([0-9a-f]+)"', html)
    return m and m.group(1)


def from_ssh(host, release, assets_site, dst):
    """The release's page files from the server, beside a local site's disc files."""
    if not (assets_site / "manifest.json").exists():
        sys.exit(f"{assets_site}: no built site for the disc files (tools/web/build-site.sh)")
    shutil.rmtree(dst, ignore_errors=True)
    dst.mkdir(parents=True)
    for name in ("assets", "soundfont"):
        os.symlink(assets_site.resolve() / name, dst / name)
    files = [f"{host}:{REMOTE_BASE}/{release}/{n}" for n in ("index.html", "noite.js", "noite.wasm", "manifest.json")]
    subprocess.run(["scp", "-q", *files, str(dst)], check=True)
    return dst


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm"}
    site = None

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(Handler.site), **kwargs)

    def end_headers(self):
        hashed = "h=" in urlsplit(self.path).query
        self.send_header("Cache-Control", "public, max-age=31536000, immutable" if hashed else "no-cache")
        super().end_headers()

    def log_message(self, *args):
        pass


def find_page(args, header):
    """The URL of a page that runs the snapshot's wasm (serving a local site if needed)."""
    build, release = header["build"], header["release"]
    candidates = [pathlib.Path(args.site)] if args.site else [ROOT / "zig-out" / "site"]
    for site in candidates:
        got = site_build(site)
        if got == build:
            print(f"  using {site} (wasm {build})")
            return serve(site)
        print(f"  {site}: wasm {got}, not {build}")
        if args.site:
            sys.exit(f"build the snapshot's commit {header.get('commit') or '?'} into a site and pass it with --site")
    if not args.ssh:
        got = live_build(args.url)
        if got == build:
            print(f"  using the live site {args.url} (release {release})")
            return args.url
        print(f"  {args.url}: wasm {got}, not {build}")
        sys.exit(f"release {release} is not the live one: pass --ssh HOST to copy it from the server's"
                 f" {REMOTE_BASE}/{release}/, or --site DIR with a build of commit {header.get('commit') or '?'}")
    dst = from_ssh(args.ssh, release, pathlib.Path(args.assets_site), ROOT / "zig-out" / "restore" / release)
    got = site_build(dst)
    if got != build:
        sys.exit(f"{dst}: wasm {got}, not the snapshot's {build}")
    print(f"  using release {release} from {args.ssh} (wasm {build})")
    return serve(dst)


def serve(site):
    Handler.site = site
    httpd = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return f"http://127.0.0.1:{httpd.server_address[1]}/"


KEYS = {"left": "ArrowLeft", "right": "ArrowRight", "up": "ArrowUp", "down": "ArrowDown",
        "return": "Enter", "enter": "Enter", "escape": "Escape", "space": "Space",
        "37": "ArrowLeft", "38": "ArrowUp", "39": "ArrowRight", "40": "ArrowDown",
        "13": "Enter", "27": "Escape", "32": "Space"}


def parse_script(text):
    """[(at_ms, cmd, args)] in time order (a click's release 50 ms on)."""
    steps, t = [], 0
    for no, raw in enumerate(text.splitlines(), 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        words = line.split()
        if len(words) < 2:
            sys.exit(f"script line {no}: missing command")
        t = t + int(words[0][1:]) if words[0].startswith("+") else int(words[0])
        cmd, rest = words[1], words[2:]
        if cmd in ("click", "rclick"):
            button = "right" if cmd == "rclick" else "left"
            x, y = int(rest[0]), int(rest[1])
            steps += [(t, "move", (x, y)), (t, "down", (button,)), (t + 50, "up", (button,))]
        elif cmd in ("ldown", "lup", "rdown", "rup"):
            x, y = int(rest[0]), int(rest[1])
            steps += [(t, "move", (x, y)), (t, cmd[1:], ("right" if cmd[0] == "r" else "left",))]
        elif cmd == "move":
            steps.append((t, "move", (int(rest[0]), int(rest[1]))))
        elif cmd in ("key", "hold"):
            key = KEYS.get(rest[0].lower())
            if not key:
                sys.exit(f"script line {no}: key {rest[0]} does not reach the page")
            ms = int(rest[1]) if cmd == "hold" else 50
            steps += [(t, "keydown", (key,)), (t + ms, "keyup", (key,))]
        elif cmd == "wait":
            steps.append((t, "wait", (rest[0], int(rest[1]) if len(rest) > 1 else 120_000)))
        elif cmd in ("dump", "report", "snapshot", "expect", "state", "log", "quit"):
            steps.append((t, cmd, (" ".join(rest),)))
        else:
            sys.exit(f"script line {no}: {cmd} is not supported here")
    return sorted(steps, key=lambda s: s[0])


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("snapshot")
    ap.add_argument("--site", help="a built site whose noite.wasm is the snapshot's")
    ap.add_argument("--url", default=LIVE, help="the live site (used if its release is the snapshot's)")
    ap.add_argument("--ssh", help="copy the release from this host's " + REMOTE_BASE)
    ap.add_argument("--assets-site", default=str(ROOT / "zig-out" / "site"), help="disc files for --ssh")
    ap.add_argument("--ms", type=int, default=3000, help="game time to run after the restore (at least)")
    ap.add_argument("--input", help="a script (src/platform/script.zig format, times from the restore)")
    ap.add_argument("--report", help="write the report JSON here at the end (- prints the game state)")
    ap.add_argument("--dump-every", type=int, default=0, help="write a frame every MS of game time")
    ap.add_argument("--out", default=str(ROOT / "zig-out" / "restore" / "out"))
    ap.add_argument("--headed", action="store_true")
    args = ap.parse_args()
    snap = pathlib.Path(args.snapshot)
    header = read_header(snap)
    state = (header.get("report") or {}).get("state") or {}
    print(f"snapshot: release {header['release']} commit {header.get('commit') or '?'} wasm {header['build']},"
          f" {header['memory'] / 1e6:.1f} MB of memory, ticks {header['ticks']},"
          f" {header['prefs']['version']}{' one-button' if header['prefs'].get('oneButton') else ''}")
    if state:
        inv = ", ".join(f"{i['id']} {i['name']}" for i in state.get("inventory", []))
        print(f"  scene {(state.get('scene') or {}).get('name')} lives {state.get('lives')}"
              f" score {state.get('score')} inventory [{inv}]")
    url = find_page(args, header)
    steps = parse_script(pathlib.Path(args.input).read_text()) if args.input else []
    out = pathlib.Path(args.out)
    if steps or args.dump_every:
        out.mkdir(parents=True, exist_ok=True)

    from playwright.sync_api import sync_playwright

    failed = False
    with sync_playwright() as pw:
        env = {k: v for k, v in os.environ.items() if k != "LD_LIBRARY_PATH"}
        profile = ROOT / "zig-out" / "restore" / "profile"
        ctx = pw.chromium.launch_persistent_context(str(profile), headless=not args.headed, env=env,
                                                    viewport={"width": 1276, "height": 960}, accept_downloads=True)
        page = ctx.new_page()
        errors = []
        page.on("pageerror", lambda e: errors.append(str(e)))
        page.on("console", lambda m: print(f"  console.{m.type}: {m.text}") if m.type in ("error", "warning") else None)
        page.goto(url + "?snapshot")
        page.wait_for_function("window.noite.ready || window.noite.failure", timeout=900_000)
        page.set_input_files("#snapfile", str(snap))
        page.wait_for_function("window.noite.restored || window.noite.failure", timeout=120_000)
        if page.evaluate("window.noite.failure"):
            sys.exit("restore failed: " + page.evaluate("window.noite.failure"))
        base = page.evaluate("window.noite.ticks")
        print(f"restored at ticks {base}, scene {page.evaluate('window.noite.scene')}")

        def now():
            return page.evaluate("window.noite.ticks") - base

        def at(x, y):
            """Client pixels to the page; the scripts' points below the client
            area (tools/play/*.input open the panel at y 465) go to its last row."""
            x, y = min(x, 637), min(y, 458)
            box = page.locator("#screen").bounding_box()
            return box["x"] + (x + 0.5) * box["width"] / 638, box["y"] + (y + 0.5) * box["height"] / 459

        def dump(name):
            png = page.evaluate("document.getElementById('screen').toDataURL('image/png')")
            path = out / f"{name}.png"
            path.write_bytes(base64.b64decode(png.split(",", 1)[1]))
            print(f"[{now()}] dump {path}")

        def write_report(dest):
            r = page.evaluate("window.noite.report()")
            if dest == "-":
                print(json.dumps(r["state"], indent=1))
            else:
                pathlib.Path(dest).write_text(json.dumps(r, indent=1))
                print(f"[{now()}] report {dest}")

        end = max([s[0] for s in steps] + [args.ms])
        next_dump, shift, i, frame = 0, 0, 0, 0
        while True:
            t = now()
            if errors:
                print("page error: " + "; ".join(errors))
                failed = True
                break
            if args.dump_every and t >= next_dump:
                dump(f"frame{frame:05d}")
                frame += 1
                next_dump += args.dump_every
            while i < len(steps) and steps[i][0] + shift <= t:
                st, cmd, a = steps[i]
                i += 1
                if cmd == "move":
                    page.mouse.move(*at(*a))
                elif cmd == "down":
                    page.mouse.down(button=a[0])
                elif cmd == "up":
                    page.mouse.up(button=a[0])
                elif cmd == "keydown":
                    page.keyboard.down(a[0])
                elif cmd == "keyup":
                    page.keyboard.up(a[0])
                elif cmd == "dump":
                    dump(a[0] or f"dump{t:08d}")
                elif cmd == "report":
                    write_report(a[0])
                elif cmd == "snapshot":
                    page.click("#morebtn")
                    with page.expect_download(timeout=120_000) as d:
                        page.click("#snapbtn")
                    d.value.save_as(a[0])
                    print(f"[{now()}] snapshot {a[0]} ({pathlib.Path(a[0]).stat().st_size / 1e6:.1f} MB)")
                elif cmd == "log":
                    print(f"[{t}] log: {a[0]}")
                elif cmd == "state":
                    s = page.evaluate("window.noite.report().state")
                    inv = [x["id"] for x in s.get("inventory", [])]
                    print(f"[{t}] state: scene {(s.get('scene') or {}).get('name')} player"
                          f" {s.get('player')} inv {inv} lives {s['lives']} score {s['score']}")
                elif cmd == "expect":
                    sc = page.evaluate("window.noite.scene")
                    ok = sc.lower() == a[0].lower()
                    print(f"[{t}] expect {a[0]}: {'ok' if ok else 'FAILED, the scene is ' + sc}")
                    failed |= not ok
                elif cmd == "wait":
                    deadline = time.time() + a[1] / 1000
                    while page.evaluate("window.noite.scene").lower() != a[0].lower():
                        if time.time() > deadline:
                            print(f"[{now()}] wait {a[0]}: timed out")
                            failed = True
                            break
                        time.sleep(0.05)
                    shift += max(0, now() - (st + shift))
                elif cmd == "quit":
                    i = len(steps)
                    end = t
            if failed or (t >= end + shift and i >= len(steps)):
                break
            time.sleep(0.01)
        if args.report:
            write_report(args.report)
        if errors and not failed:
            print("page error: " + "; ".join(errors))
            failed = True
        ctx.close()
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
