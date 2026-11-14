# INFERNO.EXE: the game as implemented

"Inferno" is the platformer in hell launched by NOITE.EXE's `3fpapmal` handler when the pope's
punishment video ends. This file describes what the code does, bugs included (they are listed in
`BUGS.md`, section INFERNO, letters H). Addresses are Ghidra `seg:off` in `/INFERNO.EXE`; names are
the current Ghidra names. Functions are in `FUNCTIONS.md`, structs and globals in `DATA.md`.
INFERNO runs TIRO's engine in the large model; where this file says "as TIRO", `docs/tiro/GAME.md`
has the detail.

## Files

All opened by relative name: `Fundo.bmp` (background, 640×480), the 12 hero strips (below),
`Plataf.bmp` (platform, 84×12), the drinks `cerva`, `chopp`, `copo` and the present `3spres`, the
rocks `rocha01`–`03`, the cross `cruz`, the hazards `carvao`, `diabo`, `fogo` (`.bmp`), `mario.mid`
(music), `sonicmor`, `sonicpul`, `sonicmag`, `sonicf.WAV` (sounds). Frames are stacked vertically;
`DATA.md` §5 has every strip's frames and size. On the disc but not referenced: `DATA.md` §5.

## Startup

As TIRO (`entry`, `WinMain` 1038:021a, `app_init` 1038:0055, `APPWNDPROC` 1038:0353), with the
class and title "Inferno" and a `WS_POPUP | WS_CAPTION` 640×480 window (no system menu):
1. `WM_CREATE` → `inferno_game_on_create` (1048:0183) → `game_init(this, "Mario", hwnd)`:
   - `inferno_game_create_init_scene`: an InfernoScene (`hasPlayer` 1, no panel, no status bar);
   - `inferno_scene_create` (1068:0000): the backdrop (`Fundo.bmp`) with `inferno_backdrop_create`
     (the floor wall: occupancy row 23); `g_startTick = GetTickCount()`; MCI `open mario.mid` alias
     `musica` and `play musica notify`; `wave_mix_init`; the waves `g_deathWave` (`sonicmor`),
     `g_pickupWave` (`sonicpul`), `g_magWave` (`sonicmag`), `g_pickupWave2` (`sonicpul` again) and
     `sonicf.WAV`, looped at once (its handle is kept only in `g_waves`); the score box (" 0000");
   - `inferno_game_create_player` (1048:0042): the Hero (`g_hero`, a Player2D) at (153, 306), move
     timer id 10 at 55 ms, animation timer id 15 at 180 ms, step 5 px, hit box 32×62.
2. `inferno_start_nop` (empty), `inferno_create_platforms` (1068:1a1e),
   `inferno_create_rocks_and_cross` (1068:272a), `inferno_create_hazards` (1068:3bf8).
3. `APPWNDPROC` sets `g_started` and starts system timer 1 (55 ms): no branch reacts to it, it only
   guarantees a message, hence a clock check, every 55 ms.

## The hero

| Strip | File | Frames | Use |
|---|---|---|---|
| 0, 2 | `marppa`, `marppal` | 2 | small, standing (right, left); frame 1 is the jump pose |
| 1, 3 | `marpa`, `marpal` | 8 | small, walking |
| 4, 6 | `margpa`, `margpal` | 2 | big, standing |
| 5, 7 | `marga`, `margal` | 8 | big, walking |
| 8, 9 | `3smort`, `3smortl` | 8 | death (facing right, left) |
| 10, 11 | `3svito`, `3svitol` | 4 | a big hero's hazard kill |

`Hero.facing` is 1 left, 2 right; `altStrips` 1 selects the big set. While `busy` (a jump) or while
its animation plays, the hero ignores the arrows.

**Walking.** LEFT/RIGHT set the walking strip and `walking`, and start a move to the screen edge
(`moveToEdgeH`), 5 px per 55-ms move tick (91 px/s). Key-up stops it. **The scroll zone:** from
x 340, facing right, a walk or a walking jump keeps the hero where it is and scrolls the world: each
move tick steps the rocks, the platforms and their drinks 5 px left, and the hazards walk 10 px per
tick instead of 5.

**Jumping.** UP (or numpad +) is the high jump, DOWN (or numpad −) the low jump: `hero_start_jump`
(1068:016c) rises 18 ticks (90 px) or 12 ticks (60 px) at 5 px per move tick, then the hero falls
at 5 px per tick to the floor line `g_floorY` (308), with no acceleration (`hero_jump_step`
1068:0edc). A jump started while walking drifts 2 px per tick sideways (not in the scroll zone,
where the world moves instead). The occupancy grid decides what the hero's next step runs into:
the floor wall (or any blocker with no object) ends the jump on the floor line; an object goes to
`hero_collide` (below).

**Big.** The cross makes the hero big (`hero_toggle_size` 1068:09be: `altStrips` 1, `powerTimer`
180). The hero-move branch of the handler counts `powerTimer` down and toggles back to small at 1,
after 179 move ticks (about 9.8 s). A second cross while big toggles back at once.

## The world

**Platforms and drinks.** 4 Platforms (`g_platforms`, `Plataf`) at (38, 247), (201, 204),
(380, 264), (524, 204), each carrying a Prop (`Platform.item`): `cerva`, `chopp`, `copo` and, on
platform 3, the present `3spres` (`presentReady` 1). They move only with the scroll (5 px per hero
move tick); a platform fully off the left edge comes back at x 638 with the next slot's height
(247, 204, 264, 204) and drink (`platform_tick` 1068:240d, `prop_drink_respawn`).

**Hitting a platform from below** (a jump into it, `hero_collide` 1068:0260): the hero bounces
down (a fall, `jumpKind` 2) and the platform's `platform_play` (1068:25e3) runs: a drink not yet
taken gives +100 and disappears until the platform respawns; the present, when ready and the hero
is small, gives +100 and opens (a play-once animation on timer 0xc). When it has opened the
handler calls `platform_drop_cross` (1068:1e5d): the cross appears beside the platform, moves right
for 5 cross ticks (600 ms), falls, and slides left along y 327 (`prop_cross_tick` 1068:2f93).

**The cross** (`g_cross`, `cruz`, `Prop.powerUp` 1): touching it gives +300 (`sonicmag`) and the
size toggle; it is parked at x 640.

**Rocks.** 6 Props (`g_rocks`: `rocha02`, `rocha01`, `rocha03` twice) along the top (y 24, 39, 45),
3 on screen at start. They scroll with the world; one reaching the left edge brings the next one in
at x 638 (`prop_rock_tick`, `g_rockIndex`, `g_rockOrder`). Nothing collides with them: they are
scenery.

**Hazards.** 6 Hazards (`g_hazards`): coal `carvao` (26×26, y 329; hazards 0, 3, 5), the devil
`diabo` (71×46, y 326; 1, 2) and fire `fogo` (29×37, y 335; 4), all walking left on the floor at
5 px per 60 ms (10 px while the world scrolls). Hazard 0 starts at x 43; when the active one
reaches x 50 the next (`g_hazardIndex`) enters at x 638, and one off the left edge is parked and
`g_hazardOrder` rotates (`hazard_tick` 1068:46f7).

## Collisions with a hazard

| Who moves into whom | Hero | Result |
|---|---|---|
| either, the hero more than 30 px above the hazard's y | small | a stomp: +150 (once per landing outside the scroll zone: `BUGS.md` H7), the hazard is parked |
| the hazard into the hero (`hazard_hit_player` 1068:3f86) | small | `inferno_lose_life` (−500, a life, `sonicmor`); the whole occupancy grid is wiped (H6); the hazard is parked; the death strip plays |
| the hero into the hazard (`hero_collide`) | small | the death strip plays and the hazard is parked, with no cost (H5) |
| either | big | +150, the hazard is parked, the kill strip (10, 11) plays |

When the hero's animation stops on strips 8–11 the handler calls `hero_anim_done` (1068:1936): the
hero stands on the floor line facing right. Nothing else happens on a death: the game goes on until
the lives or the clock run out.

## Scoring

`g_score` (16-bit int) starts at 0; `g_lives` at 5.
- +150 a stomp or a big hero's kill (`inferno_score_add_150`, `sonicpul`);
- +300 the cross (`inferno_score_add_300`, `sonicmag`);
- +100 a drink or the present (`inferno_score_add_100`, the second `sonicpul` handle);
- −500 and a life, a hazard's hit (`inferno_lose_life` 1068:58b2, `sonicmor`). No clamp.

**Score display** (`inferno_draw_score` 1068:5a9f): as TIRO, the 192×32 box at (416, 400) restored
from the background, then `" %04d"` or `"-%04d"`, one `TextOut` per character at x = 460 + 32·i,
y = 408, colour 0x00EDEEEE, transparent.

## End of the game

- **The clock** (checked on every message, 1068:4bf2): 180,000 ms after `g_startTick` the handler
  sets `g_timeUp`, posts `0x40a (g_lives, g_lives ? 500 : g_score − 1000)` to NOITE, re-arms timer
  1 and restarts the clock as a grace period. During it every message at least 100 ms after the
  last report posts it again (H2), and from 1 s on every message posts `WM_DESTROY`. The game keeps
  running meanwhile. With a life left (always, here) the report is a flat 500.
- **The lives:** `inferno_lose_life` posts `WM_DESTROY` at 0 lives and reports nothing (H3).
- **`WM_CLOSE`** (End Task only) posts the same report (H4); `0x12` (`WM_QUIT`) too, but never
  arrives.
- **A `0x40a` received** posts `WM_DESTROY`.

`WM_DESTROY` (1068:4dbe): `wave_stop_all`, `wave_free_all`, `wave_mix_close`, MCI `close musica`;
`APPWNDPROC` then posts `WM_QUIT` (it never kills timer 1).

## Protocol with NOITE.EXE

| Msg | Direction | wParam | lParam | Meaning |
|---|---|---|---|---|
| `0x40b` | NOITE → INFERNO | 0 | NOITE's main window (low word) | hello; stored in `g_noiteWnd` (`APPWNDPROC`) |
| `0x40c` | INFERNO → NOITE | INFERNO's window | 0 | ready; posted before **every** message once `g_started` is set (H1) |
| `0x40a` | INFERNO → NOITE | `g_lives` | `g_lives ? 500 : g_score − 1000` | result (time-out, `WM_CLOSE`) |

NOITE's `handler_3fpapmal` (1020:8b40; `src/handlers/3fpapmal.zig`):
- `MM_MCINOTIFY` at the video's successful end: stops and closes it, `wave_mix_init`,
  `WinExec("<CD>inferno\inferno.exe")` and timer 0x14 (100 ms);
- timer 0x14: `FindWindow("Inferno")`; once found, kills the timer and posts `0x40b`;
- `0x40c`: minigame running, hides the main window;
- `WM_SYSTIMER` while running: if the window is gone, posts itself `0x40a` (0, 0), a loss with no
  score change (the only report of a game lost on lives, H3);
- `0x40a`: realizes the palette, shows the main window, `g_score += lParam`; `wParam` 0 takes a
  life and goes to `6fsaida` (game over) at 0 lives; otherwise, won or lost, `3fhall` at
  (0xf0, 0xaa). No won flag is kept.

So a survived game is worth 500 and a lost one costs a life with no score change; INFERNO's own
points never reach NOITE. INFERNO's later messages reach the hall: the trailing `0x40c` make
`3fhall` count a lost TIRO game (H1), and the time-out's second report a won one, which sends the
player to `3fprisao` (H2).

The port reproduces NOITE's side as is (`src/handlers/3fpapmal.zig`, `3fhall.zig`). INFERNO itself
is not ported: the headless backend's minigame stub (`src/platform/sim.zig`) answers the hello with
one `0x40c` and reports the won flag and score set in `Options.minigame` once, so H1 and H2 do not
appear there.

## Keys and mouse

| Input | Effect |
|---|---|
| LEFT, RIGHT | walk (latched until key-up; the two do not exclude each other) |
| UP, numpad + | high jump (90 px) |
| DOWN, numpad − | low jump (60 px) |
| any other key | nothing (the handler returns 1) |
| mouse moves and clicks (0x200–0x202, 0x204, 0x205) | swallowed |

A key-up of LEFT or RIGHT during a jump is ignored; the walk latches are cleared later by the move
timer when the hero has stopped. The latches `g_keyLeftHeld` … `g_keyDownHeld` stop auto-repeat.

## Timers

`WM_SYSTIMER` is dispatched by wParam, tested in this order (1068:53c5 onward):

| Test | Id | Period | Owner | Action |
|---|---|---|---|---|
| 1 | 10 | 55 ms | the hero's move (`getTimerId`) | `powerTimer`, `hero_move_tick` (the walk, the jump, the scroll of the world) |
| 2 | 15 | 180 ms | the hero's animation | `animation_tick`; on strips 8–11 `hero_anim_done` |
| 3 | 0xc | 120 ms | the drinks' animation | the present opening; then `platform_drop_cross` |
| 4 | 3 | 120 ms | the cross (only while moving) | `prop_cross_tick`; 5 ticks right, then the fall |
| 5 | 0xe | 60 ms | the hazards | `hazard_tick` for each active hazard |

Any other id (timer 1 included) returns 0. The hero's move timer starts with the first walk or jump
and is never killed. The rocks, the platforms and the drinks are moved from the hero's move tick,
not by timers of their own.

## Music and sound

- Music: MCI sequencer, `mario.mid`, alias `musica` (`play musica notify`; on `MM_MCINOTIFY` success
  `play musica from 0 notify`, so it loops; `WM_ACTIVATE` resumes or pauses it with WaveMix, and
  nothing else: the clock and the timers run on; `close musica` at the end).
- Sound: WaveMix, five waves: `sonicf.WAV` looped from the start, `sonicmor` (a life lost),
  `sonicpul` (+150), `sonicmag` (+300), `sonicpul` opened a second time (+100). The handler's
  `MM_WOM_DONE` (0x3bd) case is empty.
