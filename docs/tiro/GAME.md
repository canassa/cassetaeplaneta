# TIRO.EXE: the game as implemented

"Tiro ao Álvaro" (window title "Tiro ao Alvaro") is the shooting gallery launched by NOITE.EXE's
`3fhall` handler. This file describes what the code does, bugs included (they are listed in
`BUGS.md`, section TIRO). Addresses are Ghidra `seg:off` in `/TIRO.EXE`; names are the current
Ghidra names. Functions are in `FUNCTIONS.md`, structs and globals in `DATA.md`.

## Files

All opened by relative name: `Fundtiro.bmp` (background, 640×480), `besta.bmp` / `bestse.bmp`
(the crossbow, loaded / unloaded, 3 frames of 285×127), `girla`–`girlc.bmp` and `travea`–`traveg.bmp`
(the ten targets, 9 frames of 75×95), `Tiresq.bmp` / `Tirofr.bmp` / `Tirdir.bmp` (the arrow
flying left / straight / right, 55×27), `panel.bmp` (status bar and panel frames, never shown),
`pac.mid` (music), `ARCFLE02.WAV`, `uii.wav`, `nossa.wav`, `tirojogo.wav`, `PASARS01.WAV`
(sounds), `arialbd.fot` (registered, never used). `WAVEMIX.DLL` sits next to the EXE.

## Startup

1. `entry`: MSVC medium-model Windows startup; `_cinit` runs the static initializer →
   `init_static_conditions` (the two FlagConditions).
2. `WinMain` (`1038:0202`): stores the module path, resolves USER.11 `SetSystemTimer` and USER.182
   `KillSystemTimer` with `GetProcAddress` (`g_setSystemTimer`/`g_killSystemTimer`). A second
   instance gets the message box "O aplicativo ja esta aberto !!!" and exits.
3. `app_init` (`1038:0055`): `clear_system_palette`, registers the class "Tiro ao Alvaro",
   `new TiroGame` (`tiro_game_ctor`, stored in `g_game` and `g_tiroGame`), creates a 640×480
   `WS_POPUP|WS_CAPTION` window titled "Tiro ao Alvaro", centred (no system menu, so no close
   button), and shows it.
4. `WM_CREATE` in `APPWNDPROC` (`1038:0335`): `tiro_game_on_create` (`1048:021a`), then
   `g_started = 1` and the window timer (id 1, 50 ms; nothing reacts to it).
5. `tiro_game_on_create` → `game_init(this, "Mech", hwnd)` (`1088:3dc6`):
   - `tiro_game_create_init_scene`: a TiroScene (`hasPlayer` = 1, no panel, no status bar, no
     exits);
   - `PatBlt` BLACKNESS; `tiro_scene_create` (`1068:008d`): `scene_create` builds the backdrop with
     `tiro_scene_create_screen` (`Fundtiro.bmp`, 640×480 view) and `tiro_backdrop_create`
     (`1068:0000`, 32-px occupancy grid plus wall cells); MCI
     `open pac.mid type sequencer alias musica` and `play musica notify`; `wave_mix_init`; the
     five waves into `g_shotWave`, `g_girlHitWave`, `g_travecoHitWave`, `g_hitWave`,
     `g_pasars01Wave`; `tiro_draw_score` and `tiro_blit_score_box` (" 0000");
   - the status bar and the TiroPanel are created and attached but stay hidden;
   - `tiro_game_create_player` (`1048:0029`): the Crossbow (`g_crossbow`, a Player2D) at x 200,
     y 0x17c (380), aim 1 (straight), loaded picture, `lives` = 16 (the arrow counter);
   - `PostMessage(hwnd, 0x401)`, ignored.
6. Still in `tiro_game_on_create`: `tiro_create_targets` (`1068:0163`) and `tiro_create_arrows`
   (`1068:038a`).

The wall cells (`tiro_backdrop_create`) are grid columns 0 and 19 for rows 5–13, and row 13 for
columns 0–18 (count 0xff = blocked). Only the arrow tests them; the targets ignore the grid.

## Targets

Four Target objects, `g_targets[0..3]` (`tiro_create_targets`, `srand(GetTickCount())` first):

| Target | Row (y) | Direction | Start x | Timer id |
|---|---|---|---|---|
| `[0]` | 0x55 (85) | right | 44 | 0xc |
| `[1]` | 0x55 | right | 207 | 0xd |
| `[2]` | 0x82 (130) | left | 124 | 0xe |
| `[3]` | 0x82 | left | 287 | 0xf |

All four start at once, mid-row and moving. A target steps 20 px per tick of its timer (100 ms),
so they all move at 200 px/s. Its identity is its picture (`SceneObject.curStrip`), drawn with
`rand() % 10` at creation and on every respawn: 0–2 are the three girls (`girla`–`girlc`), 3–9
the seven *travecos* (`travea`–`traveg`). Walking shows frame 0; frames 1–8 are the hit
animation.

On each target tick (`tiro_scene_handle_message`, `WM_SYSTIMER`), when the target is not in its
hit animation:
1. the edge test `target_wrap_at_edge` (`TargetVtbl.checkEdge`, `1068:1037`) runs, except while
   the pair guard holds: `[0]` waits while `[1]` is 0–87 px ahead of it (to its right), `[3]`
   waits while `[2]` is 0–175 px ahead of it (to its left); `[1]` and `[2]` never wait;
2. `target_wrap_at_edge`: a left-moving target at x ≤ 37 (half its width) or a right-moving one at
   x ≥ 490 (background width − 2 widths) stops and is erased; otherwise it takes one step
   (`target_move_tick`);
3. a target that is not moving (it just wrapped, or `target_respawn` left it waiting) is re-armed
   at once: same row and direction, a new identity, x = 0x18 (right-moving) or 565 (left-moving,
   background width − width), moving.

So a target that leaves the screen comes back at the far side of its row with a new picture in
the same tick. Targets walk through the wall cells and through each other (`target_can_step`
always says yes).

## Crossbow and aim

The crossbow's `curFrame` is the aim: 0 left, 1 straight, 2 right. LEFT (`VK_LEFT`) calls
`crossbow_aim(crossbow, 'E')` (*esquerda*), RIGHT (`VK_RIGHT`) `crossbow_aim(crossbow, 'D')`
(*direita*). Each steps the aim with wrap-around: right goes 0→1→2→0, left 0→2→1→0, so one more
press past an end jumps to the other end. Each key is latched (`g_keyLeftHeld`/`g_keyRightHeld`,
cleared on key-up), so holding it moves the aim once. After the change `crossbow_play` re-arms the
crossbow's timer (id 10, 60 ms) and every crossbow tick redraws it (`crossbow_tick`). The picture
is `besta` (loaded) or `bestse` (unloaded, from the shot until the arrow stops).

## The arrow

There is one arrow object (`g_arrows[0]`, an Arrow; the creator's loop runs `i < 1`): step 10 px,
timer id 0x10, 55 ms. SPACE (`WM_KEYDOWN` `VK_SPACE`, while `g_keySpaceHeld` is 0, which is
always) first decrements `lives`, then, if the arrow is not moving, fires:

| Aim | Picture | Start (relative to the crossbow) | Destination |
|---|---|---|---|
| 0 left | `Tiresq` | x + 0x48, y − 0x1e (272, 350) | (0, 10) |
| 1 straight | `Tirofr` | x + 0x75, y − 0x1e (317, 350) | (335, 10) |
| 2 right | `Tirdir` | x + 0xa2, y − 0x14 (362, 360) | (640, 10) |

Firing plays `ARCFLE02.WAV` (`tiro_play_shot_wave`), starts the line move (`moveTo`) and shows
the unloaded crossbow. On each arrow tick `projectile_step_move` (`1068:1641`) takes one
Bresenham step (y is the major axis on all three paths) and asks `projectile_try_step`
(`1068:1448`):
- the occupancy query of the arrow's next rect (`actor2d_can_step`) finds the area free: the arrow
  moves on;
- it is blocked by a wall cell, or by an object that is not a Target (`isTarget`, SceneObject slot
  0x58): the arrow stops and disappears;
- it is blocked by a Target: if the arrow's next y is within half the target's height (47 px) of
  the target's y, it reports a hit (`outDir` = 3); either way it moves on.

The arrow also stops when it reaches its destination. When it stops the crossbow is shown loaded
again.

## The hit test

1. **First stage** (above): the arrow's rect touches some Target in the occupancy grid, within
   47 px of its row.
2. **Second stage** (`tiro_scene_handle_message`, the arrow-timer branch; `target_hit` calls at `1068:28d0`, `2a30`, `2b90`, `2cf0`): the arrow is stopped
   (`stopMoving`), the crossbow reloaded, and the targets are tested in the order 2, 3, 1, 0 by x
   alone, the arrow spanning x..x+55 and a target x..x+75. A target matches when, with strict
   comparisons, the arrow lies inside it (t < a and a+55 < t+75), its left edge lies inside the
   arrow (a < t < a+55), or its right edge does (t < a, t+75 < a+55, a < t+75). The first match gets
   `target_hit` (`1068:08ab`); if none matches, the arrow is spent and nothing scores.

The target hit need not be the one that stopped the arrow (BUGS T5).

## The hit animation

`target_hit`: the target stops (`mover_stop_moving_dc`), its timer is set to 55 ms, the score
changes (below), `animation_play` starts and the first hit frame is drawn. Each 55-ms tick then
shows the next frame (`target_tick`) while `hitFrame` counts 0→8; at 8 (about 0.44 s)
`target_respawn` (`1068:0991`) puts the timer back to 100 ms, erases the target, draws a new
identity and re-enters it: `[0]` and `[1]` at x 0x18 moving right, `[2]` and `[3]` at x 565 moving
left, on their own row. `[1]` starts only when it is more than 0x58 px from `[0]`, `[2]` only when
it is more than 0xb0 px from `[3]`; a target that does not start is re-armed on its next tick
(step 3 under Targets).

## Scoring

`g_score` (a 16-bit int in the BSS) starts at 0. `target_hit` tests the target's identity:
- a girl (`curStrip` < 3): `tiro_hit_girl`, **+150**, plays `uii.wav`;
- a traveco: `tiro_hit_traveco`, **−150**, plays `nossa.wav`.

Both also play `tirojogo.wav` and redraw the score box. There is no clamp and no bonus.

**Score display** (`tiro_draw_score`, `1068:2ed4`): the 192×32 box at (448, 400) is restored from
the background, then `sprintf(" %04d", g_score)` or `sprintf("-%04d", −g_score)`; each of the five
characters, the leading space included, is drawn with its own `TextOut` at x = 492 + 32·i, y = 408,
black, transparent, in the DC's default font. `tiro_blit_score_box` (`1068:2e89`) copies the box to
the window.

## End of the game

On every target tick (for `[2]` only when it is not in its hit animation) the handler tests
`lives == 1`; when it holds it sends itself `WM_DESTROY` (`SendMessage`, `1068:1e41` etc.) and
carries on. `lives` starts at 16 and every SPACE press takes one, so the game ends at the first
target tick after the 15th press (BUGS T3, T4).

`WM_DESTROY` in `tiro_scene_handle_message`: `wave_stop_all`, `wave_free_all`, `wave_mix_close`,
MCI `close musica`, then `PostMessage(g_noiteWnd, 0x40a, g_score > 0, (long)g_score)`. It returns
0, so `APPWNDPROC` kills timer 1 and posts `WM_QUIT`; `app_exit` deletes the game. **TIRO is won
when the final score is positive.** A window close (`WM_CLOSE` → `DestroyWindow`) reports the
current score the same way.

## Protocol with NOITE.EXE

| Msg | Direction | wParam | lParam | Meaning |
|---|---|---|---|---|
| `0x40b` | NOITE → TIRO | 0 | NOITE's main window (low word) | hello; TIRO stores it in `g_noiteWnd` (in `APPWNDPROC`, after the game declines it) |
| `0x40c` | TIRO → NOITE | TIRO's window | 0 | ready; posted once, on the first message after `g_started` when `g_noiteWnd` is set (`g_handshakePending` 1 → 0) |
| `0x40a` | TIRO → NOITE | 1 won (score > 0), 0 lost | the score (sign-extended 16-bit `g_score`) | result |

NOITE's `handler_3fhall` (1020:7b06; `src/handlers/3fhall.zig`):
- a right click on the door shuffled to the minigame: `WinExec("<CD>tiro\tiro.exe")` and timer
  0x14 (100 ms);
- timer 0x14: `FindWindow("Tiro ao Alvaro")`; once found, kills the timer and posts `0x40b`;
- `0x40c`: minigame running, hides the main window;
- `WM_SYSTIMER` while running: if the window is gone, posts itself `0x40a` (0, 0), a loss with no
  score change; the tick is swallowed;
- `0x40a`: realizes the palette, shows the main window, records the result in
  `Game.minigameWon[1]`, adds lParam to the score (a negative TIRO score lowers it); a win goes to
  `3fprisao` with the player at (0xf0, 0xc8); a loss takes a life and goes back to `3fhall` at
  (0xf0, 0xc8), or to `6fsaida` (game over) when lives reach exactly 0.

## Keys and mouse

| Input | Effect |
|---|---|
| SPACE | fire (see The arrow); every press, and every key repeat, takes an arrow |
| LEFT | aim one step left ('E'), with wrap |
| RIGHT | aim one step right ('D'), with wrap |
| any other key | nothing (the handler returns 1) |
| mouse moves and clicks (0x200–0x202, 0x204, 0x205) | swallowed |

`tiro_scene_handle_message` answers every key, timer and mouse message itself, so the engine's
`game_handle_message` (player walking, panel, items, exits) never runs in TIRO.

## Music and sound

- Music: MCI sequencer, `pac.mid`, alias `musica`. `play musica notify` at start;
  `MM_MCINOTIFY` with `MCI_NOTIFY_SUCCESSFUL` → `play musica from 0 notify` (it loops); the handler
  returns 1 for every `MM_MCINOTIFY`. `WM_ACTIVATE` active and not minimised →
  `play musica notify` + `wave_mix_activate`; otherwise `pause musica` + `wave_mix_deactivate`
  (a failure shows "Erro Wave Mix"); it returns 0 either way, so `DefWindowProc` also runs.
  `close musica` at the end.
- Sound: WaveMix, five waves, each played once with no notify window: `ARCFLE02.WAV` per shot,
  `uii.wav` / `nossa.wav` plus `tirojogo.wav` per hit, and `PASARS01.WAV` on every `WM_PAINT`
  (`APPWNDPROC`). The handler's `0x3bd` (wave done → `wave_stop_all`) never arrives, since no wave
  is played with a notify window.
