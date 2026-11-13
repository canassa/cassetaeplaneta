#!/usr/bin/env python3
"""Browser test of the web build: headless Chromium through Playwright.

    nix develop -c tools/web/build-site.sh
    nix develop .#web -c python3 tools/web/test.py [--site zig-out/site | --url https://…] [--out zig-out/web-test]

Serves the site on a local port (with nginx's Cache-Control: immutable
for `?h=` URLs, no-cache otherwise) and checks, with screenshots of the
canvas in --out: index.html loads a hashed noite.js; a cache of a loader
before the hashes is migrated (files whose content matches the manifest's
hash are reused, a corrupted one is not) and dropped; the loader
downloads every file, each by its hashed URL; no AudioContext before a user
gesture; the Original version with video skipping (the defaults) starts
from the Jogar button with a running AudioContext and reaches the wasm as
such; a click 3 s into the 22 s opening video skips it to the title
screen (title.png); JOGAR then NOVO JOGO start a new game whose opening
video Esc skips to the bedroom, 1fquarbo (bedroom.png); a right click on
desk drawer 3 opens 1fgvboy3 (drawer.png), as in tools/play/full.input.
At 1280×960, 1920×1080, two phone sizes and an exact 2× (no letterbox)
the canvas fills the window in one dimension, keeps its aspect ratio, is
centred, and the tool buttons stay in the window and off the game unless
the letterbox has no room for them (window-WxH.png). Then the version
button reloads into the Corrigida version: the loader shows it chosen, the load comes from Cache Storage (cache.png) and is quicker,
and the wasm has every fix on. Last, a simulated deploy (a copy of the
site with noite.js and one disc file changed, restamped by
tools/web/stamp.py, served at the same origin): the reload downloads
only that file, runs the new noite.js and drops the stale cache entry.
Exits non-zero on the first failed check or on a page error.
"""

import argparse
import http.server
import json
import os
import pathlib
import re
import shutil
import sys
import threading
import time
from urllib.parse import unquote, urlsplit

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "tools" / "web"))
from stamp import stamp  # noqa: E402


class Handler(http.server.SimpleHTTPRequestHandler):
    """The site in `Handler.site` (a deploy swaps it), with the headers of
    docs/WEB.md; every request path is logged in `Handler.requests`."""

    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm"}
    site = None
    requests = []

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(Handler.site), **kwargs)

    def do_GET(self):
        Handler.requests.append(self.path)
        super().do_GET()

    def end_headers(self):
        hashed = "h" in dict(q.split("=", 1) for q in urlsplit(self.path).query.split("&") if "=" in q)
        self.send_header("Cache-Control", "public, max-age=31536000, immutable" if hashed else "no-cache")
        super().end_headers()

    def log_message(self, *args):
        pass


def serve(site):
    Handler.site = site
    httpd = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd


def deploy_copy(site, dst, changed_url):
    """A copy of `site` (hard links) with noite.js and `changed_url` edited
    and the hashes restamped: a deploy of a new build."""
    shutil.rmtree(dst, ignore_errors=True)
    shutil.copytree(site, dst, copy_function=os.link)
    js = dst / "noite.js"
    text = js.read_text()
    js.unlink()  # break the hard link before writing
    js.write_text(text + "\nwindow.noiteDeployTest = true;\n")
    f = dst / unquote(changed_url)
    data = bytearray(f.read_bytes())
    f.unlink()
    data[-1] ^= 0xFF
    f.write_bytes(bytes(data))
    stamp(dst)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--site", default=str(ROOT / "zig-out" / "site"))
    ap.add_argument("--out", default=str(ROOT / "zig-out" / "web-test"))
    ap.add_argument("--headed", action="store_true")
    ap.add_argument("--url", help="test a deployed site instead of serving --site")
    args = ap.parse_args()
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    site = pathlib.Path(args.site)
    if args.url:
        url = args.url.rstrip("/") + "/"
    else:
        httpd = serve(site)
        url = f"http://127.0.0.1:{httpd.server_address[1]}/"
    errors = []

    def check(ok, what):
        print(("ok    " if ok else "FAIL  ") + what, flush=True)
        if not ok:
            sys.exit(1)

    with sync_playwright() as pw:
        # A host LD_LIBRARY_PATH (other nixpkgs libraries) breaks the
        # browser from the web shell.
        env = {k: v for k, v in os.environ.items() if k != "LD_LIBRARY_PATH"}
        browser = pw.chromium.launch(headless=not args.headed, env=env)
        # One context for both loads, so the second one sees the cache.
        ctx = browser.new_context(viewport={"width": 1280, "height": 960})
        page = ctx.new_page()
        page.on("pageerror", lambda e: errors.append(str(e)))
        page.on("console", lambda m: print(f"  console.{m.type}: {m.text}") if m.type in ("error", "warning") else None)

        def scene():
            return page.evaluate("window.noite.scene")

        def wait_scene(name, timeout_s):
            end = time.time() + timeout_s
            while time.time() < end:
                if scene() == name:
                    return True
                if errors:
                    check(False, "page error: " + "; ".join(errors))
                time.sleep(0.25)
            return False

        def at(x, y):
            box = page.locator("#screen").bounding_box()
            return box["x"] + (x + 0.5) * box["width"] / 638, box["y"] + (y + 0.5) * box["height"] / 459

        def click(x, y, button="left"):
            page.mouse.move(*at(x, y))
            time.sleep(0.05)
            page.mouse.down(button=button)
            time.sleep(0.05)
            page.mouse.up(button=button)

        def shot(name):
            page.locator("#screen").screenshot(path=str(out / name))

        def check_fit(vw, vh):
            page.set_viewport_size({"width": vw, "height": vh})
            time.sleep(0.5)
            box = page.locator("#screen").bounding_box()
            tools = page.locator("#tools").bounding_box()
            overlay = page.evaluate("document.getElementById('tools').classList.contains('overlay')")
            page.screenshot(path=str(out / f"window-{vw}x{vh}.png"))
            what = f"{vw}x{vh}: canvas {box['width']:.1f}x{box['height']:.1f} at {box['x']:.1f},{box['y']:.1f}"
            check(abs(box["width"] - vw) <= 1 or abs(box["height"] - vh) <= 1, f"{what} fills the window")
            check(abs(box["width"] / box["height"] - 638 / 459) < 0.005, f"{vw}x{vh}: aspect ratio kept")
            check(abs(box["x"] * 2 + box["width"] - vw) <= 1 and abs(box["y"] * 2 + box["height"] - vh) <= 1,
                  f"{vw}x{vh}: centred")
            inside = tools["x"] >= 0 and tools["y"] >= 0 and tools["x"] + tools["width"] <= vw \
                and tools["y"] + tools["height"] <= vh
            apart = (tools["x"] >= box["x"] + box["width"] or tools["x"] + tools["width"] <= box["x"]
                     or tools["y"] >= box["y"] + box["height"] or tools["y"] + tools["height"] <= box["y"])
            room = max(vw - box["width"], vh - box["height"]) / 2
            check(inside and (apart or (overlay and room < tools["height"])),
                  f"{vw}x{vh}: tools {'over the game' if overlay else 'in the letterbox'}"
                  f" ({tools['width']:.0f}x{tools['height']:.0f} at {tools['x']:.0f},{tools['y']:.0f})")

        def load():
            t0 = time.time()
            page.wait_for_function("window.noite.ready || window.noite.failure", timeout=600_000)
            check(not page.evaluate("window.noite.failure"), "the page loads every file")
            return time.time() - t0

        def play():
            page.click("#play")
            page.wait_for_function("window.noite.started || window.noite.failure", timeout=60_000)
            check(not page.evaluate("window.noite.failure"), "Jogar starts the game")

        def manifest():
            return page.evaluate("""async () => {
                const html = await (await fetch("./", { cache: "no-cache" })).text();
                const src = html.match(/data-manifest="([^"]+)"/)[1];
                return await (await fetch(src)).json();
            }""")

        def wait_pruned():
            page.wait_for_function("window.noite.pruned", timeout=60_000)
            return page.evaluate("""async () => ({
                names: await caches.keys(),
                urls: (await (await caches.open('noite.files')).keys()).map((r) => r.url),
            })""")

        # A returning player's cache from before the hashes: "noite-<version>",
        # keyed by the plain URLs. Two good files and a corrupted one.
        page.goto(url + "seed.html")  # a 404 page of the same origin: no loader
        files = manifest()["files"]
        seeded = [files[0]["url"], files[1]["url"], files[2]["url"]]
        page.evaluate("""async (urls) => {
            const c = await caches.open("noite-0123456789abcdef");
            for (const [i, u] of urls.entries()) {
                const body = new Uint8Array(await (await fetch(u)).arrayBuffer());
                if (i === 2) body[0] ^= 0xff;
                await c.put(u, new Response(body));
            }
        }""", seeded)
        Handler.requests.clear()
        page.goto(url)
        first_load = load()
        print(f"      first load {first_load:.1f} s")
        html = page.evaluate("document.documentElement.outerHTML")
        check(re.search(r'<script src="noite\.js\?h=[0-9a-f]{16}" data-wasm="noite\.wasm\?h=[0-9a-f]{16}"'
                        r' data-manifest="manifest\.json\?h=[0-9a-f]{16}">', html) is not None,
              "index.html loads noite.js, the wasm and the manifest by hash")
        if not args.url:
            plain = [r for r in Handler.requests if r not in ("/", "/favicon.ico") and "?h=" not in r]
            check(not plain, f"every request but the page's carries ?h= ({plain[:3]})")
            got = {urlsplit(r).path for r in Handler.requests}
            check(not any(("/" + u) in got for u in seeded[:2]) and ("/" + seeded[2]) in got,
                  "the old cache's good files are migrated, the corrupted one downloaded")
        stats = page.evaluate("window.noite.loadStats")
        check(stats["migrated"] == 2, f"two files migrated from the old cache ({stats})")
        caches_now = wait_pruned()
        check(caches_now["names"] == ["noite.files"] and len(caches_now["urls"]) == len(files),
              f"the old cache is dropped, the new one holds the manifest's files"
              f" ({caches_now['names']}, {len(caches_now['urls'])} of {len(files)})")
        check(page.evaluate("window.noite.audioState") == "none", "no AudioContext before a user gesture")
        check(page.is_checked('input[name="versao"][value="original"]') and page.is_checked("#skip"),
              "the loader offers Original with video skipping by default")
        play()
        check(page.evaluate("window.noite.audioState") == "running", "AudioContext running after Jogar")
        check(page.evaluate("[window.noite.fixes, window.noite.skipVideos]") == [False, True],
              "the wasm runs the Original version with video skipping")
        # The opening video (abert) runs 22 s; a click skips it to the title.
        check(wait_scene("abert", 10), "the opening video plays (abert)")
        time.sleep(3)
        t0 = time.time()
        click(320, 240)
        check(wait_scene("fundinic", 3), f"a click skips the opening video to the title ({time.time() - t0:.1f} s)")
        time.sleep(1.5)
        shot("title.png")
        check(not errors, "title screen, no page errors")
        click(290, 345)  # JOGAR
        time.sleep(2)
        click(370, 412)  # NOVO JOGO
        check(wait_scene("abertura", 20), "a new game starts its opening video (abertura)")
        time.sleep(2)
        page.keyboard.press("Escape")
        check(wait_scene("1fquarbo", 5), "Esc skips it to the bedroom (1fquarbo)")
        time.sleep(2)
        shot("bedroom.png")
        peak = page.evaluate("window.noite.audioPeak")
        check(peak > 1000, f"sound reaches WebAudio (peak sample {peak})")
        fs = page.evaluate("window.noite.frameStats")
        print(f"      {fs['frames']} frames, {fs['avgMs']:.2f} ms per game turn on average, worst {fs['worstMs']:.0f} ms")
        for vw, vh in ((1920, 1080), (390, 844), (844, 390), (1276, 918), (1280, 960)):
            check_fit(vw, vh)
        click(287, 275, "right")  # desk drawer 3
        check(wait_scene("1fgvboy3", 40), "a right click on the desk drawer opens it (1fgvboy3)")
        time.sleep(1.5)
        shot("drawer.png")

        # The version button reloads into the other version (after a confirm).
        page.once("dialog", lambda d: d.accept())
        page.click("#switch")
        page.wait_for_load_state()
        again = load()
        print(f"      second load {again:.1f} s")
        check(page.is_checked('input[name="versao"][value="corrigida"]'), "the loader comes back with Corrigida chosen")
        play()
        check(page.evaluate("[window.noite.fixes, window.noite.skipVideos]") == [True, True],
              "the wasm runs the Corrigida version (every fix on)")
        time.sleep(3)
        shot("cache.png")
        stats = page.evaluate("window.noite.loadStats")
        check(stats["fromCache"] == stats["files"], f"the second load comes from the cache ({stats})")
        check(page.evaluate("JSON.parse(localStorage.getItem('noite:prefs')).version") == "corrigida",
              "the choice is remembered")
        check(not errors, "no page errors")

        if not args.url:
            # A deploy: noite.js and one disc file change; the rest keeps its hash.
            changed = next(f for f in reversed(files) if f["url"].startswith("assets/") and f["url"].endswith(".BMP"))
            new_site = out / "site-deploy"
            before = {name: (site / name).read_bytes() for name in ("index.html", "manifest.json", "noite.js")}
            deploy_copy(site, new_site, changed["url"])
            check(all((site / k).read_bytes() == v for k, v in before.items()),
                  "the deploy copy leaves the built site alone")
            Handler.site = new_site
            Handler.requests.clear()
            page.goto(url)
            load()
            stats = page.evaluate("window.noite.loadStats")
            fetched = sorted(r for r in Handler.requests if r.startswith(("/assets/", "/soundfont/")))
            new_hash = next(f["hash"] for f in json.loads((new_site / "manifest.json").read_text())["files"]
                            if f["url"] == changed["url"])
            check(fetched == [f"/{changed['url']}?h={new_hash}"] and stats["downloaded"] == 1
                  and stats["fromCache"] == len(files) - 1,
                  f"after a deploy only the changed file is downloaded ({fetched}, {stats})")
            check(page.evaluate("window.noiteDeployTest === true"), "the page runs the new noite.js")
            caches_now = wait_pruned()
            stale = [u for u in caches_now["urls"] if changed["url"] in u and new_hash not in u]
            check(len(caches_now["urls"]) == len(files) and not stale,
                  f"the stale cache entry is dropped ({len(caches_now['urls'])} entries, stale {stale})")
            play()
            check(wait_scene("abert", 10), "the new build starts (abert)")
            check(not errors, "no page errors after the deploy")
            shutil.rmtree(new_site)
        browser.close()
    if not args.url:
        httpd.shutdown()
    print(f"screenshots in {out}")


if __name__ == "__main__":
    main()
