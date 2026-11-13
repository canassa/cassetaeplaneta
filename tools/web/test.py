#!/usr/bin/env python3
"""Browser test of the web build: headless Chromium through Playwright.

    nix develop -c tools/web/build-site.sh
    nix develop .#web -c python3 tools/web/test.py [--site zig-out/site | --url https://…] [--out zig-out/web-test]

Serves the site on a local port and checks, with screenshots of the canvas
in --out: the loader downloads every file; no AudioContext before a user
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
and the wasm has every fix on. Exits non-zero on the first failed check
or on a page error.
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
    ap.add_argument("--url", help="test a deployed site instead of serving --site")
    args = ap.parse_args()
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    if args.url:
        url = args.url.rstrip("/") + "/"
    else:
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

        page.goto(url)
        first_load = load()
        print(f"      first load {first_load:.1f} s")
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
        browser.close()
    if not args.url:
        httpd.shutdown()
    print(f"screenshots in {out}")


if __name__ == "__main__":
    main()
