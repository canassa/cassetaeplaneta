# SAUNA.EXE: the game as implemented

"Sauna Mista" is the Pac-Man in a sauna launched by NOITE.EXE's `3fsauna` handler. This file
describes what the code does, bugs included (they are listed in `BUGS.md`, section SAUNA, letters
P). Addresses are Ghidra `seg:off` in `/SAUNA.EXE`; names are the current Ghidra names. Functions
are in `FUNCTIONS.md`, structs and globals in `DATA.md`. SAUNA runs TIRO's engine in the large
model; where this file says "as TIRO", `docs/tiro/GAME.md` has the detail. All the game logic is in
the SaunaScene handler `sauna_scene_handle_message` (1080:32f7) and the Pacman and Ghost overrides
(1080).

## Files

All opened by relative name: `3fpac2.bmp` (background, 640×460), `pacinter.bmp` (the control panel,
640×48), `3o1amend.bmp` (the peanut, 20×12), `3o1rolha.bmp` (the cork, 20×25), the nine strips
`3SP*.bmp` (`DATA.md`, "Pictures"), `pac.mid` (music) and the waves `pacman`, `pacman2`, `pacman3`,
`pacman4`, `control`, `ROLHAS01` (`.wav`). On the disc but not referenced: `DATA.md`.

## Startup

As TIRO (`entry`, `WinMain` 1058:021a, `app_init` 1058:0055, `APPWNDPROC` 1058:0353), with the
class and title "Sauna Mista" and a `WS_POPUP | WS_CAPTION` 640×480 window, centred, with no
system menu. A second instance shows "O aplicativo já está aberto !!!" and quits.
1. `WM_CREATE` → `sauna_game_on_create` (1048:01ab) → `game_init(this, "Labirinto", hwnd)`:
   - `sauna_game_create_init_scene`: a SaunaScene (`hasPlayer` 1, `hasControlPanel` 1, no status
     bar) whose ctor builds the four ghosts and the peanut and cork objects;
   - `sauna_scene_create` (1080:2f14): the backdrop `3fpac2.bmp` (`sauna_backdrop_create` marks
     the maze walls in the occupancy grid); the dots stamped into the second bitmap; MCI
     `open pac.mid … alias musica`, `play musica notify`; WaveMix and the six waves; the score
     box (" 0000");
   - `sauna_game_create_control_panel`: `pacinter.bmp` at y 592, below the window: it is never
     seen;
   - `sauna_game_create_player` (1048:0042): Pacman (`g_pacman`) at (300, 304), idle.
   `game_init` then posts `0x401`: `srand(GetTickCount())` and each ghost's
   `ghost_choose_direction`, so the ghosts start at once.
2. `APPWNDPROC` sets `g_started` and starts system timer 1 (50 ms); no branch reacts to it.

## The maze

30 rows of 40 cells of 16×16 px (`s_mazeRow00…29`): `1` wall, `2` peanut (96), `3` cork (4, near
the corners), space empty. The walls are occupancy count −1. A peanut or cork is drawn at
(16·col + 8, 16·row + 10). `g_dotsLeft` starts at 100.

## Pacman

40×40 sprite, hit box 24×24 at (8, 8), at x = 16c − 4, y = 16r; it moves in 16-px steps (one cell)
every 55 ms (timer 0x10), about 290 px/s. Strips: left 0, right 1, up 2, down 3, plus 4 under
power (the ghosts' pictures), 8 the death (6 frames). The mouth keeps chomping while idle
(`pacman_tick`).

**Arrows** (`WM_KEYDOWN`): LEFT/RIGHT call `pacman_move_to_edge_h` (1, 2), UP/DOWN
`pacman_move_to_edge_v` (4, 8): stop, set the strip, and start a straight move to the window edge.
A step that is blocked (wall, or a ghost met) stops him (`pacman_move_tick`); there is no turn
buffering, so a key works only if the first step in that direction is free. Each arrow has a latch
(`g_keyLeftHeld` …) against auto-repeat; any arrow's key-up clears all four but does **not** stop
Pacman: he runs until blocked.

**A left click** walks him to the point (`game_handle_message` → `pacman_move_to`): a Bresenham
line in 16-px steps, diagonals allowed (BUGS.md P5 for the picture).

**Eating** (`pacman_restore_background`, after each step): the first cell holding a dot among the
four cells at the top left of the position he has just left (BUGS.md P3). A peanut: +100
(`pacman.wav`). A cork: no points, `pacman2.wav`, the `control.wav` loop, and the power mode. Each
dot is cleared from the maze and from the second bitmap, and `--g_dotsLeft`.

## The ghosts

Four Ghosts built with the same arguments: home (300, 230), the same speed as Pacman (16 px per
55 ms), all on the one timer 0x11 (the handler steps the four in turn on it), 8 strips (left,
right, up, down; +4 under power, Pacman's pictures). `ghost_choose_direction` (1080:1abe) picks a
heading:
1. Pacman within 16 px in x: up or down toward him (away while powered); keep it if the next step is
   free of walls (`ghost_is_next_step_free`).
2. Else Pacman within 16 px in y: left or right toward him (away while powered); same test.
3. Else a random direction (`rand() % 4`), unchecked.

It runs at the start, at the power's start and end, whenever a ghost is blocked or reaches the edge
(a ghost never idles), and on every tick while the ghost is within 16 px of Pacman on either axis.
There is no pathfinding and no scatter or home-return mode.

## Meeting a ghost

Both `pacman_can_step` (Pacman's step) and `ghost_can_step` (a ghost's step) query the occupancy
cells of the next position: the first occupied cell scanned decides (P1, P2).
- **Powered** (`g_powerStrip` 4): `sauna_eat_ghost` (+500, `pacman4.wav`); the ghost is put back
  home at once and keeps walking. The mover that found it stops (Pacman stands; the ghost re-aims).
- **Unpowered:** `sauna_lose_life` (`pacman3.wav`, a life, −500 unless it was the last),
  `sauna_scene_send_ghosts_home` (the four ghosts back home, still walking their old lines), and
  `g_pacmanDying`.

**The death** (Pacman's timer while `g_pacmanDying`): the timer goes to 110 ms, strip 8 plays its
6 frames (about 0.7 s), then Pacman reappears at (300, 304) on strip 0 and the latches are
cleared. The ghosts keep moving meanwhile (P6) and the arrows stay live (P7).

## The power mode

A cork sets `g_powerStrip` = 4 and `g_powerStartPending`. The next message of any kind (within
50 ms) runs the start: `pacman_refresh_power_strip` (P4), each ghost's `ghost_choose_direction`
(they flee), and system timer 10 at 5000 ms (a second cork re-arms it). Under power Pacman and the
ghosts swap pictures. Timer 10 ends it: `g_powerStrip` 0, the pictures swapped back, the ghosts
re-aimed, `control.wav` stopped, the timer killed.

## Scoring

`g_score` (16-bit int) starts at 0; `g_lives` at 3 (not shown anywhere).
- +100 a peanut (`sauna_eat_peanut`); +500 a ghost eaten (`sauna_eat_ghost`), again every time;
- −500 a life lost, but not the last (`sauna_lose_life`);
- at the end, +1000 for a win, −1000 otherwise (the `WM_DESTROY` case). No clamp.

**Score display** (`sauna_draw_score` 1080:426e): the 192×20 box at (416, 437) restored from the
background, then `" %04d"` or `"-%04d"` of |score|, one `TextOut` per character at x = 460 + 32·i,
y = 445, colour 0x00EDEEEE, transparent; `sauna_blit_score_box` copies the box to the window. Five
digits do not fit (P8).

## End of the game

- **Win:** `pacman_restore_background` sends itself `WM_DESTROY` (wParam 0xffff) when
  `g_dotsLeft` reaches 0 (all 96 peanuts and 4 corks).
- **Loss:** `sauna_lose_life` sends `WM_DESTROY` (wParam 0) when `g_lives` reaches 0: the third
  catch.
- **Any other destroy** (End Task, Windows shutdown: the window has no system menu) arrives with
  wParam 0: a loss.

`WM_DESTROY` (1080:342b): `wave_stop_all`, `wave_free_all`, `wave_mix_close`, MCI `close musica`,
`g_score += wParam ? 1000 : −1000`, `PostMessage(g_noiteWnd, 0x40a, wParam, (long)g_score)`; it
returns 0, so `APPWNDPROC` kills timer 1 and posts `WM_QUIT`. Nothing calls `DestroyWindow`: the
game sends the message itself and quits; the window dies with the task.

## Protocol with NOITE.EXE

| Msg | Direction | wParam | lParam | Meaning |
|---|---|---|---|---|
| `0x40b` | NOITE → SAUNA | 0 | NOITE's main window (low word) | hello; stored in `g_noiteWnd` (`APPWNDPROC`, also before `WM_CREATE`) |
| `0x40c` | SAUNA → NOITE | SAUNA's window | 0 | ready; posted once (`g_handshakePending`), on the first message after `g_started` with `g_noiteWnd` set |
| `0x40a` | SAUNA → NOITE | 0xffff won, 0 lost | `g_score` (with the ±1000) | result, from `WM_DESTROY` |

NOITE's `handler_3fsauna` (1020:7f58; `src/handlers/3fsauna.zig`):
- the first right click in the scene plays the attendant's animation once and its wave; when the
  wave ends (`MM_WOM_DONE`), `WinExec("<CD>sauna\sauna.exe")` and timer 0x14 (100 ms);
- timer 0x14: `FindWindow("Sauna Mista")`; once found, kills the timer and posts `0x40b`;
- `0x40c`: minigame running, hides the main window;
- `WM_SYSTIMER` while running: if the window is gone, posts itself `(0x40a, 0, 0)`, a loss with no
  score change (SAUNA always reports first, so this covers a crash);
- `0x40a` (the first one: it switches scene): realizes the palette, shows the main window,
  `minigameWon[4]` = (wParam ≠ 0), `g_score += lParam`; a loss takes a life and goes to
  `6fsaida` (game over) when that reaches 0; otherwise, won or lost, `3fhall` at (0xf0, 200).

So SAUNA's whole score reaches NOITE: its points plus 1000 for a win, minus 1000 for a loss. SAUNA
posts one `0x40c` and one `0x40a`, so nothing leaks into the hall.

The port reproduces NOITE's side (`src/handlers/3fsauna.zig`). SAUNA itself is not ported: the
headless backend's minigame stub (`src/platform/sim.zig`) answers the hello with one `0x40c` and
reports the won flag and score set in `Options.minigame`.

## Keys and mouse

| Input | Effect |
|---|---|
| LEFT, RIGHT, UP, DOWN | Pacman runs that way until blocked (latched until any arrow's key-up) |
| any other key | nothing (the handler returns 1) |
| left click | Pacman walks to the point (`pacman_move_to`) |
| right click on Pacman or a ghost | its `playOnce` (`game_handle_message`'s `isAnimation` arm), which only re-arms its timer |
| mouse move below y 440 | starts the off-screen panel's slide once (its timer 0xc is swallowed by the handler, so it never finishes) |

The scene handler swallows `WM_KEYDOWN`, `WM_KEYUP` and `WM_SYSTIMER`, so `game_handle_message`'s
own arms for them are dead; it returns 0 for the mouse, which reaches the engine.

## Timers

`WM_SYSTIMER` is dispatched by wParam, tested in this order (1080:3765), and always returns 1:

| Test | Id | Period | Owner | Action |
|---|---|---|---|---|
| 1 | 0x10 | 55 ms (110 dying) | Pacman (`getTimerId`) | dying: the death strip and the respawn; else `moveTick` if moving, `tick` if not |
| 2 | 0x11 | 55 ms | the four ghosts (`ghosts[0]`'s id) | each ghost in turn: `moveTick` or `tick` |
| 3 | 10 | 5000 ms | the power mode (only while `g_powerStrip` is 4) | the power's end |

Timer 1 (50 ms, `APPWNDPROC`) and the panel's 0xc match nothing. Every `WM_SYSTIMER` ends with the
update-list flush.

## Music and sound

- Music: MCI sequencer, `pac.mid`, alias `musica` (`play musica notify`; on `MM_MCINOTIFY` success
  `play musica from 0 notify`, so it loops; `WM_ACTIVATE` pauses or resumes it with WaveMix;
  `close musica` at the end). The game itself keeps running while inactive.
- Sound: WaveMix, six waves: `pacman.wav` (peanut), `pacman2.wav` (cork), `pacman4.wav` (ghost
  eaten), `pacman3.wav` (caught), `control.wav` (looped while powered; the only wave with a notify
  window, whose `MM_WOM_DONE` flushes every channel), `ROLHAS01.WAV` (restarted by `APPWNDPROC` on
  every `WM_PAINT`).
