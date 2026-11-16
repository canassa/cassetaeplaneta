# SERIAL.EXE: the game as implemented

"Serial Killer" is the shooting gallery launched by NOITE.EXE's `3farmcai` handler after the
prison-escape video. This file describes what the code does, bugs included (they are listed in
`BUGS.md`, section SERIAL, letters K). Addresses are Ghidra `seg:off` in `/SERIAL.EXE`; names are
the current Ghidra names. Functions are in `FUNCTIONS.md`, structs and globals in `DATA.md`.
SERIAL is TIRO's sibling build: where this file says "as TIRO", `docs/tiro/GAME.md` has the detail.

## Files

All opened by relative name: `Fundo.bmp` (background, 640×480), `trabu.bmp` (the gun, a
*trabuco*: 3 frames of 238×105, one per aim), the 15 figures `3sarab` … `3scoel.bmp` (vertical
strips, table below), `bala.bmp` (the bullet, 3 frames of 47×31, one per aim), `panel.bmp`
(status bar and panel frames, never shown), `doom2.mid` (music), `tiros1.WAV`, `morte2.wav`,
`PRACAS01.WAV` (sounds). `WAVEMIX.DLL` sits next to the EXE. On the disc but not referenced:
`ARMA.BMP`, `CARREGA.WAV`, `CARREGA2.WAV`, `LPVITOR.WAV`, `METRAL.WAV`, `TIROS.WAV`, `VELHA.MID`.

## Startup

As TIRO (`entry`, `WinMain` 1038:0202, `app_init` 1038:0055, `APPWNDPROC` 1038:0335), with the
class and title "Serial Killer":
1. `WM_CREATE` → `serial_game_on_create` (1048:021a) → `game_init(this, "Serial", hwnd)`:
   - `serial_game_create_init_scene`: a SerialScene (`hasPlayer` 1, no panel, no status bar);
   - `serial_scene_create` (1068:008d): the backdrop (`Fundo.bmp`, 640×480) with
     `serial_backdrop_create` (TIRO's 32-px grid and wall cells); MCI
     `open doom2.mid type sequencer alias musica` and `play musica notify`; `wave_mix_init`; the
     three waves `g_shotWave` (`tiros1`), `g_hitWave` (`morte2`), `g_pracas01Wave`; the score box
     (" 0000");
   - `serial_game_create_player` (1048:0029): the Gun (`g_gun`, a Player2D) at (200, 380), timer
     id 10 at 60 ms, `lives` = 16 (an unused shot counter); `game_init`'s `mover_show` resets
     `curFrame` to 0, so the game starts aimed left, as TIRO;
   - then the APPWNDPROC starts system timer 1 (50 ms; nothing reacts to it).
2. `serial_create_targets` (1068:013f): `srand(time(NULL))`, the 15 figures, hidden, and the game
   timers (below).
3. `serial_create_bullets` (1068:03d5): the one Bullet (`g_bullets[0]`) at (0, 380), step 20 px,
   timer id 0xc at 55 ms.

## The figures

15 Target objects, `g_targets[0..14]`, one per bitmap, all built at start. Each has a kind
(`g_targetKinds`, `Target.kind`): **kind 0 costs 100 points when hit, kind 1 gives +100, kind 2
gives +200 and shoots back**.

| # | File | Frames, w×h | Kind | Lane | # | File | Frames, w×h | Kind | Lane |
|---|---|---|---|---|---|---|---|---|---|
| 0 | `3sarab` | 6, 80×177 | 0 | 0 | 8 | `3snoel` | 4, 48×95 | 0 | 1 |
| 1 | `3sbaba` | 10, 88×100 | 0 | 0 | 9 | `3snoem` | 16, 124×105 | **2** | 1 |
| 2 | `3sbabt` | 12, 88×99 | **2** | 0 | 10 | `3svelh` | 10, 74×102 | 1 | 1 |
| 3 | `3sclu` | 13, 92×127 | 0 | 0 | 11 | `3sesco` | 12, 128×147 | 1 | 1 |
| 4 | `3sfada` | 12, 88×121 | 1 | 0 | 12 | `3spira` | 12, 52×120 | 0 | 1 |
| 5 | `3shitl` | 10, 52×111 | 0 | 0 | 13 | `3skenn` (Kennedy) | 2, 200×67 | 1 | 2 |
| 6 | `3slenn` | 11, 40×136 | 1 | 0 | 14 | `3scoel` (the rabbit) | 6, 188×60 | 1 | 2 |
| 7 | `3smafi` | 9, 88×105 | 0 | 1 | | | | | |

**Lanes.** Three lanes, one figure on each at a time (`g_targets[0]->laneBusy[0..2]`, cleared when
the figure leaves or is hit):

| Lane | Figures | y | Enters at | Walks | Walk timer | Speed |
|---|---|---|---|---|---|---|
| 0 | 0–6, `rand() % 7` | 1 | x 20 | right | id 3, 200 ms | 100 px/s |
| 1 | 7–12, `7 + rand() % 6` (jump table `g_spawnLane1JumpTable` 1068:22ab) | 45 | x 640 − width | left | id 3, 200 ms | 100 px/s |
| 2 | 13 or 14, `rand() % 2` | 190 | 13: x 20, right; 14: x 452, left | | id 6, 100 ms | 200 px/s |

**Spawning** (`serial_scene_handle_message`, `WM_SYSTIMER` id 7, every 5 s from the start): a free
lane 0 gets a figure, then a free lane 1 (which takes its first step at once); lane 2 alternates on
`g_spawnToggle`, so it is tried on every second tick (10 s, 20 s, …) and gets a figure if it is
free. A new figure starts at frame 0, is drawn and shown, and walks toward the far edge
(`mover_move_to_edge_h`). Lane 2's own spawn timer (id 10 on target 13, 5 s) never reaches its
branch (BUGS K5).

**Walking.** On each tick of a walk timer (id 3 for figures 0–12, id 6 for 13–14) every moving figure
of the group runs `target_wrap_at_edge` (`TargetVtbl.checkEdge`, 1068:0f59): a left-walker at
x ≤ −w/2 or a right-walker at x ≥ 630 is stopped, hidden and erased, and its lane is freed;
otherwise `target_move_tick` (1068:0dfc) steps it 20 px and advances its animation frame (with
wrap-around). The figures ignore the grid and each other (`target_can_step` always says yes); a
lane-1 figure's step repaints the other walking figures of lanes 0 and 1 (`target_redraw_overlapping`).

**The killers.** A kind-2 figure "shoots" on the step that brings its frame to two before the end
of its strip: `target_move_tick` plays `tiros1.WAV` and takes one of `g_lives` (5); at 0 it sends
`WM_DESTROY`. That is once per animation cycle: figure 2 (12 frames, 31 steps per crossing) shoots
at its 10th and 22nd step, figure 9 (16 frames, 29 steps) at its 14th. Kinds 0 and 1 never shoot.

## The gun and the shot

The gun's `curFrame` is the aim: 0 left, 1 straight, 2 right. LEFT calls `gun_aim(gun, 'E')`, RIGHT
`gun_aim(gun, 'D')`, with TIRO's wrap-around (right 0→1→2→0, left 0→2→1→0); each is latched until
its key-up. After each aim change `gun_play` re-arms the gun's timer (id 10, 60 ms), whose ticks
redraw the gun (`gun_tick`).

SPACE (while `g_keySpaceHeld` is 0, which is always: BUGS K4) first decrements `g_gun->lives`
(never read), then, if the bullet is not moving, fires:

| Aim | Bullet frame | Start (from the gun at 200, 380) | Destination |
|---|---|---|---|
| 0 left | 0 | x + 0x2a, y − 0x1e (242, 350) | (0, 10) |
| 1 straight | 1 | x + 0x61, y − 0x1e (297, 350) | (325, 10) |
| 2 right | 2 | x + 0xa2, y − 0x14 (362, 360) | (640, 10) |

Firing plays `tiros1.WAV` and starts the line move (`moveTo`). There is one bullet and no ammunition
limit. On each bullet tick (id 0xc, 55 ms) `projectile_step_move` (1068:13d7) takes one 20-px
Bresenham step and asks `projectile_try_step` (1068:12a5), as TIRO:
- the grid query of the bullet's next rect finds the area free: it moves on;
- a wall cell or a non-Target blocker: the bullet stops and disappears;
- a Target: when the bullet's next y is within half the figure's height of the figure's y it
  reports a hit (`outDir` = 3); either way it moves on.

It also stops at its destination.

## The hit test

1. **First stage** (above): the bullet's rect touches some Target in the grid, near its row.
2. **Second stage** (the handler's bullet branch, `target_hit` calls 1068:2fe4–45ea): the bullet is
   stopped and the gun redrawn; then the figures are tested by x alone, lane 2 first (13, 14, if
   `laneBusy[2]`), then lane 1 (7–12), then lane 0 (0–6), moving ones only. The bullet spans
   x..x+55 (TIRO's arrow width; `bala.bmp` is 47 wide), a figure x..x+w; TIRO's three strict
   overlap cases. The first match gets `target_hit`; with no match the bullet is spent (BUGS K3).

`target_hit` (1068:0c42) scores by kind, stops and hides the figure, frees its lane and erases it on
the window (`target_hide_and_blit`). There is no hit animation and no respawn: the lane refills on a
later spawn tick.

## Scoring

`g_score` (16-bit int) starts at 0:
- kind 1: `serial_hit_kind1`, **+100**;
- kind 0: `serial_hit_kind0_2`, **−100**;
- kind 2: `serial_hit_kind0_2`, **+200**.

Each hit plays `morte2.wav` and redraws the score box. No clamp. **Score display**
(`serial_draw_score`, 1068:48bc): the 192×32 box at (416, 400) is restored from the background,
then `" %04d"` or `"-%04d"`, each of the five characters drawn with its own `TextOut` at
x = 460 + 32·i, y = 408, in colour 0x00EDEEEE (near white), transparent, in the DC's default font.

## End of the game

Two ends:
- **the clock**: timer id 8 at 60 s on target 0; the first tick counts (`clockTicks` 0→1), the
  second (120 s after the start) sends `WM_DESTROY`;
- **the lives**: the killers' shot that takes `g_lives` to 0 sends `WM_DESTROY` from inside
  `target_move_tick`; the rest of that tick runs on with the waves already freed (`wave_play`
  then finds no wave and does nothing).

`WM_DESTROY` in `serial_scene_handle_message` (1068:1577): `wave_stop_all`, `wave_free_all`,
`wave_mix_close`, MCI `close musica`, then
`PostMessage(g_noiteWnd, 0x40a, hwnd, MAKELONG(g_lives, g_lives > 0 ? 500 : g_score))`
(1068:1598–15be). It returns 0, so `APPWNDPROC` kills timer 1 and posts `WM_QUIT`. The wParam is
SERIAL's own window, never 0, so NOITE always reads a win (BUGS K1), and the score sits in the high
word (BUGS K2). A window close reports the same way.

## Protocol with NOITE.EXE

| Msg | Direction | wParam | lParam | Meaning |
|---|---|---|---|---|
| `0x40b` | NOITE → SERIAL | 0 | NOITE's main window (low word) | hello; stored in `g_noiteWnd` (`APPWNDPROC`) |
| `0x40c` | SERIAL → NOITE | SERIAL's window | 0 | ready; posted once, on the first message after `g_started` (`g_handshakePending` 1 → 0) |
| `0x40a` | SERIAL → NOITE | SERIAL's window (always non-zero) | `MAKELONG(g_lives, g_lives > 0 ? 500 : g_score)` | result |

NOITE's `handler_3farmcai` (1020:8458; `src/handlers/3farmcai.zig`):
- the scene start (0x401): `play musica notify`, `pause musica`, the waves stopped and freed,
  WaveMix closed, the video (object 0x7f) played;
- `MM_MCINOTIFY` at the video's end: closes it, `wave_mix_init`, `WinExec("<CD>serial\serial.exe")`
  and timer 0x14 (100 ms);
- timer 0x14: `FindWindow("Serial Killer")`; once found, kills the timer and posts `0x40b`;
- `0x40c`: minigame running, hides the main window;
- `WM_SYSTIMER` while running: if the window is gone, posts itself `0x40a` (0, 0), a loss with no
  score change;
- `0x40a` (1020:8671–8679): realizes the palette, shows the main window,
  `minigameWon[2] = (wParam != 0)` and `g_score += lParam`, the whole 32-bit lParam. A loss takes a
  life and goes to `3fprisao` at (0xf0, 0xc8), or to `6fsaida` (game over) when lives reach 0; a
  win goes to `3fhall` at (0xf0, 0xc8) if the jail minigame (XILINDRO, `minigameWon[3]`) is won
  too, else back to `3fprisao`.

So with SERIAL's message every game is a win, and NOITE's 32-bit score gains 500·65536 + lives
(32,768,001–32,768,005) after a survived game, `g_score`·65536 after a lost one. NOITE shows and
saves only the low word (BUGS B19): on screen the score grows by the lives left, or not at all.

The port reproduces NOITE's side as is: `src/handlers/3farmcai.zig` sets
`minigameWon[2] = @intFromBool(m.wparam != 0)` and adds the whole `m.lparam` (`g.score +%= m.lparam`,
32-bit wrapping). SERIAL is ported too (`src/serial/`): NOITE's WinExec runs it as a second
program, so K1 and K2 reach NOITE as above (`tools/play/serial-3farmcai-win.input`: +32,768,002
with 2 lives left; `-lose`: +6,553,600 and no life taken).

## Keys and mouse

| Input | Effect |
|---|---|
| SPACE | fire (see The gun and the shot); every press and every key repeat runs the fire code |
| LEFT | aim one step left ('E'), with wrap |
| RIGHT | aim one step right ('D'), with wrap |
| any other key | nothing (the handler returns 1) |
| mouse moves and clicks (0x200–0x202, 0x204, 0x205) | swallowed |

`serial_scene_handle_message` answers every key, timer and mouse message itself, so the engine's
`game_handle_message` never runs.

## Timers

`WM_SYSTIMER` is dispatched by wParam, tested in this order (1068:1abd onward):

| Test | Id | Period | Owner | Action |
|---|---|---|---|---|
| 1 | 10 | 60 ms (5 s until the first aim key) | the gun | `gun_tick` |
| 2 | 3 | 200 ms | figures 0–12 | walk |
| 3 | 6 | 100 ms | figures 13–14 | walk |
| 4 | 7 | 5 s | `g_targets[0]->timerId2` | spawn |
| 5 | 10 | 5 s | `g_targets[13]->timerId13` | lane-2 spawn, never reached (test 1 takes id 10) |
| 6 | 0xc | 55 ms | the bullet | flight and hit test |
| 7 | 8 | 60 s | `g_targets[0]->clockTimerId` | the clock |

Any other id redraws the (hidden) panel. Every branch ends in the update-list flush and returns 1.
The walk timers are re-armed by each spawn (`mover_move_to_edge_h`).

## The Corrigida

What the Corrigida version (`Fixes.all()`) adds in front of the game, none of it a bug fix (BUGS.md,
"Corrigida additions"; code `src/serial/corrigida.zig`): the aims, the one bullet, the figures, the
scores, the clock and the lives are the original's, the pictures are over the screen, never in it.

- **Intro screen** (`serial_intro_screen`). "SERIAL KILLER", "Você é o serial killer. 5 vidas, 2 minutos.",
  then three rows, each with a figure from the strips (3svelh, 3shitl, 3sbabt at its shot frame):
  "Mate os bonzinhos: +100 / fada, Lennon, velhinha, escoteiro, Kennedy e o coelhinho da Páscoa";
  "Poupe os malvados: -100 / Hitler, Klan, mafioso, pirata, árabe, a babá e o Papai Noel que não atiram";
  "Cuidado com os outros assassinos! / A babá e o Papai Noel que atiram avisam com um '!' antes. Acerte
  primeiro: +200"; the keys ("← → mira", "Espaço atira") and "Aperte uma tecla ou clique para começar".
  The spawn, lane-2 and clock timers are stopped from WM_CREATE until a key or a click takes it down
  (`target.disarmTimers`, `armTimers`: the same calls `serial_create_targets` makes), so the game's first
  spawn comes 5 s after that. Any key (the key is ignored till it is released) or click.
- **The killers' warning** (`serial_killer_warning`). `CARREGA.WAV` plays and, until the shot, the figure's box
  blinks red and yellow (110 ms) with a yellow "!" sign over it. The shot happens in the walk tick of a figure that
  is still moving: a hit stops it (`target_hit`), so a hit in the warning cancels the shot. The babá (3sbabt, 12
  frames) and Noel (3snoem, 16) show their own tells in the strip (the baby rises at frame 8; Noel lies down with the
  rifle at 8). With `serial_killer_after_middle` (below) the warning is where the killer enters the middle path;
  without it, 3 steps (600 ms) before the original's shot (the step that brings the frame to 2 from the strip's end).
- **Shots after the middle** (`serial_killer_after_middle`). Each killer fires once per crossing, at a fixed x, after
  it has left the straight aim's hit window. Measured with `tools/serial_plan.py` (a straight bullet takes 825 ms,
  15 bullet ticks, to the lane): a bullet that lands with the babá at x 220..340 (walking right, 20 px a 200 ms step)
  or Noel at x 336..176 (walking left) hits. The warning starts at the babá's x 140 / Noel's x 416 (a bullet fired
  then lands 4 steps on, at the window's first step) and the shot is at x 360 / x 156, 11 steps (2.2 s) and 13 steps
  (2.6 s) later. A bullet fired in the first 1.4 s (babá) or 1.8 s (Noel) of the warning lands before the shot and
  hits; the original's fixed frames shoot nothing.
- **Shot feedback** (`serial_shot_flash`): when a killer's shot lands, a yellow and white burst at its gun (260 ms),
  a sideways shake of the picture (8 px easing off, 260 ms), the screen's edge red in two pulses (600 ms in all) and
  the lives' box blinking red with the lives left.
- **Lives** (`serial_lives_display`): "Vidas: N" at the bottom left, drawn like the score.
- **End screen** (`serial_end_screen`): `corrigida.finish` stands where the original sends WM_DESTROY (the
  fifth shot, the second clock tick): a panel "Fim de jogo!" (lives 0) or "Você sobreviveu!", "Pontos: N",
  "Vidas que sobraram: N", for 3 s (system timer 11) or until a key or a click; then WM_DESTROY and the
  0x40a result as ever. Frozen meanwhile (every timer, key and mouse message is swallowed; a second killer
  shooting in the same tick takes no life).
- **NOITE** (`serial_loss_message`): `3farmcai` shows "O serial killer foi pego! / Você perdeu uma vida." for 4 s
  in the prison after a lost game (`src/note.zig`, `Screen.overlay`).

**How beatable.** `tools/serial_bot.py` plays the simulation (`tools/serial_plan.py`, the Corrigida's rules) as
a player with a reaction time: it sees a figure `--reaction` ms after it appears, shoots the good ones, shoots a
killer from the straight aim `--reaction` ms after its warning starts and, when a harmless figure stands in the
bullet's way (the first match in x wins, lane 1 before lane 0), shoots that one first (-100). 24 games each
(`--seeds 24`), per game:

| Player | Lives lost (of 5) | Games lost | Killers that walk in | Hit before they fired | Killers stopped |
|---|---|---|---|---|---|
| bot, 400 ms | 0.46 | 0 of 24 | 5.17 | 4.42 | 91 % |
| bot, no reaction time | 0.08 | 0 of 24 | 5.29 | 4.88 | 98 % |

(Before `serial_killer_after_middle` the killers fired at the strip's fixed frames wherever they stood and a 400 ms
bot stopped about a third of them: 3.5 lives lost, 7 of 24 games lost.) What still costs a life: a harmless figure
in the middle path that cannot be cleared in time, or the bullet still in flight from the last shot (one at a time).

## Music and sound

- Music: MCI sequencer, `doom2.mid`, alias `musica`, as TIRO (`play musica notify`; on
  `MM_MCINOTIFY` success `play musica from 0 notify`, so it loops; `WM_ACTIVATE` resumes or pauses
  it with WaveMix; `close musica` at the end).
- Sound: WaveMix, three waves, each played with no notify window (flags 7, `wave_play`):
  `tiros1.WAV` for the player's shot and a killer's shot, `morte2.wav` for every hit, and
  `PRACAS01.WAV` on every `WM_PAINT` (`APPWNDPROC`). The handler's `0x3bd` case returns 1 and never
  arrives.
