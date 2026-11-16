# XILINDRO.EXE: the game as implemented

"Xilindro" (window title and class; *xilindró* is slang for jail) is the street fight against a jail
inmate that NOITE.EXE's `3fstreet` handler launches: one round against a computer opponent, against
a 90 s clock. It is SALGIN's fight (`docs/salgin/GAME.md`) with other numbers and a few other
mechanics. This file describes what the code does, bugs included (they are listed in `BUGS.md`,
section XILINDRO). Addresses are Ghidra `seg:off` in `/XILINDRO.EXE`; names are the current Ghidra
names. Functions are in `FUNCTIONS.md`, structs and globals in `DATA.md`.

## Files

All opened by relative name: `fundluta.bmp` (background, 640×480), the 11 fighter strips `sbsoco`
`sbchme` `sbrast` `sbchal` `sbanda` `sbpula` `sbdefa` `sbdefe` `sbcai` `sbsego` `sbflut` (231×266,
3 frames each), the 11 opponent strips `sasoco` `sachme` `sarast` `sachal` `saanda` `sapula`
`sadefa` `sadefe` `sacai` `sasego` `sacome` (252×295, 3 or 2 frames: 3,2,3,2,2,3,2,2,3,3,3),
`porrada.bmp` (the PORRADA banner, 232×42), `energia.bmp` (an energy-bar tile, 16×19), `panel.bmp`
(status bar and panel frames, never shown), `porrada.mid` (music), `soco2`, `soco`, `dor3`, `dor1`,
`chute3`, `vaias`, `lutamal3.WAV`, `murmlut2.WAV` (sounds), `arialbd.fot` (registered, never used).
`CENAPEQ2.BMP`, `SFINTERF.BMP`, `CHUTE`, `CHUTE2`, `CHUTES`, `GOLPE`…`GOLPE4`, `LUTA` and
`LUTA3.WAV` are on the disc but never opened.

## Startup

1. `entry`, `WinMain` (`1038:0202`), `app_init` (`1038:0055`): as TIRO and SALGIN. A second
   instance gets "O aplicativo já está aberto !!!". `new XilindroGame` (`xilindro_game_ctor`,
   `g_game`/`g_xilindroGame`); a 640×480 window "Xilindro".
2. `WM_CREATE` (`APPWNDPROC` `1038:0335`): `xilindro_game_on_create` (`1048:0210`), then
   `g_started = 1` and the system timer id 1, 50 ms.
3. `xilindro_game_on_create` → `game_init(this, "Virtual", hwnd)`:
   - `xilindro_game_create_init_scene`: a XilindroScene, `secondsLeft` = 90;
   - `xilindro_scene_create` (`1068:2ae7`): `scene_create` with `xilindro_scene_create_screen`
     (`fundluta.bmp`) and `xilindro_backdrop_create` (5-px occupancy grid, no walls); MCI
     `open porrada.mid type sequencer alias musica`, `play musica notify`; `wave_mix_init`; the
     eight waves; `murmlut2.WAV` (crowd murmur) starts looping for the whole fight;
   - the status bar and the XilindroPanel are created but stay hidden;
   - `xilindro_game_create_player` (`1048:0029`): the Fighter (`g_fighter`) at (0, 0x96), guard
     strip 6, `energy` 91;
   - `PostMessage(hwnd, 0x401)` (the handler restamps and draws the clock on it).
4. Still in `xilindro_game_on_create`: the fighter's own timer (FighterVtbl.startTimer, id 10,
   1100 ms) and a move to the right edge are started, then `xilindro_create_opponent`
   (`1068:0000`: the Opponent at (200, 0x8c), walking left, `energy` 91), `xilindro_create_banner`
   (`0119`: PORRADA at (200, 200), blitted once to the window) and `xilindro_create_energy_bar`
   (`01ea`: both energies 91).

## Heartbeat

As in SALGIN, nothing reads a timer id: timer 1 (50 ms), the id-10 object timer and the end timer
0xc only make `WM_SYSTIMER`s, which the scene handler swallows. **Every** message first runs the
clock block of `xilindro_scene_handle_message` (`1068:0d79`), driven by `GetTickCount`:

| Stamp | Period | Does |
|---|---|---|
| `g_lastPumpTick` | ≥ 200 ms | `wave_pump`, and the **beat**: the fight step after the message's own case |
| `g_lastSecondTick` | > 1000 ms | `secondsLeft--`, redraw the clock |
| `g_lastFrameTick` | > 100 ms | after the round: the winner's animation and the end count |

The fight runs in 200 ms beats, rounded up to the 50 ms timer.

## The fight

The fighter (the player) stands on the left, the opponent to its right. A fighter's move is its
strip (`SceneObject.curStrip`); `moveFrame` counts the frames played, one per beat, and at
`framesLeft` the move ends.

| Strip | Fighter (key) | Opponent | Damage of the fighter's blow | Damage of the opponent's attack |
|---|---|---|---|---|
| 0 *soco*, punch | PgUp | attack | 1 | 4 |
| 1 *chute médio*, middle kick | Up | attack | 2 | 2 |
| 2 *rasteira*, sweep | Down | attack | 1 | 2 |
| 3 *chute alto*, high kick | Home | attack | 2 | 6 |
| 4 *anda*, walk | Left / Right | approach | | |
| 5 *pula*, jump | Insert | — | none | |
| 6 guard | (rest) | — | | |
| 7 *defesa*, block | End | — | | |
| 8 *cai*, fall; 9 reel | hit reactions | hit reactions | | |
| 10 victory | round won | round won | | |

The damage tables are `g_fighterMoveDamage` {1, 2, 1, 2} and `g_opponentMoveDamage` {4, 2, 2, 6}
(0 for strips 4 and up). The energies that decide the round are the energy bar's `fighterEnergy`
and `opponentEnergy`.

**The fighter's attack** (`WM_KEYDOWN`) sets the strip, frame 0, `moveFrame` 0 and the latches
(Keys). The blow lands at once, on the key press, when |opponent.x − fighter.x| ≤ 100:
- the blow's waves play;
- **recoil**: when fighter.x − 100 > −50, the fighter jumps 100 px back (x, nextX and targetX);
- `opponentEnergy` loses `g_fighterMoveDamage[strip]` (PgUp, Up and Home also lower the unused
  `Opponent.energy`);
- **Down and Home trade**: `fighterEnergy` also loses `g_opponentMoveDamage[the opponent's
  strip]`, i.e. the opponent's attack damage if it is attacking (strips 0–3), else 0. PgUp and Up
  never cost the fighter anything;
- the opponent's tile check (The energy bar), `opponent_stop_moving`;
- **always** a reaction of the opponent, whatever its strip:
  `g_reactionTable[fighter strip][opponent strip][opponentEnergy < 6]`. An attacking opponent
  (0–3) keeps its strip; a walking, jumping or blocking one (4, 5, 7) reels (9), or blocks (7)
  against the high kick; one on guard (6) falls (8); below 6 energy every non-attacking opponent
  falls. `Opponent.reacting` is set.

Out of range the move just plays. Insert plays `chute3` + `dor1` at once and deals nothing; End
(block) changes only the pose.

After a recoil the gap is usually over 130 px, so on the next beat the opponent's approach (below)
replaces its reaction strip with the walk: a reaction is seen in full only when the gap stays
≤ 130 (a hit from 30 px or closer, or a fighter at x ≤ 50).

## The opponent

On each beat, after the KO test and the fighter's frame step:
1. **Approach**: farther than 130 px, it walks left 32 px a beat (`opponent_walk` `1068:0a08`;
   starting the walk, strip 4, if it is not moving), so it stops 99–130 px away, out of the
   fighter's 100-px reach. `opponent_walk`'s own clamp (68 px) is never reached.
2. **Animation**: within 130 px, not moving and its animation running, it steps its frame (unless
   `reacting`); at the end of the move it jumps back +100 px (x at most 500) in one go, back to the
   walk strip 4. Pinned at x 500 it is left moving, so within 130 px it attacks again on the next
   beat.
3. **Attack**: within 130 px and moving, or not running, it attacks:
   - `opponent_choose_attack` (`1068:0b85`): `srand(time(NULL))`, then strip `rand() % 4`; against
     a jumping fighter (strip 5) a sweep becomes the high kick. The reseed makes the choice a
     function of the clock second (BUGS X3);
   - the attack's waves (`xilindro_play_opponent_move_waves`); the fighter stops walking;
   - a fighter in strip 4–7 (walk, jump, guard, block) plays a reaction,
     `g_reactionTable[opponent strip][fighter strip][Fighter.energy < 10]` (the second column is
     never used, BUGS X2), which locks all keys; then `fighterEnergy` loses
     `g_opponentMoveDamage[opponent strip]`, blocking included (BUGS X1). Against a block, a walk
     or a jump, the punch and the two lower attacks show the reel (9), the high kick the block (7);
     against the guard, the fall (8);
   - a fighter in any other strip (attacking, reacting, 8–10) **clashes**: `opponentEnergy` loses
     `g_fighterMoveDamage[fighter strip]` and `fighterEnergy` loses
     `g_opponentMoveDamage[opponent strip]`, with no reaction.

The damage lands when the attack starts, from up to 130 px away. If the fighter stands still the
opponent cycles: attack (2–3 beats), jump back 100 px, walk in, attack again, every 6–7 beats
(about 1.3 s), for 3.5 energy on average. A Left press with the opponent to the right more than
80 px away and not moving starts it walking.

## The clock

`XilindroScene.secondsLeft` starts at 90 and loses 1 on each clock tick (a little over a second
each). `xilindro_draw_clock` restores the 20×15 box at (310, 22) from the background and draws
"%2.2d" in yellow (`SetTextColor(0x0000FFFF)`: COLORREF is 0x00BBGGRR); `xilindro_blit_clock`
copies it to the window.

## The energy bar

`g_energyBar` holds `fighterEnergy` and `opponentEnergy` (91 each). The bar is drawn as tiles: when
a side's energy is 7 or more below its mark level (`g_fighterBarMark`/`g_opponentBarMark`, 91),
`energy_bar_add_mark` adds one `energia.bmp` tile at y 20 and the level drops by 7. The fighter's
tiles grow left from x 290, the opponent's right from x 333; they are never erased. The fighter's
level is checked only after the opponent's attack, the opponent's only after the fighter's hit
(BUGS X8). The loser gets one more tile at the end of the round.

## End and result

The round ends:
- **by KO**, on the beat, when either energy is ≤ 0 (all keys locked): the opponent wins when its
  energy is still above 0, otherwise the fighter (a double KO gives the fighter the pose, BUGS X7);
- **on time**, when `secondsLeft` reaches 0: **the fighter wins unless its energy is below the
  opponent's** (a tie is a win).

The winner plays strip 10 and the loser's side gets a tile; a fighter win plays `vaias` (the crowd
boos), an opponent win `lutamal3.WAV`. `g_fightOver` is set and timer 0xc (100 ms) started. From
then on each > 100 ms tick advances the animation of the side ahead on energy (the fighter on a
tie) and redraws the arena; keys are ignored, and from the 31st tick (about 3.1 s) the handler posts
itself `WM_DESTROY` on every tick until it arrives. Both outcomes close this way; the `MM_WOM_DONE` (0x3bd) case is unreachable,
since no wave is played with a notify window.

`WM_DESTROY` (once, `g_resultSent`): `wave_stop_all`, `wave_free_all`, `wave_mix_close`,
`close musica`, then `PostMessage(g_noiteWnd, 0x40a, won, score)` with
won = !(fighterEnergy < opponentEnergy) and score = won ? fighterEnergy × 150 : −1000 (16-bit,
sign-extended). It has no `g_fightOver` test (BUGS X6). It returns 0, so `APPWNDPROC` kills timer 1
and posts `WM_QUIT`.

## Protocol with NOITE.EXE

| Msg | Direction | wParam | lParam | Meaning |
|---|---|---|---|---|
| `0x40b` | NOITE → XILINDRO | 0 | NOITE's main window | hello; stored in `g_noiteWnd` |
| `0x40c` | XILINDRO → NOITE | XILINDRO's window | 0 | ready; posted once, on the first message after `g_started` |
| `0x40a` | XILINDRO → NOITE | 1 won, 0 lost | 150–13,650 on a win (≤ 0 after a double KO; 0 in the Corrigida version), −1000 on a loss | result |

NOITE's `handler_3fstreet` (1020:8750; `src/handlers/3fstreet.zig`), the street-escape cutscene:
- when its video ends (`MM_MCINOTIFY` successful): closes the video, `WinExec("<CD>xilindro\
  xilindro.exe")`, timer 0x14 (100 ms);
- timer 0x14: `FindWindow("Xilindro")`; once found, kills the timer and posts `0x40b`;
- `0x40c`: minigame running, hides the main window;
- `WM_SYSTIMER` while running: if the window is gone, posts itself `0x40a` (0, 0), a loss with no
  score change;
- `0x40a`: shows the main window, records the result in `Game.minigameWon[3]` and adds lParam to
  the score (a loss takes 1000 off); a win goes to the `3fstree2` cutscene, a loss to `3fstree1`.
  - `3fstree1` (when its video ends): takes a life, then back to `3fprisao`, or to `6fsaida` (game
    over) when the lives reach exactly 0;
  - `3fstree2` (when its video ends): to `3fhall` when the SERIAL minigame (`minigameWon[2]`,
    `3farmcai`) is won too, otherwise back to `3fprisao`.

## Keys and mouse

| Input | Effect |
|---|---|
| PgUp, Up, Down, Home | attack, strips 0–3 (The fight) |
| End | block, strip 7 |
| Insert | jump, strip 5: `chute3` + `dor1`, no damage |
| Left / Right | one 32-px step per press, strip 4; Left at x ≤ 0 and Right at x ≥ 400 stop (tested before the step, BUGS X11); Right within 100 px of the opponent puts the fighter exactly 68 px from it (BUGS X10) |
| key-up of Left / Right | stop walking, back to guard (whatever move is playing, BUGS X4) |
| other keys | nothing (the handler returns 0) |
| mouse (0x200–0x202, 0x204, 0x205) | swallowed |

The port's Corrigida version (`--fix all`) adds a key layout and a controls screen in front of
this handler (`docs/salgin/DESIGN.md` "Decisions"): ↑ jumps, ↓ blocks, A, S, D and F are
PgUp, Up, Home and Down; a controls screen and PORRADA's 2 s come before the round.

The latches (`g_key*Held`): a key starts its move only while its own latch is 0, and sets it. An
attack or the block also sets every other latch except Insert's (BUGS X5); Insert sets all 8; Left
and Right set only their own and their key-up clears it. All 8 clear when the fighter's move ends
(unless both energies are ≤ 0), or when the opponent's move ends with both energies above 0; a
reaction of the fighter and the KO set all 8. Every key-up redraws the arena. While the round is
over, keys return 1 at once.

## Music and sound

- Music: MCI sequencer, `porrada.mid`, alias `musica`, as SALGIN: `play musica notify` at start,
  `MM_MCINOTIFY` with `MCI_NOTIFY_SUCCESSFUL` → `play musica from 0 notify` (it loops);
  `WM_ACTIVATE` active and not minimised → `play musica notify` + `wave_mix_activate` (a failure
  shows "Erro Wave Mix"), otherwise `pause musica` + `wave_mix_deactivate`; the handler returns 1.
  `close musica` at the end.
- Sound: WaveMix, pumped on every beat. Every wave is played with `hWndNotify` 0, so `wave_play`
  passes the flags 7 (`CLEARQUEUE|USELRUCHANNEL|HIGHPRIORITY`): overlapping waves get free
  channels. Each event plays a pair at once:

| Event | Waves |
|---|---|
| the whole fight | `murmlut2.WAV`, looped |
| PgUp hit | `soco` + `dor1` |
| Up or Home hit; any Insert | `chute3` + `dor1` |
| Down hit | `soco2` |
| opponent's punch (0) | `soco` + `dor3` |
| opponent's middle or high kick (1, 3) | `chute3` + `dor3` |
| opponent's sweep (2) | `soco2` |
| fighter wins | `vaias` |
| opponent wins | `lutamal3.WAV` |

## Display

The arena is the band y 140–434 (0x8c, 295 high), 640 wide. `xilindro_redraw_arena` (`1068:0c87`)
restores it from the background, draws the opponent and then the fighter (in front), and copies
it to the window; it runs after every beat, every key-up and every end tick. Nothing else in the
band is redrawn, so the PORRADA banner at (200, 200), blitted once while the window is still being
created, never stays on screen (BUGS X9). The clock and the energy tiles sit above the band and are
drawn on their own. The two fighters' redraw slots (`fighter_redraw_overlapping`,
`opponent_redraw_overlapping`) redraw each other.

## Fair fight (Corrigida)

The Corrigida's default fight is the MK3 one (below, `fight_mk3`); this section and the next describe the fight
you get with `--fix all,-fight_mk3` or the web's `?mk3=0`.

The port's Corrigida version (`--fix all`) replaces the opponent's approach and attack with a fair
fight (`fight_fair`, `src/core/fight_fair.zig`; research, tuning and checks in
`docs/fights/FAIRNESS.md`). Everything above is the Original's, and stays so without the flag.

- **The cycle.** The opponent walks in (32 px a beat), stands one step out of reach (gap 101-132) for
  1-2 beats, steps in to 69-100 px and winds up: it shows frame 0 of the attack it picked (the
  Original's `rand() % 4`, the sweep turned into the high kick against a jumping fighter) for 2 beats and
  plays the attack's own wave (`soco` for the punch, `chute3` for the kicks, `soco2` for the sweep: frame 0 alone does
  not tell the punch and the middle kick from the stance). Then it strikes, plays the attack's other frames, stands a beat
  in range, jumps 100 px back and pauses 1-2 beats. One arrival in 6 is a feint: it stands a beat and
  backs off.
- **The strike** lands only if the gap is still at most 100 and the fighter is not blocking (End / ↓)
  a punch or a kick, not jumping (Insert / ↑) the sweep and not reeling (strips 8, 9). A hit is the
  Original's reaction and damage (`g_opponentMoveDamage`, {4, 2, 2, 6}), the fighter's own move cut short; there is no clash.
- **The fighter's blows** land at a gap of at most 100 (the Original's) for {2, 4, 2, 4}, twice the Original's,
  with the 100-px recoil as before. A reeling opponent cannot be hit; any other reacts (the reel, or the fall when weak), and a
  blow in its wind-up cuts the attack. No trade.
- **Whiffs.** A blow thrown while the opponent stands one step out of reach makes it step in at once:
  its strike lands on the beat the fighter's 3-beat move ends.
- **Answers.** Every attack has one: step back (←) during the wind-up and it whiffs, then step in and
  punish it while it stands; block a punch or a kick; jump the sweep; or hit first.
- PORRADA's frozen intro (the controls screen) holds the opponent; without the screen it stands 10 beats.
- F9 (Debug builds) shows the gap, the AI's phase and the beat count over the arena.

## Easy opponent (Corrigida)

On top of the fair fight, `--fix all` turns on `fight_easy_ai` (the decisions are `src/core/fight_easy.zig`,
carried out by `arena.zig`'s `easyDecide`; research, the behaviour table, tuning and win rates in
`docs/fights/EASY_AI.md`). The moves, the tells and the strike's rules are the fair fight's; what changes is what
the opponent *decides* whenever it is free (it has arrived in range, or a pause, a wait or a guard is over). It
rolls on a personality table with the game's own `rand()`, and never reads a key:

- **In range** it attacks (the wind-up, then the strike), waits, guards, backs off or feints, 58 / 15 / 10 / 10 / 7 in 100;
  an open fighter (in a blow of its own) is punished 35% of the time first. It attacks less when it leads by 18 energy
  points and more when it trails by 25.
- **Walking in** it stands 1-2 beats instead of stepping 20% of the time; one step out of reach it now and then (12%)
  starts a blow from there, which whiffs unless the fighter walks in.
- **Wait** is a stance for 1-4 beats (the walk strip 4, frame 0), in reach: it can be hit.
- **Guard** is strip 7 (the art's guard pose) for 2-4 beats. It holds the punch and both kicks (no damage, no recoil,
  `soco`) and the sweep goes under it, as the fighter's own block works. A blocked blow is countered 25% of the time:
  the guard ends at once and a 3-beat wind-up follows, a beat longer than the usual tell.
- **A hit** it takes without reeling 10% of the time unless it is winding up or striking (the
  damage and the pain wave happen, the opponent goes on with what it was doing); a hit in the wind-up always cuts the attack.
  After the reel it guards 15% of the time and backs off 25% (a hop of 100 px, then a pause).
- **Wind-ups** are 2 beats, 25% of them a lazy 3. The fighter's whiffed blow (the Original's tell for "step in now") is punished 50% of the time.
- **Mercy**: after it lands a hit it stands one more beat before it decides again.
- F9 (Debug builds) shows the phases `wait` and `guard` too; `tools/fight_bots.py` plays it with player bots.

## MK3 fight (Corrigida)

`fight_mk3`, in `--fix all` (so the web's Corrigida version too; `--fix all,-fight_mk3` and the web page's `?mk3=0`
turn it off), replaces the fight (the opponent's AI, the
blows, the beat) with Mortal Kombat 3's: `docs/fights/MK3.md` has every mechanic, its value and its source;
the engine is `src/core/fight_mk3/` (shared, sprite-agnostic), its glue here `core/fight_mk3/xilindro.zig`
and `arena.zig`'s `mk3Update`. The fighters keep XILINDRO's own art: `core/fight_mk3/strips.zig` converts the strips the game
has loaded (the fighter's `sb*` for the player, the inmate's `sa*` for the opponent, the files listed above, at their native size, the
key colour 11 transparent as the Original's blits, the shadow split off and drawn on the floor; the inmate's, which face left, are mirrored) at
WM_CREATE into two MK3 characters, each with its own pictures: which strip plays which move is the table in `docs/fights/MK3.md` 11.5
(`soco` the punches, `chme` the middle kick, `chal` the high kick and roundhouse, `rast` the sweep, `anda` the walk, `pula` the jump, `defa` the rest
pose, `defe` the block, `cai` the fall and the lying figure, `sego` the hit, `flut` / `come` the win). What stays
XILINDRO's: the background, the clock (90 s: the better energy wins at zero), the energy bar's two numbers
(MK3's 166-unit health mapped to 0-91, so the score is still energy x 150), the controls screen (with MK3's
keys), the sounds and WM_DESTROY's result to NOITE. What is new: the fighters are drawn by `Match.view` at the
display rate (`host.Program.view`), opening 400 px apart (MK3's `set_x_woff`: each 96 arcade px in from its edge), the energy bars drain over the
background's yellow bar. The F9 key shows the hurt (blue) and hit (red) boxes in a Debug build.

## Smooth motion (Corrigida)

With `fight_smooth_motion` (`--fix all`; `src/core/fight_smooth.zig`, TIRO's mechanism) the window
shows each fighter's move over its beat instead of in one go: the walk's 32-px step per beat (the opponent's approach, the fighter's step per
press), the opponent's 100-px jump back after its move or a reel and the fighter's 100-px recoil
after a landed blow. Only the presented picture
changes (`host.Program.view`, every web frame, every SDL loop turn and every harness dump): the
arena band is rebuilt there as `xilindro_redraw_arena` does it (the background band, PORRADA while it
shows, the opponent, the fighter) with each fighter at its shown x; the clock, the energy tiles and
the F9 overlay lie above the band and come from the screen. Positions, reach checks, hits,
energies, timers, `rand()` and results are the game's, so every script keeps its result.

- A move is seen where the screen shows it: the fighter's x changed since the last arena redraw.
  It runs one beat (200 ms) from where the picture showed the fighter then, so a move that starts
  during another carries on from it. The picture lags the game by at most one beat.
- A step (at most 32 px) is linear: consecutive steps chain into a steady 160 px/s walk (2-3 px a
  60-Hz frame). A longer move (the 100-px jump back and recoil, the Right clamp) is eased out
  (1 - (1 - t)^2): it leaves fast, as the blow or the end of the move that caused it, and slows
  into its landing (15, 14, 12, 11, 10, 8, 8, 6, 4, 4, 2, 1 px a 16-ms frame for 100 px), a hop
  rather than a fast walk with no walking frames.
- The animation frames stay one per beat (there is no in-between art).
