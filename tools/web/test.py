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
and the wasm has every fix on; a new game there, to the corridor with
the wallet (as in tools/play/full.input), drags the wallet out of the
panel: its icon follows the pointer (drag.png) and is gone once it is
released over the panel (drag-released.png). On a phone-sized touch
screen (a new context, has_touch): the loader has "Controle com um botão"
on by default and the wasm gets it; with taps only, the opening video is
skipped, a new game starts, the desk drawer opens and gives the wallet,
a tap on the door walks the player over and out to the corridor
(touch-corridor.png), a tap on the wallet's slot selects it and a tap in
the scene drops it (touch-drop.png), and a tap on it on the floor takes it
back.
Last, a simulated deploy (a copy of the
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

        def region(x, y, r=20):
            """The canvas's RGBA bytes of the (2r)² square centred on (x, y)."""
            return page.evaluate("""([x, y, r]) => Array.from(document.getElementById("screen")
                .getContext("2d").getImageData(x - r, y - r, 2 * r, 2 * r).data)""", [x, y, r])

        def changed(a, b):
            return sum(a[i:i + 3] != b[i:i + 3] for i in range(0, len(a), 4))

        def drag_shows_item():
            """Corrigida: the wallet dragged out of the panel follows the
            pointer (Fixes.drag_shows_item) and goes with the release."""
            check(wait_scene("abert", 10), "Corrigida: the opening video plays (abert)")
            time.sleep(3)
            click(320, 240)
            check(wait_scene("fundinic", 3), "Corrigida: a click skips to the title")
            time.sleep(1.5)
            click(290, 345)  # JOGAR
            time.sleep(2)
            click(370, 412)  # NOVO JOGO
            check(wait_scene("abertura", 20), "Corrigida: a new game starts")
            time.sleep(2)
            page.keyboard.press("Escape")
            check(wait_scene("1fquarbo", 5), "Corrigida: the bedroom (1fquarbo)")
            time.sleep(1)
            click(287, 275, "right")  # desk drawer 3
            check(wait_scene("1fgvboy3", 40), "Corrigida: the drawer opens (1fgvboy3)")
            time.sleep(1)
            click(286, 261, "right")  # the wallet
            time.sleep(1.5)
            click(300, 330, "right")
            check(wait_scene("1fquarbo", 40), "Corrigida: back in the bedroom with the wallet")
            time.sleep(1)
            click(130, 360)
            time.sleep(4.5)
            click(95, 80, "right")
            check(wait_scene("1fcorred", 40), "Corrigida: the corridor (1fcorred)")
            time.sleep(1)
            page.mouse.move(*at(320, 452))  # open the panel (y > 440)
            time.sleep(1.5)
            page.mouse.move(*at(116, 425))
            time.sleep(0.3)
            before = region(300, 200)
            panel_before = region(300, 430)
            page.mouse.down(button="right")  # slot 0: the wallet
            for x, y in ((150, 380), (200, 320), (250, 260), (300, 200)):
                page.mouse.move(*at(x, y))
                time.sleep(0.1)
            time.sleep(0.3)
            during = region(300, 200)
            shot("drag.png")
            n = changed(before, during)
            check(n > 300, f"Corrigida: the dragged item's icon is drawn at the pointer ({n} pixels changed)")
            page.mouse.move(*at(300, 430))  # back over the panel: no drop
            time.sleep(0.2)
            page.mouse.up(button="right")
            time.sleep(0.5)
            after = region(300, 200)
            shot("drag-released.png")
            n = changed(before, after)
            n += changed(panel_before, region(300, 430))
            check(n == 0, f"Corrigida: released on the panel, the icon is gone ({n} pixels differ)")
            check(not errors, "Corrigida: drag, no page errors")

        def one_button_touch():
            """A touch screen: the one-button mode by default, taps only."""
            tctx = browser.new_context(viewport={"width": 844, "height": 390}, has_touch=True, is_mobile=True)
            tpage = tctx.new_page()
            terrors = []
            tpage.on("pageerror", lambda e: terrors.append(str(e)))
            tpage.goto(url)
            tpage.wait_for_function("window.noite.ready || window.noite.failure", timeout=600_000)
            check(not tpage.evaluate("window.noite.failure"), "touch: the page loads every file")
            check(tpage.evaluate("matchMedia('(pointer: coarse)').matches"), "touch: the pointer is coarse")
            check(tpage.is_checked("#onebutton"), "touch: the loader offers the one-button control by default")
            tpage.click("#play")
            tpage.wait_for_function("window.noite.started || window.noite.failure", timeout=60_000)
            check(tpage.evaluate("[window.noite.fixes, window.noite.skipVideos, window.noite.oneButton]")
                  == [False, True, True], "touch: the wasm runs the Original version with one-button control")
            check(tpage.evaluate("JSON.parse(localStorage.getItem('noite:prefs')).oneButton") is True,
                  "touch: the choice is remembered")

            def tscene():
                return tpage.evaluate("window.noite.scene")

            def twait(name, timeout_s):
                end = time.time() + timeout_s
                while time.time() < end:
                    if tscene() == name:
                        return True
                    if terrors:
                        check(False, "touch: page error: " + "; ".join(terrors))
                    time.sleep(0.25)
                return False

            def tap(x, y):
                box = tpage.locator("#screen").bounding_box()
                tpage.touchscreen.tap(box["x"] + (x + 0.5) * box["width"] / 638,
                                      box["y"] + (y + 0.5) * box["height"] / 459)

            def items():
                return tpage.evaluate("window.noite.inventory")

            check(twait("abert", 10), "touch: the opening video plays (abert)")
            time.sleep(3)
            tap(320, 240)
            check(twait("fundinic", 3), "touch: a tap skips the opening video to the title")
            time.sleep(1.5)
            tap(290, 345)  # JOGAR
            time.sleep(2)
            tap(370, 412)  # NOVO JOGO
            check(twait("abertura", 20), "touch: a new game starts (abertura)")
            time.sleep(2)
            tap(320, 240)
            check(twait("1fquarbo", 5), "touch: a tap skips to the bedroom (1fquarbo)")
            time.sleep(1)
            tap(287, 275)  # desk drawer 3
            check(twait("1fgvboy3", 40), "touch: a tap on the desk drawer opens it (1fgvboy3)")
            time.sleep(1)
            tap(286, 261)  # the wallet
            time.sleep(1.5)
            tap(300, 330)
            check(twait("1fquarbo", 40), "touch: back in the bedroom")
            time.sleep(1)
            tap(95, 80)  # the door, from across the room: walk there, then open it
            check(twait("1fcorred", 40), "touch: a tap on the door walks out to the corridor (1fcorred)")
            time.sleep(1.5)
            tpage.locator("#screen").screenshot(path=str(out / "touch-corridor.png"))
            check(items() == 1, "touch: the player carries the wallet")
            tap(320, 452)  # the bottom strip: the panel slides open
            time.sleep(1.5)
            tap(116, 425)  # slot 0: the wallet, selected
            time.sleep(0.3)
            check(items() == 1, "touch: a tap on the slot only selects the wallet")
            tap(100, 300)  # dropped: it falls to the floor
            time.sleep(2)
            tpage.locator("#screen").screenshot(path=str(out / "touch-drop.png"))
            check(items() == 0, "touch: the next tap in the scene drops it")
            tap(100, 250)  # a walk there; the panel slides closed
            time.sleep(2.5)
            tap(100, 368)  # the wallet on the floor
            time.sleep(1.5)
            check(items() == 1, "touch: a tap on it takes it back")
            pad = tpage.locator("#dpad")
            check(pad.is_visible(), "touch: the on-screen arrows show in one-button mode")
            before = tpage.locator("#screen").screenshot()
            left = tpage.locator('#dpad [data-key="37"]').bounding_box()
            cx, cy = left["x"] + left["width"] / 2, left["y"] + left["height"] / 2
            # A held arrow: a touch that stays down (CDP touch events).
            cdp = tctx.new_cdp_session(tpage)
            cdp.send("Input.dispatchTouchEvent", {"type": "touchStart", "touchPoints": [{"x": cx, "y": cy}]})
            time.sleep(1.5)
            cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})
            time.sleep(0.5)
            tpage.screenshot(path=str(out / "touch-dpad.png"))
            check(tpage.locator("#screen").screenshot() != before, "touch: holding ◀ walks the player")
            check(not terrors, "touch: no page errors")
            tctx.close()

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
        check(page.is_checked('input[name="versao"][value="original"]') and page.is_checked("#skip")
              and not page.is_checked("#onebutton"),
              "the loader offers Original with video skipping, two buttons, by default")
        play()
        check(page.evaluate("window.noite.audioState") == "running", "AudioContext running after Jogar")
        check(page.evaluate("[window.noite.fixes, window.noite.skipVideos, window.noite.oneButton]")
              == [False, True, False], "the wasm runs the Original version with video skipping")
        # The opening video (abert) runs 22 s; a click skips it to the title.
        check(wait_scene("abert", 10), "the opening video plays (abert)")
        time.sleep(3)
        t0 = time.time()
        click(320, 240)
        check(wait_scene("fundinic", 3), f"a click skips the opening video to the title ({time.time() - t0:.1f} s)")
        time.sleep(1.5)
        shot("title.png")
        check(not errors, "title screen, no page errors")
        check(not page.locator("#dpad").is_visible(), "no on-screen arrows with two buttons")
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
        page.evaluate("window.noite.suspendAudio()")
        check(page.evaluate("window.noite.audioState") == "suspended", "audio suspended (page sent to the background)")
        page.evaluate("document.dispatchEvent(new Event('visibilitychange'))")
        time.sleep(0.5)
        check(page.evaluate("window.noite.audioState") == "running", "coming back to the page resumes the audio")
        page.evaluate("window.noite.suspendAudio()")
        click(5, 5)
        time.sleep(0.5)
        check(page.evaluate("window.noite.audioState") == "running", "a click resumes the audio")
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
        drag_shows_item()
        one_button_touch()

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
