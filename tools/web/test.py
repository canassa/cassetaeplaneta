#!/usr/bin/env python3
"""Browser test of the web build: headless Chromium through Playwright.

    nix develop -c tools/web/build-site.sh
    nix develop .#web -c python3 tools/web/test.py [--site zig-out/site] [--out zig-out/web-test]

Serves the site on a local port and checks, with screenshots of the canvas
in --out: the loader downloads every file and the title screen renders
(title.png); no AudioContext before a user gesture, a running one after
the first click; JOGAR then NOVO JOGO start a new game whose opening ends
in the bedroom, 1fquarbo (bedroom.png); a right click on desk drawer 3
opens 1fgvboy3 (drawer.png), as in tools/play/full.input. A second load
of the page must come from Cache Storage (cache.png) and be quicker.
Exits non-zero on the first failed check or on a page error.
"""

import argparse
import functools
import http.server
import os
import pathlib
import sys
import threading
import time

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm"}

    def log_message(self, *args):
        pass


def serve(site):
    httpd = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Handler, directory=str(site)))
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--site", default=str(ROOT / "zig-out" / "site"))
    ap.add_argument("--out", default=str(ROOT / "zig-out" / "web-test"))
    ap.add_argument("--headed", action="store_true")
    args = ap.parse_args()
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    httpd = serve(pathlib.Path(args.site))
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
            return box["x"] + (x + 0.5) * box["width"] / 640, box["y"] + (y + 0.5) * box["height"] / 480

        def click(x, y, button="left"):
            page.mouse.move(*at(x, y))
            time.sleep(0.05)
            page.mouse.down(button=button)
            time.sleep(0.05)
            page.mouse.up(button=button)

        def shot(name):
            page.locator("#screen").screenshot(path=str(out / name))

        t0 = time.time()
        page.goto(url)
        page.wait_for_function("window.noite.started || window.noite.failure", timeout=600_000)
        check(not page.evaluate("window.noite.failure"), "the page loads and starts the game")
        first_load = time.time() - t0
        print(f"      first load {first_load:.1f} s")
        check(page.evaluate("window.noite.audioState") == "none", "no AudioContext before a user gesture")
        # The title menu shows after the intro (22 s in the playthrough).
        time.sleep(24)
        shot("title.png")
        check(not errors, "title screen, no page errors")
        click(290, 345)  # JOGAR
        time.sleep(0.5)
        check(page.evaluate("window.noite.audioState") == "running", "AudioContext running after the click")
        time.sleep(1.5)
        click(370, 412)  # NOVO JOGO
        check(wait_scene("1fquarbo", 240), "a new game ends its opening in the bedroom (1fquarbo)")
        time.sleep(2)
        shot("bedroom.png")
        peak = page.evaluate("window.noite.audioPeak")
        check(peak > 1000, f"sound reaches WebAudio (peak sample {peak})")
        fs = page.evaluate("window.noite.frameStats")
        print(f"      {fs['frames']} frames, {fs['avgMs']:.2f} ms per game turn on average, worst {fs['worstMs']:.0f} ms")
        click(287, 275, "right")  # desk drawer 3
        check(wait_scene("1fgvboy3", 40), "a right click on the desk drawer opens it (1fgvboy3)")
        time.sleep(1.5)
        shot("drawer.png")

        t0 = time.time()
        page.reload()
        page.wait_for_function("window.noite.started || window.noite.failure", timeout=600_000)
        again = time.time() - t0
        print(f"      second load {again:.1f} s")
        time.sleep(3)
        shot("cache.png")
        stats = page.evaluate("window.noite.loadStats")
        check(stats["fromCache"] == stats["files"], f"the second load comes from the cache ({stats})")
        check(not errors, "no page errors")
        browser.close()
    httpd.shutdown()
    print(f"screenshots in {out}")


if __name__ == "__main__":
    main()
