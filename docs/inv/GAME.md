# INV.EXE: the game as implemented

"Invasores" (window title and class) is the Space Invaders minigame that NOITE.EXE's `4fsacaet`
handler launches. This file describes what the code does, bugs included (they are listed in
`BUGS.md`, section INV). Addresses are Ghidra `seg:off` in `/INV.EXE`; names are the current Ghidra
names. Functions are in `FUNCTIONS.md`, structs and globals in `DATA.md`.

## Files

All opened by relative name: `Espaco.bmp` (background, 640×480), `Canhao.bmp` / `Brocha.bmp` (the
cannon, 1 frame, and its destruction, 7 frames, 65×67), `Movein.bmp` (a column of five invaders,
2 frames of 88×217), `Naboom1.bmp` (one invader exploding, 8 frames of 88×44), `Disco.bmp` /
`Explod.bmp` (the saucer, 3 frames of 61×32, and its explosion, 8 frames of 111×103), `Tiro.bmp`
(the shot, 2 frames of 12×22, frame 1 blank), `Bomba.bmp` / `Bomtir.bmp` (a bomb, 12×22, and its
impact, 3 frames of 25×28), `panel.bmp` (status bar and panel frames, never shown), `doom1.mid`
(music), `tiroes2`, `explos`, `nave`, `explo1`, `brocha3`, `explo5`, `marcha`, `desceniv` `.wav`
(sounds), `arialbd.fot` (TIRO's, registered, never used). `NABOOM.BMP`, `EXPLO2`–`EXPLO4`,
`QUEDANAV` and `TIROESP` `.WAV` are on the disc but never opened.

## Startup

1. `entry`, `WinMain` (`1038:0202`), `app_init` (`1038:0055`): as TIRO. A second instance gets
   "O aplicativo já está aberto !!!". `new InvGame` (`inv_game_ctor`, `g_game`/`g_invGame`); a
   640×480 `WS_POPUP|WS_CAPTION` window "Invasores" (no system menu, so no close button).
2. `WM_CREATE` (`APPWNDPROC` `1038:0335`): `inv_game_on_create` (`1048:01ff`), then `g_started = 1`
   and the system timer id 1, 50 ms. Unlike TIRO, `WM_PAINT` plays no wave.
3. `inv_game_on_create` → `game_init(this, "Mech", hwnd)`:
   - `inv_game_create_init_scene`: the InvScene (no panel, no status bar, no exits);
   - `inv_scene_create` (`1068:0026`): `scene_create` with `inv_scene_create_screen`
     (`Espaco.bmp`) and `inv_backdrop_create` (32-px occupancy grid, no wall cells); MCI
     `open doom1.mid type sequencer alias musica`, `play musica notify`; `wave_mix_init`; the eight
     waves; the score box drawn with " 0000";
   - the status bar and the panel are created but stay hidden;
   - `inv_game_create_player` (`1048:0029`): the Cannon (`g_cannon`, a Player2D) at (340, 380),
     timer 0xa at 60 ms, 20-px steps, `lives` 4, `hitFrame` −1.
4. Still in `inv_game_on_create`, in this order: `inv_on_create_hook` (empty),
   `inv_create_invader_columns`, `inv_create_invader_explosion`, `inv_create_saucer`,
   `inv_create_bombs`, `inv_create_shot` (all `1068`). The bomb and shot creators write through
   their still-null object pointers first (BUGS.md, INV Harmless).

## Heartbeat

Every object has its own system timer, and `inv_scene_handle_message` (`1068:1c9c`) compares
`WM_SYSTIMER`'s wParam with the objects' timer ids (`getTimerId`), the first match winning:

| Id | Period | Object |
|---|---|---|
| 1 | 50 ms | the app (`APPWNDPROC`); matches no object |
| 0x10 | 55 ms | the invader explosion |
| 0xa | 60 ms | the cannon |
| 0xc | 60 ms | the saucer |
| 0xe | 10 s | the saucer's launch (`Saucer.timer2Id`) |
| 8, 9 | 2 s, 5 s | the drops of bomb 0 and bomb 1 (`Missile.timer2Id`, `timer2IdB`) |
| 6, 7 | 55 ms | bomb 0, bomb 1 |
| 0xd | 55 ms | the shot |
| 0xf | `g_invaderPeriod` | the four invader columns (one timer) |

Before the chain, every `WM_SYSTIMER`, whatever its id, runs the win test (End and result). The
handler returns 1 for every timer message, so the engine's timer code never runs.

## The invaders

The 20 invaders are four InvaderColumns (`g_invaderColumns[0..3]`, `inv_create_invader_columns`
`1068:016e`): one 88×217 `Movein.bmp` picture each, at x 40 + 108·i, y 60, holding five
`InvaderCell`s 44 px apart (`x`, `y`, `alive`). `lowestAlive` is the index of the bottom live cell
(−1 for an empty column); a column is drawn and restored only (lowestAlive + 1)·44 px high
(`invader_column_draw`, `invader_column_restore_background`). `g_invadersLeft` starts at 20.

**The formation step** (timer 0xf; `marcha.wav` on each tick): every live column takes one 20-px
step (InvaderVtbl.step = `invader_column_step` `1068:181f`) and flips its picture's frame. The order
depends on `g_formationDir` (2 right, the start; 1 left): columns 3..0 moving right, 0..3 moving
left, so the leading column steps first. When a column reports `atEdge`, `g_formationDir` flips and
every live column not yet stepped this tick turns with it (`invader_column_turn` `1068:157b`).

- **Right edge**: a column at x ≥ 464 (background width − 2 widths) turns left and **descends
  22 px** (a quarter of its width; `invader_column_stop_moving_dc` `1068:13a8`). Each new lowest y
  of the formation (`g_formationMaxY`, from 60) plays `desceniv.wav`.
- **Left edge**: a column at x ≤ 44 (half its width) turns right **without descending**. The test
  is off until the formation's first reversal (`firstPass`).
- **Landing**: when the leading column's right-edge turn leaves its lowest live invader's bottom
  at y ≥ 390 ((lowestAlive + 1)·44 + y, tested before the descent in
  `invader_column_stop_moving_dc` and again after it in `invader_column_step`; the cannon's top is
  380), the column sets `landed` and `g_invadersLanded` and sends `WM_DESTROY` with wParam 0:
  **the game is lost**. It is sent several times in that tick (BUGS.md, INV Harmless).

**The speed** is `g_invaderPeriod`, 500 ms at the start. After each kill: with 15, 10 or 5
invaders left it drops by 100 ms (400, 300, 200); with 1 left it becomes 55 ms. The new period is
set on timer 0xf and in each column. The last kill also takes the "multiple of 5" branch
(BUGS.md, INV Harmless).

## The cannon

LEFT and RIGHT (`WM_KEYDOWN`, latched in `g_keyLeftHeld`/`g_keyRightHeld`, cleared on key-up)
start the cannon toward its edge (`moveToEdgeH`: x −32, half off the screen, or 575) and take one
20-px step at once; it then steps every 60 ms. A fresh press of the other key reverses it at once.
Releasing a key with the other still held resumes the other direction, otherwise the cannon stops.
`cannon_can_step` (`1068:0837`) never stops it (when the grid reports it blocked it is first put at
(620, 460), then moved on in the same step). `cannon_blit_to_dc` blits a rect one step wider on
each side, so the 20-px trail is erased.

**SPACE** fires when `g_keySpaceHeld` is 0 (always: nothing sets it, BUGS I1), the cannon is not
exploding (`hitFrame` == −1) and the shot is not moving: the shot starts at (cannon x + 27,
cannon y − 30) and flies up (`moveToEdgeV`, 20 px per 55 ms, timer 0xd) with `tiroes2.wav`. There
is one shot, so at most one is in flight.

**Losing a life** (`cannon_lose_life` `1068:07a6`, after a bomb hit): `lives` drops by 1; at 0
(the fourth hit) the game is lost (`WM_DESTROY`, wParam 0). Otherwise the cannon stops and plays
`Brocha.bmp`: the cannon branch counts `hitFrame` up to 7 frames of 60 ms, then goes back to
`Canhao.bmp`, sets `hitFrame` −1 and resumes a held arrow key. A direction key pressed during the
explosion moves the cannon instead and resets `hitFrame`; until the cannon's first tick after the
hit `hitFrame` is still −1, so SPACE fires then too (BUGS I2).

## The shot and the hit test

On each shot tick `missile_move_tick` (`1068:0f2f`) stops the shot at y < 5, otherwise
`missile_move_step` takes a step. The step asks the occupancy grid (`missile_can_step` `1068:0fba`):
a free rect moves on; a grid edge stops it; a blocking object is classified by the type-test slots
into `Missile.hitState`, the class of the blocker: '1' shot, '2' invader (a column or the
explosion), '3' saucer, '4' cannon (stops), '5' bomb. The handler then reads the shot's `hitState`
and resets it:

- **'3', the saucer**: `g_score` **+500** (`explo1.wav`), `saucer_explode` (below).
- **'2', an invader: the second stage.** For each column (0..3, all tested): the shot hits when
  col.x < shot.x < col.x + 88 (strict) and (shot.y − col.y) / 44 (signed, truncated) ==
  `lowestAlive`. Only the bottom live invader of a column can be hit. A hit clears that cell, moves
  the explosion onto it and plays it (`invader_explosion_start`, `Naboom1.bmp`, 8 frames of 55 ms),
  recomputes `lowestAlive`, gives `g_score` **+100** (`explos.wav`), vanishes the shot
  (`shot_vanish`: frame 1, stopped), decrements `g_invadersLeft` and applies the speed-up. A shot
  that matches no column flies on.

The other codes do nothing. The cannon's `Player2D.score` (a dword) also gets +10 per invader and
+50 per saucer; nothing reads it, and NOITE gets `g_score`.

## The saucer

`inv_create_saucer` (`1068:0343`) arms timer 0xe at 10 s (`SaucerVtbl.armTimer`). Each tick of it
puts the saucer at (50, 10), draws it, plays `nave.wav` and starts it right (20 px per 60 ms).
`saucer_check_edge` (`1068:0d3e`, the 0xc branch) stops, hides and parks it at x ≥ 518, about 1.4 s
later. A shot hit (`saucer_explode` `1068:0c16`) stops it, moves it 20 px up and left and plays
`Explod.bmp` (7 frames of 60 ms), then hides it until the next launch.

## The bombs

Two bombs (`g_bombs[0..1]`, `inv_create_bombs` `1068:0541`), parked hidden at (620, 0). On each
tick of its drop timer (8: 2 s; 9: 5 s; `MissileVtbl.armTimer`), a bomb that is not moving is
dropped by the first live column (0..3) within 88 px of the cannon (|cannon.x − col.x| ≤ 88): from
(col.x + 44, col.y + (lowestAlive + 1)·44), falling 20 px per 55 ms; `g_bombHitCannon[i]` is
cleared. With no column over the cannon nothing drops.

On each bomb tick (not in its impact animation): `missile_move_tick` (the bomb stops below
y 470), then the handler's own test: cannon.x < bomb.x < cannon.x + 65 and bomb.y > 410 sets
`hitState` '4'. Then:
- **'4', the cannon**: once per drop (`g_bombHitCannon[i]`): `g_score` **−500** (`brocha3.wav`)
  and `cannon_lose_life`;
- **'1', the shot met it**: `explo5.WAV`, `shot_vanish` and `bomb_shot_down` (the bomb stops and
  shows `Bomtir.bmp`, which the bomb branch ends on the next tick).

## Scoring

`g_score` (a signed 16-bit int) starts at 0: **+100** per invader, **+500** per saucer, **−500** per
bomb hit, with no clamp. The maximum is 20 × 100 plus 500 per saucer.

**Score display** (`inv_draw_score` `1068:351d`): the 192×20 box at (416, 437) is restored from the
background, then `sprintf(" %04d", g_score)` or `sprintf("-%04d", −g_score)`; each of the five
characters gets its own `TextOut` at x = 460 + 32·i, y = 445, pale grey (`0xedeeee`), transparent,
in the DC's default font. `inv_blit_score_box` (`1068:34d2`) copies the box to the window.

## End and result

- **Win**: the kill that leaves `g_invadersLeft` at 0 re-arms timer 0xf at 65,491 ms (BUGS.md,
  INV Harmless); the next `WM_SYSTIMER` of any id (within 50 ms) sends `WM_DESTROY` with **wParam 0xffff** and sets
  `g_invadersLeft` to −1.
- **Loss**, `WM_DESTROY` with **wParam 0**: the fourth bomb hit, or the landing.

`WM_DESTROY` in `inv_scene_handle_message`: `wave_stop_all`, `wave_free_all`, `wave_mix_close`,
`close musica`, then `PostMessage(g_noiteWnd, 0x40a, wParam, (long)g_score)`: **the won flag is
WM_DESTROY's own wParam**, not the score (TIRO sends `g_score > 0`). There is no guard: each
`WM_DESTROY` posts a result. It returns 0, so `APPWNDPROC` kills timer 1 and posts `WM_QUIT`. The
column tick's own `g_invadersLeft < 1` test would send a second `WM_DESTROY` (wParam 0) after a
win, but timer 0xf is then 65 s away and `WM_QUIT` is retrieved before any later timer message.

## Protocol with NOITE.EXE

| Msg | Direction | wParam | lParam | Meaning |
|---|---|---|---|---|
| `0x40b` | NOITE → INV | 0 | NOITE's main window | hello; stored in `g_noiteWnd` |
| `0x40c` | INV → NOITE | INV's window | 0 | ready; posted once, on the first message after `g_started` |
| `0x40a` | INV → NOITE | 0xffff won, 0 lost | the score (sign-extended `g_score`) | result |

NOITE reaches the minigame from the bar: the right answer to the esoteric's question in
`handler_4fbar` switches to `4FSACAET`. NOITE's `handler_4fsacaet` (1028:0000;
`src/handlers/4fsacaet.zig`), the flying-saucer scene:
- on scene start the saucer (`disco`, INI Number 0xf3) plays its animation and wave;
- when that wave ends (`MM_WOM_DONE`): `WinExec("<CD>Inv\Inv.exe")` (an "Erro na abertura do jogo"
  box when it reports out of memory), timer 0x14 (100 ms);
- timer 0x14: `FindWindow("Invasores")`; once found, kills the timer and posts `0x40b`;
- `0x40c`: minigame running, hides the main window;
- `WM_SYSTIMER` while running: if the window is gone, posts itself `0x40a` (0, 0), a loss with no
  score change;
- `0x40a`: shows the main window, adds lParam to the score (a negative INV score lowers it), keeps
  wParam ≠ 0 as the result in its own state (no `Game.minigameWon` slot) and switches to
  `4fmarte2` on a win, `4fmarte` on a loss. It takes no life.
  - `4fmarte` (1028:0308; `src/handlers/4fmarte.zig`), the losing scene: the Martian (0xf0) plays
    its animation and wave; when the wave ends a life is taken, and the game goes back to `4fbar`,
    or to `6fsaida` (game over) when the lives reach exactly 0;
  - `4fmarte2` (1028:04e6; `src/handlers/4fmarte2.zig`), the winning scene: the Martian (0xf1)
    speaks; when its wave ends, the `ESOTEBOY` cutscene, which goes back to `4fbar`.
  Neither handles `0x40a`, so the extra results of a landing (BUGS.md, INV Harmless) are ignored.

## Keys and mouse

| Input | Effect |
|---|---|
| SPACE | fire (The cannon); every key repeat fires again once the shot is free (BUGS I1) |
| LEFT / RIGHT | move the cannon (The cannon) |
| key-up of LEFT / RIGHT | resume the other held key, or stop |
| other keys | nothing (the handler returns 1) |
| mouse (0x200–0x202, 0x204, 0x205) | swallowed |

`inv_scene_handle_message` answers every key, timer and mouse message (but the double click
0x203) itself, so the engine's `game_handle_message` key, timer and mouse code never runs.

## Music and sound

- Music: MCI sequencer, `doom1.mid`, alias `musica`, as TIRO: `play musica notify` at start,
  `MM_MCINOTIFY` with `MCI_NOTIFY_SUCCESSFUL` → `play musica from 0 notify` (it loops);
  `WM_ACTIVATE` active and not minimised → `play musica notify` + `wave_mix_activate` (a failure
  shows "Erro Wave Mix"), otherwise `pause musica` + `wave_mix_deactivate`. `close musica` at the
  end.
- Sound: WaveMix. Every wave is played with `hWndNotify` 0, so `wave_play` passes the flags 7
  (`CLEARQUEUE|USELRUCHANNEL|HIGHPRIORITY`) and the handler's `MM_WOM_DONE` (0x3bd) case is
  unreachable.

| Event | Wave |
|---|---|
| SPACE fires | `tiroes2.wav` |
| an invader is hit | `explos.wav` |
| the saucer is launched | `nave.wav` |
| the saucer is hit | `explo1.wav` |
| a bomb hits the cannon | `brocha3.wav` |
| the shot meets a bomb | `explo5.WAV` |
| each formation step | `marcha.wav` |
| the formation reaches a new lowest y | `desceniv.wav` |

## Arcade rules (Corrigida)

Everything above is the 1995 game (the Original, and the Corrigida's bug fixes I1 and I2 on it). With
`Fixes.inv_arcade_rules` (`--fix all`) INV plays by the rules of **Taito's 1978 Space Invaders** on INV's art
and sounds, the owner's request after he found the Corrigida's cannon and bombs "horrible" and "impossible to
prevent being shot": the original's invaders step 20 px every 500 ms in four columns that turn at different
times, the cannon steps 20 px every 60 ms, and two bombs fall at fixed times from the columns near the cannon
and cannot be seen coming. The research (the arcade's program, address by address) and every number is
`docs/inv/ARCADE.md`; the code is `src/inv/arcade/` (design: DESIGN.md "Arcade rules (Corrigida)"). The
original's cannon, columns, bombs, shot and saucer code does not run: the objects only carry the pictures,
and the game draws them onto the presented picture (`inv_clean_render`).

**Keys:** LEFT and RIGHT (or A and D) move the cannon, SPACE fires, Esc leaves (a loss, as closing the
window). A controls screen comes first (`inv_controls_screen`): any key or a click takes it down and is no
move; the game starts then (half a second of nothing moving, and the invaders do not fire for another 0.8 s).

**The rack** is the original's 4 x 5 invaders (`MOVEIN.BMP`'s column cut into its five invaders, two pictures
each), 108 px apart across and 38 up. It marches **as one block**, a little every frame: 6 px per as many frames as
there are invaders (a third of a second with 20), so the whole rack speeds up as they die, to 6 px a frame
(360 px/s) for the last one (540 going right). All invaders share one picture, which toggles each time the
rack has moved 6 px but no oftener than every 8 frames. At a wall the direction flips, the rack stands still
sideways and **drops 16 px, 2 px a frame**, then goes back. (The arcade moves one invader a frame, a ripple;
with this art's big two-pose sprites it flickers.) Ten drops take the bottom row from y 194 to
the cannon's top; an invader placed on that line has **landed**: the cannon blows up and the game is lost. A
kill stops the march for 16 frames (`NABOOM1.BMP`). Invaders eat the bunkers they walk over.

**The cannon** moves 180 px/s (constant, from x 24 to 551, 2.9 s across) and starts, and returns after a
death, at the left. **One shot at a time**, 420 px/s (the bolt crosses the field in 0.74 s), spent when it
hits an invader (the next shot waits for the burst, 16 frames), a bunker, a bomb, the saucer (at once) or the
top (a burst of 10 frames). A fire button still down when a shot ends does not fire again: release and press.

**The bombs** (`BOMBA.BMP`, up to three on screen) are the arcade's three kinds. The **rolling** one falls from
the lowest invader of the column over the cannon's middle: it aims. The **plunger** and **squiggly** fall from
the columns of the arcade's table (its 11 columns mapped on our 4). They fall smoothly at 140 px/s (175 with
three invaders or fewer), slower than the cannon and a third of the shot's speed. How many fall at once is the
arcade's reload rule: a new bomb may leave only when each other one has taken more than N steps (a step is 3
frames), N = 48 at the start, which never happens (one bomb at a time), 16 once 30 % of a rack's points are
scored (two or three bombs), 11, 8 and 7 later; so a casual player meets one bomb at a time for the first
third of the wave. A shot that meets a bomb destroys both (`explo5.wav`). **A bomb that hits the cannon** takes
a life (-500, `brocha3.wav`): the cannon blows up (`BROCHA.BMP`, a second) with everything standing still, then
is back at the left, the bombs and the shot gone, and the invaders do not fire for 0.8 s. **Three lives**, shown
with the score (a number and a little cannon each in reserve); the third hit is the loss.

**The four bunkers** are the arcade's shield picture (22 x 16 pixels) in 3 x 3 px blocks in a green of the
game's palette (the disc has no bunker art), 66 x 48 px, y 312. A shot bites the bunker from below with the
arcade's 8 x 8 burst, a bomb from above with its 6 x 8 one, an invader walking over it eats it; each burst
clears its own blocks, so the holes are ragged as the arcade's. A shot fired from under a bunker digs into it.

**The saucer** (`DISCO.BMP`) launches 12.8 s after the rack has first dropped, then every 12.8 s (half the
arcade's 25.6 s: a wave of ours is a third of the arcade's), alternating its direction with the shot count, when
no squiggly bomb is falling and three invaders are left; it crosses in 4.6 s at 114 px/s (a shot must go
between the invader columns to reach it). Its score is the arcade's mystery score by **the shots fired**: 100,
50, 50, 100, 150, 100, 100, 50, **300**, 100, 100, 100, 50, 150, 100 by the pointer that advances at every
shot's end and wraps after 15, so **the 8th shot, the 23rd and the 38th are worth 300** (the famous rule). Times
ten here: 500, 1000, 1500 or **3000**; shown on its burst (`EXPLOD.BMP`) 8 frames after the hit.

**Score:** the arcade's 10, 10, 20, 20, 30 by row from the bottom, times ten (INV's +100): 100, 100, 200, 200,
300, a rack 3600; the saucer; -500 a cannon lost. The score box and the result are INV's: clearing the rack is
the win (`WM_DESTROY` 0xffff after half a second), the third cannon lost or a landing the loss (0), each with
`g_score` for NOITE.

**The picture** is rebuilt from the clean background every frame (no trails, no flicker): the sprites are
shown between the game's frames, from where they were a frame ago, at the display's rate. The sounds are INV's:
`tiroes2` the shot, `explos` an invader, `nave` the saucer, `explo1` its hit, `brocha3` the cannon, `explo5` a
shot meeting a bomb, `marcha` the march (no oftener than 7 a second), `desceniv` a drop; the music is
`doom1.mid` as ever.

**How beatable** (`tools/inv_bot.py`: the bot plays the very game, `src/inv/arcade/bot.zig`, with a reaction
time; 400 games each, wins, cannons lost of 3, seconds of a game):

| Player (the bot's reaction to a new bomb, the age of the picture it aims by, its aim error, how often it looks at the bombs) | Wins | Cannons lost | A game |
|---|---|---|---|
| attentive: 400 ms, 100 ms, 10 px, 9 times in 10 | 100 % | 0.4 | 32 s |
| casual: 600 ms, 150 ms, 25 px, 7 in 10 | 82 % | 1.4 | 38 s |
| inattentive: 800 ms, 200 ms, 40 px, 5 in 10 | 41 % | 2.3 | 40 s (46 s a win) |
| distracted: 1000 ms, 250 ms, 50 px, 35 in 100 | 16 % | 2.8 | 37 s (50 s a win) |

With no key at all the cannon at the left is hit three times, the last at 27 s (`lost -1500`). A win takes
20 kills (about 26 shots) in 30 to 45 s; the saucer comes once or twice in that and is hit in one game of five.
The losses are the lives; a rack that lands is rare because the last two or three invaders (the fast ones)
have ten drops (12 s or more) to be hit.

**Tests and tools:** `zig build test` (the rules, the bunkers, the clock, the bot's sim: `src/inv/arcade/`);
`tools/play/inv-corrigida-*.input` (the controls screen, Esc, a won game by the bot, the saucer's 23rd shot, a
lost game with no key, both through NOITE's `4fsacaet`); `tools/inv_bot.py` (the table above; `--emit` writes
a bot's game as an input script, exact to the millisecond because the bot runs the game's own clock).
