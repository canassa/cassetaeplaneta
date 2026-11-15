# JARDIM.EXE: the game as implemented

"Noite Animal Jardim" is the first-person labyrinth (a Doom-like raycaster, source folder
`d:\c&p\doom\`) that NOITE.EXE launches at the end of the game, from `espquete` and `4fjarvamp`.
This file describes what the code does, bugs included (they are listed in `BUGS.md`, section
JARDIM, letters J). Addresses are Ghidra `seg:off` in `/JARDIM.EXE`; names are the current Ghidra
names. Functions are in `FUNCTIONS.md`, structs and globals in `DATA.md`. JARDIM runs TIRO's engine
in the large model, but the engine only hosts it: the game is the LabyrinthBackdrop (`1028`), its
32-bit walks and blitters (`1000–1018`) and the three phase scenes (`1098`, `10a8`, `10b0`).

## Files

All opened by relative name from `<CD>jardim` (NOITE `_chdir`s there). Per phase *N* = 1, 2, 3:
`raymapN.dat` (the map), `opcaoN.bmp` (640×480: the frame around the view, the sky and the floor),
`paredesN.bmp` (32×1800: 6 wall textures of 32×300), `rostoN.bmp` (44×330: 5 faces), `shotN.bmp`
(64×270: 2 shot frames), the hands strips, the objects (below) and `portainv.bmp` (the exit
object, never drawn). Shared: `labinter.bmp` (640×138, the control panel under the view),
`doom.mid` (music) and the waves. `passo1.bmp` (the Player's strip) is not on the disc
(`BUGS.md`, harmless). `DATA.md` lists the files on the disc that nothing names.

## Startup

As TIRO (`entry` 10b8:001a, `WinMain` 1020:021a, `app_init` 1020:0055): the class and title
"Noite Animal Jardim", a `WS_POPUP | WS_CAPTION` 640×480 window, the Game subclass
(`jardim_game_ctor`). `WM_CREATE` → `jardim_game_on_create` → `game_init`: the control panel
(`labinter.bmp`, timer 0xc), the Player (a dummy: its picture `passo1.bmp` does not load and it
is never shown, the phase scenes have `hasPlayer` 0), no status bar, and the first scene,
Phase1Scene (`jardim_game_create_init_scene`); `APPWNDPROC` starts system timer 10 (50 ms, only
the NOITE handshake uses it). The scene's create (`phase1_scene_create` 1098:0078) builds the
level, below.

**A phase scene's create** (`phase1/2/3_scene_create`):
1. `mapFile` = `raymapN.dat`; `labyrinth_scene_create` → `createScreen` → `labyrinth_backdrop_ctor`
   (`opcaoN.bmp`) → `labyrinth_backdrop_create` (1028:2191), once per backdrop: `g_startTick =
   GetTickCount()` the first time only (`g_startTickPending`); the minimap pens and brushes; the
   map rows and `raycast_build_tables`; `labyrinth_load_map`; the player at
   (`g_startX`, `g_startY`), also saved as the respawn point `startX/startY`; `viewAngle` 480
   (60°); the view rectangle; the sprite queue; **system timer 1 at 55 ms**, the game tick.
2. Phases 1 and 2: an Exit object (`portainv.bmp`) whose only use is its exit index
   (`scene_add_exit_at`).
3. The backdrop's objects: the face (`rostoN`, at (33, 382)), the shot (a Portable), the hands
   (`maosN` strips, at (145, 261); `hands.curStrip = g_curWeapon`), the wall strip (`paredesN`).
4. The phase's Portables (the tables below), each placed once at its constructor position
   (`labyrinth_place_object(-1, -1)`), then `placeObjects` (scene slot 0x12) places the map copies.
5. Phase 1 only: MCI `open doom.mid type sequencer alias musica`, `play musica notify`, and
   `wave_mix_init`. Every phase opens its own waves (`g_phaseNWaves`).
6. `handlerEnabled` = 1, `backdrop.active` = 1, `labyrinth_paint`.

## Units

- **Positions:** longs in 1/32 cell: cell = pos >> 5. The map is 57 columns × 80 rows
  (1824 × 2560 units); y grows upward (row 0 is the last line of the file).
- **Angles:** 2880 per turn (8 per degree), 0 = +x, counter-clockwise; 720 = +y.
- **Tables** (`raycast_build_tables` 1028:0077, FP emulator, once per backdrop and never freed):
  `g_labyrinthTables[0..6]`, 2881 longs each in 16.16 (index 2880 = 0): [0] tan, [1] cot,
  [2] ±32·|tan| (the y step of a 32-unit x step), [3] ±32·|cot|, [5] 1/cos, [6] 1/sin; [4] has
  481 entries, 22500/cos(a) for a = −30°..+30°, the wall-height factor with the fisheye
  correction. The angle of index *i* is (2·(i|1))·π/2880 + 0.0003272 rad, so no entry is exactly
  on an axis. `secAtAngle`/`cscAtAngle` point at [5]/[6] for the current angle: a move of *s*
  units is (s·65536/sec, s·65536/csc).

## The map

`raymapN.dat`: text, 80 lines of 57 characters plus CRLF (`labyrinth_load_map` 1028:056c, no
check of the line length). File line *k* is row 79 − *k*. `wallRows[80]` (58-byte rows) holds the
cell values, `objectRows[80]` (57 far `SceneObject *` per row) the objects.

| Char | Value | Meaning |
|---|---|---|
| space | 0 | floor |
| `1`–`6` | 1–6 | wall; texture (v+1)/2 − 1 (1–2 → 0, 3–4 → 1, 5–6 → 2); odd and even differ only in the collision push (below) |
| `7`, `8` | 7, 8 | exit door, texture 3; handled by the phase handlers' SPACE |
| `9`, `A`, `B`, `C` | 9–12 | door, textures 4 (9–10) and 5 (11–12); SPACE opens it (the cell becomes 0) |

A door pair (7/8, 9/10, 11/12) is one door in two orientations: in the walk along the vertical
lines an odd door is drawn see-through (the cell behind it is drawn instead) and an even door as a
plane recessed half a cell; the horizontal walk does the reverse. The shipped maps: map 1 uses
`1`–`9`, `A`–`C`; map 2 `1`–`4`, `6`, `7`, `9`, `A`, `B`; map 3 `1`–`4`, `6`, `8`, `9`–`C`.
Exit doors: map 1 `8` at row 77 col 0 (the exit) and `7` at row 0 col 27 (beside the start);
map 2 `7` at row 79 col 42 (the exit) and row 0 col 54 (beside the start); map 3 `8` at row 3
col 0 (beside the start).

## The raycaster

This is the 1995 renderer, which the Original keeps. The Corrigida (`jardim_raycaster`) draws the floor,
the walls and the sprites' clip with a proper per-pixel raycaster; steps 2–4 below are then only run for the
sprite queue, the object flags and `g_columnDepth` (DESIGN.md "The raycaster").

Every frame (`labyrinth_render_frame` 1028:4655, or `labyrinth_move_and_render` 1028:3e23 after a
move; `labyrinth_paint` for `WM_PAINT`):
1. **Sky and floor** (`labyrinth_draw_sky_floor` 1028:134f): copies of the background image
   (`opcaoN.bmp`) into the off-screen surface, the sky half (y 42–191) shifted horizontally by
   `skyScrollX`, the floor half (192–341) by `floorScrollX` and vertically by `floorScrollY`, each
   cyclic within the view.
2. **Walls** (`raycast_render_view` 1028:0951). The view is 480×300 at (20, 42): 120 columns of
   4 px, a 60° field (4 angle units, 0.5°, per column), the horizon at y 192. For each column, from
   the right (x 496, angle − 240) to the left, two DDA walks in 32-bit code:
   `raycast_walk_vertical` (1010:0024) along the lines x = 32k and `raycast_walk_horizontal`
   (1008:0024) along y = 32k. Each returns the ray length to the first non-empty cell (0x7fffffff
   when the ray leaves the map: there is no bound on the other axis, the map border must be
   walls), the cell value, and the hit coordinate along the line. Objects in the empty cells
   crossed are queued (below). The nearer hit wins (a tie: the horizontal one). Height h =
   (table[4][column] / dist) >> 16 = 22500/(cos·dist) px (0x65ae at dist 0), top
   = 42 + (300 − h)/2; `g_columnDepth[column]` = dist.
3. **The column blit**: one of four identical drawers (`wall_strip_draw_wall_a/b`,
   `wall_strip_draw_door_a/b` 1028:482c–4a4e) → `dib_blit_scaled_column` (1068:0000) →
   `blit_scaled_column` (1000:0024, 32-bit): a 4-px column of texture row (v+1)/2 − 1 of the wall
   strip, scaled to h rows with nearest-row stepping, clipped to the 300-row view by assuming the
   view is as tall as the texture. The texture column is the screen x & 31 for a wall (so the
   pattern stays on the screen, `BUGS.md` J4) and the hit coordinate & ~3 for a door.
4. **Shading** (in the blit): k = min(3, dist >> 6) is added to every pixel byte as k·0x17: the
   palette holds each wall colour four times, 23 entries apart, darker each time. Full colour up to
   2 cells, then one step per 2 cells, the darkest from 6 cells. Sprites are not shaded.
5. **Sprites** (`sprite_queue_flush`, below), the hands (slot `draw`), then the HUD.
6. **The hands' bob:** `g_handsBobPos` steps by `g_handsBobStep` (±2) between −4 and 4 every
   frame and the hands' y moves with it.

## Sprites

**The sprite queue** (`SpriteQueue`, 0x7d6 bytes at backdrop +0x71e): a binary tree of up to 100
`SpriteQueueEntry` nodes keyed by depth. The 32-bit walks call `object_set_visible_from32`
(1028:4b81) and `sprite_enqueue_from32` (1028:4b04), 16:32 gateways whose prologue rebuilds a
16-bit far frame, for every object met in an empty cell; `sprite_queue_insert` (1028:5ac6) keeps
one node per cell (a second ray through the same cell returns the existing node), goes right when
the node's depth is ≤ the new one, left otherwise, and has no capacity check. The object under an
in-flight shot is added by hand (cell −1, −1 = the object's own cell). `sprite_queue_flush`
(1028:5d6d) draws the tree farthest first (`sprite_queue_draw_tree`, right subtree, node, left
subtree; it clears the links as it goes) and resets the root and `nextFree` = 1.

**One sprite** (`labyrinth_draw_sprite_entry` 1028:52a8):
1. Unless it is the shot, the object's world position is snapped to the centre of the queued cell:
   one object placed in many cells is drawn once per cell.
2. Depth d = dx·cos + dy·sin, lateral = dy·cos − dx·sin (view angle); screen x = 260 +
   240·lateral/(d·tan 30°), scale = |22500/d| (0x65ae for d ≈ 0); width = frame width·scale/300,
   centred. Skipped when it lies outside x 20–500.
3. The visible span: from each end, columns are dropped while the wall in `g_columnDepth` is
   nearer. Top y = (scale + 300)/2 − height·scale/300 + 42: the sprite stands on the floor line of
   its depth. The copy is `dib_stretch_copy_transparent` (1068:1336) →
   `blit_scaled_sprite_transparent` (1018:0024, 32-bit), column by column with a 2-D
   Bresenham, colour 10 transparent (`g_unk0010`), clipped vertically only to the 640×480 surface
   (the HUD repaints over what falls below the view; `BUGS.md` J5 and the harmless list for its
   edge cases).
4. **Enemies** (`SceneObject.isEnemy`, +0x49a): each drawn frame calls scene slot 0x14 (the step
   wave); when the animation is on its last frame the enemy hits: health −1 and slot 0x13 (the
   attack wave); then health ≤ 0 → health 100 and a life; lives 0 → `WM_DESTROY` (a loss). So every
   visible enemy, at any distance, costs 1 health per animation cycle. Then, still on screen
   (behind a wall too), it moves one cell toward the player along the view axis (its position −
   32·(cos, sin) of the view angle), if that cell is not a wall, is empty or holds the same object,
   and its frame is 0; then its animation advances (`nextFrame`).

## The minimap and the HUD

- **Minimap** (114×160 at (513, 42), 2 px per cell, row 79 at the top): `labyrinth_minimap_walls`
  draws one green pixel per non-zero cell (after a door opens, `labyrinth_refresh_map_panel`
  redraws it); `labyrinth_minimap_player` a 4×4 red square at (x/16 + 513, 202 − y/16), drawn on
  the window after each step, once the minimap rectangle has been copied from the surface (which
  erases the old one). Objects are not shown.
- **HUD** (`labyrinth_draw_hud` 1028:43e9, `labyrinth_present_hud` 438d): yellow transparent text (`SetTextColor` 0x0000ffff: red and green)
  at y 410: level `%2.2d` at x 225, ammo `%3.3d` at 308, health `%3.3d%%` at 392, score `%3.3d` at
  493, lives `%2.2d` at 582. The face (`rostoN`, 5 frames at (33, 382)): frame 0 at 80 % health and
  above, one worse per 20 points, frame 0 again above 100. The control panel strip
  (`labinter.bmp` and the inventory) is redrawn by `labyrinth_paint` and, on a step taken while
  the shot is over an object, by `labyrinth_present_hud_strip`.

## Moving

`labyrinth_backdrop_handle_message` (1028:2609, LabyrinthBackdrop slot 0x17) gets every message
through the phase handler and `labyrinth_scene_handle_message`.

| Input | Effect |
|---|---|
| LEFT, RIGHT | turn ±48 (6°) on the press and every 55-ms tick while held (±96 with SHIFT on the ticks); RIGHT wins over LEFT |
| LEFT, RIGHT with CAPS LOCK held down | strafe 16 units to the side |
| UP, DOWN | walk 16 units on the press; while held 24 per tick (16 on the first tick), 64 with SHIFT (run); after the release the speed coasts down by 4 per tick to 16 |
| CTRL | fire (below) |
| SPACE | open the door one cell ahead (9–12), or take an exit door (7, 8: the phase handler) |
| ESC | kill the timer and `PostQuitMessage`: JARDIM ends without a result |

The latches `g_keyLeftDown` … `g_keysDownCount` drive the tick; a turn moves the
sky 8 px and the floor 16 px per step, a step moves the floor 10 px (15 held, 30 running).

**The speeds.** The tick runs on every `WM_SYSTIMER`, timer 10's included (Timers, BUGS.md J8): about
38 ticks a second at the exact 50/55-ms periods. Held, that is 24 units a tick walking (≈ 28 cells a
second on a 32-unit cell) and 64 running (≈ 76), and 6° a tick turning (≈ 228° a second, twice that with
SHIFT). The presses add a step or a turn each on top.

The Corrigida replaces this movement with Wolfenstein 3D's (continuous, 5.6 cells a second walking,
11.2 running, 122.5° a second turning, sliding along walls), W/A/S/D and E for the keys, a controls
screen first and one tick a timer-1 period (`docs/jardim/DESIGN.md` "Decisions"); the rules below are
the original's.

**A step** (`labyrinth_move_and_render` 1028:3e23): x += velX, y += velY. If the new cell is a wall
or door, the player is pushed out along one axis by the cell's parity: an even value along x (8
units before the wall face), an odd value along y. If the cell at the midpoint of the step (against
running through a thin wall) or the pushed position is still non-empty, the whole step is undone:
no sliding along walls, and the speed drops back to 16. Otherwise an object in the new cell goes to
scene slot 0x11 (`touch`); a non-zero answer (an enemy) undoes the step. Only on this path are
health ≤ 0 (→ 100, a life) and lives = 0 (→ `WM_DESTROY`) checked, besides the enemy attack.

## Weapons and shots

`hands.curStrip` is the weapon: 0 fists, 1 crossbow, 2 the bra (phase 1) or the bazooka (phases
2–3); frame 1 of the strip is the firing pose. Ammo is `LabyrinthBackdrop.ammo`.
- **Fists:** CTRL shows frame 1 while held and plays the punch (`soco`); nothing is ever hit.
- **The others:** CTRL with no shot in flight: `shotInFlight` = 1, the shot object starts in the
  player's cell, the fire wave plays (slot 0x15), ammo −1. On every tick the shot moves one cell
  (32 units) along the firing angle, displacing the cell's object while it passes. It stops in a
  wall cell, or in a cell whose object is tall enough (shot height − 20 ≤ the object's height), and
  calls scene slot 0x10 (`hit`) with that cell and object; then at 0 ammo the hands go back to the
  fists. The shot frame is 0 (an arrow) for the crossbow, 1 for the bra or the bazooka.
- **A weapon picked up** while the other one is held leaves the old one in the cell (a swap); one
  picked up while a shot flies is lost (`BUGS.md` J3).

## The phases

Each phase scene is a LabyrinthScene subclass with the slots `hit` 0x10, `touch` 0x11,
`placeObjects` 0x12, `playEnemyAttackSound` 0x13, `playEnemyStepSound` 0x14, `playFireSound` 0x15,
`playDoorSound` 0x16, `onLifeLost` 0x17. Every type of object is **one** Portable stored in many
cells; it also stands at its constructor position (an extra copy, unless that cell is a wall;
phase 3 places Chato there twice and Bicho and the goal not at all).
Counts are the `placeObjects` calls ("+ctor" when the constructor cell is a floor cell).

**Phase 1** (`raymap1.dat`, start (912, 48) = col 28, row 1). Weapons: fists, crossbow, bra.

| Object | File | Count | Touch | Shot |
|---|---|---|---|---|
| `enemyBussuf` | `bussuf` 128×227 ×4 | 13 +ctor | health −5 | crossbow: removed, +200 |
| `enemySeios` | `seios` 128×200 ×5 | 5 +ctor | a life | bra: removed, +100 |
| crossbow | `besta` | 5 (4: one is overwritten) +ctor | crossbow, ammo +6 (kept on a swap from the bra) | – |
| bra | `sutien1` | 6 +ctor | bra, ammo = 1 (+1 if held) | – |
| medkit | `medkit` | 4 | health +20 | – |
| beer | `chopp` | 6 | health −15, score +100 | – |
| açaí | `acai` | 15 +ctor | health +5 | – |
| arrows | `setas` | 18 | with the crossbow ammo +3, else left | – |

**Phase 2** (`raymap2.dat`, start (1744, 48) = col 54, row 1). Weapons: fists, crossbow, bazooka.

| Object | File | Count | Touch | Shot |
|---|---|---|---|---|
| `enemyAlemao` | `alemao` 128×232 ×2 | 31 (28 cells) +ctor | health −5 | any weapon: removed, +200 |
| `enemySiri` | `siri` 338×217 ×4 | 4 +ctor | a life | bazooka: removed, +100 |
| crossbow | `besta2` | 2 +ctor | crossbow, ammo +6, = 6 on a switch | – |
| bazooka | `bazuka2` | 2 +ctor | bazooka, ammo +3, = 3 on a switch | – |
| medkit | `medkit2` | 11 +ctor | health +20 | – |
| beer | `chopp2` | 8 +ctor | health −15, score +100 | – |
| shrimp | `Camarao2` | 7 (6: one is overwritten) +ctor | health +5 | – |
| arrows | `setas2` | 25 | with the crossbow ammo +3, else left | – |
| bombs | `bomba2` | 7 +ctor | with the bazooka ammo +1, else left | – |

**Phase 3** (`raymap3.dat`, start (48, 112) = col 1, row 3). Pickups as phase 2 (`besta3`,
`bazuka3`, `medkit3`, `chopp3`, `Camarao3` 156×78, `setas3`, `bomba3`; counts 2 +ctor, 2 +ctor, 5,
1 +ctor, 6, 6 +ctor, 7 +ctor).

| Object | File | Count | Touch | Shot |
|---|---|---|---|---|
| `enemyChato` | `Chato` 98×227 ×2 | 9 +ctor | health −5 | any weapon: +200, **not removed** (`BUGS.md` J2) |
| `enemyBicho` | `Bicho` 234×205 ×3 | 3 | a life | any weapon: removed, +100 |
| `goal` | `espanf` 74×173 ×4 (variant 1) or `vamanf` 82×182 ×4 (variant 0) | 1, at row 78 col 2 | **the win** | ignored |

Common rules:
- A pickup touched is removed from the player's cell (only that cell); one refused (arrows or
  bombs with the wrong weapon) stays. There is no health cap.
- An enemy blocks the step and is never consumed; each blocked step repeats the damage (every tick
  while the key is held: `BUGS.md` J6).
- A kill clears only the hit cell and stops all waves (`wave_stop_all`); there is no kill sound.
- **Waves** (`g_phaseNWaves`): phase 1 `busrang2`/`barang` (Bussuf attack/step), `seio`/`seio2`
  (Seios), `acai`, `ARROTO` (beer), `barul1` (crossbow), `yeeha` (bra), `arcfle02` (shot),
  `abrport2` (door), `alivio` (medkit), `barul2` (arrows, bombs), `soco` (punch), `berro` (a life
  lost), `esmagar` (opened, never played). Phases 2–3 add `bazzo` (bazooka shot) and `armad`
  (bazooka pickup); the enemies' are `assass`/`tiros` (Alemão), `siri2`/`siri3` (Siri), `chato`
  (Chato's step; its attack slot is `g_phase3Waves[0]`, never opened, so silent), `bibliaok`/`bicho`
  (Bicho). The shrimp plays `acai`.

## Fair enemies (Corrigida)

Not the original's rules: the Corrigida's `jardim_fair_enemies` (with the Wolf-like movement;
`src/jardim/enemies.zig`, every number in its `EnemyTuning`; docs/jardim/ENEMIES.md is the
investigation, docs/jardim/DESIGN.md "Decisions" the choices). The original's enemies above
(one shared Portable per type, logic in the sprite draw, damage from every drawn copy at any
distance, steps along the view axis into and past the player) stay in the Original.

- **Instances.** Each enemy placed on the map is its own instance (its cell, its walk between two
  cells, its frame, its timers, alive or not); the map still holds the type's object in the
  instance's cell, so the shots, the touch and the phases' `hit` are the original's. The logic runs
  once per instance on each game tick (timer 1, about 10 a second with the frame cost), timed in
  milliseconds; the drawing (every frame, the motion frames too) only shows it.
- **Sight.** An enemy sees the player along a line from its cell's centre to him clear of walls and
  closed doors (not through a corner between two walls), up to 16 cells, whichever way he faces.
  Until it first sees him it stands (and animates); then it reacts after 300–800 ms (the CRT's
  `rand()`, never seeded) and chases; it keeps chasing 1.5 s after it last saw him.
- **Chase.** A step every 600 ms (Bussuf, Siri, Chato), 800 ms (Seios, Bicho) or 450 ms (Alemão):
  one cell along the larger axis towards the player, else the smaller, only into an empty floor
  cell that no other enemy holds, walks out of or dies in, never the player's cell and never a
  cell whose centre is within 24 units of him. It stops at 1 cell (Chebyshev: the 8 cells around
  him) or, for Alemão, 2. It is drawn sliding between the two cells over the step.
- **Attacks.** In sight and within reach (1 cell; Alemão 4), and not walking: a 250-ms wind-up (its
  last frame, the attack pose, and its attack wave: the tell; Chato's attack slot is silent, so his
  step wave), then the blow if the player is still in sight and reach, then 1200 ms of cooldown.
  Bussuf and Chato take 5 health, Seios, Siri and Bicho 10; Alemão shoots with Wolf3D's chance
  (256 − 16·cells)/256 for 8 (1 cell), 4 (up to 3) or 2. After a hit the player cannot be hit for
  500 ms, and after a life lost not until the respawn.
- **Contact.** Walking into an enemy only blocks: no damage, no life (the blows are the damage;
  `contact_hurts` would bring back the original's touch, once per contact by J6's rule). The final
  enemy is still the win, and it stands and animates (it neither moves nor attacks).
- **Feedback.** A hit draws a 4-px red border round the view for 150 ms and the face one step worse
  for 300 ms; a kill draws the enemy white for its next 2 game frames (about 200 ms), then it is
  gone. Animation at 8 frames a second (the walking frames; the last is the attack pose).
- **Deaths.** A life lost: the scream, then the original's respawn (the pickups placed again, the
  player at the start, −500), and every enemy, the killed ones too, comes back at its own cell (the original's rule).
- **Shots** (`jardim_shot_substeps`, also in the Corrigida): the shot's cell a tick is reached in four
  8-unit steps, each new cell met as the original's step meets its one: a diagonal shot no longer
  steps over a cell's corner. Which weapon kills which enemy is the original's (the tables above):
  one shot kills.
- **Measured** (the probe, `jardim-corrigida-alone-lose.input` and `-win.input`): one Seios next to
  the player takes 10 health every 1.5 s (6.7 a second, a life in 15 s; a Bussuf would take 3.3);
  two Seios and a Bussuf around him about 10 a second (the 500 ms after each hit swallow the blows
  that come together; a life in 10 s). The original's: about 8 a second for one Seios drawn 6 cells
  away. A kill is one shot: the shot flies a cell a tick (about 10 cells a second), so 0.1 s a cell
  of distance; from the key to the white flash 0.34–0.41 s for Bussufs, 0.18–0.68 s for Alemaos,
  0.02–0.19 s for Chatos and 0.48 s for a Bicho shot on the win route (Seios and Siri the same with
  the bra or the bazooka), then 0.2 s of flash.
- **Debug** (Debug builds): F9 shows the nearest enemy's state and the player's in the view and logs
  every tick's (`[ms] fair player …`); `zig build -Djardim-probe` logs from the start, with the
  map's objects, and skips the motion frames (`tools/jardim_plan.py`).

## Lives and deaths

Health starts at 100, lives at 3, both carried across phases. Health ≤ 0 costs a life and resets
health to 100. A lost life (lives changed during a frame) calls scene slot 0x17
(`phaseN_scene_on_life_lost`): `berro` played with a notify window; its end (`MM_WOM_DONE` 0x3bd)
makes the phase handler stop the waves and call `labyrinth_scene_respawn` (1028:5ef1):
`placeObjects` again (every pickup and every killed enemy comes back; nothing is removed first),
the fists and ammo 0, the player back at the phase's start, **score −500**, a full repaint. The game
goes on meanwhile until the scream ends. At 0 lives the game posts itself `WM_DESTROY`: a loss.

## Exits and the win

- **SPACE** (all phases): the cell one cell ahead along the view. 9–12: the backdrop opens it (the
  cell becomes floor, the minimap is redrawn, `abrport2`). 7 or 8: the phase handler, before the
  backdrop, if the row is above a guard (phases 1–2: row > 1, which excludes the doors beside the
  start; phase 3: row > 5):
  - phases 1 and 2: `g_startX/Y` = the next phase's start, `PostMessage(0x402, exit index)`; the
    base scene handler saves health, lives, ammo, level + 1 and **score + 500** in the `g_carry*`
    globals and the weapon in `g_curWeapon` (the bra becomes the fists in phase 2), stops and frees
    the waves; `game_take_exit` builds the next phase (`phase1/2_scene_create_new_scene`). The old
    scene is deleted through the base destructor (the Portables leak, harmless).
  - phase 3: `PostMessage(WM_DESTROY, 0)`, a loss; map 3 has no such door past row 5, so the
    branch is dead.
- **The win:** touching the `goal`, the woman in the swimsuit (phase 3 only; not an enemy, it cannot be shot):
  `PostMessage(WM_DESTROY, 0xffff)`.

## The result

The backdrop's `WM_DESTROY` case (1028:2609), reached through the phase handler's `WM_DESTROY`
(which stops and frees the waves, closes WaveMix and `close musica`):
- **win** (wParam 0xffff and lives ≠ 0): score += 10⁹ / (`GetTickCount()` − `g_startTick`), the
  milliseconds since the first labyrinth was built; `PostMessage(g_noiteWnd, 0x40a, 1, score)`.
  As compiled the tick is cut to its low 16 bits and sign-extended, so the "bonus" is almost always
  a small negative number (`BUGS.md` J1).
- **loss** (anything else): score −1000; `PostMessage(g_noiteWnd, 0x40a, 0, score)`.

`APPWNDPROC` then kills timer 10 and posts `WM_QUIT`. The score is a 16-bit int: the points of the
three phases (kills, beers, +500 per finished phase, −500 per death) plus the end adjustment. ESC
ends the program without a `WM_DESTROY`, so nothing is posted; closing the window (End Task)
destroys it with wParam 0: a loss.

## Protocol with NOITE.EXE

| Msg | Direction | wParam | lParam | Meaning |
|---|---|---|---|---|
| `0x40b` | NOITE → JARDIM | the variant (1 `espquete`, 0 `4fjarvamp`) | NOITE's window | hello; AppWndProc's case would store `g_noiteWnd` and `g_variant` and post `0x40c`, but once `WM_CREATE` has run `game_handle_message` takes it first and answers 1: it never runs (`BUGS.md` J7) |
| `0x40c` | JARDIM → NOITE | JARDIM's window | 0 | ready; posted on **every** message until NOITE's `0x40a` arrives (`g_noiteAcked`); JARDIM also looks NOITE up itself (`FindWindow("Noite Animal")`, retried on timer 10) |
| `0x40a` | NOITE → JARDIM | 0 | 0 | NOITE's answer to `0x40c`: would stop the re-posting (`g_noiteAcked`), swallowed as the hello |
| `0x40a` | JARDIM → NOITE | 1 won, 0 lost | the score | the result |

NOITE's side (`src/handlers/espquete.zig`, `src/handlers/4fjarvamp.zig`):
- `handler_espquete` (1028:0a88), the garden cutscene: at the video's successful end
  (`MM_MCINOTIFY`) it `_chdir`s to `<CD>jardim`, `WinExec`s `<CD>jardim\jardim.exe` and starts timer
  0x14 (100 ms); the timer finds "Noite Animal Jardim", hides the main window and posts `0x40b`
  with **variant 1** (the goal is `espanf`). JARDIM's own 0x40c gets there first and the handler
  kills the timer, so this hello is never sent; JARDIM would not read it anyway, and the goal is
  `vamanf` (`BUGS.md` J7).
- `handler_4fjarvamp` (1028:0d80), the vampire's garden: the same at the scene start (0x401), with
  **variant 0** (`vamanf`).
- Both answer each `0x40c` with `0x40a` (`espquete` to window 0: it never learns JARDIM's;
  `4fjarvamp` to JARDIM, which posts another 0x40c for each: the two bounce messages for the whole
  game and the result is lost, `BUGS.md` J7), and on
  `WM_SYSTIMER` post themselves `(0x40a, 0, 0)` if the window has gone (the only report after ESC: a
  loss with no score change).
- The result (`0x40a`): shows the main window, `g_score += lParam`, then the scene switch:
  `espquete` → `6fsai1` (the first ending) on a win, `6fsaida` (game over) on a loss;
  `4fjarvamp` → `6fsai2` (the second ending) on a win, `6fsaida` on a loss. No life is taken: a
  loss ends the game. The CD directory is not restored (`BUGS.md` B11).

The port has both sides: NOITE's handlers above and JARDIM (`src/jardim/`,
`docs/jardim/DESIGN.md`); `--minigame-stub` keeps the headless stub (`src/platform/sim.zig`),
which answers the hello and reports the result set in `Options.minigame`.

## Timers

| Id | Period | Set by | Use |
|---|---|---|---|
| 10 | 50 ms | `APPWNDPROC` `WM_CREATE` | meant to retry `FindWindow("Noite Animal")`; its `WM_SYSTIMER` ticks the game too, since the backdrop ignores the id (BUGS.md J8), and AppWndProc's own case never runs (the FindWindow at the top of every message does the retry) |
| 1 | 55 ms | `labyrinth_backdrop_create` | the game tick (`WM_SYSTIMER`, any id): the shot step, coasting or the held keys, otherwise an idle redraw that animates the enemies |
| 0xc, 0xd, 0xf | 55 / 100 / 55 ms | the ids of the control panel, the Player, the Portables | never acted on: every `WM_SYSTIMER` reaches the backdrop first (which ignores the id), and `game_handle_message`'s timer case is dead; the enemies animate from the frame redraw |

## Music and sound

- Music: MCI sequencer, `doom.mid`, alias `musica`, opened by phase 1 and kept by phases 2–3;
  `MM_MCINOTIFY` success restarts it (`play musica from 0 notify`). `WM_ACTIVATE` pauses or resumes
  it with WaveMix (`wave_mix_activate`/`deactivate`, a message box on failure); the game tick runs
  on while inactive.
- Sound: WaveMix on channel 0, one wave at a time. Only `berro` is played with a notify window;
  `MM_WOM_DONE` triggers the respawn.

## Dead parts of the engine

`game_handle_message` (1058:0000) is TIRO's: since the labyrinth scene answers 1 for every key,
mouse and timer message, only its `0x402` case (→ `game_take_exit`) runs. The 2-D Player, the
control panel's sliding and inventory clicks, the status bar and the drag-and-drop of objects are
linked but never used. The C ray casters (`dead_ray_cast_horizontal_lines`/`vertical_lines`), the
16-bit blitters of `1068` and the RLE encoder are dead (`FUNCTIONS.md`).
