# Casseta & Planeta — Noite Animal

Reverse engineering of *Casseta & Planeta – Noite Animal* (ATR Multimedia,
1995), a Brazilian point-and-click adventure for Windows 3.1.

- `assets/` — the game disc, extracted (executables, `CASSETA.INI` scene
  data, bitmaps, AVI clips, WAV sounds).
- `ghidra/` — Ghidra 12.2 project, scripts and calling-convention extensions.
- `toolchain/ghidra-mcp` — the Ghidra MCP server used to drive the analysis.
- `CLAUDE.md` — binary facts, architecture notes and naming conventions.

## Running the port

The native port (Zig 0.17, `src/`, design in `docs/DESIGN.md`) runs from the
dev shell (`nix develop`, which also sets `$NOITE_SOUNDFONT` for the music):

```sh
nix develop -c zig build                       # Debug, self-hosted backend
nix develop -c ./zig-out/bin/noite             # the game in an SDL3 window
./zig-out/bin/noite --headless --ms 60000      # no window, virtual clock
```

Original bugs are reproduced; `--fix all` (or `--fix name,…`, `all,-name` to leave one out, see
`src/core/fixes.zig` and `BUGS.md`) turns their fixes on. Videos play to
the end as in the original; `--skip-videos` lets a click, a right click or
Esc/Enter/Space end one (a convenience, not a fix). `--one-button` plays
with the left button alone (`src/one_button.zig`, for touch screens): a
click on a door, an item or a character does what a right click did (the
player walks over to a door first; a tap on the player walks, even over an
item he hides), anything else walks; an inventory
item is tapped then placed with the next click, or dragged. ENCAIXE
(3ffarao's Tetris, `src/encaixe/`, `docs/encaixe/DESIGN.md`) and TIRO
(3fhall's shooting gallery, `src/tiro/`, `docs/tiro/DESIGN.md`) are
ported: NOITE runs them as second programs (`src/platform/host.zig`), and
`--minigame encaixe|tiro` plays one alone. The other minigames (separate
EXEs) are stubbed, and the ported ones too with `--minigame-stub`: they
report a win, or a loss with `--minigame lose`; their window shows 1.5 s
after `WinExec` and answers the game's hello after 100 ms
(`--minigame-startup MS`, `--minigame-reply MS`). A held key repeats as on
Windows (500 ms, then every 33 ms; `--key-repeat DELAY,PERIOD|off`): on in
the window and the browser, off headless. A minigame gets every key
(TIRO: LEFT, RIGHT, SPACE); NOITE gets Enter, Esc and Space only to skip
videos.
Saves go to `save/` (`--save DIR`).

## Testing the port

- `zig build test` — unit tests; `uv run noite check|initdata` — the tracker
  (`noite -p encaixe …` for ENCAIXE).
- **Harness** (`src/platform/harness.zig`), for either backend:
  `--input FILE` plays timed input (`src/platform/script.zig`: `click`,
  `rclick`, `hold`, `offer`, `wait SCENE`, `expect SCENE`, `drawn ID 0|1`, `where ID`, `dump`, `state`,
  `report FILE` (the state as JSON, as the web page's Relatório),
  `focus 0|1`, `freeze MS` (a time jump: the clock runs on while nothing is
  dispatched, as in a hidden web page), `result won|lost|none [SCORE]` (the
  last real minigame's 0x40a), `quit`…; input goes to the active window's
  program), `--dump DIR [--dump-every MS]` writes PNG frames of the screen
  (and of the SDL window), `--scene NAME [--take ID,…]` starts in any INI
  scene carrying those items, `--trace FILE` logs every message. A panic or
  segfault prints the scene and the last 64 messages; a message loop that
  stops the clock is reported as a hang (`timeout -s SEGV` gives the stack
  of any other hang).
- **Smoke test**: `nix develop -c python3 tools/smoke.py [--offers|--monkey SEED [--freeze]|--lose] [SCENE…]`
  starts every INI scene and clicks around (`--freeze`: with random time jumps); failures keep their log in
  `zig-out/smoke/`. `--offers` gives the key items to every object (in the one-button mode by dragging and
  by tap-tap); the harness fails a run when an item a handler takes back had moved from where it was
  released (with B30's fix) or left its image on the screen (with B25's).
  `--scene 2fportdi --take 86 --fix all --ms 6000 --input tools/play/taxi-wine.input` checks that the wine
  given to the taxi driver is not drawn over his drinking animation (B45).
- **Playthrough**: `./zig-out/bin/noite --headless --ms 600000 --input tools/play/full.input`
  plays from the title screen to the sportsman ending, checking every scene
  (the hall's TIRO and the pharaoh's ENCAIXE with scripted wins).
  With the fixes: add `--fix all,-avi_exit_ignores_timer`
  (the script follows this run's hall doors and the 3fstreet shortcut of BUGS.md B21).
  One-button: `--one-button --ms 480000 --input tools/play/onebutton.input` (the
  whole game with left clicks only and TIRO's keys, doors clicked from afar, items dropped and
  offered by tap-tap and by dragging) and
  `--one-button --scene 1fquarbo --ms 30000 --input tools/play/onebutton-corridor.input`;
  `tools/smoke.py --one-button` runs the smoke test in that mode.
- **ENCAIXE**: `--minigame encaixe --ms 90000 --input tools/play/encaixe-win.input`
  (10 lines, `result won 1500`) and `--ms 20000 --input tools/play/encaixe-lose.input`
  (no input, -500); from NOITE, `--scene 3ffarao --ms 120000 --input
  tools/play/encaixe-3ffarao-win.input` (NOITE hides, gets the win, +1500, the hall) and
  `--ms 50000 --input tools/play/encaixe-3ffarao-lose.input` (a life less, 3fcasame); each
  the same with `--fix all`. The win moves come from `tools/encaixe_plan.py` (the pieces follow
  from the start time: rerun it when that moves). `tools/smoke.py --minigame encaixe
  [--monkey SEED]` presses random arrows for 60 s.
- **TIRO**: `--minigame tiro --ms 60000 --input tools/play/tiro-alone-win.input` (14 girls,
  `result won 2100`) and `tools/play/tiro-alone-lose.input` (-750); from NOITE, `--scene 3fhall
  --ms 40000 --input tools/play/tiro-3fhall-win.input` (NOITE hides, +2100, the prison) and
  `tools/play/tiro-3fhall-lose.input` (-1050, a life less, the hall); `--minigame tiro --ms 30000
  --key-repeat 500,33 --input tools/play/tiro-endless.input` holds SPACE (BUGS.md T1, T3: no
  result). Each the same with `--fix all`. The shots come from `tools/tiro_plan.py --start MS
  --win|--lose` (it simulates the game; the targets follow from TIRO's start time: rerun it when
  that moves; `--check FILE` simulates a script). `tools/smoke.py --minigame tiro [--monkey SEED]`
  presses random aim keys and SPACE for 60 s.
- **SDL without a display**: `SDL_VIDEODRIVER=offscreen SDL_AUDIODRIVER=dummy`
  (or `disk` with `SDL_AUDIO_DISK_OUTPUT_FILE=out.raw` to capture the mix).

## Web build

The same game in a browser (wasm32, self-hosted backend; design, layout
and the nginx setup in `docs/WEB.md`):

```sh
nix develop -c tools/web/build-site.sh            # site in zig-out/site/ (188 MB)
nix develop -c python3 -m http.server -d zig-out/site 8080   # http://localhost:8080
nix develop .#web -c python3 tools/web/test.py    # headless Chromium check
```

The page downloads the disc files the game opens (once; later visits load
them from Cache Storage) while the player picks the version (Original, or
Corrigida = `--fix all`), whether videos can be skipped (on by
default) and the one-button control (on by default on touch screens), then
runs the game; saves go to localStorage, apart per version. "Jogo" picks
the whole game or one ported minigame alone (Encaixe Perfeito, Tiro ao
Álvaro). On a touch screen the on-screen pad shows the keys of the window
on top: for TIRO ◀, a fire button and ▶.
