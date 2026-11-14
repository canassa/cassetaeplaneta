# SALGIN.EXE: the game as implemented

"Porrada na Sala de Ginástica" (window title and class "Sala de Ginástica") is the gym fist fight
launched by NOITE.EXE's `4fsalgin` handler: one round against a computer opponent, against a 90 s
clock. This file describes what the code does, bugs included (they are listed in `BUGS.md`,
section SALGIN). Addresses are Ghidra `seg:off` in `/SALGIN.EXE`; names are the current Ghidra
names. Functions are in `FUNCTIONS.md`, structs and globals in `DATA.md`.

## Files

All opened by relative name: `fundluta.bmp` (background, 640×480), the 11 player strips `vbbsoc`
`vbbvoo` `vbras` `vbbsal` `vbbgan` `vbbsat` `vbgin` `vbbdef` `vbtomb` `vbbmup` `vbbmen` (173×279,
3 frames each, `vbbmen` 11), the 11 opponent strips `magaso` `machvi` `maband` `machsa` `magaan`
`magasa` `maging` `magade` `matomb` `matoup` `macofi` (216×295, 3 frames each, `macofi` 22),
`porrada.bmp` (the PORRADA banner, 232×42), `energia.bmp` (an energy-bar tile, 16×19),
`panel.bmp` (status bar and panel frames, never shown), `porrada.mid` (music), `soco2`, `soco`,
`dor4`, `dor2`, `chute3`, `vaias`, `mane.WAV` (sounds), `arialbd.fot` (registered, never used).
`COMECESP`, `LUTA`, `LUTA2`, `LUTAMAL`, `LUTAMAL2` and `APANHA.WAV` are on the disc but never
opened.

## Startup

1. `entry`, `WinMain` (`1038:0202`), `app_init` (`1038:0055`): as TIRO (`docs/tiro/GAME.md`). A
   second instance gets "O aplicativo já está aberto !!!". `new SalginGame` (`salgin_game_ctor`,
   `g_game`/`g_salginGame`); a 640×480 `WS_POPUP|WS_CAPTION` window, centred, no system menu.
2. `WM_CREATE` (`APPWNDPROC` `1038:0335`): `salgin_game_on_create` (`1048:0210`), then
   `g_started = 1` and the system timer id 1, 50 ms (the heartbeat, below).
3. `salgin_game_on_create` → `game_init(this, "Virtual", hwnd)`:
   - `salgin_game_create_init_scene`: a SalginScene, `clock` = 90;
   - `salgin_scene_create` (`1068:29e2`): `scene_create` with `salgin_scene_create_screen`
     (`fundluta.bmp`) and `salgin_backdrop_create` (5-px occupancy grid, no walls); MCI
     `open porrada.mid type sequencer alias musica`, `play musica notify`; `wave_mix_init`; the
     seven waves;
   - the status bar and the SalginPanel are created but stay hidden;
   - `salgin_game_create_player` (`1048:0029`): the Fighter (`g_fighter`) at (0, 0x8c), guard strip
     6, `health` 91;
   - `PostMessage(hwnd, 0x401)` (the handler restamps and draws the clock on it).
4. Still in `salgin_game_on_create`: the fighter's own timer (id 10, 1100 ms) and a move to the
   right edge are started, then `salgin_create_opponent` (`1068:0000`: the Opponent at (200, 0x8c),
   walking left, `health` 91), `salgin_create_banner` (`0119`: PORRADA at (200, 200), blitted once
   to the window) and `salgin_create_energy_bar` (`01ea`: both energies 91).

## Heartbeat

Nothing in the game reads a timer id. Timer 1 (50 ms) posts `WM_SYSTIMER`, which the scene
handler swallows; the id-10 object timers and the end timer 0x14 only add more `WM_SYSTIMER`s and
are never dispatched to their objects. But **every** message first runs the clock block of
`salgin_scene_handle_message` (`1068:0d73`), driven by `GetTickCount`:

| Stamp | Period | Does |
|---|---|---|
| `g_lastPumpTick` | ≥ 200 ms | `wave_pump`, and the **beat**: the fight step after the message's own case |
| `g_lastClockTick` | > 1000 ms | `clock--`, redraw the clock |
| `g_lastAnimTick` | > 100 ms | after the round: the winner's animation and the end count |

So the fight runs in 200 ms beats, rounded up to the 50 ms timer.

## The fight

Both fighters stand on y 0x8c, the player on the left. A fighter's move is its strip
(`SceneObject.curStrip`); each move is 3 frames, one per beat (`frameCount` counts them, and at
`framesLeft` the fighter goes back to the guard strip 6).

| Strip | Player (key) | Opponent | Damage dealt by the player |
|---|---|---|---|
| 0 *soco*, punch | PgUp | attack | 1 |
| 1 *voadora*, flying kick | Up | attack | 2 |
| 2 *rasteira*, sweep | Down | attack | 1 |
| 3 *salto*, jump kick | Home | attack | 2 |
| 4 *ginga*, walk | Left / Right | approach | |
| 5 jump | Insert | — | none |
| 6 guard | (rest) | (rest) | |
| 7 *defesa*, block | End | — | |
| 8 *tombo*, fall; 9 reel | hit reactions | hit reactions | |
| 10 victory | round won | round won | |

**The player's attack** (`WM_KEYDOWN`) sets the strip, frame 0, and the latches (Keys). The
blow lands at once, on the key press, when |opponent.x − fighter.x| ≤ 120:
- the opponent's energy loses `g_fighterDamage[strip]` = {1, 2, 1, 2}, and so does its `health`
  (not on the sweep); the blow's waves play; the opponent stops walking;
- an opponent in strip 4–6 (4–7 for the sweep), walking or on guard, plays a reaction:
  `g_reactionStrips[(its strip − 4)·4 + attack][health < 6]`: the reel (9), or the fall (8) for
  the sweep or when its `health` is below 6; `hitLock` delays its first reaction frame by a beat;
- an opponent in any other strip (attacking, reacting) gets no reaction: a **trade**, and the
  player's `health` loses `g_opponentDamage[its strip]` = {2, 1, 1, 3} (0 for strips 4 and up).
  The energy bar does not move.

Out of range the move just plays. Insert plays `chute3` + `dor2` at once and deals nothing; End
(block) changes nothing but the pose.

**Hit reactions of the player** come from the same table with the player's strip as the row and
`health < 10` choosing the fall.

## The opponent

On each beat, after the KO test and the player's frame step:
1. **Approach**: farther than 100 px, it walks left 32 px a beat (`opponent_walk` `1068:0a08`), so
   it stops 69–100 px away. `opponent_walk` also clamps nextX to fighter.x + 100, but only where
   nextX is not past it, which the handler's > 100 test never lets happen (the clamp is dead).
2. **Animation**: within 100 px and in a move (not walking, not strip 6) it steps its frame; at
   the end of the move it jumps back +100 px (x at most 500) in one go, back to guard. A hit
   reaction therefore also knocks it back 100 px.
3. **Attack**: within 100 px and walking or on guard, it attacks:
   - `opponent_choose_attack` (`1068:0b85`): `srand(time(NULL))`, then strip `rand() % 4`; against a
     jumping player (strip 5) a sweep becomes the jump kick. The reseed makes the choice a
     function of the clock second (BUGS S5);
   - the counter waves (`salgin_play_counter_wave`);
   - the player stops walking and **its energy loses `g_fighterDamage[the opponent's strip]`**
     = {1, 2, 1, 2} (BUGS S1), whatever the player is doing, blocking included (BUGS S2);
   - a player in strip 4–7 (walk, jump, guard, block) plays a reaction, which locks all keys
     until it ends. Against a block, the punch and both kicks show the block pose (7), the sweep
     the fall.

The damage lands when the attack starts. If the player stands still the opponent cycles: attack
(3 beats), jump back 100 px, three or four steps in, attack again: every 7–8 beats, about 1.5 s. Walking left away from it pulls it along (a Left press with the gap above 80 starts
it walking).

## The clock

`SalginScene.clock` starts at 90 and loses 1 on each clock tick (a little over a second each).
`salgin_draw_clock` restores the 20×15 box at (310, 22) from the background and draws "%2.2d" in
yellow (`SetTextColor(0x0000FFFF)` at 1068:2b63; COLORREF is 0x00BBGGRR); `salgin_blit_clock`
copies it to the window.

## The energy bar

`g_energyBar` holds `playerEnergy` and `opponentEnergy` (91 each), the only scores that decide
the round. The bar is drawn as tiles: each time a side's energy is 7 or more below its mark level
(`g_playerMarkLevel`/`g_opponentMarkLevel`, 91), `energy_bar_add_mark` adds one `energia.bmp`
tile at y 20 and the level drops by 7 (one tile per hit at most). The opponent's tiles grow right
from x 333, the player's left from x 290; they are never erased. The loser gets one more tile at
the end of the round.

## End and result

The round ends:
- **by KO**, on the beat, when either energy is below 1: the opponent's KO is tested first (player
  wins), otherwise the opponent wins; all keys are locked;
- **on time**, when `clock` reaches 0: **the player wins unless their energy is below the
  opponent's** (a tie is a win).

The winner plays strip 10, the loser's side gets a tile; a player win plays `vaias` (the crowd
boos), an opponent win `mane.WAV`, the only wave played with a notify window. `g_roundOver` is
set and timer 0x14 (100 ms) started. From then on each >100 ms tick advances the winner's
animation and redraws the arena; keys and the beat stop.
- A player win sets `g_endReady` on the first tick; 30 ticks (3 s) later the handler posts itself
  `WM_DESTROY`.
- An opponent win closes only when `mane.WAV` ends: `MM_WOM_DONE` (0x3bd) posts `WM_DESTROY`
  (BUGS S6).

`WM_DESTROY` (once, `g_resultSent`): `wave_stop_all`, `wave_free_all`, `wave_mix_close`,
`close musica`, then `PostMessage(g_noiteWnd, 0x40a, won, score)` with
won = !(playerEnergy < opponentEnergy) and score = won ? playerEnergy × 100 : −1000
(sign-extended). It has no round-over test (BUGS S7). It returns 0, so `APPWNDPROC` kills timer 1
and posts `WM_QUIT`.

## Protocol with NOITE.EXE

| Msg | Direction | wParam | lParam | Meaning |
|---|---|---|---|---|
| `0x40b` | NOITE → SALGIN | 0 | NOITE's main window | hello; stored in `g_noiteWnd` |
| `0x40c` | SALGIN → NOITE | SALGIN's window | 0 | ready; posted once, on the first message after `g_started` |
| `0x40a` | SALGIN → NOITE | 1 won, 0 lost | 100–9,100 on a win, −1000 on a loss | result |

NOITE's `handler_4fsalgin` (1028:0678; `src/handlers/4fsalgin.zig`):
- when the gym scene's 0xf4 animation (`4smaoe`) finishes: `stop musica`,
  `WinExec("<CD>salgin\salgin.exe")`, timer 0x14 (100 ms);
- timer 0x14: `FindWindow("Sala de Ginástica")`; once found, kills the timer and posts `0x40b`;
- `0x40c`: minigame running, hides the main window;
- `WM_SYSTIMER` while running: if the window is gone, posts itself `0x40a` (0, 0), a loss with no
  score change;
- `0x40a`: shows the main window and adds lParam to the score (a loss takes 1000 off); a win goes
  to the `espquete` cutscene; a loss takes a life and goes back to `4fbar`, or to `6fsaida` (game
  over) when the lives reach exactly 0. The result stays in a scene global, not in
  `Game.minigameWon`.

## Keys and mouse

| Input | Effect |
|---|---|
| PgUp, Up, Down, Home | attack, strips 0–3 (The fight) |
| End | block, strip 7 |
| Insert | jump, strip 5: `chute3` + `dor2`, no damage |
| Left / Right | one 32-px step per press (the latch ignores key repeats), strip 4; Left at x < 1 and Right at x ≥ 400 stop (tested before the step, BUGS S11); Right within 100 px of the opponent puts the fighter exactly 68 px from it (BUGS S10) |
| key-up of Left / Right | stop walking, back to guard (whatever move is playing, BUGS S3) |
| other keys | nothing (the handler returns 0) |
| mouse (0x200–0x202, 0x204, 0x205) | swallowed |

The latches (`g_key*Held`): a key starts its move only while its own latch is 0, and sets it.
An attack or the block also sets every other latch except Insert's (BUGS S4); Insert sets all 8;
Left and Right set only their own and their key-up clears it. All 8 clear when the player's move
ends, or when the opponent's move ends with both energies above 0; a reaction of the player and
the KO set all 8. Every key-up redraws the arena. While the round is over, keys return 1 at once.

## Music and sound

- Music: MCI sequencer, `porrada.mid`, alias `musica`. `play musica notify` at start;
  `MM_MCINOTIFY` with `MCI_NOTIFY_SUCCESSFUL` → `play musica from 0 notify` (it loops).
  `WM_ACTIVATE` active and not minimised → `play musica notify` + `wave_mix_activate` (a failure
  shows a message box); otherwise `pause musica` + `wave_mix_deactivate`. The handler returns 1.
  `close musica` at the end.
- Sound: WaveMix, pumped on every beat. Each event plays a pair (blow, pain) at once:

| Event | Waves |
|---|---|
| PgUp hit | `soco` + `dor2` |
| Up or Home hit; any Insert | `chute3` + `dor2` |
| Down hit | `soco2` |
| opponent's punch (0) | `soco` + `dor4` |
| opponent's flying or jump kick (1, 3) | `chute3` + `dor4` |
| opponent's sweep (2) | `soco2` |
| player wins | `vaias` |
| opponent wins | `mane.WAV` (with notify: its end closes the game) |

## Display

The arena is the band y 140–434 (0x8c, 295 high, the fighters' height), 640 wide.
`salgin_redraw_arena` (`1068:0c81`) restores it from the background, draws the opponent and then
the player (in front), and copies it to the window; it runs after every beat, every key-up and
every end tick. Nothing else in the band is redrawn, so the PORRADA banner at (200, 200), blitted
only once while the window is still being created, never stays on screen (BUGS S9). The clock and
the energy tiles sit above the band and are drawn on their own. The two fighters' redraw slots
(`fighter_redraw_overlapping`, `opponent_redraw_overlapping`) redraw each other.
