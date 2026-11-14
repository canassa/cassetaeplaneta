# Web build

The port running in a browser: the same game code compiled to
`wasm32-wasi` with Zig's self-hosted wasm backend and linker (no LLVM),
a `web` platform backend (`src/platform/web.zig`) and a small hand-written
page (`web/index.html`, `web/noite.js`). It is served as a static site at
https://cassetaeplaneta.canassa.com.

## Building

```sh
nix develop -c tools/web/build-site.sh [OUT]     # default zig-out/site
```

The script runs `zig build web` (→ `zig-out/web/`: the page, `noite.wasm`,
`manifest.json`), then makes OUT a self-contained site: it copies the page,
the disc files the manifest lists (from `assets/`) and the SoundFont
(`$NOITE_SOUNDFONT`, the dev shell's GeneralUser GS from the nix store),
and stamps it with content hashes (`tools/web/stamp.py`, see Caching
below) and with the release id and the commit, which the page puts in its
reports (`data-release`, `data-commit` on the script tag: `$NOITE_RELEASE`,
set by `tools/deploy-web.sh` to the server's `releases/<id>` name, else
`local`; `git describe --always --dirty`). OUT is deleted and rebuilt.

Site layout:

```
OUT/
  index.html          the page: the only file loaded without a hash
  noite.js            loader + runtime (no frameworks, no bundler)
  noite.wasm          the game (~3.3 MB, Debug)
  manifest.json       files to download (with their hashes), DOS path → file
  assets/…            753 disc files under their real (upper-case) names
  soundfont/GeneralUser-GS.sf2
```

Download: **753 files, 188.5 MB** (156 MB of disc files + the 32 MB
SoundFont), against 547 MB for the whole disc.

## Serving (nginx)

Plain static files; no COOP/COEP (no SharedArrayBuffer, no threads) and no
server logic. Needs:

- **HTTPS** (Cloudflare is fine): Cache Storage, where the page keeps the
  downloaded files, exists only in secure contexts. Over plain HTTP the
  game still runs but downloads everything on every visit.
- **MIME**: serve `.wasm` as `application/wasm` (the page instantiates
  from bytes, so it would work without, but streaming compilation, gzip
  rules and proxies key on it; recent nginx `mime.types` files have it —
  add `application/wasm wasm;` if yours does not). Everything else can be
  the defaults
  (`.INI`/`.RLE`/`.FON`/`.SF2` as `application/octet-stream`).
- **Case**: URLs use the files' real names (`assets/FASE1/1FCORRED/…BMP`),
  exactly as copied; nothing relies on case-insensitive matching.
- **Caching**: every file but `index.html` is requested with its
  content hash, `url?h=<hash>` (the first 16 hex digits of its SHA-256).
  `tools/web/stamp.py` writes them: the manifest gets each disc file's
  `hash`, and `index.html`'s script tag becomes `<script
  src="noite.js?h=…" data-wasm="noite.wasm?h=…"
  data-manifest="manifest.json?h=…">`; noite.js reads the two data
  attributes and the manifest, so a page always runs the JS, wasm and
  files of its own build. Headers:
  - `index.html` (and `/`): `Cache-Control: no-cache` (revalidate,
    ETag/Last-Modified as nginx sends them) — the only entry point.
  - any request with an `h` query argument: `Cache-Control: public,
    max-age=31536000, immutable` — the URL changes when the content does.
  - the other files without `h`: `no-cache`. Only a page from before the
    hashes, still open during a deploy, asks for those.

  Cloudflare's browser TTL (4 h on its "static" extensions such as `.js`)
  raised `no-cache` to `max-age=14400` on the old fixed `noite.js`, so a
  browser could pair a stale JS with a new wasm; with hashed URLs a stale
  copy is never asked for. Cloudflare's default cache key includes the
  query string, so its edge keeps one copy per hash.

  The page keeps the files in Cache Storage (`noite.files`), keyed by the
  hashed URLs: after a deploy only the files whose hash changed are
  downloaded, and once the load ends the entries the manifest no longer
  lists are deleted. Caches of the loader before the hashes
  (`noite-<version>`, keyed by plain URLs) are read once: a file whose
  content has the manifest's hash (SHA-256 in the page) moves to the new
  cache, then the old caches are deleted.
- **Compression** (optional, saves bandwidth): gzip `application/wasm`,
  `application/javascript`, `application/json`, `text/html`, and the disc
  files (`image/bmp`, `audio/wav`/`audio/x-wav`, `application/octet-stream`
  — 8-bit BMPs and PCM shrink well; AVIs are already compressed).
  The page checks sizes after decompression, so transfer encoding is fine.
- **Cloudflare**: its default edge cache goes by file extension and skips
  some of the disc's (`.INI`, `.RLE`, `.FON`, `.SF2`, `.wasm`); add a
  Cache Rule for `/assets/*` and `/soundfont/*` if they should be cached
  at the edge.

```nginx
server {
    server_name cassetaeplaneta.canassa.com;
    root /srv/cassetaeplaneta;          # OUT
    types { application/wasm wasm; }    # if mime.types lacks it
    include mime.types;

    gzip on;
    gzip_types application/wasm application/javascript application/json
               image/bmp audio/wav audio/x-wav application/octet-stream;

    location / {
        add_header Cache-Control $noite_cache always;
        try_files $uri $uri/ =404;
    }
    location = /index.html {
        add_header Cache-Control "no-cache" always;
    }
}

# http block: hashed URLs are immutable, the rest revalidates.
map $arg_h $noite_cache {
    ""      "no-cache";
    default "public, max-age=31536000, immutable";
}
```

## How it works

- **Files.** The game reads files synchronously (DOS open/read/seek), so
  the page downloads all of them before starting: `manifest.json` lists
  them, six fetches run at a time, each retried 4 times with backoff, with
  a progress bar (bytes, %, file count) and an error box naming the file
  that failed. Downloaded files go to Cache Storage; a returning visitor
  loads them from there ("Carregando do cache…", well under a second
  locally). The wasm then reads them through `js_file_size`/`js_file_read`
  by key: the DOS path normalised by `sim.hostKey` (drive dropped, `\` →
  `/`, lower case), which settles DOS case-insensitivity at build time.
- **Which files.** `tools/web/files.txt`, generated by
  `tools/web/files.py`: every name in `CASSETA.INI` and in the port's
  string literals, expanded the way the engine builds paths (`.bmp`,
  `.wav`, `.rle`, `.avi`, numbered frames) and resolved through the
  engine's fallback chains (`pan\bmp`, `pan\wav`, `hd\` → name →
  `pan\avi`), keeping only the first file of a chain that exists; plus
  the fixed names (CASSETA.INI, CASSETUP.INI, JOGO*.INI, the save slots
  HD\JOGO*.INI, MSSVGA\VGASYS.FON). `--trace` merges `strace -f -e
  trace=openat` logs of native runs and `--check` fails if one opened a
  file the static rules missed — run over the playthrough and six smoke
  runs (plain, `--offers`, `--lose`, `--monkey 1-3`), none was missing.
  Left out: the minigame directories and EXEs (the minigames are
  stubbed), installers, drivers, the other fonts, unreferenced files.
  `manifest.py` downloads identical files once: `HD\*.AVI` clips that are
  copies of `PAN\AVI\*` are fetched from there (only `HD/2ABUSVOM.AVI`
  has no twin). Regenerate files.txt when the engine starts opening new
  names.
- **Options.** The loader offers the version — *Original* (the
  original's bugs reproduced, the native default) or *Corrigida* (every
  BUGS.md fix, `Fixes.all()`, as `--fix all`) — and "Pular vídeos com
  clique ou Esc" (on by default; `--skip-videos` natively, off there) and
  "Controle com um botão" (on by default on a touch screen, `(pointer:
  coarse)`, else off; `--one-button` natively). The
  Jogar button starts the game (and the AudioContext: it is a user
  gesture) once the files are loaded; the choice is kept in localStorage
  (`noite:prefs`, the page works without it) and passed to
  `noite_start(fixes, skip_videos, one_button)`. A line under the canvas names the
  version and reloads into the other one (`?versao=corrigida|original`,
  after a confirm); the game itself never sees it. `noite_options` reports
  what the wasm got (`window.noite.fixes`, `.skipVideos`, `.oneButton`,
  for the test; `noite_inventory`, `.inventory`, counts the items carried).
- **Skipping videos** is a platform option, not a fix (`Sim.filterInput`,
  through `Platform.filterInput` on every backend): a left/right button
  press or Esc/Enter/Space while an AVI clip plays moves the clip's
  pending MM_MCINOTIFY (successful) to now and stops its frames and sound,
  so every scene and handler continues as on a natural end, with exactly
  one notification. The press and its release are kept from the game;
  once the end is delivered, input passes as usual. The page sends Esc,
  Enter and Space to the wasm only when the option is on.
- **One-button control** (`src/one_button.zig`; not a fix, any version):
  a filter in front of the window procedure (`Game.oneButton`, seen by
  `Game.dispatchPending` before the message is dispatched) turns left
  presses into the original's right-button actions, as real messages, so
  scene handlers see a right click. In a scene with the player, a click
  on an exit, an item, an animation (or an object a handler acts on) is a
  right click on it — an exit out of reach (`game_input.exitInReach`) is
  walked to first, horizontally, and right-clicked when the walk ends
  (0x404); a new press, a key or a scene change cancels that — and any
  other click walks. A click counts for an object when it is on it or
  left of/above it within the original's 16-pixel probe (not on the cells
  that overhang its bottom: the floor under a door walks); a tall
  non-exit hotspot (a character, the corridor's invisible bathroom door)
  only in its upper two thirds. Without the player every press is the
  right button, except in the menus (fundinic, fundini1, salvar2),
  click-to-continue and one-animation scenes. On the open panel: Opções;
  an inventory slot selects its item — released on the same slot (a tap)
  it stays selected, with its icon (`Screen.overlay`) at the pointer,
  until the next click drops or offers it there (on the panel: put back);
  released elsewhere (a drag) it is dropped or offered there. The bottom
  strip that slides the panel open does not walk. Off, nothing changes
  (the traces of `tools/play/full.input` are identical). Original bugs stay
  reachable as with right clicks: a knock on the bathroom door leaves its
  animation timer on (B21 then ends the garden video into 4fbar), a tap on
  the 4fbarboy boys reaches B24's crash in the Original version.
  The page also shows on-screen arrows (`#dpad`, in a strip the game
  leaves on its right or below it, whichever keeps the game larger): held, they hold
  the arrow keys, for the walks a click's straight line can't make (past
  the cat in 1fsala).
- **Loop.** `noite_frame` (`src/web_main.zig`), called on every
  `requestAnimationFrame`, is one turn of `main.zig`'s message loop
  without the wait: deliver platform events, dispatch every due message,
  present. Same game code, same message order; the clock is
  `performance.now()`.
- **Screen.** The 8-bit screen goes through the palette to RGBA once per
  frame when it changed (`js_present` → `putImageData`); the canvas is
  638×459, the original's client area (only that top-left part of the 640×480
  framebuffer is drawn), scaled by CSS with `image-rendering: pixelated` to
  the largest size the window allows with its aspect ratio (fractional,
  snapped to device pixels), centred on a black letterbox and refitted on
  every resize, orientation change or fullscreen switch; clicks map
  through the canvas's bounding box, exact at any scale. The version
  switch and a fullscreen button (when the browser has the Fullscreen API)
  sit in the letterbox when it has room for them, else as a faint overlay
  in the top right corner that lights up on hover or tap.
- **Input.** Pointer events → WM_MOUSEMOVE/L/RBUTTONDOWN/UP in screen
  pixels (a touch is the left button: move + down at the touch, up at the
  release; `pointercancel` releases too); the canvas takes no browser
  gestures (`touch-action: none`, no callout or selection, no context
  menu); the arrow keys (and, to skip videos, Esc/Enter/Space) →
  WM_KEYDOWN/UP; window focus → WM_ACTIVATE.
- **Audio.** The mixer (`mixer.zig`: WaveMix channels, MCI wave, AVI
  track, MIDI through TinySoundFont, built with Zig's bundled clang
  against wasi-libc) is pulled in 2048-frame chunks of 44.1 kHz stereo
  and scheduled as WebAudio buffers ~150 ms ahead. The AudioContext is
  created on the first click or key press (autoplay policy); until then
  the mix is rendered and dropped so it stays in time.
- **Saves.** `JOGO*.INI` writes go to `localStorage`
  (`noite:save:hd/jogo1.ini`, base64) and are read before the disc's.
  The Corrigida version keeps its own (`noite:corrigida:save:…`): a save
  can hold what only one version produces (a 32-bit score, B19; a scene
  only the fixes reach), so the versions never load each other's.
- **Minigames.** Stubbed as in the native port (a win after a few
  seconds); while one "runs" the page shows a note instead of the canvas.
- **Message boxes** are logged to the console and answered with their
  first button, like the SDL backend.

## Bug reports

The tools bar (with the version switch and fullscreen) lets a player
send us the game's state instead of describing it. The file goes to the
share sheet where the browser can share it (a phone: straight to a chat
or mail), else it is downloaded.

- **Relatório** (`#reportbtn`): `noite-<release>-<scene>-<UTC time>.json`
  (~250 kB): release, commit, the wasm's and noite.js's hashes, version,
  skip-videos, one-button, user agent, viewport, the canvas as a PNG data
  URL, and `state`, the JSON of `noite_report` (`src/platform/report.zig`):
  the scene (name, number, flags, scroll), the previous scene number,
  lives, score, inputLocked, exitPending, aviPlaying, itemSelected and
  selectedItem, the drag and one-button state, the panel, the player
  (position, strip, frame, moving, allowOffscreen, target), the inventory
  and used items (id and bitmap name), every object of the scene's list
  and of the draw list (id, kind, bitmap or clip name, x, y, visible,
  strip, frame, dirty and clip rects, timers and whether they are armed,
  an exit's target), the update list, every portable of the game (id,
  name, scene, previous and home scene, which list holds it, owner,
  visible, x, y, elevation), the armed timers, the queue's counts and the
  last 64 messages (the panic report's trail). Names are the objects'
  bitmap files (`Dib.name`, kept by `dib.loadDib` for this; an item in
  the inventory has only its icon's, `<name>2`). The native harness writes
  the same JSON with the script command `report FILE`.

## Testing

```sh
nix develop -c tools/web/build-site.sh
nix develop .#web -c python3 tools/web/test.py
```

`tools/web/test.py` serves the site on a local port, with the headers
above, and drives headless Chromium (Playwright, from the `web` dev
shell): index.html loads noite.js, the wasm and the manifest by hash and
every other request carries `h=`; a seeded cache of the loader before the
hashes is migrated (good files reused, a corrupted one downloaded) and
deleted; the loader finishes, no
AudioContext exists before a gesture and one runs after Jogar, the wasm
gets the Original version with video skipping, a click 3 s into the
opening video reaches the title screen, JOGAR + NOVO JOGO start the
new-game video and Esc skips it to the bedroom, a right click opens the
desk drawer, sound reaches WebAudio; at 1920×1080, two phone sizes, an
exact 2× and 1280×960 the canvas fills the window in one dimension,
centred with its aspect ratio, and the buttons stay off the game unless
the letterbox has no room (`window-WxH.png`); then the version button
reloads into
the Corrigida version, which loads every file from Cache Storage, has
every fix on in the wasm and is remembered; a drag there shows the item,
and with the player behind the open panel no frame the page presents
cuts the panel as it starts closing (B48, `panel-close.png`).
Relatório downloads a report with the scene, a screenshot and the
inventory (empty in the bedroom; the wallet in the Corrigida corridor).
Then a phone-sized touch context (`has_touch`): the one-button control is
on by default and reaches the wasm, and with `touchscreen.tap` only the
videos are skipped, a new game starts, the drawer gives the wallet, a
tap on the door walks the player out to the corridor, a tap on the
wallet's slot and one in the scene drop it, a tap on it takes it back
(`touch-corridor.png`, `touch-drop.png`), and a held ◀ on the
on-screen arrows walks (`touch-dpad.png`). Last, a simulated deploy: a
hard-linked copy of the site with `noite.js` and one disc file changed,
restamped and served at the same origin; the reload downloads only that
file, runs the new `noite.js`, drops the stale cache entry and starts the
game. Screenshots go to
`zig-out/web-test/` (`title.png`, `bedroom.png`, `drawer.png`,
`window-*.png`, `cache.png`).
