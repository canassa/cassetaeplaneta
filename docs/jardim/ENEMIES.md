# JARDIM's enemies: the investigation behind the fair enemies

Why the enemies felt "impossible to fight, almost invisible, teleporting" (the owner), measured on
the port before the animation fix (`4b96c52`, "let JARDIM's enemies and hands animate") and the
Corrigida's fair enemies (`src/jardim/enemies.zig`, docs/jardim/DESIGN.md "Decisions", GAME.md
"Fair enemies (Corrigida)"). Two builds were compared: the port as it was, and the port with
`nextFrame`/`prevFrame` fixed, which behaves as JARDIM.EXE does.

## 0. Summary

| Complaint | Cause | Original or port? |
|---|---|---|
| Teleporting | **Port bug:** an enemy's frame never advances, so every enemy on screen moves one whole cell on every rendered frame: 38 cells/s, about 1200 units/s. In the original, each enemy *type* moves one cell per F draws of that type (F = its frame count). That is still a 32-unit snap, along the view axis, and paced by frames drawn, not by time. | Mostly port (5× too fast, and no animation). The snap and the view-axis movement are original. |
| Almost invisible | The enemy reaches the player in about 0.2 s. It enters the player's cell, fills the screen for 1–2 frames, then steps behind the player and is no longer drawn (§3). The sprite drawing itself is correct: transparent key, scale, y, clipping, order. | Original mechanics, made extreme by the port bug |
| Impossible to fight | In the original, every drawn copy deals damage at any distance: R·N/F health per second. That is 8 hp/s measured for one Seios 6 cells away, and up to 57 hp/s for 3 Alemão at 38 fps. In the port there is **no** damage at range. Instead the enemies rush the player and sit in or behind them, and every step inside that cell costs 5 health or a life (touch, J6). | The damage model is original. The port bug replaces it with rush plus contact. |

**Port bug (one, root cause):** `src/jardim/behaviour/animation.zig` `nextFrame`/`prevFrame` treat
`scene_object_next_frame_default` 10c0:38ea and `scene_object_prev_frame_default` 10c0:393a as
no-op stubs. In JARDIM both are real 79-byte functions that wrap the frame (§1).

## 1. The port bug: enemies (and the hands) never animate (fixed since, `4b96c52`)

`labyrinth_draw_sprite_entry` (1028:52a8) ends with `CALLF [BX+0xb0]` (1028:5ab8), which is
SceneObject slot 0x2C `nextFrame`. Enemies are Portables. The tracker DB
(`db/jardim.sqlite`, `vtables`) puts `10c0:38ea scene_object_next_frame_default` in slot 44
of `g_portableSceneObjectVtbl` and of `g_sceneObjectVtbl`. Its body is:

```
10c0:38fd  CALLF 10c0:2f32          ; current strip
10c0:3906  MOV AX,ES:[BX+0xc]       ; strip.count
10c0:390d  SUB AX,ES:[BX+0x24]      ; - curFrame
10c0:3911  DEC AX / JNZ             ; last frame?
10c0:3919  MOV ES:[BX+0x24],0       ;   -> 0
10c0:3925  INC ES:[BX+0x24]         ; else +1
```

This is exactly `animation_next_frame`. 393a is the matching `prev_frame`. The DB marks both
`absorbed` (kind `default`). The port maps them to `0`:

```zig
// src/jardim/behaviour/animation.zig, nextFrame
// scene_object_next_frame_default (absorbed)
.scene_object, .wall_strip, .portable => 0,
```

(`prevFrame` has the same problem.) In NOITE, ENCAIXE, INV, SALGIN, SERIAL, TIRO and XILINDRO
this default is a 5–28-byte stub, so treating it as a no-op is right there. JARDIM's copy is
the 79-byte one, like SAUNA's, and the SAUNA port handles it correctly (`.control_panel, .pacman,
.ghost, .dot => animationNextFrame(obj)`, "absorbed: the same wrap"). The tracker sweep of
absorbed functions of 40 bytes or more found only these two that matter here. slot24 and
redraw_overlapping are overridden for Portables; I did not audit them for the hands.

**What the bug causes in the port** (curFrame of every enemy stays 0):
- **Movement.** The move test `curFrame == 0` (1028:5a52) passes on every draw. Every queued
  copy inside the view's x-range moves 32 units on every render.
- **Attack.** The test `frameCount − curFrame == 1` (1028:58b5–58be) never passes, because
  every enemy strip has 2–5 frames. There is no ranged damage at all.
- **Animation.** Enemies always show frame 0. Seios's squirt (its last, attack frame) and the
- **Hands.** The hands are `.scene_object`. `fire` and `shotHit` call `nextFrame(hands)`, so
  the crossbow and bazooka firing pose (frame 1) never shows. The fists set the frame
  directly, so they are not affected.
- **Step sound.** The step wave (slot 0x14) still plays on every draw.

**Fix (not applied):** in `src/jardim/behaviour/animation.zig`:
- Make `nextFrame` `.scene_object, .wall_strip, .portable => animationNextFrame(obj)` with
  `// @orig 10c0:38ea scene_object_next_frame_default`.
- Make `prevFrame` `... => animationPrevFrame(obj)` with
  `// @orig 10c0:393a scene_object_prev_frame_default`.
- Then run `noite -p jardim check --fix-status`. Ideally add an emulated oracle test for 38ea.

The bodies are byte-for-byte the same logic: wrap at `curStrip.count`. I built exactly this
variant (nf). It **breaks the planned scripts:**
- `jardim-alone-win.input` ends with "no minigame result" at 81000. The port wins at 79870.
- `jardim-alone-lose.input` also fails.

So the fix has to land together with re-planned `jardim-*.input` scripts, the NOITE-side ones
included. Run `tools/play_all.py` afterwards. It is the `animation` unit, outside both other
agents' areas, but it changes everything they will test against.

## 2. Teleporting (Q1): the code, original against port

`drawEntry` (`src/jardim/sprites.zig`) matches 1028:52a8 instruction for instruction. I
checked the snap, the x-range early return to the epilogue at 5ac0, the attack block at
586a–592c, which runs only when a span was drawn, and the move block at 5931–5aa0.

1. **One shared Portable, its position rewritten for each cell.** This is original.
   - Before each draw, `obj.worldX/Y = cell centre` of the queued cell.
   - The frame (`curFrame`) is shared by every copy. In the original, each copy drawn advances
     it, so N copies on screen advance the type's animation N frames per render.
   - When N is a multiple of F the phase locks. One copy is always at frame F−1 (it hits on
     every render), one is always at frame 0 (it moves on every render, 38 cells/s even in the
     original), and the rest freeze in a pose.
2. **A 32-unit jump, once per F draws of the type, not per unit of time.**
   - Original: each copy moves R/F cells/s on average, where R is renders per second. R
     depends on the frame rate.
   - Port: every copy moves R cells/s.
3. **Movement along the player's view axis.** The new position is `worldX + (−0x200000 /
   sec)`, i.e. −32·cos, and likewise −32·sin. This is the view angle, not the direction to the
   player.
   - Depth drops by 32 and the lateral offset stays the same, so an enemy off to the side
     slides past the player instead of reaching them.
     place at row 30: copies of Seios and Bussuf hop diagonally one cell per frame (log:
     `33,33→34,32→35,31→36,30` in 50 ms).
   - Enemies move only while queued and inside x 20–500. Enemies off screen, or behind the
     player, are frozen.
4. **Map and drawing agree.** `labyrinth_remove_object` (1028:214e) clears the cell under the
   snapped position, which is the queued cell. `labyrinth_place_object(-1,-1)` (2034) stores
   the object at its new cell, so the map is updated.
   - The copy is drawn *before* it moves, so its picture lags its map cell by one step. That
     is only one frame.
   - **A move into a cell holding the same type is allowed (`id` equal), so copies merge.**
     Bunched enemies disappear for good, until a death respawns them all.
   - Pickups block movement. The test Seios waited at row 29 behind a bra until the player
     took the bra.
5. **Measured.**
   - Port: Seios 13 cells away, player still. It goes 38,36 → 38,29 in 7 renders, 4720 →
   - nf: one cell every 5 draws, 38,36 → 38,29 in 0.8 s, with the squirt frame every 5th

## 3. "They stay behind me" (the second hypothesis): confirmed

The player is not a map object, so the move test (wall ≤ 0, cell empty or same type) lets an
enemy into the player's own cell and then past it:

```
port  t=7400  MOVE Seios 38,29 -> 38,28   player 38,28   (into the player's cell)
port  t=7425  MOVE Seios 38,28 -> 38,27   player 38,28   (behind, 25 ms later)
nf    t=7500  MOVE Seios 38,29 -> 38,28   player 38,28
nf    t=7645  MOVE Seios 38,28 -> 38,27   player 38,28
```

- **Drawn huge for a moment.** In the player's cell the sprite is drawn at d = 16, w = 599,
  h = 937: the whole view is skin for 1 frame (port) or about 6 frames (nf)
- **Then gone.** Next it has negative depth. The ray walks only queue cells ahead of the
  player, so it is never drawn again and never moves or attacks.
- **Nothing stops it.** Contact and J6 are tested only in `labyrinth_move_and_render`, on the
  player's step, never on the enemy's move. Turning does not call it.
- **What a hidden enemy costs.** It sits invisible, in the player's cell or behind. Any later
  step that ends in that cell (a step backwards, or a 16-unit step that stays inside the cell)
  runs `touch`: Bussuf, Alemão and Chato take 5 health; Seios, Siri and Bicho take **a life**.
  The step is also undone. Held keys repeat this every tick (J6).
- **It comes back.** When the player turns round, it is queued again and resumes. In nf it

## 4. Speed (the first hypothesis), with the correction

- **Render rate R.** The harness measured 37–39 renders/s idle, because timer 10 (50 ms,
  APPWNDPROC) and timer 1 (55 ms, labyrinth) both send WM_SYSTIMER and the backdrop ignores
  the id. Pressing keys adds renders: up to 72/s with presses every 30 ms.
  - On Windows 3.1 both timers round to the 54.9-ms tick, so the original's upper bound is
    about 36/s.
  - A 486 rendering 120 rays plus sprites through WinG probably managed about 10–15 fps
    (estimate, not measured).
- **Correction to hypothesis 1.** It assumed the enemies animate. In the port they do not
  (§1), so the port moves every visible copy **1 cell per render: 38 cells/s, about 1200
  units/s**. Walking speed is 24/tick, about 900 units/s held; running is 64/tick.
- **The original's speeds:**

| Enemy (F frames) | move cells/s, R=38 | R=10 | damage hp/s per drawn copy, R=38 | R=10 |
|---|---|---|---|---|
| Bussuf (4), Siri (4), final enemy (4) | 9.5 | 2.5 | 9.5 | 2.5 |
| Seios (5) | 7.6 | 2.0 | 7.6 | 2.0 |
| Bicho (3) | 12.7 | 3.3 | 12.7 | 3.3 |
| Alemão (2), Chato (2, silent attack) | 19 | 5 | 19 | 5 |

Measured in nf: one Seios 6 cells away, stuck behind a pickup, took 100 → 67 health in 4.1 s,
which is 8.0 hp/s (predicted 7.6). The port took 0 over the same time.

## 5. "Almost invisible" (Q2): checks of the drawing

| Suspect | Finding | Verdict |
|---|---|---|
| Column depth test | It compares the sprite's perpendicular depth with `g_columnDepth`, the euclidean ray length, which is always ≥ the perpendicular distance. So the test is lenient: sprites near the edges can overdraw a wall slightly, but are never wrongly hidden. Many queue entries are dropped entirely (log `ENT` without `DRAW`, e.g. a Bussuf at 25,28, d=800): a ray clips the cell's corner but the cell centre is behind the wall edge. | Original, minor |
| Transparent key | Key 10 (`g.spriteKey` = `g_unk0010`). BUSSUF, SEIOS, ALEMAO, SIRI, CHATO, BICHO, ESPANF and VAMANF all have index 10 in all four corners and the whole border (51–74 % of their pixels). | Correct |
| Scale and y | Top = (scale+300)/2 − h + 42, i.e. the floor line at that depth (horizon 192 + scale/2). Sprites stand on the floor in every dump. | Correct |
| Snap to cell | Drawn at the centre of the cell it occupies in the map. Consistent with the map; the jump is the movement, not a mismatch. | Original |
| Draw order | Tree farthest first; insert keyed by the ray distance; matches 5ac6/5cea. | Correct |
| Frames skipped | Port: only frame 0 is ever drawn (§1). Original: frames step by N per render with N copies on screen, which strobes or freezes. | **Port bug** / original |

**Oracle coverage.** The pixel blitters are emulated against the original: `blit_scaled_sprite_transparent`
1018:0024, `dib_stretch_copy_transparent` 1068:1336, and the column blitters, all in
`src/jardim/scaled.zig`, J5 included. These have **no** oracle test:
- `labyrinth_draw_sprite_entry` (projection, clipping, enemy logic);
- `sprite_queue_insert`/`flush` (they have one hand-written unit test);
- the frame defaults, which is where the bug sat.

An emulated test of 10c0:38ea, and a trace test of 52a8 for one enemy (check curFrame, the
move and health after three calls), would have caught it.

## 6. Fighting (Q3), quantified

- **Ranged damage.**
  - Original: R·N/F hp/s for every drawn copy, at any distance, partly behind walls too (the
    span only has to be ≥ 1 column). Each copy takes 1 health per hit.
  - Examples at R=38: one Bussuf in view costs a life (100 hp) in 10.5 s; 3 Alemão in view
    cost one in 1.75 s.
  - Port: none.
- **Contact.** The enemy blocks the step and `touch` runs: −5 health (Bussuf, Alemão, Chato)
  or a life (Seios, Siri, Bicho). It repeats every tick while held (J6: 3 lives in 165 ms).
  - In the port this is the only damage. Enemies park in or behind the player's cell (§3), so
    the player bumps into enemies they cannot see.
- **Shots.**
  - The shot moves one cell (32 units) per tick: 38 cells/s in the port, 18–36 in 1995.
  - It is sampled once per 32-unit step along the firing angle, so diagonal shots can step
    over a cell's corner.
  - It stops at the first object that is "tall enough": every enemy and the tall pickups.
  - A hit clears **that cell only** (one copy). It is a one-shot kill, scores +200/+100, and
    gives no visual feedback (all waves stop; there is no kill sound).
- **Weapon rules.**
  - Phase 1: Bussuf only to the crossbow (6 per pickup, +3 per arrows); Seios only to the bra,
    1 shot per bra (6 bras for 6 Seios).
  - Phase 2: Siri only to the bazooka.
  - Phase 3: Chato is never removed (J2); the fists hit nothing.
- **Time to kill one:** one shot, plus the flight time of d/38 s (≤ 0.4 s at 13 cells).
  - Port: the enemy closes at 38 cells/s, the same speed the shot flies, so after the enemy
    is first seen you have about 1–3 renders to fire before it is in your cell.
  - Original at R=38: you have about 1 s per 10 cells, while losing 8–19 hp/s per visible copy.
- **Winnable?**
  - Port: only by script. The planner wins by shooting Bussufs and Alemão straight ahead and
    walking round everything else with single presses.
  - Original at 38 fps: no, for a human. In phase 2, 28 Alemão cells drain about 19 hp/s each
    in view, deaths respawn every enemy, and score −500.
  - Original at a 1995 frame rate (about 10): hard but possible, because everything is about
    4× slower.
- **Corrigida today:** the same as the Original on every one of these points. None of J1–J5
  or J7 touch enemies, and J6 is a choice that is not in the Corrigida.

## 7. The proposal: "fair enemies" (now `Fixes.jardim_fair_enemies`; what was built differs, DESIGN.md "Decisions")

Wolfenstein 3D reference points (id-Software/wolf3d, WOLFSRC):
- **Reaction delay.** `SightPlayer` (WL_STATE.C) sets a delay before reacting: guard
  `ob->temp2 = 1+US_RndT()/4` tics (14–914 ms at 70 Hz), officer 2 tics, SS
  `1+US_RndT()/6`, dog `1+US_RndT()/8`.
- **Chase speed.** `FirstSighting` speeds the actor up when chasing (guard ×3, officer ×5, SS
  ×4, dog ×2), from `SPDPATROL 512` and `SPDDOG 1500` (WL_DEF.H, `TILEGLOBAL` = 65536). A guard
  chases at 1536·70/65536 ≈ **1.6 tiles/s**; a dog runs at ≈ 3.2 tiles/s.
- **Smooth, per-actor movement.** `TryWalk` and `MoveObj` move each actor with its own
  sub-tile `distance` (TILEGLOBAL per step) and never onto the player (`MINACTORDIST`).
- **Attack only with line of sight.** `T_Chase` (WL_ACT2.C) shoots only `if (CheckLine(ob))`,
  with `chance = (tics<<4)/dist`, or 300 at point-blank range.
- **Damage falls off with distance.** `T_Shoot` uses `hitchance = 256-dist*16` (lower when
  the player runs) and damage `US_RndT()>>2` under 2 tiles, `>>3` under 4, `>>4` beyond.

Fitted to this engine, ranked by impact divided by effort:

| # | Change | Numbers | Effort | Impact | Coordinate with the movement rework? |
|---|---|---|---|---|---|
| 0 | **Port fix §1** (not Corrigida) | — | S | Restores the original; prerequisite | No, but re-plan scripts |
| 1 | **Enemy clock and per-cell state.** Under the flag, `drawEntry` only draws, using the cell's own frame and offset, and marks the cell "seen". Enemy logic runs once per enemy cell from the game tick, timed in **ms** (accumulate `plat.ticks()`), not per drawn copy. State lives in a side table `enemy[80][57] {frame, phaseMs, cooldownMs, reactMs, from/to cell, t}` in `Backdrop`, moved together with `objectRows` and reset by `placeObjects`. This gives logical per-enemy instances without allocating Objects. | Animation 8 fps (125 ms per frame) | M | **Highest**: removes N/F scaling, phase lock and frame-rate dependence | Yes: the tick and timer handling are theirs; keying on ms makes it independent of their tick rate |
| 2 | **Chase toward the player and stop at melee range.** Step along the major axis of (player − enemy), else the minor axis (Wolf `SelectChaseDir`, no diagonals). The target cell must be floor, hold **no** object (no merging), and not be the player's cell. Stop at Chebyshev distance ≤ 1. Move only while seen or within 1.5 s after last seen. | 1 cell per 600 ms (1.6 cells/s, Wolf guard); Seios and Bicho 800 ms; Alemão 450 ms | S after #1 | **High**: fixes rush, pass-through and "behind me" | Yes: the player-cell definition and the enemy-blocks-step and touch rules |
| 3 | **Attack only with line of sight, in range, with a tell and a cooldown.** "Seen" is a true line-of-sight test: a cell is queued only if a ray crosses it before a wall. Melee enemies attack at distance ≤ 1, Alemão (`tiros`) at ≤ 4. Reaction 300–800 ms after first sight. Wind-up: show the last (attack) frame and play the attack wave for 250 ms, then damage. Cooldown 1200 ms. | Damage: Bussuf and Chato 5, Seios, Siri and Bicho 10, Alemão `(256−16·d)/256` chance of 8 (d ≤ 1), 4 (d ≤ 3) or 2. Global 500-ms invulnerability after any hit. That is ≤ 5 hp/s from one enemy, ≤ 10 hp/s from a crowd, so 10–20 s per life under pressure instead of 1.75 s. | S–M | **High** | No |
| 4 | **Hit feedback.** Player hit: red 4-px border around the view for 150 ms, face one step worse for 300 ms. Enemy hit: sprite drawn flat white (draw every non-key pixel as colour 15) for 2 frames before the cell clears, plus a kill wave (`berro` is the player's; reuse the attack wave or `esmagar`, which is loaded and never played). | — | S | Medium | No |
| 5 | **Smooth movement between cells.** Draw at `lerp(from, to, t)` instead of the cell centre, t over the 600-ms step. The map cell switches to `to` at the start of the step, so collisions and shots stay cell-based. | — | M | Medium (visual) | Yes if they change the sprite projection or the player's sub-cell position |
| 6 | **Shots.** Sub-step each 32-unit flight in 4 × 8 units so diagonal shots cannot skip a cell. Optionally, fists hit the cell ahead (≤ 1) for melee enemies, 2 punches. | — | S | Low–medium | Fists: input and controls are theirs |
| 7 | J6 (already a flag): a life once per contact plus 1 s invulnerability, instead of every tick | — | S | Medium | It is an owner's choice |

Do #0 first, then #1, #2 and #3 together: they are one change to `sprites.drawEntry`, a new
`enemyThink` called from `labyrinth_input.tick`, and the respawn. #4–#6 can follow on their
own. Every part goes behind the flag, so the Original keeps the 1995 behaviour, which after
#0 is the original's damage at any distance, paced by frames drawn.

