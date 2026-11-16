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
In the bedroom the Relatório button downloads a report named after the
release and the scene, with a screenshot and the game state (the scene,
the empty inventory, the player, every portable).
At 1280×960, 1920×1080, two phone sizes and an exact 2× (no letterbox)
the canvas fills the window in one dimension, keeps its aspect ratio, is
centred, and the tool buttons stay in the window and off the game unless
the letterbox has no room for them (window-WxH.png). Then the version
button reloads into the Corrigida version: the loader shows it chosen, the load comes from Cache Storage (cache.png) and is quicker,
and the wasm has every fix on; a new game there, to the corridor with
the wallet (as in tools/play/full.input), drags the wallet out of the
panel: its icon follows the pointer (drag.png) and is gone once it is
released over the panel (drag-released.png); with the player walked down
behind the open panel, three closes each keep the panel whole in every
frame the page presents until the first step of the slide (B48,
panel-close.png). In the corridor the report lists the wallet, and "⋯"
then "Estado completo" downloads a snapshot; restored into a new page
(`?snapshot` and its file picker) the game goes on in the corridor with
the wallet, its clock from the captured time, for a few seconds without
page errors (restored.png). On a phone-sized touch
screen (a new context, has_touch): the loader has "Controle com um botão"
on by default and the wasm gets it; with taps only, the opening video is
skipped, a new game starts, the desk drawer opens and gives the wallet,
a tap on the door walks the player over and out to the corridor
(touch-corridor.png), a tap on the wallet's slot selects it and a tap in
the scene drops it (touch-drop.png), and a tap on it on the floor takes it
back.
Then a simulated deploy (a copy of the
site with noite.js and one disc file changed, restamped by
tools/web/stamp.py, served at the same origin): the reload downloads
only that file, runs the new noite.js and drops the stale cache entry.
Then "Jogo" = Encaixe Perfeito: the minigame starts alone and a left
arrow moves its falling piece one column (encaixe.png, encaixe-left.png).
Then "Jogo" = Tiro ao Álvaro: TIRO starts alone and SPACE fires: the
crossbow turns to its unloaded picture (tiro.png, tiro-fire.png); on a
touch screen the pad shows ◀, a fire button and ▶, and the fire button
fires (tiro-touch.png).
Then "Jogo" = Serial Killer: SERIAL starts alone and SPACE fires: the
bullet leaves the gun (serial.png, serial-fire.png); on a touch screen
the pad shows ◀, a fire button and ▶, and the fire button fires
(serial-touch.png).
Then "Jogo" = Porrada na Sala de Ginástica: SALGIN starts alone and a
held Up kicks the opponent until its energy bar gets a tile (salgin.png,
salgin-kick.png); on a touch screen the pad shows the eight fight keys
and a held ▲ does the same (salgin-touch.png).
Then "Jogo" = Invasores: INV starts alone and SPACE fires: the shot
leaves the cannon (inv.png, inv-fire.png); on a touch screen the pad
shows ◀, a fire button and ▶, and the fire button fires (inv-touch.png).
Then "Jogo" = Xilindro: XILINDRO starts alone and Right and Up pressed in
turn walk in and kick the opponent until its energy bar gets a tile
(xilindro.png, xilindro-kick.png); on a touch screen the pad shows the
eight fight keys and ▶ and ▲ tapped in turn do the same
(xilindro-touch.png); in the Corrigida on a phone held upright the
controls screen keeps the clock still, the pad shows the arrows and the
four named moves, a tap on one takes it down, the clock stands under
PORRADA's 2 s and then runs, and ▶ and Chute tapped each move the fighter
(xilindro-controls.png, xilindro-corrigida-touch.png). Then "Jogo" =
Inferno: INFERNO starts alone and a held Right walks the hero off his starting place (inferno.png,
inferno-walk.png); on a touch screen the pad shows the four arrows and a
held ▶ does the same (inferno-touch.png). Then "Jogo" = Sauna Mista:
SAUNA starts alone and Left runs Pacman along his row, eating peanuts:
the score box changes (sauna.png, sauna-run.png); on a touch screen the
pad shows the four arrows and ◀ does the same (sauna-touch.png). In the Corrigida
the controls screen comes first and keeps the game still (sauna-controls.png), Enter takes it
down and, after the READY second, Pacman runs on his own and eats peanuts
(sauna-arcade.png); on a phone a tap on an arrow takes it down
(sauna-corrigida-touch.png). Then
"Jogo" = Jardim: JARDIM starts alone, a held Up walks the player: the
minimap's square moves (jardim.png, jardim-walk.png), and a held Ctrl
shows the fists' punch (jardim-punch.png); on a touch screen the pad shows
the arrows, Abrir (SPACE) and Tiro (CTRL), and a held ▲ walks
(jardim-touch.png). In the Corrigida the controls screen comes first
(jardim-controls.png; the key that takes it down does not walk), then a
held W walks, A strafes and Space punches (jardim-corrigida-walk.png); on a
phone the pad shows the arrows, the strafes, Abrir (E), Tiro and Arma (Q,
the next weapon, under them), a tap
takes the screen down and a held ▲ walks (jardim-corrigida-touch.png).
Before the game: /explorer/ (the asset explorer) lists the unused files
and opens one on a click, on a desktop and a phone (explorer.png,
explorer-detail.png, explorer-phone.png); the game page later loads none of
its files.
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


def explorer(browser, url, out, check):
    """/explorer/ (tools/explorer/): the grid lists the unused files by
    default, a click opens a file's picture and details, on a desktop and a
    phone-sized touch screen (explorer.png, explorer-detail.png,
    explorer-phone.png), without page errors."""
    for name, opts in (("explorer", {"viewport": {"width": 1280, "height": 900}}),
                       ("explorer-phone", {"viewport": {"width": 390, "height": 844}, "has_touch": True,
                                           "is_mobile": True, "device_scale_factor": 2})):
        ctx = browser.new_context(**opts)
        page = ctx.new_page()
        errors = []
        page.on("pageerror", lambda e: errors.append(str(e)))
        page.goto(url + "explorer/")
        page.wait_for_selector(".card", timeout=30_000)
        n = page.locator(".card").count()
        total = page.evaluate("ITEMS.length")
        unused = page.evaluate("ITEMS.filter((i) => i.status === 'unused').length")
        check(n == unused and 0 < n < total, f"{name}: /explorer/ lists the {n} unused files of {total}")
        check(page.evaluate("getComputedStyle(document.querySelector('#grid')).display") == "grid",
              f"{name}: the page is styled")
        width = page.evaluate("document.documentElement.scrollWidth")
        check(width <= opts["viewport"]["width"], f"{name}: no horizontal scroll ({width} px)")
        page.wait_for_function("[...document.querySelectorAll('.card img')].slice(0, 4).every((i) => i.complete && i.naturalWidth)",
                               timeout=30_000)
        page.screenshot(path=str(out / f"{name}.png"))
        card = page.locator(".card").first
        card.tap() if opts.get("has_touch") else card.click()
        page.wait_for_function("(() => { const i = document.querySelector('#d-stage img, #d-stage canvas, #d-stage video');"
                               " return i && (i.tagName !== 'IMG' || (i.complete && i.naturalWidth)); })()", timeout=30_000)
        check(page.locator("#d-meta dd").count() >= 5, f"{name}: a click opens the file's details")
        # Playwright's Chromium has no H.264: there the clip is only checked to be there.
        if page.locator("#d-stage video").count() and page.evaluate(
                "document.createElement('video').canPlayType('video/mp4; codecs=\"avc1.640028\"')"):
            page.evaluate("document.querySelector('#d-stage video').muted = true; document.querySelector('#d-stage video').play()")
            page.wait_for_function("document.querySelector('#d-stage video').currentTime > 0.3", timeout=30_000)
            check(True, f"{name}: the clip plays")
        if name == "explorer":
            page.screenshot(path=str(out / "explorer-detail.png"))
        check(not errors, f"{name}: no page errors ({errors[:2]})")
        ctx.close()


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
        explorer(browser, url, out, check)
        # One context for both loads, so the second one sees the cache.
        ctx = browser.new_context(viewport={"width": 1280, "height": 960}, accept_downloads=True)
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

        def save_report(pg, scene_name):
            """Relatório: the downloaded JSON, checked against the page."""
            with pg.expect_download() as d:
                pg.click("#reportbtn")
            name = d.value.suggested_filename
            path = out / name
            d.value.save_as(path)
            r = json.loads(path.read_text())
            check(re.fullmatch(rf"noite-[0-9A-Za-z._-]+-{scene_name}-\d{{8}}T\d{{6}}Z\.json", name) is not None
                  and r["release"] == pg.evaluate("window.noite.release"),
                  f"Relatório downloads {name}")
            st = r["state"]
            check(st["scene"]["name"] == scene_name and r["screenshot"].startswith("data:image/png;base64,")
                  and r["build"] == pg.evaluate("window.noite.build") and len(st["portables"]) > 50
                  and st["player"] is not None and r["userAgent"] and r["viewport"]["width"] > 0,
                  f"the report has the scene, a screenshot, the build, the player and the portables"
                  f" ({len(path.read_bytes()) / 1e3:.0f} kB)")
            return r

        def snapshot_restore():
            """In the corridor with the wallet: a snapshot, restored into a new page."""
            before = save_report(page, "1fcorred")
            inv = [(i["id"], i["name"]) for i in before["state"]["inventory"]]
            check(len(inv) == 1, f"the report lists the wallet in the inventory ({inv})")
            page.click("#morebtn")
            check(page.is_visible("#snapbtn"), "⋯ shows Estado completo")
            with page.expect_download(timeout=120_000) as d:
                page.click("#snapbtn")
            snap = out / d.value.suggested_filename
            d.value.save_as(snap)
            check(not page.is_visible("#snapbtn") and snap.suffix == ".noitesnap",
                  f"Estado completo downloads {snap.name} ({snap.stat().st_size / 1e6:.1f} MB)")
            rpage = ctx.new_page()
            rerrors = []
            rpage.on("pageerror", lambda e: rerrors.append(str(e)))
            rpage.goto(url + "?snapshot")
            rpage.wait_for_function("window.noite.ready || window.noite.failure", timeout=600_000)
            check(rpage.is_visible("#snapfile"), "?snapshot offers a snapshot file on the loader")
            rpage.set_input_files("#snapfile", str(snap))
            rpage.wait_for_function("window.noite.restored || window.noite.failure", timeout=120_000)
            check(not rpage.evaluate("window.noite.failure"), "the snapshot is restored")
            t0 = rpage.evaluate("window.noite.ticks")
            check(rpage.evaluate("[window.noite.scene, window.noite.inventory, window.noite.fixes]")
                  == ["1fcorred", 1, True], "restored: the corridor, the wallet, the Corrigida version")
            check(t0 >= before["state"]["ticks"], f"restored: the clock goes on from the capture ({t0} ms)")
            time.sleep(3)
            after = rpage.evaluate("window.noite.report()")["state"]
            check(after["ticks"] - t0 >= 2500 and after["scene"]["name"] == "1fcorred"
                  and [(i["id"], i["name"]) for i in after["inventory"]] == inv,
                  f"restored: still running {after['ticks'] - t0} ms later, same scene and inventory")
            rpage.locator("#screen").screenshot(path=str(out / "restored.png"))
            check(not rerrors, "restored: no page errors" + (": " + "; ".join(rerrors) if rerrors else ""))
            rpage.close()

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
            snapshot_restore()
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
            panel_close_whole()

        def panel_close_whole():
            """Corrigida (B48): with the player standing behind the open
            panel, every frame the page presents while the panel starts
            sliding closed keeps the panel whole: until its first step
            (which changes the whole width) nothing changes in its paper
            rows 365-395 (above the slots). Three closes: the cut needed
            the player's idle tick to come before the first step."""
            click(200, 400)  # a walk down, behind the panel
            time.sleep(4)
            page.evaluate("""() => {
                const ctx = document.getElementById("screen").getContext("2d");
                const put = CanvasRenderingContext2D.prototype.putImageData;
                window.__rows = [];
                ctx.putImageData = function (img, ...rest) {
                    window.__rows.push(img.data.slice(365 * 640 * 4, 396 * 640 * 4));
                    return put.call(this, img, ...rest);
                };
            }""")
            results = []
            for i in range(3):
                page.mouse.move(*at(320, 452))  # open
                time.sleep(1.5)
                if i == 0:
                    shot("panel-close.png")
                page.evaluate("window.__rows = []")
                page.mouse.move(*at(320, 200))  # close
                time.sleep(1.5)
                results.append(page.evaluate("""() => {
                    const f = window.__rows, cuts = [];
                    for (let i = 1; i < f.length; i++) {
                        let lo = 640, hi = -1;
                        for (let k = 0; k < f[i].length; k += 4) {
                            if (f[i][k] !== f[i - 1][k] || f[i][k + 1] !== f[i - 1][k + 1]
                                || f[i][k + 2] !== f[i - 1][k + 2]) {
                                const x = (k / 4) % 640;
                                lo = Math.min(lo, x);
                                hi = Math.max(hi, x);
                            }
                        }
                        if (hi < 0) continue;
                        if (lo < 60 && hi > 580) return {frames: f.length, slid: true, cuts};
                        cuts.push([i, lo, hi]);
                    }
                    return {frames: f.length, slid: false, cuts};
                }"""))
            page.evaluate('delete document.getElementById("screen").getContext("2d").putImageData')
            check(all(r["slid"] and not r["cuts"] for r in results),
                  "Corrigida: the panel slides closed over the player whole, three times"
                  f" (frames, cuts before the first step: {[(r['frames'], r['cuts']) for r in results]})")

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
            check(tpage.locator("#screen").screenshot() != before, "touch: holding ◀ walks the player")
            def pad_outside(vw, vh, name):
                tpage.set_viewport_size({"width": vw, "height": vh})
                time.sleep(0.5)
                g = tpage.locator("#screen").bounding_box()
                d = pad.bounding_box()
                apart = (d["x"] >= g["x"] + g["width"] or d["y"] >= g["y"] + g["height"])
                inside = d["x"] + d["width"] <= vw and d["y"] + d["height"] <= vh
                tpage.screenshot(path=str(out / name))
                check(apart and inside, f"touch {vw}x{vh}: the arrows sit outside the game, bottom right ({name})")
            pad_outside(390, 844, "touch-dpad-portrait.png")
            pad_outside(844, 390, "touch-dpad.png")
            check(not terrors, "touch: no page errors")
            tctx.close()

        def piece_left():
            """The leftmost column of the playfield (x 32-383, above the
            floor's bricks) that is not ENCAIXE's background, or None."""
            return page.evaluate("""() => {
                const d = document.getElementById("screen").getContext("2d").getImageData(32, 0, 352, 400).data;
                let left = null;
                for (let i = 0; i < d.length; i += 4) {
                    if (Math.abs(d[i] - 16) + Math.abs(d[i + 1] - 16) + Math.abs(d[i + 2] - 16) > 24) {
                        const x = 32 + (i / 4) % 352;
                        if (left === null || x < left) left = x;
                    }
                }
                return left;
            }""")

        def minigame_alone():
            """Jogo: Encaixe Perfeito alone. It starts, a left arrow moves the
            falling piece one 32-px column, no page errors."""
            if not args.url:
                Handler.site = site  # back from the deploy copy
            page.goto(url)
            load()
            check(not page.is_disabled("#jogo option[value=encaixe]"), "the loader offers Encaixe Perfeito alone")
            page.select_option("#jogo", "encaixe")
            page.check('input[name="versao"][value="original"]')
            play()
            end = time.time() + 5
            while (piece_left() or 0) <= 40 and time.time() < end:  # the first piece (x 160)
                time.sleep(0.05)
            shot("encaixe.png")
            before = piece_left()
            page.keyboard.press("ArrowLeft")
            time.sleep(0.3)
            after = piece_left()
            shot("encaixe-left.png")
            check(before is not None and after is not None and after <= before - 32,
                  f"Encaixe Perfeito runs: the left arrow moves the piece (left edge {before} -> {after})")
            check(not errors, "Encaixe Perfeito: no page errors")

        def crossbow():
            """A checksum of the crossbow's picture (TIRO, x 200-484, y
            385-454: below the arrow's flight), or None."""
            return page.evaluate("""() => {
                const d = document.getElementById("screen").getContext("2d").getImageData(200, 385, 285, 70).data;
                let sum = 0;
                for (let i = 0; i < d.length; i += 4) sum = (sum * 31 + d[i] + 7 * d[i + 1] + 13 * d[i + 2]) % 1000000007;
                return sum;
            }""")

        def tiro_alone():
            """Jogo: Tiro ao Álvaro alone. It starts, SPACE fires (the crossbow
            shows `bestse`, unloaded), no page errors."""
            page.goto(url)
            load()
            check(not page.is_disabled("#jogo option[value=tiro]"), "the loader offers Tiro ao Álvaro alone")
            page.select_option("#jogo", "tiro")
            page.check('input[name="versao"][value="original"]')
            play()
            time.sleep(1.5)
            shot("tiro.png")
            before = crossbow()
            page.keyboard.press("Space")
            time.sleep(0.3)
            after = crossbow()
            shot("tiro-fire.png")
            check(before is not None and after is not None and before != after,
                  "Tiro ao Álvaro runs: SPACE fires (the crossbow is unloaded)")
            check(not errors, "Tiro ao Álvaro: no page errors")

        def tiro_touch():
            """Tiro ao Álvaro alone on a touch screen: the pad's keys are
            TIRO's (LEFT, fire, RIGHT) and the fire button fires."""
            tctx = browser.new_context(viewport={"width": 844, "height": 390}, has_touch=True, is_mobile=True)
            tpage = tctx.new_page()
            terrors = []
            tpage.on("pageerror", lambda e: terrors.append(str(e)))
            tpage.goto(url)
            tpage.wait_for_function("window.noite.ready || window.noite.failure", timeout=600_000)
            tpage.select_option("#jogo", "tiro")
            tpage.click("#play")
            tpage.wait_for_function("window.noite.started || window.noite.failure", timeout=60_000)
            time.sleep(1.5)
            shown = tpage.evaluate("""() => Array.from(document.querySelectorAll('#dpad button'))
                .filter((b) => !b.hidden).map((b) => Number(b.dataset.key))""")
            check(sorted(shown) == [32, 37, 39], f"touch TIRO: the pad shows LEFT, fire and RIGHT ({shown})")
            sum_js = """() => {
                const d = document.getElementById("screen").getContext("2d").getImageData(200, 385, 285, 70).data;
                let sum = 0;
                for (let i = 0; i < d.length; i += 4) sum = (sum * 31 + d[i] + 7 * d[i + 1] + 13 * d[i + 2]) % 1000000007;
                return sum;
            }"""
            before = tpage.evaluate(sum_js)
            tpage.locator('#dpad [data-key="32"]').tap()
            time.sleep(0.3)
            tpage.screenshot(path=str(out / "tiro-touch.png"))
            check(tpage.evaluate(sum_js) != before, "touch TIRO: the fire button fires")
            check(not terrors, "touch TIRO: no page errors")
            tctx.close()

        # SERIAL's flight area above the gun (x 0-639, y 200-374): empty
        # road and grass until the first figures walk in at 5 s, so a
        # change there is the bullet.
        flight_js = """() => {
            const d = document.getElementById("screen").getContext("2d").getImageData(0, 200, 640, 175).data;
            let sum = 0;
            for (let i = 0; i < d.length; i += 4) sum = (sum * 31 + d[i] + 7 * d[i + 1] + 13 * d[i + 2]) % 1000000007;
            return sum;
        }"""

        def serial_alone():
            """Jogo: Serial Killer alone. It starts, SPACE fires (the bullet
            flies above the gun), no page errors."""
            page.goto(url)
            load()
            check(not page.is_disabled("#jogo option[value=serial]"), "the loader offers Serial Killer alone")
            page.select_option("#jogo", "serial")
            page.check('input[name="versao"][value="original"]')
            play()
            time.sleep(1.5)
            shot("serial.png")
            before = page.evaluate(flight_js)
            page.keyboard.press("Space")
            time.sleep(0.3)
            after = page.evaluate(flight_js)
            shot("serial-fire.png")
            check(before is not None and after is not None and before != after,
                  "Serial Killer runs: SPACE fires (the bullet flies)")
            check(not errors, "Serial Killer: no page errors")

        def serial_touch():
            """Serial Killer alone on a touch screen: the pad's keys are
            SERIAL's (LEFT, fire, RIGHT) and the fire button fires."""
            tctx = browser.new_context(viewport={"width": 844, "height": 390}, has_touch=True, is_mobile=True)
            tpage = tctx.new_page()
            terrors = []
            tpage.on("pageerror", lambda e: terrors.append(str(e)))
            tpage.goto(url)
            tpage.wait_for_function("window.noite.ready || window.noite.failure", timeout=600_000)
            tpage.select_option("#jogo", "serial")
            tpage.click("#play")
            tpage.wait_for_function("window.noite.started || window.noite.failure", timeout=60_000)
            time.sleep(1.5)
            shown = tpage.evaluate("""() => Array.from(document.querySelectorAll('#dpad button'))
                .filter((b) => !b.hidden).map((b) => Number(b.dataset.key))""")
            check(sorted(shown) == [32, 37, 39], f"touch SERIAL: the pad shows LEFT, fire and RIGHT ({shown})")
            before = tpage.evaluate(flight_js)
            tpage.locator('#dpad [data-key="32"]').tap()
            time.sleep(0.3)
            tpage.screenshot(path=str(out / "serial-touch.png"))
            check(tpage.evaluate(flight_js) != before, "touch SERIAL: the fire button fires")
            check(not terrors, "touch SERIAL: no page errors")
            tctx.close()

        # SALGIN's opponent energy tiles (x 333 on, y 20, 16x19 each): only
        # the player's blows add them (one per 7 points), so a change there
        # is a kick that landed. Up held 10 s (the game's key repeat kicks
        # again as each move ends) takes 10 or more points.
        # The fights' clock box (20 x 15 at 310, 22).
        clock_js = """() => {
            const d = document.getElementById("screen").getContext("2d").getImageData(310, 22, 20, 15).data;
            let sum = 0;
            for (let i = 0; i < d.length; i += 4) sum = (sum * 31 + d[i] + 7 * d[i + 1] + 13 * d[i + 2]) % 1000000007;
            return sum;
        }"""
        tiles_js = """() => {
            const d = document.getElementById("screen").getContext("2d").getImageData(333, 18, 240, 24).data;
            let sum = 0;
            for (let i = 0; i < d.length; i += 4) sum = (sum * 31 + d[i] + 7 * d[i + 1] + 13 * d[i + 2]) % 1000000007;
            return sum;
        }"""

        def salgin_alone():
            """Jogo: Porrada na Sala de Ginástica alone. It starts, a held Up
            kicks (the opponent's energy bar gets a tile), no page errors."""
            page.goto(url)
            load()
            check(not page.is_disabled("#jogo option[value=salgin]"), "the loader offers Porrada alone")
            page.select_option("#jogo", "salgin")
            page.check('input[name="versao"][value="original"]')
            play()
            time.sleep(1.5)
            shot("salgin.png")
            before = page.evaluate(tiles_js)
            page.keyboard.down("ArrowUp")
            time.sleep(10)
            page.keyboard.up("ArrowUp")
            time.sleep(0.3)
            after = page.evaluate(tiles_js)
            shot("salgin-kick.png")
            check(before is not None and after is not None and before != after,
                  "Porrada runs: a held Up kicks (the opponent's energy bar loses a tile)")
            check(not errors, "Porrada: no page errors")

        def salgin_touch():
            """Porrada alone on a touch screen: the pad's keys are SALGIN's
            eight and a held ▲ kicks."""
            tctx = browser.new_context(viewport={"width": 844, "height": 390}, has_touch=True, is_mobile=True)
            tpage = tctx.new_page()
            terrors = []
            tpage.on("pageerror", lambda e: terrors.append(str(e)))
            tpage.goto(url)
            tpage.wait_for_function("window.noite.ready || window.noite.failure", timeout=600_000)
            tpage.select_option("#jogo", "salgin")
            tpage.click("#play")
            tpage.wait_for_function("window.noite.started || window.noite.failure", timeout=60_000)
            time.sleep(1.5)
            shown = tpage.evaluate("""() => Array.from(document.querySelectorAll('#dpad button'))
                .filter((b) => !b.hidden).map((b) => Number(b.dataset.key))""")
            check(sorted(shown) == [33, 35, 36, 37, 38, 39, 40, 45], f"touch Porrada: the pad shows the eight fight keys ({shown})")
            before = tpage.evaluate(tiles_js)
            up = tpage.locator('#dpad [data-key="38"]').bounding_box()
            cdp = tctx.new_cdp_session(tpage)
            cdp.send("Input.dispatchTouchEvent", {"type": "touchStart",
                     "touchPoints": [{"x": up["x"] + up["width"] / 2, "y": up["y"] + up["height"] / 2}]})
            time.sleep(10)
            cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})
            time.sleep(0.3)
            tpage.screenshot(path=str(out / "salgin-touch.png"))
            check(tpage.evaluate(tiles_js) != before, "touch Porrada: a held ▲ kicks")
            check(not terrors, "touch Porrada: no page errors")
            tctx.close()

        def fight_corrigida_touch(game, who, shot):
            """`who` (Xilindro, Porrada) alone in the Corrigida on a phone (`game`,
            the page's ?jogo name; the MK3 pad of both): the controls screen
            is up and the clock stands, the pad shows the arrows and the four
            moves with their names, a tap on one takes the screen down (the
            clock runs), and ▶ and Chute (S) tapped each move the fighter."""
            tctx = browser.new_context(viewport={"width": 390, "height": 844}, has_touch=True, is_mobile=True)
            tpage = tctx.new_page()
            terrors = []
            tpage.on("pageerror", lambda e: terrors.append(str(e)))
            tpage.goto(url)
            tpage.wait_for_function("window.noite.ready || window.noite.failure", timeout=600_000)
            tpage.select_option("#jogo", game)
            tpage.check('input[name="versao"][value="corrigida"]')
            tpage.click("#play")
            tpage.wait_for_function("window.noite.started || window.noite.failure", timeout=60_000)
            time.sleep(1.5)
            tpage.screenshot(path=str(out / f"{shot}-controls.png"))
            shown = tpage.evaluate("""() => Array.from(document.querySelectorAll('#dpad button'))
                .filter((b) => !b.hidden).map((b) => [Number(b.dataset.key), b.textContent])""")
            check(sorted(k for k, _ in shown) == [32, 37, 38, 39, 40, 65, 68, 70, 83],
                  f"Corrigida touch {who}: the pad shows the MK3 layout: the arrows, A S D F and the block ({shown})")
            check(dict(shown).get(68) == "Chute" and dict(shown).get(65) == "Soco" and dict(shown).get(32) == "Def.",
                  f"Corrigida touch {who}: the moves have their names ({shown})")
            clock = tpage.evaluate(clock_js)
            time.sleep(1.5)
            check(tpage.evaluate(clock_js) == clock, f"Corrigida touch {who}: the clock waits under the controls screen")
            # The Corrigida's opponent fights back, so whether a kick lands
            # in a given 15 s depends on its moves (the energy bar is no
            # check here). A tap on a pad button instead shows in the fighter
            # at once: ▶ walks it and Chute moves it into the kick. The
            # fighter's start (x 100-200) is clear of the opponent's reach.
            fighter_js = region_js(90, 230, 130, 170)
            right = tpage.locator('#dpad [data-key="39"]')
            kick = tpage.locator('#dpad [data-key="83"]')

            def moves_after_tap(button):
                before = tpage.evaluate(fighter_js)
                button.tap()
                end = time.time() + 1.5
                while time.time() < end:
                    if tpage.evaluate(fighter_js) != before:
                        return True
                    time.sleep(0.03)
                return False

            kick.tap()
            # PORRADA's frozen 2 s, then the clock's first second.
            time.sleep(1.0)
            check(tpage.evaluate(clock_js) == clock, f"Corrigida touch {who}: the clock waits under PORRADA")
            time.sleep(2.7)
            check(tpage.evaluate(clock_js) != clock, f"Corrigida touch {who}: a pad button starts the round (the clock runs)")
            check(moves_after_tap(right), f"Corrigida touch {who}: ▶ walks the fighter")
            time.sleep(1.0)
            check(moves_after_tap(kick), f"Corrigida touch {who}: Chute moves the fighter into the kick")
            time.sleep(0.3)
            tpage.screenshot(path=str(out / f"{shot}-corrigida-touch.png"))
            check(not terrors, f"Corrigida touch {who}: no page errors")
            tctx.close()

        def xilindro_corrigida_touch():
            fight_corrigida_touch("xilindro", "Xilindro", "xilindro")

        def salgin_corrigida_touch():
            fight_corrigida_touch("salgin", "Porrada", "salgin")

        # INV's shot leaves the cannon (x 340, y 380) at x 367, y 350 and
        # climbs 20 px per 55 ms; the strip above the cannon, under the
        # invaders' bottom row (y 280) and right of the third column, is
        # still until then, and no bomb falls before the first drop at 2 s.
        shot_js = """() => {
            const d = document.getElementById("screen").getContext("2d").getImageData(361, 285, 22, 90).data;
            let sum = 0;
            for (let i = 0; i < d.length; i += 4) sum = (sum * 31 + d[i] + 7 * d[i + 1] + 13 * d[i + 2]) % 1000000007;
            return sum;
        }"""

        def inv_alone():
            """Jogo: Invasores alone. It starts, SPACE fires (the shot climbs
            above the cannon), no page errors."""
            page.goto(url)
            load()
            check(not page.is_disabled("#jogo option[value=inv]"), "the loader offers Invasores alone")
            page.select_option("#jogo", "inv")
            page.check('input[name="versao"][value="original"]')
            play()
            time.sleep(0.8)
            shot("inv.png")
            before = page.evaluate(shot_js)
            page.keyboard.press("Space")
            time.sleep(0.15)
            after = page.evaluate(shot_js)
            shot("inv-fire.png")
            check(before is not None and after is not None and before != after,
                  "Invasores runs: SPACE fires (the shot climbs)")
            check(not errors, "Invasores: no page errors")

        def inv_touch():
            """Invasores alone on a touch screen: the pad's keys are INV's
            (LEFT, fire, RIGHT) and the fire button fires."""
            tctx = browser.new_context(viewport={"width": 844, "height": 390}, has_touch=True, is_mobile=True)
            tpage = tctx.new_page()
            terrors = []
            tpage.on("pageerror", lambda e: terrors.append(str(e)))
            tpage.goto(url)
            tpage.wait_for_function("window.noite.ready || window.noite.failure", timeout=600_000)
            tpage.select_option("#jogo", "inv")
            tpage.click("#play")
            tpage.wait_for_function("window.noite.started || window.noite.failure", timeout=60_000)
            time.sleep(0.8)
            shown = tpage.evaluate("""() => Array.from(document.querySelectorAll('#dpad button'))
                .filter((b) => !b.hidden).map((b) => Number(b.dataset.key))""")
            check(sorted(shown) == [32, 37, 39], f"touch INV: the pad shows LEFT, fire and RIGHT ({shown})")
            before = tpage.evaluate(shot_js)
            tpage.locator('#dpad [data-key="32"]').tap()
            time.sleep(0.15)
            tpage.screenshot(path=str(out / "inv-touch.png"))
            check(tpage.evaluate(shot_js) != before, "touch INV: the fire button fires")
            check(not terrors, "touch INV: no page errors")
            tctx.close()

        # XILINDRO's opponent stops 99-130 px away, out of the fighter's
        # 100-px reach, so a held Up never lands: Right (one 32-px step a
        # press) and Up pressed in turn, every 100-200 ms for 15 s, land
        # 8 to 14 points (the port, headless), a tile (one per 7) on
        # XILINDRO's opponent bar, at SALGIN's place (tiles_js).
        def xilindro_alone():
            """Jogo: Xilindro alone. It starts, Right and Up in turn kick (the
            opponent's energy bar gets a tile), no page errors."""
            page.goto(url)
            load()
            check(not page.is_disabled("#jogo option[value=xilindro]"), "the loader offers Xilindro alone")
            page.select_option("#jogo", "xilindro")
            page.check('input[name="versao"][value="original"]')
            play()
            time.sleep(1.5)
            shot("xilindro.png")
            before = page.evaluate(tiles_js)
            end = time.time() + 15
            while time.time() < end:
                page.keyboard.press("ArrowRight")
                time.sleep(0.06)
                page.keyboard.press("ArrowUp")
                time.sleep(0.06)
            time.sleep(0.3)
            after = page.evaluate(tiles_js)
            shot("xilindro-kick.png")
            check(before is not None and after is not None and before != after,
                  "Xilindro runs: Right and Up kick (the opponent's energy bar loses a tile)")
            check(not errors, "Xilindro: no page errors")

        def xilindro_touch():
            """Xilindro alone on a touch screen: the pad's keys are the eight
            fight keys and ▶ and ▲ tapped in turn kick."""
            tctx = browser.new_context(viewport={"width": 844, "height": 390}, has_touch=True, is_mobile=True)
            tpage = tctx.new_page()
            terrors = []
            tpage.on("pageerror", lambda e: terrors.append(str(e)))
            tpage.goto(url)
            tpage.wait_for_function("window.noite.ready || window.noite.failure", timeout=600_000)
            tpage.select_option("#jogo", "xilindro")
            tpage.click("#play")
            tpage.wait_for_function("window.noite.started || window.noite.failure", timeout=60_000)
            time.sleep(1.5)
            shown = tpage.evaluate("""() => Array.from(document.querySelectorAll('#dpad button'))
                .filter((b) => !b.hidden).map((b) => Number(b.dataset.key))""")
            check(sorted(shown) == [33, 35, 36, 37, 38, 39, 40, 45], f"touch Xilindro: the pad shows the eight fight keys ({shown})")
            before = tpage.evaluate(tiles_js)
            right = tpage.locator('#dpad [data-key="39"]')
            up = tpage.locator('#dpad [data-key="38"]')
            end = time.time() + 15
            while time.time() < end:
                right.tap()
                time.sleep(0.05)
                up.tap()
                time.sleep(0.05)
            time.sleep(0.3)
            tpage.screenshot(path=str(out / "xilindro-touch.png"))
            check(tpage.evaluate(tiles_js) != before, "touch Xilindro: ▶ and ▲ in turn kick")
            check(not terrors, "touch Xilindro: no page errors")
            tctx.close()

        # INFERNO's hero stands at x 153 (y 306, 62 px tall) and nothing
        # crosses that spot in the first 5 s (the first hazard walks away
        # to the left); a held Right walks him 5 px per 55 ms.
        hero_js = """() => {
            const d = document.getElementById("screen").getContext("2d").getImageData(150, 300, 40, 70).data;
            let sum = 0;
            for (let i = 0; i < d.length; i += 4) sum = (sum * 31 + d[i] + 7 * d[i + 1] + 13 * d[i + 2]) % 1000000007;
            return sum;
        }"""

        def inferno_alone():
            """Jogo: Inferno alone. It starts, a held Right walks the hero off
            his starting place, no page errors."""
            page.goto(url)
            load()
            check(not page.is_disabled("#jogo option[value=inferno]"), "the loader offers Inferno alone")
            page.select_option("#jogo", "inferno")
            page.check('input[name="versao"][value="original"]')
            play()
            time.sleep(1)
            shot("inferno.png")
            before = page.evaluate(hero_js)
            page.keyboard.down("ArrowRight")
            time.sleep(1.5)
            page.keyboard.up("ArrowRight")
            time.sleep(0.3)
            after = page.evaluate(hero_js)
            shot("inferno-walk.png")
            check(before is not None and after is not None and before != after,
                  "Inferno runs: a held Right walks the hero")
            check(not errors, "Inferno: no page errors")

        def inferno_touch():
            """Inferno alone on a touch screen: the pad's keys are the four
            arrows and a held ▶ walks the hero."""
            tctx = browser.new_context(viewport={"width": 844, "height": 390}, has_touch=True, is_mobile=True)
            tpage = tctx.new_page()
            terrors = []
            tpage.on("pageerror", lambda e: terrors.append(str(e)))
            tpage.goto(url)
            tpage.wait_for_function("window.noite.ready || window.noite.failure", timeout=600_000)
            tpage.select_option("#jogo", "inferno")
            tpage.click("#play")
            tpage.wait_for_function("window.noite.started || window.noite.failure", timeout=60_000)
            time.sleep(1)
            shown = tpage.evaluate("""() => Array.from(document.querySelectorAll('#dpad button'))
                .filter((b) => !b.hidden).map((b) => Number(b.dataset.key))""")
            check(sorted(shown) == [37, 38, 39, 40], f"touch Inferno: the pad shows the four arrows ({shown})")
            before = tpage.evaluate(hero_js)
            right = tpage.locator('#dpad [data-key="39"]').bounding_box()
            cdp = tctx.new_cdp_session(tpage)
            cdp.send("Input.dispatchTouchEvent", {"type": "touchStart",
                     "touchPoints": [{"x": right["x"] + right["width"] / 2, "y": right["y"] + right["height"] / 2}]})
            time.sleep(1.5)
            cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})
            time.sleep(0.3)
            tpage.screenshot(path=str(out / "inferno-touch.png"))
            check(tpage.evaluate(hero_js) != before, "touch Inferno: a held ▶ walks the hero")
            check(not terrors, "touch Inferno: no page errors")
            tctx.close()

        # SAUNA's score box (416-608, 437-457) shows " 0100" from the start
        # (Pacman eats the peanut he is placed on) until he eats another
        # one or a ghost catches him, which takes far longer than the 2 s
        # here; Left runs him along row 19, a peanut every other cell.
        score_js = """() => {
            const d = document.getElementById("screen").getContext("2d").getImageData(416, 437, 192, 20).data;
            let sum = 0;
            for (let i = 0; i < d.length; i += 4) sum = (sum * 31 + d[i] + 7 * d[i + 1] + 13 * d[i + 2]) % 1000000007;
            return sum;
        }"""

        def sauna_alone():
            """Jogo: Sauna Mista alone. It starts, Left runs Pacman and his
            peanuts change the score box, no page errors."""
            page.goto(url)
            load()
            check(not page.is_disabled("#jogo option[value=sauna]"), "the loader offers Sauna Mista alone")
            page.select_option("#jogo", "sauna")
            page.check('input[name="versao"][value="original"]')
            play()
            time.sleep(1)
            shot("sauna.png")
            before = page.evaluate(score_js)
            page.keyboard.press("ArrowLeft")
            time.sleep(1)
            after = page.evaluate(score_js)
            shot("sauna-run.png")
            check(before is not None and after is not None and before != after,
                  "Sauna Mista runs: Left runs Pacman over the peanuts")
            check(not errors, "Sauna Mista: no page errors")

        def sauna_touch():
            """Sauna Mista alone on a touch screen: the pad's keys are the four
            arrows and ◀ runs Pacman over the peanuts."""
            tctx = browser.new_context(viewport={"width": 844, "height": 390}, has_touch=True, is_mobile=True)
            tpage = tctx.new_page()
            terrors = []
            tpage.on("pageerror", lambda e: terrors.append(str(e)))
            tpage.goto(url)
            tpage.wait_for_function("window.noite.ready || window.noite.failure", timeout=600_000)
            tpage.select_option("#jogo", "sauna")
            tpage.click("#play")
            tpage.wait_for_function("window.noite.started || window.noite.failure", timeout=60_000)
            time.sleep(1)
            shown = tpage.evaluate("""() => Array.from(document.querySelectorAll('#dpad button'))
                .filter((b) => !b.hidden).map((b) => Number(b.dataset.key))""")
            check(sorted(shown) == [37, 38, 39, 40], f"touch Sauna Mista: the pad shows the four arrows ({shown})")
            before = tpage.evaluate(score_js)
            tpage.locator('#dpad [data-key="37"]').tap()
            time.sleep(1)
            tpage.screenshot(path=str(out / "sauna-touch.png"))
            check(tpage.evaluate(score_js) != before, "touch Sauna Mista: ◀ runs Pacman over the peanuts")
            check(not terrors, "touch Sauna Mista: no page errors")
            tctx.close()

        def sauna_corrigida():
            """Jogo: Sauna Mista alone in the Corrigida (the arcade rules): the
            controls screen is up (the score box is still " 0100" under it),
            Enter takes it down, a second of READY, then Pacman runs left on
            his own and eats peanuts; WASD steer."""
            page.goto(url)
            load()
            page.select_option("#jogo", "sauna")
            page.check('input[name="versao"][value="corrigida"]')
            play()
            time.sleep(1.5)
            shot("sauna-controls.png")
            before = page.evaluate(score_js)
            time.sleep(1.5)
            check(page.evaluate(score_js) == before, "Corrigida Sauna Mista: the game stands under the controls screen")
            page.keyboard.press("Enter")
            time.sleep(3)
            shot("sauna-arcade.png")
            check(page.evaluate(score_js) != before, "Corrigida Sauna Mista: after the READY second Pacman runs and eats peanuts")
            page.keyboard.press("w")
            time.sleep(0.5)
            page.keyboard.press("d")
            time.sleep(0.5)
            check(not errors, "Corrigida Sauna Mista: no page errors")

        def sauna_corrigida_touch():
            """Sauna Mista alone in the Corrigida on a phone: the pad shows the
            four arrows; a tap on one takes the controls screen down, and
            Pacman runs."""
            tctx = browser.new_context(viewport={"width": 844, "height": 390}, has_touch=True, is_mobile=True)
            tpage = tctx.new_page()
            terrors = []
            tpage.on("pageerror", lambda e: terrors.append(str(e)))
            tpage.goto(url)
            tpage.wait_for_function("window.noite.ready || window.noite.failure", timeout=600_000)
            tpage.select_option("#jogo", "sauna")
            tpage.check('input[name="versao"][value="corrigida"]')
            tpage.click("#play")
            tpage.wait_for_function("window.noite.started || window.noite.failure", timeout=60_000)
            time.sleep(1.5)
            shown = tpage.evaluate("""() => Array.from(document.querySelectorAll('#dpad button'))
                .filter((b) => !b.hidden).map((b) => Number(b.dataset.key))""")
            check(sorted(shown) == [37, 38, 39, 40], f"Corrigida touch Sauna Mista: the pad shows the four arrows ({shown})")
            before = tpage.evaluate(score_js)
            tpage.locator('#dpad [data-key="38"]').tap()
            time.sleep(3.5)
            tpage.screenshot(path=str(out / "sauna-corrigida-touch.png"))
            check(tpage.evaluate(score_js) != before, "Corrigida touch Sauna Mista: a tap takes the screen down and Pacman runs")
            check(not terrors, "Corrigida touch Sauna Mista: no page errors")
            tctx.close()

        # JARDIM's minimap (114x160 at 513, 42): the player's red square
        # moves with every step; the hands (145-495, 261-341) punch while
        # Ctrl is held.
        def region_js(x, y, w, h):
            return """() => {
                const d = document.getElementById("screen").getContext("2d").getImageData(%d, %d, %d, %d).data;
                let sum = 0;
                for (let i = 0; i < d.length; i += 4) sum = (sum * 31 + d[i] + 7 * d[i + 1] + 13 * d[i + 2]) %% 1000000007;
                return sum;
            }""" % (x, y, w, h)
        minimap_js = region_js(513, 42, 114, 160)
        hands_js = region_js(145, 261, 350, 80)

        def jardim_alone():
            """Jogo: Jardim alone. It starts, a held Up walks the player (the
            minimap's square moves), a held Ctrl punches, no page errors."""
            page.goto(url)
            load()
            check(not page.is_disabled("#jogo option[value=jardim]"), "the loader offers Jardim alone")
            page.select_option("#jogo", "jardim")
            page.check('input[name="versao"][value="original"]')
            play()
            time.sleep(1.5)
            shot("jardim.png")
            before = page.evaluate(minimap_js)
            page.keyboard.down("ArrowUp")
            time.sleep(0.6)
            page.keyboard.up("ArrowUp")
            time.sleep(0.3)
            after = page.evaluate(minimap_js)
            shot("jardim-walk.png")
            check(before is not None and after is not None and before != after,
                  "Jardim runs: a held Up walks the player on the minimap")
            hands = page.evaluate(hands_js)
            page.keyboard.down("Control")
            time.sleep(0.3)
            punch = page.evaluate(hands_js)
            shot("jardim-punch.png")
            page.keyboard.up("Control")
            check(punch != hands, "Jardim: a held Ctrl punches")
            check(not errors, "Jardim: no page errors")

        def jardim_touch():
            """Jardim alone on a touch screen: the pad's keys are the arrows,
            Abrir (SPACE) and Tiro (CTRL), and a held ▲ walks."""
            tctx = browser.new_context(viewport={"width": 844, "height": 390}, has_touch=True, is_mobile=True)
            tpage = tctx.new_page()
            terrors = []
            tpage.on("pageerror", lambda e: terrors.append(str(e)))
            tpage.goto(url)
            tpage.wait_for_function("window.noite.ready || window.noite.failure", timeout=600_000)
            tpage.select_option("#jogo", "jardim")
            tpage.click("#play")
            tpage.wait_for_function("window.noite.started || window.noite.failure", timeout=60_000)
            time.sleep(1.5)
            shown = tpage.evaluate("""() => Array.from(document.querySelectorAll('#dpad button'))
                .filter((b) => !b.hidden).map((b) => [Number(b.dataset.key), b.textContent])""")
            keys = sorted(k for k, _ in shown)
            check(keys == [17, 32, 37, 38, 39, 40], f"touch Jardim: the pad shows the arrows, SPACE and CTRL ({shown})")
            labels = dict(shown)
            check(labels.get(32) == "Abrir" and labels.get(17) == "Tiro", f"touch Jardim: SPACE opens, CTRL fires ({labels})")
            before = tpage.evaluate(minimap_js)
            up = tpage.locator('#dpad [data-key="38"]').bounding_box()
            cdp = tctx.new_cdp_session(tpage)
            cdp.send("Input.dispatchTouchEvent", {"type": "touchStart",
                     "touchPoints": [{"x": up["x"] + up["width"] / 2, "y": up["y"] + up["height"] / 2}]})
            time.sleep(0.6)
            cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})
            time.sleep(0.3)
            tpage.screenshot(path=str(out / "jardim-touch.png"))
            check(tpage.evaluate(minimap_js) != before, "touch Jardim: a held ▲ walks the player")
            check(not terrors, "touch Jardim: no page errors")
            tctx.close()

        def jardim_corrigida():
            """Jardim alone in the Corrigida: the controls screen is up and
            a held W does not walk under it (its press takes the screen
            down); then Enter is not needed again: a held W walks, a held A
            strafes (the minimap's square moves) and Space punches."""
            page.goto(url)
            load()
            page.select_option("#jogo", "jardim")
            page.check('input[name="versao"][value="corrigida"]')
            play()
            time.sleep(1.5)
            shot("jardim-controls.png")
            page.keyboard.down("w")
            time.sleep(0.3)
            before = page.evaluate(minimap_js)
            time.sleep(0.6)
            held = page.evaluate(minimap_js)
            page.keyboard.up("w")
            time.sleep(0.3)
            check(held == before, "Corrigida Jardim: the key that takes the controls screen down does not walk")
            page.keyboard.down("w")
            time.sleep(0.6)
            page.keyboard.up("w")
            time.sleep(0.3)
            walked = page.evaluate(minimap_js)
            shot("jardim-corrigida-walk.png")
            check(walked != before, "Corrigida Jardim: a held W walks the player on the minimap")
            page.keyboard.down("a")
            time.sleep(0.4)
            page.keyboard.up("a")
            time.sleep(0.3)
            check(page.evaluate(minimap_js) != walked, "Corrigida Jardim: a held A strafes")
            hands = page.evaluate(hands_js)
            page.keyboard.down(" ")
            time.sleep(0.3)
            punch = page.evaluate(hands_js)
            page.keyboard.up(" ")
            check(punch != hands, "Corrigida Jardim: a held Space punches")
            # The weapon keys and the wheel (no weapon owned: nothing to switch to, nothing may break).
            for k in ("1", "2", "3", "q"):
                page.keyboard.press(k)
            page.mouse.move(320, 200)
            page.mouse.wheel(0, 120)
            time.sleep(0.3)
            check(not errors, "Corrigida Jardim: no page errors")

        def jardim_corrigida_touch():
            """Jardim alone in the Corrigida on a phone: the pad shows the
            arrows, the two strafes, Abrir (E) and Tiro (CTRL); a tap takes
            the controls screen down and a held ▲ walks."""
            tctx = browser.new_context(viewport={"width": 844, "height": 390}, has_touch=True, is_mobile=True)
            tpage = tctx.new_page()
            terrors = []
            tpage.on("pageerror", lambda e: terrors.append(str(e)))
            tpage.goto(url)
            tpage.wait_for_function("window.noite.ready || window.noite.failure", timeout=600_000)
            tpage.select_option("#jogo", "jardim")
            tpage.check('input[name="versao"][value="corrigida"]')
            tpage.click("#play")
            tpage.wait_for_function("window.noite.started || window.noite.failure", timeout=60_000)
            time.sleep(1.5)
            shown = tpage.evaluate("""() => Array.from(document.querySelectorAll('#dpad button'))
                .filter((b) => !b.hidden).map((b) => [Number(b.dataset.key), b.textContent])""")
            keys = sorted(k for k, _ in shown)
            check(keys == [17, 37, 38, 39, 40, 65, 68, 69, 81],
                  f"Corrigida touch Jardim: the pad shows the arrows, A, D, E, CTRL and Q ({shown})")
            labels = dict(shown)
            check(labels.get(81) == "Arma", f"Corrigida touch Jardim: Q is the 'Arma' (next weapon) button ({labels})")
            weapon = tpage.locator('#dpad [data-key="81"]').bounding_box()
            fire = tpage.locator('#dpad [data-key="17"]').bounding_box()
            vp = tpage.viewport_size
            check(weapon is not None and fire is not None and weapon["y"] >= fire["y"] + fire["height"] - 1
                  and weapon["x"] >= 0 and weapon["y"] + weapon["height"] <= vp["height"]
                  and weapon["x"] + weapon["width"] <= vp["width"],
                  f"Corrigida touch Jardim: 'Arma' sits under Tiro, on the screen ({weapon}, {fire})")
            tpage.locator('#dpad [data-key="81"]').tap()
            check(labels.get(69) == "Abrir" and labels.get(17) == "Tiro" and "Lado" in labels.get(65, ""),
                  f"Corrigida touch Jardim: E opens, CTRL fires, A and D strafe ({labels})")
            up = tpage.locator('#dpad [data-key="38"]')
            up.tap()
            time.sleep(0.5)
            before = tpage.evaluate(minimap_js)
            box = up.bounding_box()
            cdp = tctx.new_cdp_session(tpage)
            cdp.send("Input.dispatchTouchEvent", {"type": "touchStart",
                     "touchPoints": [{"x": box["x"] + box["width"] / 2, "y": box["y"] + box["height"] / 2}]})
            time.sleep(0.6)
            cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})
            time.sleep(0.3)
            tpage.screenshot(path=str(out / "jardim-corrigida-touch.png"))
            check(tpage.evaluate(minimap_js) != before, "Corrigida touch Jardim: a held ▲ walks the player")
            check(not terrors, "Corrigida touch Jardim: no page errors")
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
                        r' data-manifest="manifest\.json\?h=[0-9a-f]{16}" data-release="[^"]+"', html) is not None,
              "index.html loads noite.js, the wasm and the manifest by hash")
        if not args.url:
            plain = [r for r in Handler.requests if r not in ("/", "/favicon.ico") and "?h=" not in r]
            check(not plain, f"every request but the page's carries ?h= ({plain[:3]})")
            check(not any(r.startswith("/explorer/") for r in Handler.requests),
                  "the game page downloads none of the asset explorer's files")
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
        r = save_report(page, "1fquarbo")
        check(r["state"]["inventory"] == [] and r["version"] == "Original",
              "the bedroom's report: nothing carried, the Original version")
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
        # Hidden and shown again: the next click replaces the context (iOS can
        # leave the old one silent while it says "running"), once.
        n0 = page.evaluate("window.noite.audioContexts")
        page.evaluate("Object.defineProperty(document, 'visibilityState', {value: 'hidden', configurable: true});"
                      "document.dispatchEvent(new Event('visibilitychange'));"
                      "Object.defineProperty(document, 'visibilityState', {value: 'visible', configurable: true});"
                      "document.dispatchEvent(new Event('visibilitychange'))")
        click(5, 5)
        time.sleep(0.5)
        click(5, 5)
        time.sleep(0.5)
        check(page.evaluate("[window.noite.audioContexts - %d, window.noite.audioState]" % n0) == [1, "running"],
              "after the page was hidden a click makes one new running audio context")
        # A phone back from another app: blur, hidden, visible, and no focus
        # event. The game must be active again (its sound unpaused).
        page.evaluate("window.dispatchEvent(new Event('blur'));"
                      "Object.defineProperty(document, 'visibilityState', {value: 'hidden', configurable: true});"
                      "document.dispatchEvent(new Event('visibilitychange'))")
        check(page.evaluate("window.noite.active") is False, "a hidden page deactivates the game")
        page.evaluate("Object.defineProperty(document, 'visibilityState', {value: 'visible', configurable: true});"
                      "document.dispatchEvent(new Event('visibilitychange'))")
        check(page.evaluate("window.noite.active") is True, "showing the page again activates the game, without a focus event")
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
        minigame_alone()
        tiro_alone()
        tiro_touch()
        serial_alone()
        serial_touch()
        salgin_alone()
        salgin_touch()
        inv_alone()
        inv_touch()
        xilindro_alone()
        xilindro_touch()
        xilindro_corrigida_touch()
        salgin_corrigida_touch()
        inferno_alone()
        inferno_touch()
        sauna_alone()
        sauna_touch()
        sauna_corrigida()
        sauna_corrigida_touch()
        jardim_alone()
        jardim_touch()
        jardim_corrigida()
        jardim_corrigida_touch()
        browser.close()
    if not args.url:
        httpd.shutdown()
    print(f"screenshots in {out}")


if __name__ == "__main__":
    main()
