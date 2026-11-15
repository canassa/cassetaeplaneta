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
(3ffarao's Tetris, `src/encaixe/`, `docs/encaixe/DESIGN.md`), TIRO
(3fhall's shooting gallery, `src/tiro/`, `docs/tiro/DESIGN.md`), SERIAL
(3farmcai's Serial Killer, `src/serial/`, `docs/serial/DESIGN.md`), SALGIN
(4fsalgin's gym fight, `src/salgin/`, `docs/salgin/DESIGN.md`), INV
(4fsacaet's space invaders, `src/inv/`, `docs/inv/DESIGN.md`), XILINDRO
(3fstreet's jail fight, `src/xilindro/`, `docs/xilindro/DESIGN.md`), INFERNO
(3fpapmal's platformer in hell, `src/inferno/`, `docs/inferno/DESIGN.md`), SAUNA
(3fsauna's Pac-Man, `src/sauna/`, `docs/sauna/DESIGN.md`) and JARDIM (the garden's
first-person labyrinth after espquete and 4fjarvamp, `src/jardim/`, `docs/jardim/DESIGN.md`) are
ported: NOITE runs them as second programs (`src/platform/host.zig`), and
`--minigame encaixe|tiro|serial|salgin|inv|xilindro|inferno|sauna|jardim` plays one alone. The other minigames (separate
EXEs) are stubbed, and the ported ones too with `--minigame-stub` (only some with
`--minigame-stub=NAME,…`): they
report a win, or a loss with `--minigame-result lose`; their window shows 1.5 s
after `WinExec` and answers the game's hello after 100 ms
(`--minigame-startup MS`, `--minigame-reply MS`). A held key repeats as on
Windows (500 ms, then every 33 ms; `--key-repeat DELAY,PERIOD|off`), in
the window, the browser and headless runs. A minigame gets every key
(TIRO, SERIAL and INV: LEFT, RIGHT, SPACE; SALGIN and XILINDRO: the arrows, PgUp,
Home, End, Insert, and in the Corrigida A, S, D, F; INFERNO and SAUNA: the arrows; SAUNA also the left button; JARDIM: the arrows,
Ctrl to fire, Space for doors, Shift to run and Caps Lock held to strafe, read with `GetKeyState`); NOITE
gets Enter, Esc and Space only to skip videos, and never Shift, Ctrl or Caps Lock.
The fights' Corrigida keys (`--fix all`): ← / → walk, ↑ jumps, ↓ blocks, A punches, S and D
kick (middle and high; SALGIN's voadora and salto), F sweeps; a controls screen comes first (any
key or a click takes it down), then PORRADA stands for 2 s before the round starts; and the fight is
fair (`fight_fair`, `docs/fights/FAIRNESS.md`): the opponent stops within reach, shows each attack for
2 beats (its first frame and its sound) before it lands, and can be dodged (←), blocked (↓, not the
sweep), jumped (↑, the sweep) or hit first; F9 in a Debug build shows its state over the arena.
Saves go to `save/` (`--save DIR`).

## Testing the port

- `zig build test` — unit tests; `uv run noite check|initdata` — the tracker
  (`noite -p encaixe …` for ENCAIXE).
- **Harness** (`src/platform/harness.zig`), for either backend:
  `--input FILE` plays timed input (`src/platform/script.zig`: `click`,
  `rclick`, `hold`, `offer`, `wait SCENE`, `expect SCENE`, `drawn ID 0|1`, `pixel X Y INDEX`, `where ID`, `dump`, `state`,
  `report FILE` (the state as JSON, as the web page's Relatório),
  `focus 0|1`, `freeze MS` (a time jump: the clock runs on while nothing is
  dispatched, as in a hidden web page), `result won|lost|none [SCORE] [| won|lost|none [SCORE]]`
  (the last real minigame's 0x40a; the part after `|` is what a run with a `--fix` must get), `close` (the user closes the active window: WM_CLOSE), `quit`,
  `delay MS` (later lines move by MS), `keymap K1 K2` (later `key`/`hold` K1 press K2)…; a
  command after `?FLAG` runs only with that fix on, after `!FLAG` only with it off (a line
  that does not run is dropped with its time: the fights' scripts take the Corrigida's controls
  screen down this way); input goes to the active window's program), `--dump DIR [--dump-every MS]` writes PNG frames of the screen
  (and of the SDL window), `--scene NAME [--take ID,…]` starts in any INI
  scene carrying those items, `--trace FILE` logs every message. A panic or
  segfault prints the scene and the last 64 messages; a message loop that
  stops the clock is reported as a hang (`timeout -s SEGV` gives the stack
  of any other hang).
- **All scripts**: `nix develop -c tools/play_all.py [-j N] [NAME…]` builds once and runs every
  `tools/play/*.input` in parallel (about 20 s on 32 cores, 110 s serial). Each script's header comment
  lists its commands (the `zig-out/bin/noite …` lines; `[--dump DIR]` is dropped) and, for a run that must
  crash or exit nonzero as the original does, `expect-panic` / `expect-exit: N`. Logs in
  `zig-out/play-logs/`. Run it after touching engine, handler or minigame code.
- **Smoke test**: `nix develop -c python3 tools/smoke.py [--offers|--monkey SEED [--freeze]|--minigame-result lose] [SCENE…]`
  starts every INI scene and clicks around (`--freeze`: with random time jumps); failures keep their log in
  `zig-out/smoke/`. `--offers` gives the key items to every object (in the one-button mode by dragging and
  by tap-tap); the harness fails a run when an item a handler takes back had moved from where it was
  released (with B30's fix) or left its image on the screen (with B25's).
  `--scene 2fportdi --take 86 --fix all --ms 6000 --input tools/play/taxi-wine.input` checks that the wine
  given to the taxi driver is not drawn over his drinking animation (B45).
  `--fix all --ms 20000 --input tools/play/b52-corridor-frame-speck.input` checks that the player's
  pixels do not stay on the corridor's Mona Lisa (B52; the Original fails it).
  `--fix all --ms 4000 --input tools/play/sala-street-door.input` checks that a click at (20, 120) takes the
  living room's street exit (a Corrigida addition); `sala-street-door-orig.input` is the Original's miss.
- **Playthrough**: `./zig-out/bin/noite --headless --minigame-stub=jardim --ms 660000 --input tools/play/full.input`
  plays from the title screen to the sportsman ending, checking every scene
  (the hall's TIRO, the pharaoh's ENCAIXE and the gym's SALGIN with scripted wins; the
  street's XILINDRO runs unplayed over the hall, B21; the garden's JARDIM stays the stub's win).
  With the fixes: add `--fix all,-avi_exit_ignores_timer`
  (the script follows this run's hall doors and the 3fstreet shortcut of BUGS.md B21;
  both versions play the same timeline, TIRO's 16 presses included).
  One-button: `--minigame-stub=jardim --one-button --ms 600000 --input tools/play/onebutton.input` (the
  whole game with left clicks only and the minigames' keys, XILINDRO fought and won
  over the disco, doors clicked from afar, items dropped and offered by tap-tap and
  by dragging; the same with `--fix all,-avi_exit_ignores_timer`) and
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
  --ms 42000 --input tools/play/tiro-3fhall-win.input` (NOITE hides, +2100, the prison) and
  `--ms 32000 --input tools/play/tiro-3fhall-lose.input` (-1050, a life less, the hall);
  `--minigame tiro --ms 16000 --input tools/play/tiro-hit-depth.input` checks two pixels of a falling
  target that a walking one covers in the Original (T8; `pixel X Y INDEX | INDEX`, the Corrigida's after `|`);
  `--minigame tiro --ms 30000 --input tools/play/tiro-endless.input` holds SPACE (BUGS.md T1,
  T3: no result in the Original, none either with the fixes: 15 arrows left). Each script is the
  same with `--fix all` and gives the same result: 16 presses, the Original ending after the 15th
  (the 16th finds TIRO gone), the Corrigida after the 16th arrow has stopped, 2 to 4 s later
  (BUGS.md T2, T4), so the result is checked after both. The shots come from
  `tools/tiro_plan.py --start MS --win|--lose` (it simulates the game; the targets follow from
  TIRO's start time: rerun it when that moves; `--check FILE` simulates a script). `tools/smoke.py
  --minigame tiro [--fix all] [--monkey SEED]` presses random aim keys and SPACE for 60 s.
- **SERIAL**: `--minigame serial --ms 125000 --input tools/play/serial-alone-win.input` (killers
  shot, the clock ends it with lives left: `result won 32768002 | won 500`) and `--ms 110000
  --input tools/play/serial-alone-lose.input` (the killers take the five lives: `won 32768000 |
  lost 1100`); from NOITE, `--scene 3farmcai --ms 126000 --input tools/play/serial-3farmcai-win.input`
  (NOITE hides, gets the result, the prison) and `--ms 39000 --input
  tools/play/serial-3farmcai-lose.input` (the Corrigida takes a life); `--minigame serial --ms
  125000 --key-repeat 500,33 --input tools/play/serial-held-space.input` holds SPACE (BUGS.md K4: 4
  shots in the Original, 1 with the fixes). Each the same with `--fix all`, whose game differs
  (BUGS.md K5: lane 2 also spawns on its own timer, so other figures come): each shot hits a
  wanted figure in at least one version, and each `result` line carries both results (K1/K2: the
  Original reports every game as a win, the score packed in the high word). The shots come from
  `tools/serial_plan.py --start MS --win|--lose` (it simulates the game; the figures follow from
  SERIAL's start time: rerun it when that moves; `--check FILE` simulates a script, `--trace FILE`
  prints every tick). `tools/smoke.py --minigame serial [--fix all] [--monkey SEED]` presses random
  aim keys and SPACE for 130 s.
- **SALGIN**: `--minigame salgin --ms 60000 --input tools/play/salgin-alone-win.input` (Up held
  from the start: the key repeat kicks as each move ends, a KO at 51 s, `result won 8200`) and
  `--ms 100000 --input tools/play/salgin-alone-lose.input` (no key: the clock ends the round with
  the player behind, `lost -1000`); `--ms 2000 --input tools/play/salgin-close.input` closes the
  window at 0.5 s (new script command `close`: BUGS.md S7, `won 9100 | lost -1000`); from NOITE,
  `--scene 4fsalgin --ms 72000 --input tools/play/salgin-4fsalgin-win.input` (NOITE hides, adds
  the score, the garden cutscene `espquete`, which starts JARDIM) and `--ms 110000 --input
  tools/play/salgin-4fsalgin-lose.input` (-1000, a life less, back to `4fbar`). Each also runs
  with `--fix all`. In the Original a held attack key is all a win takes. The Corrigida's runs take
  the controls screen down (`?fight_controls_screen key return` 50 ms after it opened) and `delay
  2050` the rest (PORRADA's 2 s); its fight is the fair one (`fight_fair`), where a held key loses,
  so the Original's keys are `!fight_fair` lines and the Corrigida's win is `?fight_fair` lines
  planned by `tools/fight_plan.py` (below): a KO with the player untouched, `won 9100`.
  `--minigame salgin --ms 110000 --fix all --input tools/play/salgin-fair-mash.input` presses A
  every beat: it loses (docs/fights/FAIRNESS.md "Checks").
  `tools/smoke.py --minigame salgin [--fix all] [--monkey SEED]` presses and holds random fight
  keys for 110 s.
- **INV**: `--minigame inv --ms 15000 --input tools/play/inv-alone-win.input` (the 20 invaders
  and no bomb hit, `result won 2000` at 10.6 s) and `--input tools/play/inv-alone-lose.input` (no
  key: four bomb hits, `lost -2000`); `--key-repeat 500,33 --ms 25000 --input
  tools/play/inv-held-space.input` holds SPACE (BUGS.md I1: the Original fires on every repeat,
  `lost 500 | lost -1900`); `--input tools/play/inv-explosion-move.input` moves and fires during
  the cannon's explosion (I2, `lost -1900 | lost -2000`); from NOITE, `--scene 4fsacaet --ms 76000
  --input tools/play/inv-4fsacaet-win.input` (NOITE hides, adds the score, the Martian's thanks
  `4fmarte2`, the `ESOTEBOY` cutscene and back to `4fbar`) and `--ms 46000 --input
  tools/play/inv-4fsacaet-lose.input` (-2000, `4fmarte`, a life less, back to `4fbar`). Each the
  same with `--fix all`. INV has no randomness, so `tools/inv_plan.py --win|--lose [--start MS]`
  plans a game by probing the port (it closes INV at a time and reads the score it reports);
  `--start` is INV's WM_CREATE in the target run (0 alone, 26808 from `4fsacaet`): rerun it when
  that moves. `tools/smoke.py --minigame inv [--fix all] [--monkey SEED]` presses random
  LEFT/RIGHT and SPACE for 60 s. The playthroughs take the sportsman's route at `4fbar`; INV is
  the esoteric's, a detour that comes back to the bar.
- **XILINDRO**: `--minigame xilindro --ms 62000 --input tools/play/xilindro-alone-win.input` (a KO
  at 55.8 s with the fighter untouched, `result won 13650`) and `--ms 42000 --input
  tools/play/xilindro-alone-lose.input` (no key: the opponent's attacks KO the fighter, `lost
  -1000`); `--ms 2000 --input tools/play/xilindro-close.input` closes the window at 0.5 s (BUGS.md
  X6, `won 13650 | lost -1000`); from NOITE, `--scene 3fstreet --ms 93000 --input
  tools/play/xilindro-3fstreet-win.input` (NOITE hides, adds the score, `3fstree2`, back to
  `3fprisao`), `--ms 80000 --input tools/play/xilindro-3fstreet-lose.input` (-1000, `3fstree1`, a
  life less, back to `3fprisao`) and `--ms 222000 --input tools/play/xilindro-serial-hall.input`
  (the fight, then the lift's stairs to `3farmcai`, whose SERIAL win now goes to `3fhall`). Each
  also runs with `--fix all`. In the Original the opponent stops beyond the fighter's reach, so a
  held key loses: the win steps Right and kicks Up in the 200 ms between the opponent's arrival and
  its attack, and steps back Left while it is far, so it never attacks; the keys were planned
  against the port with a temporary trace, and shift with XILINDRO's start (26095 ms later from
  `3fstreet`). The Corrigida's runs take the controls screen down as SALGIN's, and fight the fair
  fight with `?fight_fair` lines from `tools/fight_plan.py`, the fighter untouched (`won 13650`):
  the reactor alone; from NOITE the faster `--player fast`, whose last kick is held back with
  `--ko-at` so that the KO falls on the Original fight's beat and all that follows (the SERIAL of
  `xilindro-serial-hall.input`) plays as before.
  `--minigame xilindro --ms 100000 --fix all --input tools/play/xilindro-fair-mash.input` presses A
  every beat: it loses.
  **`tools/fight_plan.py SCRIPT [--block NAME] [--player react|fast|mash|idle] [--ko-at MS]
  [--end-at MS]`** plans a script's Corrigida fight between its `# fair-plan NAME begin` / `end`
  lines: it probes the port (the script's `--fix` command, with F9 on: a Debug build logs every
  beat of the fair fight), reads the opponent's phase, adds the next answer and probes again.
  Rerun it when what comes before the fight moves.
  `--minigame xilindro --ms 18000 --fix all --input tools/play/xilindro-controls.input` shows the
  controls screen (`controls` dump), PORRADA's frozen 2 s (a press there does nothing) and A, S,
  D, F, ↑ and ↓ in the round.
  `tools/smoke.py --minigame xilindro [--fix all] [--monkey SEED]` presses and holds random fight
  keys for 110 s (with `--fix all`: Enter first, and A, S, D, F too).
- **INFERNO**: `--minigame inferno --ms 180900 --input tools/play/inferno-alone-win.input` (32
  stomps, the 3 minutes survived, `result won 500`), `--ms 30000 --input
  tools/play/inferno-alone-lose.input` (no key: five hazards walk into the hero, no result,
  BUGS.md H3) and `--ms 3000 --input tools/play/inferno-close.input` (the window closed at 2 s: `won
  500`, H4); from NOITE, `--scene 3fpapmal --ms 198300 --input
  tools/play/inferno-3fpapmal-win.input` (the Original's H1/H2: two lives lost and the prison with
  +1000; the fixed run's hall with +500) and `--ms 50000 --input
  tools/play/inferno-3fpapmal-lose.input` (no report: NOITE finds the window gone, a life less, the
  hall). Each the same with `--fix all`. The win's jumps are `tools/inferno_plan.py [--start MS]`,
  planned against the port (INFERNO starts 17403 ms into `--scene 3fpapmal`). The Original runs
  stop before 181 s of INFERNO, where it spins on `WM_DESTROY` for good (H8: the port panics).
  `tools/smoke.py --minigame inferno [--fix all] [--monkey SEED]` holds LEFT/RIGHT and presses
  UP/DOWN at random for 190 s.
- **SAUNA**: `--minigame sauna --ms 22500 --input tools/play/sauna-alone-win.input` (the
  planner's arrows and clicks eat the 100 dots with no ghost met, `result won 10600` at
  21400), `--ms 47000 --input tools/play/sauna-alone-lose.input` (no key: three catches,
  `lost -1900`) and `--ms 3000 --input tools/play/sauna-close.input` (the window closed at 2 s:
  `lost -900`); from NOITE, `--scene 3fsauna --ms 28000 --input
  tools/play/sauna-3fsauna-win.input` (a right click on the attendant, NOITE hides, gets the win,
  +10600, the hall) and `--ms 25000 --input tools/play/sauna-3fsauna-lose.input` (-1900, a life
  less, the hall). Each the same with `--fix all`: Pacman never meets a ghost in the wins, so the
  P-bugs only change pictures there. The ghosts turn at random from `srand(GetTickCount())`, so
  the moves come from `tools/sauna_plan.py [--scene 3fsauna --prefix FILE --start MS]`, which
  models Pacman and probes the port for the ghosts (it closes SAUNA after each move and reads
  the score): rerun it when SAUNA's start time moves (4100 from `--scene 3fsauna`'s click at
  1000). `tools/smoke.py --minigame sauna [--fix all] [--monkey SEED]` presses and holds random
  arrows and clicks the maze for 120 s. The playthroughs never enter the sauna.
- **JARDIM**: `--minigame jardim --ms 82000 --input tools/play/jardim-alone-win.input` (the three
  labyrinths and the final enemy at 79870: `result won 6328 | won 14620`, BUGS.md J1),
  `--ms 8000 --input tools/play/jardim-alone-lose.input` (Up held into two Seios and a Bussuf: lost,
  reported twice, -1000 then -2000) and `--ms 3000 --input tools/play/jardim-close.input` (the
  window closed at 2 s: `lost -1000`); from NOITE, `--scene espquete --ms 104000 --input
  tools/play/jardim-espquete-win.input` (the video ends, JARDIM starts at 21165, NOITE hides, gets
  the win with J1's penalty, `won -17430 | won 14620`, and plays the first ending `6fsai1`), `--ms
  30000 --input tools/play/jardim-espquete-lose.input` (-1000, game over `6fsaida`) and `--scene
  4fjarvamp --ms 84000 --input tools/play/jardim-4fjarvamp-win.input` (the Original loses the win
  in the 0x40c/0x40a ping-pong, BUGS.md J7: `6fsaida`; the fixed run `6fsai2`). Each the same
  with `--fix all`. JARDIM has no randomness; the moves were planned against the port with a
  temporary state probe (docs/jardim/DESIGN.md "Tests") and depend only on JARDIM's start: the
  NOITE scripts are the alone ones shifted to it. `tools/smoke.py --minigame jardim [--fix all]
  [--monkey SEED]` presses and holds random arrows, Ctrl, Space, Shift and Caps Lock for 60 s. The
  playthroughs keep JARDIM's stub (`--minigame-stub=jardim`).
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
Álvaro, Serial Killer, Porrada na Sala de Ginástica, Invasores, Xilindro,
Inferno, Sauna Mista, Jardim).
On a touch screen the on-screen pad shows the keys of the window on top: for
TIRO, SERIAL and INV ◀, a fire button and ▶; for SALGIN and XILINDRO their eight keys as on the numeric keypad
(Salto = Home, ▲, Soco = PgUp; ◀, Pulo = Insert, ▶; Defesa = End, ▼), and in the
Corrigida the four arrows on the left (▲ jumps, ▼ blocks) and the moves on the right
(XILINDRO: Soco, Chute, Chute alto, Rasteira; SALGIN: Soco, Voadora, Salto, Rasteira); for
INFERNO and SAUNA the four arrows; for JARDIM the arrows, Abrir (Space: a door) in the middle and Tiro (Ctrl:
fire) bottom right.
