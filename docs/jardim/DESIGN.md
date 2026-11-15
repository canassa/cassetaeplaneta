# Native port of JARDIM.EXE — design

JARDIM.EXE ("Noite Animal Jardim", the garden's first-person labyrinth, source folder `doom`) in
Zig, next to NOITE's, ENCAIXE's and TIRO's ports. NOITE's `docs/DESIGN.md`, TIRO's
`docs/tiro/DESIGN.md` (and ENCAIXE's) and the zig-developer skill hold for everything this file
does not override. Ghidra (program `JARDIM.EXE`, through the tracker snapshot `noite -p jardim
show`) is the specification; `GAME.md` (the raycaster, the map, the rules, the phases, the
protocol), `DATA.md` (classes, vtables, globals), `FUNCTIONS.md` (names, dead code),
`QUALITY.md` (the large-model `/Od` build), `TEXTURES.md` (the walls up close), BUGS.md J1–J8.

## Decisions

- **Own tree, TIRO's Zig for the engine, NOITE's layouts.** JARDIM runs the engine sources TIRO
  and ENCAIXE are built from ("Faltou redefinir…", `MAX_OBJECT_QTY`), compiled `/Od` with stack
  probes like TIRO, but in the **large model** like NOITE (far code, far data, far `this`, the
  vtables in code segment `10c0`). So it is a third build of the same engine, and a different
  program from both:
  - the struct layouts are NOITE's (far pointers): SceneObject 0x49e, the Backdrop is NOITE's
    base Backdrop (one WinG bitmap, no grid), Object3D/Mover/Animation at NOITE's offsets;
  - the SceneObjectVtbl has **97** slots: NOITE's 102 without `reoccupy`, `isAvi`,
    `advanceFrames`, `isAnimated3D`/`asAnimated3D`; it keeps NOITE's five leading slots
    (`slot00`, `slot01`, `enableRle`, `isRle`, `getSceneName`) that TIRO lacks; the
    AnimationVtbl has 6 slots (`lock`, `isLocked`, three stubs where NOITE has its AVI methods,
    `playOnce`);
  - the class set is NOITE's: Player, Actor, Exit, Portable, Moveable, Animated3D are linked,
    and Portable, Exit, Player and ControlPanel are **built** (TIRO's Actor2D/Player2D/Crossbow do
    not exist); the occupancy grid is linked but dead;
  - `/Od` keeps the accessors, the update list and the Object3D ctor out of line, as in TIRO;
  - and the game itself has no twin anywhere: the LabyrinthBackdrop (`1028`), the scaled DIB
    copies (`1068`), the three phase scenes (`1098`, `10a8`, `10b0`) and four **32-bit**
    segments (`1000–1018`): the two ray walks, the wall-column blit and the sprite blit.

  JARDIM gets its own units under `src/jardim/`, ported from its own functions with its own
  `@orig` addresses; it calls neither TIRO's nor NOITE's units. **Sharing was weighed and
  rejected**, for TIRO's reasons (docs/tiro/DESIGN.md "Decisions"), which weigh more here:
  - every engine function takes its program's `Game`/`Object`/`Backdrop`; sharing means making
    finished TIRO (or NOITE) units generic over the memory model, the slot numbering (91 vs 97 vs
    102), the class set and the Backdrop, i.e. editing checked units for JARDIM's sake;
  - an `@orig` tag maps to one program's address, `noite check` scans one program's tree and
    `noite finish` refuses a unit that edits another program's tree: a shared function would need
    two tags and a tracker that checks a file against two DBs, and a J-fix could not land in it;
  - where the builds differ, a shared body carries `if (jardim)` branches; a copy keeps each port
    a plain transcription of its own binary.

  The copy is cheap: **TIRO's unit of the same name** (`src/tiro/`, ported and checked; the same
  `/Od` code shape, the same slot names and signatures) is the starting point of every engine
  unit; **NOITE's** (`src/behaviour/*`, `src/object_create.zig`, …) is the template for what TIRO
  lacks (the Player/Actor/Exit/Portable/Moveable/Animated3D overrides and the five leading
  slots) and for the large-model offsets. An agent transcribes each JARDIM function from
  JARDIM's decompile/asm, reuses the twin's Zig where the decompiles agree, and says in its commit
  body which functions differ from the twin and how.
- **Shared, because identical or not game code:** the platform layer (`src/platform/`, host
  included), `core/msg.zig`, `core/queue.zig`, `core/cstr.zig`, `core/stub.zig`,
  `core/errors.zig`, `core/fixes.zig` (one `Fixes`, J-flags prefixed `jardim_`), the Win16 data
  types (`Dib`, `BitmapInfoHeader`, `RgbQuad`, `Rect`). JARDIM's `1000:0148`/`0234` are NOITE's
  two 32-bit row copies (checked in the oracle on 300 random cases each,
  `zig-out/jardim/g4/cmp_noite.py`): `dib.rowsCopyTransparent32`/`rowsCopy32`, tagged with
  JARDIM's addresses, call NOITE's `src/dib.zig`, as TIRO's and ENCAIXE's do (bug B12 comes with
  them: `fixes.opaque_copy_black_tail`). The same state-free delegation rule as TIRO's holds
  (`read_dib_info`, the `dib` copies, `rle_blit_transparent` if its decompile matches NOITE's).
- **The 32-bit routines are transcribed, then proved bit-exact in the oracle** ("The 32-bit
  routines" below): Zig functions written from the `objdump -mi386` listings, tested against the
  original code run in `tools/oracle` (`oracle=emulated`), which already ran all six in phase 4.
- **The trigonometric tables are precomputed and verified, not computed at run time**
  ("The tables" below): a generator models `raycast_build_tables`' x87 sequence exactly and
  checks every entry against the original run in the oracle; the port embeds the result.
  Porting the CRT's FP library (`_trandisp`, 3.4 KB of 8087 code) or calling a host libm were
  rejected.
- **Faithful first, the owner's rule.** J1–J8 are reproduced as they are by default; each fix
  exists only behind its own `Fixes` flag (off by default), all of them in the Corrigida
  (`Fixes.all()`). J5 (the original faults) and the latent overruns become panics naming their
  BUGS.md entry, as NOITE's L5: a smoke "orig" line.
- **The owner's answers:**
  - **J4:** the wall-texture fix stays in the Corrigida.
  - **J5:** the Original keeps panicking (naming J5) where the original crashes.
  - **J6:** in the Corrigida an enemy hurts once per contact, and again only after the player has
    moved away and come back; pressing into it, held or repeated, costs once
    (`jardim_enemy_once_per_contact`, in `all`; it replaces the earlier choice
    `jardim_enemy_blocks_walk`). "Away" is more than half a cell (16 units) from the enemy's cell, or
    the enemy gone from it (`labyrinth_input.touchObject`/`leaveContact`), in both movements.
  - **J7:** the fix stays on JARDIM's side (0x40c only after 0x40b; the hello and the ack reach
    AppWndProc). The Corrigida's goal after `espquete` is `espanf`, after `4fjarvamp`
    `vamanf`: `jardim-espquete-win.input` checks the picture (`pixel … | …`).
  - **Timers:** the queue keeps the exact 50/55-ms periods; no Windows 3.1 quantising. The
    Corrigida's movement does not depend on them (below).
  - **ESC** stays a loss with no score change (NOITE's poll).
- **"Make it move like Wolf"** (the owner, for the Corrigida): three additions and one bug fix,
  each its own flag, all in `all`:
  - `jardim_game_timer_only` (BUGS.md J8): only timer 1 (55 ms) ticks the game; timer 10's 50-ms
    `WM_SYSTIMER` no longer doubles it. The tick (18.2 a second at most; 10 with the frame cost, "Platform") keeps the shot's flight, the
    enemies (animation, step wave, attack, move: all inside the sprite draw,
    `labyrinth_draw_sprite_entry`), the hands' sway, pickups' and doors' effects and exits.
  - `jardim_smooth_movement` (`src/jardim/wolf.zig`, not a port unit): the player's motion leaves
    the tick. A system timer of its own (id 0x57, 14 ms, set in `labyrinth.create`) polls the keys
    (`Queue.keyState`) and moves the player in Wolf3D's 70-Hz tics counted against the clock
    (thousandths of a tic carried over; at most 10 a step), so the speed is the same whatever the
    timers' periods, the display or the host: walk 5.61 cells a second, run 11.2, back 3.74 (7.48),
    strafe as walk, turn 122.5° a second (245 running), no acceleration, the numbers of id's 1995
    source (WL_PLAY.C `PollKeyboardMove`: BASEMOVE 35, RUNMOVE 70 per tic; WL_AGENT.C
    `ControlMovement`/`Thrust`: ×MOVESCALE 150 forward and sideways, ×BACKMOVESCALE 100 back, turn
    /ANGLESCALE 20 degrees; ID_SD.H `TickBase` 70), converted to 1/32 cell and 2880 per turn:
    168000/65536 units a tic walking, 14 angle units turning. Collision is Wolf3D's `ClipMove`: a box
    of PLAYERSIZE (0x5800, 11 units) tried whole, then along x, then along y: the player slides along
    walls. The original's step (parity push, midpoint test, undone step, speed back to 16) is not
    used: it snaps the player 8 units off any wall cell he enters, which at 2.6 units a tic would
    jitter and stick. Objects keep the original's cell rule: a pickup is touched when the player's
    centre enters its cell; an enemy's cell blocks the entry and touches it (J6's rule; without the
    J6 fix once a game tick); an enemy that walks into the player's cell does not trap him. The
    arrows' presses and the tick's held keys and coast do nothing (Caps Lock + ← / → strafes, as
    before).
  - **Drawing at the display rate, enemies on the tick.** A motion step that moved or turned draws a
    frame (`labyrinth.renderFrame` + the minimap marker) with `g.viewOnly` set: `raycast.renderView`
    leaves the hands' sway and `sprites.drawEntry` only draws, skipping the enemy's step wave,
    attack, life check, move and `nextFrame`. The tick's frame (timer 1) runs them as ever, so the
    enemies act once a tick whatever the frame rate: 10 times a second with the frame cost, as the Original's ("Platform: frame cost"). The
    alternative, TIRO's `host.Program.view` (a presented picture between steps), was rejected: here
    the motion itself changes the game state (collisions, pickups) and must stay in the task's
    message order, deterministic in the headless harness. The web and SDL loops dispatch the 14-ms
    timer once per frame when they are slower (Windows' coalescing), so a frame is drawn per
    display frame while moving.
  - `jardim_wall_margin`: at least 8 units from every wall face (the 1995 step is undone if it
    comes nearer; the Wolf3D box keeps 11), for the textures up close (the owner approved it
    after a texture investigation; the textures themselves are another change).
- **The walls up close** (the owner approved the texture investigation's fixes 1–3;
  `docs/jardim/TEXTURES.md` has its findings and how to make the frames):
  - `jardim_texture_per_pixel` (J4, replacing the first fix `jardim_wall_texture_on_wall`, which
    passed the hit & ~3 for a wall as for a door and turned the walls into combs): each of a
    column's 4 pixels gets its own texture column from the exact 16.16 hit, interpolated towards
    the next column's hit when it is on the same plane (same walk, same grid line, both walls or
    both doors), else extrapolated from the previous one. Walls repeat their 32-texel texture **4
    times a cell** (the owner's pick, "d32 x4 per cell looks best": the bricks keep the
    Original's size at 1–3 cells, now fixed to the wall); doors once a cell (a texture is a whole
    door). `renderView` keeps its walks in the original order (the sprite queue is built the same)
    and, with the flag, draws the 120 columns after the last walk. The pixels are gathered by a
    fix-only blit, `scaled.blitScaledColumnPerPixel`, with `blit_scaled_column`'s row stepping
    (a test checks it draws the 1995 blit's rows); the oracle-tested blit is untouched. No mirror
    on the −x/−y faces (the door handles are drawn as the texture has them, in both versions).
  - `jardim_wall_height_exact`: the walks also return their length before the `>> 16`, without
    the 32-bit wrap (`raycast.Exact`, null for the 1995 callers and the oracle tests); the height
    is table 4's entry / that length, at most 0x65ae. `g_columnDepth` and the shading keep the
    whole units.
  - `jardim_wall_odd_height_row`: a slice taller than the view with an odd height gets its top a
    row lower (BUGS.md "Harmless (JARDIM)", the blit's off-by-one rows).
  - `jardim_wolf_keys` (`src/jardim/controls.zig`): W/S or ↑/↓ walk, A/D strafe, ←/→ turn, Shift
    runs, Ctrl or Space fire, E opens a door or takes an exit, Esc quits. Translated in front of the
    game (AppWndProc, before the phase handler): Space is passed on as VK_CONTROL and E as the
    original's VK_SPACE. Space as fire was chosen over keeping it for doors: it is Wolf3D's and the
    modern habit, and nothing else in JARDIM uses Space. W/A/S/D are read by the motion step (without
    `jardim_smooth_movement` W and S are passed on as ↑ and ↓, A and D do nothing). No mouse look.
  - `jardim_controls_screen` (`src/jardim/controls.zig`): a controls screen from WM_CREATE
    (Portuguese: the keys, the three exit doors, the goal, pickups, health and lives) drawn
    over the first frame with the fights' `core/controls_screen.zig` (the panel, caps and texts
    now shared; `fight_controls` keeps its rows). Until a key (Esc quits as ever) or a click, the
    game gets no key, mouse or timer message: nothing moves, no enemy acts; the NOITE handshake
    (0x40b, 0x40c, 0x40a), WM_PAINT (the screen drawn again over the frame), WM_DESTROY and the
    sound notifications go on. The key that took it down is ignored until released; the time it
    was up moves `g_startTick` on (J1's fixed bonus counts the time played) and the motion clock
    restarts.
- **The raycaster** (the owner's report on the web build, Corrigida: "at the end of the corridor the wall
  texture looks broken", "the floor texture moves as you walk, it should be fixed on the ground like in
  Doom", "a staircase pattern in the corridor walls": "implement a proper raycaster algorithm"). One flag,
  `jardim_raycaster` (`src/jardim/raycaster.zig`, not a port unit; in `all`):
  - **Casting.** One DDA ray per pixel column (480, the view's width) through a flat camera plane (a 60°
    field, the original's: the focal length is 240 / tan 30° = 415.7 px; Lode Vandevenne's grid walk on the
    32-unit cells). The distance is the **perpendicular** one (the ray parameter with the forward component
    1), so there is no fisheye to correct. The wall is 22500 / distance px tall (the original's scale: the
    eye is in the middle of a 54-unit wall, 300 px), its top and bottom at the sub-pixel (a row is the wall's
    if its centre is inside the slice), the texture row stepped per pixel row from the clipped top (exact
    when the slice is taller than the view, with no odd-height special case), and the texture column is the
    exact hit point along the wall, mirrored on the faces that would show the texture reversed (y is up and
    angles run counter-clockwise: the texture runs to the viewer's right), tiled 4 times a cell on a wall
    and once on a door (the `jardim_texture_per_pixel` choice). The pose is the player's continuous position
    (`playerX` + `g.wolf.fracX`) and the view angle as the tables read it (`angle | 1` units).
  - **Doors** are the original's (GAME.md "The map"): a door recessed half a cell is hit only if the ray is
    still in the cell when it reaches the plane (the original draws it from any ray that crossed the line);
    the other way the ray stops at the cell's face and the cell beyond is drawn there (an empty one: a wall `1`).
  - **Floor.** Cast per row in world space: the row's distance is 11250 / (row − horizon) / 32 cells (half the
    wall height under the horizon), and the world point of its pixels steps along the camera plane's right
    vector, so the floor is fixed to the ground as the player walks and turns (the sky stays the backdrop's, as
    the original scrolls it). The art is a 128 × 128 piece of the backdrop picture's own floor (`opcaoN.bmp`,
    inside its 480 × 150 sand, at the view's x + 176 and the horizon + 11), one cell wide (4 texels a unit,
    the walls' scale), mirrored where it repeats so no seam shows. The floor's palette entries have no
    shaded copies (the walls' have: 23 apart), so it is not shaded.
  - **Mips.** The six wall textures get a (2^i × 2^j) box-filter mip per axis (ripmap), the floor tile square
    ones; each average is snapped to the nearest of the texture's own palette entries (the surface is 8-bit and
    the wall shading adds a fixed step to the entry). The level is `floor(log2)` of the texels a pixel spans:
    for a wall, across: |d along / d column| from the ray's angle, down: 300 / slice height; for the floor
    the geometric mean of its two footprints. Up close the level is 0 (the texture as is). They are built the
    first frame of each phase (`State.built_for`), in the task's arena.
  - **Sprites** are drawn by `raycaster.drawSprite`: from the sprite's world position and the frame's
    continuous camera (a fair enemy walks between cells), at the wall scale of its depth, standing on the
    floor line, each pixel column kept only if the sprite is nearer than the wall's depth there (`State.depth`,
    the 1-D buffer of the walls' perpendicular distances): an enemy hides behind a pillar that cuts across it,
    not only at the ends of its span as the original's.
  - **Only the pixels are new.** `raycast.renderView` still runs the 1995 walks for every column (they queue
    the sprites, flag the objects visible and fill `g.columnDepth`: the 1995 enemies' logic reads them), draws
    nothing for the walls, and calls `raycaster.render`; `sprites.drawEntry` keeps the original's clip and
    its draw decision (the enemies' blows and sounds) and draws through `drawSprite`. So every 1995-control
    script's result is the original's; the Corrigida's pictures change (the goal's `pixel` checks in
    `jardim-corrigida-espquete-win.input` and `-4fjarvamp-win.input`: 228 / 231).
  - **The earlier wall flags** (`jardim_texture_per_pixel`, `jardim_wall_height_exact`,
    `jardim_wall_odd_height_row`) do nothing while the raycaster is on (it computes the exact column, height
    and clipping); they stay for the 1995 renderer (`--fix all,-jardim_raycaster`).
  - **Cost.** About 1.2 ms a frame natively (ReleaseFast, the self-hosted backend, a 40-cell room; 480 rays,
    about 72 000 floor and up to 144 000 wall pixels); the mips are built once (a few ms).
  - **Frames.** `zig build -Djardim-pose=X,Y,ANGLE` (units, decimals allowed; angle 0..2879) starts JARDIM at
    that pose, for `--dump`s of the same viewpoint with the flag on and off.
- **Fair enemies** (the owner's request, from the enemy investigation's ranked proposal,
  `docs/jardim/ENEMIES.md` §7; GAME.md "Fair enemies (Corrigida)" has the rules). Two flags, both
  in `all`:
  - `jardim_fair_enemies` (`src/jardim/enemies.zig`, not a port unit). It takes effect only with
    `jardim_smooth_movement`: it is built on the Corrigida's architecture (the player moved by the
    14-ms motion timer, the enemies acting on the game tick, view-only frames that only draw), and
    the 1995-control runs (`--fix all` less the movement flags) keep the 1995 enemies and their
    scripts' results.
  - **Instances, not a per-cell table.** The proposal's side table `enemy[80][57]` would have to be
    moved with every object write; instead `Game.fair` holds up to 64 `Enemy` instances built from
    the map the first time a backdrop ticks (each phase's backdrop is new), and the map keeps the
    type's object in the instance's cell. So the original's shot, touch, `hit` and the respawn's
    `placeObjects` work unchanged; a kill is seen as the instance's cell no longer holding its
    object. The draw finds the instance by its cell (`placeForDraw`): its position between two
    cells (the map's cell changes at the step's start, so collisions and shots stay per cell), its
    frame; `sprites.drawEntry` skips the original's enemy logic. Dying instances are queued by
    `sprites.flush` (their cell is empty) and drawn from a white copy of their strip, made once.
  - **The clock.** `enemies.think` runs from the game tick (`labyrinth_input.tick`, before the
    tick's frame), once per instance, on `plat.ticks()` deadlines: steps, reactions, wind-ups and
    cooldowns keep their average rate whatever the tick rate (10 a second with `render_cost_ms`),
    the copies drawn or the display's frame rate; the walking frames come from the clock too, so
    the view-only frames animate and slide the enemies between the ticks. With the frame cost a
    250-ms wind-up lasts 3 ticks (300 ms).
  - **Melee range 1 = the 8 cells around the player.** An enemy may stand in any of them (its
    blow needs it, and the original's map is mostly 1-cell corridors where the only cell ahead is
    the neighbour), never in his cell, and never in a cell whose centre is within 24 units of him
    (the original drew an enemy at 16 units over the whole view): it waits a cell further until
    he moves. A blow needs a clear line not cutting a wall's corner, so a diagonal neighbour round
    a corner cannot hit.
  - **Life-taking enemies: 10 health a blow, contact free** (the owner: OK as is). With the
    tell and the cooldown, the blows are readable damage; a life per bump (J6's rule) would make
    the three strongest enemies end a life in one touch while their blows take a tenth of one, and
    walking into an enemy that stands next to you is easy in a 1-cell corridor. Walking into any
    enemy only blocks; `EnemyTuning.contact_hurts` brings back the original's touch (once per
    contact).
  - **The goal** (not an enemy) stands and animates and is walked into for the win; shots ignore
    her. She is the woman in the swimsuit walking towards the player; who she is depends on the
    route (`espanf` after `espquete`, `vamanf` after `4fjarvamp`).
  - **Respawn: the original rule** (the owner). After a lost life every enemy, the killed ones too,
    comes back at its cell (the original places the map again; `enemies.beforeRespawn` takes the
    walked-off instances out of their cells first so none is doubled, `afterRespawn` rebuilds every
    instance idle).
  - **The numbers** are all in `enemies.EnemyTuning` (with comments); F9 in a Debug build shows the
    nearest enemy and logs every tick (the fights' precedent), `zig build -Djardim-probe` is the
    planner's build (the log from the start, the objects map, no motion frames).
  - `jardim_shot_substeps` (`labyrinth_input.shotSubsteps`): the 32-unit flight a tick in four
    8-unit steps to the same end point, each new cell met as the original's step meets its one.
    The 1995-control scripts aim along the axes and keep their results with it.
- **Two programs in one process**, as ENCAIXE and TIRO (`src/platform/host.zig`): JARDIM is a
  task with its own state, queue, timers, window and screen; the protocol runs through the
  platform as in Windows. The host needs nothing new for JARDIM; the platform needs the keys and
  `GetKeyState` ("Platform" below).
- **The playthroughs leave JARDIM out** (owner decision: each minigame is tested by its own
  scripts only). `full.input` and `onebutton.input` end in `espquete`, which launches JARDIM:
  they run with `--minigame-stub=jardim` (the stub's win, then `6fsai1`), and JARDIM is played by
  the `jardim-*.input` scripts ("Tests").
- **The Backdrop's perspective getters stay constants in `space3d`.** `getVanishX`/`Y`,
  `getEyeDistance` and `getAxisX` return the Backdrop defaults' 0 directly instead of going
  through backdrop dispatchers: JARDIM's only backdrop class (the LabyrinthBackdrop) overrides
  none of them and its `setVanishPoint`/`setView`/`setAxis` calls are the defaults too, so a
  dispatch would always land on the same 0 (and JARDIM's `backdrop` unit declares no such slots).
- **The heap.** JARDIM never frees most of what it allocates: the seven tables per backdrop
  (three backdrops, `_fmalloc`, 71 KB each), the backdrops, the phase scenes' Portables (their
  destructors never run). `Game.local()` is the task's heap (an arena freed by `Game.destroy`):
  every `operator new`/`_fmalloc` of JARDIM allocates there, and the faithful leak is not a leak
  of the port.
- **The touch pad** (the owner's decision): the four arrows, SPACE (open) in the centre and CTRL
  (fire) bottom right; running (SHIFT) and strafing (CAPS LOCK) are left out
  (`PAD_KEYS.jardim` at the integration, Integration). The Corrigida's (`PAD_CORRIGIDA.jardim`, the
  fights' 6-row grid): the arrows on the left (▲ ▼ walk, ◀ ▶ turn), on the right "◁ Lado" and
  "Lado ▷" (A, D: strafe) over "Abrir" (E) and "Tiro" (CTRL); running is left out.
- **The won flag (the owner's SERIAL rule, survive = win, checked here):**
  the won flag stays 1 when the goal is reached with lives left, 0
  otherwise. The win is completion. BUGS.md "The won flag of the other minigames".

## Source layout

```
src/jardim/root.zig          program root: core, units, `ready`, `program` (host.Program)
src/jardim/core/             types only (not units)
  game.zig                   Game: JardimGame + every JARDIM DGROUP global; queue, send/post, timers, heap
  object.zig                 Object (kinds scene_object / wall_strip / portable / exit / player / control_panel), parts, Frame
  world.zig                  Scene (+ SceneVtbl, the phases'), Backdrop (+ LabyrinthBackdrop), SpriteQueue, Tables, lists, Condition
src/jardim/<unit>.zig        module units
src/jardim/behaviour/        behaviour units (one group of SceneObject slots)
src/jardim/units.zig         generated index (`noite -p jardim unit sync`)
src/jardim/tables.bin        the precomputed trigonometric tables (unit `tables`, generated)
src/jardim/testdata/         oracle vectors of the 32-bit routines (units `raycast`, `scaled`)
```

The core files are types only; a unit that finds a field the skeleton lacks adds it there with
its `@orig` offset (DATA.md lists Portable, Exit, ControlPanel, Moveable, Animated3D and Frame as
skeletons: their parts carry the twins' fields until a unit confirms them).

## Object model

As TIRO's (one `Object`, a `kind`, every part present), with JARDIM's classes. Six kinds are
built:

| Kind | Class (vtables) | Used for | Parts live |
|---|---|---|---|
| `scene_object` | SceneObject (3f0e) | the face (`rostoN`), the hands (`maosN` strips, `curStrip` = the weapon), the shot (`shotN`) | base |
| `wall_strip` | WallStrip (8e60: SceneObject + `attach`) | the wall textures (`paredesN`, 6 × 32×300) | base (+ `textureCount`) |
| `portable` | Portable ← Moveable ← Mover + Object3D (59d4, 59d8, 5b5c) | every pickup and enemy: **one** object per type, stored in many map cells | base, o3d, mover, portable |
| `exit` | Exit ← Animated3D ← Animation + Object3D (8fe4, 8ffc, 9180) | phases 1–2's `portainv.bmp`, only its exit index | base, o3d, anim, exit |
| `player` | Player ← Actor ← Moveable + Animated3D (7d6a, 7d6e, 7d86, 7f0a) | createPlayer's dummy (`passo1.bmp`, not on the disc), never shown | base, o3d, anim, mover, actor |
| `control_panel` | ControlPanel ← Animated3D (7b84, 7bbc, 7d40) | `labinter.bmp` | base, o3d, anim, panel |

`Object.is/as` are the type-test slots 41–52, 58, 59. Mover, Moveable, Animation, Animated3D,
Object3D and Actor are only bases: their methods that no live table reaches are `dead` in the
plan, with TIRO's leftovers (`actor2d_*`, `player2d_*`, the dead Player methods). A method that
overrides a SceneObject slot gets the SceneObject subobject in the original and reaches its class
through the vbtable (DATA.md "Classes"; the decompile shows `*(int *)(&p[0x10].field_0x1a +
vbptr->sceneObjectOffset)`): in the port that is just `obj`. The labyrinth's own fields on the
SceneObject: `worldX`/`worldY` (+0x496/+0x498, the map position), `isEnemy` (+0x49a),
`framesLeft` (+0x49c; the wall strip's texture height).

## Virtual slots

Each SceneObject slot is one `pub fn` dispatcher (named after the vtable field) in the unit that
owns it, already declared in the skeleton with its final signature and a `stub.unported` body; it
switches on `obj.kind` and calls one function per original implementation, each tagged `@orig`.
The default stub (`scene_object_*_default`, absorbed) is the `else` arm. Thunks (276), defaults
(86) and type tests (40) are `absorbed`. Signatures: `(g: *Game, obj: *Object, <args in source
order>)` (Ghidra lists far pascal parameters reversed); hwnd and hdc parameters are dropped;
`*Backdrop` stays; out-parameters join the return value (`space3d.Support`). The signatures are
TIRO's skeleton's where the field exists there. A class's override of a SceneObject slot lives
in the slot's unit, next to its dispatcher (the wall strip's `attach` is in `occupancy`, the
Exit's `play`/`tick` and `exit_has_key_object` in `animation`, the panel's `draw` and its texts
in `render`).

Single-class tables are plain functions: Game (`game`, `game_input`), Backdrop (only the
LabyrinthBackdrop is built: `labyrinth.create` is slot 00, `labyrinth_input.handleMessage` slot
17, the defaults are `backdrop`'s), ControlPanel (`panels`), Condition (`game`), Frame
(`object_create.getCell`).

### Scenes

The scene is the one table with several live classes: Phase1Scene, Phase2Scene and Phase3Scene
(LabyrinthSceneVtbl 834c, 91aa, 92da; 24 slots = SceneVtbl's 16 + `hit`, `touch`,
`placeObjects`, the four sounds, `onLifeLost`). The port keeps the original's shape:
`world.SceneVtbl` is a table of function pointers (the slots a phase overrides), one constant
per phase unit (`phase1.vtbl` …), stored in `Scene.vtbl` by the phase's ctor
(`labyrinth_scene.ctor(phase)`), and called through `Scene`'s wrappers (`s.touch(g, obj)` …). A
dispatcher that switched on the phase would have to import the three phase units from a unit
they call (a cycle the tracker refuses). The base slots (SceneVtbl 01–04, 08–0F) are `scene`'s
plain functions; `scene.createNewSceneDefault` (absorbed, "Faltou redefinir…") is what each
phase's `createNewScene` calls first and what Phase3Scene's slot 06 is.

### SceneObject slots (kinds: scene_object, wall_strip, portable, exit, player, control_panel)

JARDIM's slot numbers (byte offset = 4 × slot); `tiro` is TIRO's slot of the same field.
Generated from the tracker's vtables (thunks resolved); `noite -p jardim unit dep infer` reads
the unit column.

| slot | behaviour | unit | tiro | default | overrides (impl: kinds) |
|---|---|---|---|---|---|
| 00 | slot00 | position | – | scene_object_slot00_default |  |
| 01 | slot01 | position | – | scene_object_slot01_default |  |
| 02 | enableRle | position | – | scene_object_enable_rle |  |
| 03 | isRle | position | – | scene_object_is_rle |  |
| 04 | getSceneName | position | – | scene_object_get_scene_name |  |
| 05 | getWorldX | space3d | 00 | scene_object_get_world_x_default | object3d_get_world_x: portable exit player control_panel |
| 06 | getWorldDepth | space3d | 01 | scene_object_get_world_depth_default | object3d_get_world_depth: portable exit player control_panel |
| 07 | getWorldElev | space3d | 02 | scene_object_get_world_elev_default | object3d_get_world_elev: portable exit player control_panel |
| 08 | getSizeW | space3d | 03 | scene_object_get_size_w_default | object3d_get_size_w: portable exit player control_panel |
| 09 | getSizeH | space3d | 04 | scene_object_get_size_h_default | object3d_get_size_h: portable exit player control_panel |
| 0A | getSizeD | space3d | 05 | scene_object_get_size_d_default | object3d_get_size_d: portable exit player control_panel |
| 0B | getAnchorX | space3d | 06 | scene_object_get_anchor_x_default | object3d_get_anchor_x: portable exit player control_panel |
| 0C | getAnchorY | space3d | 07 | scene_object_get_anchor_y_default | object3d_get_anchor_y: portable exit player control_panel |
| 0D | getX | position | 08 | scene_object_get_x | mover_get_x: portable player |
| 0E | getY | position | 09 | scene_object_get_y | mover_get_y: portable player |
| 0F | getStepX | position | 0A | scene_object_get_step_x_default | mover_get_step_x: portable player |
| 10 | getStepY | position | 0B | scene_object_get_step_y_default | mover_get_step_y: portable player |
| 11 | slot11 | position | 0C | scene_object_slot11_default |  |
| 12 | setElevation | space3d | 0D | scene_object_set_elevation_default | portable_set_elevation: portable; object3d_set_elevation: exit control_panel; moveable_set_elevation: player |
| 13 | setAnchor | space3d | 0E | scene_object_set_anchor_default | object3d_set_anchor: portable exit player control_panel |
| 14 | setSize | space3d | 0F | scene_object_set_size_default | object3d_set_size: portable exit player control_panel |
| 15 | setWorldElev | space3d | 10 | scene_object_set_world_elev_default | portable_set_world_elev: portable |
| 16 | drawBounds | space3d | 11 | scene_object_draw_bounds_default | object3d_draw_bounds: portable exit player control_panel |
| 17 | addDirtyRect | render | 12 | scene_object_add_dirty_rect |  |
| 18 | computeOverlap | render | 13 | scene_object_compute_overlap |  |
| 19 | restoreBackground | render | 14 | scene_object_restore_background | mover_restore_background: portable player |
| 1A | drawDirtyTo | render | 15 | scene_object_draw_dirty_to | mover_draw_dirty_to: portable player |
| 1B | draw | render | 16 | scene_object_draw | exit_draw: exit; player_draw: player; control_panel_draw: control_panel |
| 1C | drawClipTo | render | 17 | scene_object_draw_clip_to |  |
| 1D | drawClip | render | 18 | scene_object_draw_clip |  |
| 1E | erase | render | 19 | scene_object_erase | animation_erase: exit player control_panel |
| 1F | slot1F | render | 1A | scene_object_slot1f_default | animation_slot1f: exit player control_panel |
| 20 | redraw | visibility | 1B | scene_object_redraw | animated3d_redraw: exit player control_panel |
| 21 | hideAndInvalidate | visibility | 1C | scene_object_hide_and_invalidate |  |
| 22 | blitToDc | visibility | 1D | scene_object_blit_to_dc | moveable_blit_to_dc: portable player |
| 23 | invalidate | visibility | 1E | scene_object_invalidate | moveable_invalidate: portable player |
| 24 | slot24 | visibility | 1F | scene_object_slot24_default | mover_slot24: portable player |
| 25 | hide | visibility | 20 | scene_object_hide | mover_hide: portable player |
| 26 | show | visibility | 21 | scene_object_show | mover_show: portable; animated3d_show: exit control_panel; actor_show: player |
| 27 | occupy | occupancy | 22 | scene_object_occupy | player_occupy: player; control_panel_occupy: control_panel |
| 28 | vacate | occupancy | 23 | scene_object_vacate | player_vacate: player; control_panel_vacate: control_panel |
| 29 | attach | occupancy | 24 | scene_object_attach | wall_strip_attach: wall_strip; moveable_attach: portable player; object3d_attach: exit; control_panel_attach: control_panel |
| 2A | canStep | occupancy | 25 | scene_object_can_step_default | portable_can_step: portable; moveable_can_step: player |
| 2B | isStepBlocked | occupancy | 26 | scene_object_is_step_blocked |  |
| 2C | nextFrame | animation | 27 | scene_object_next_frame_default | animated3d_next_frame: exit player control_panel |
| 2D | prevFrame | animation | 28 | scene_object_prev_frame_default | animated3d_prev_frame: exit player control_panel |
| 2E | play | animation | 29 | scene_object_play_default | exit_play: exit; animated3d_play: player control_panel |
| 2F | playIdle | animation | 2A | scene_object_play_idle_default |  |
| 30 | stopAndRedrawDc | animation | 2B | scene_object_stop_and_redraw_dc_default | animated3d_stop_and_redraw_dc: exit control_panel; actor_stop_and_redraw_dc: player |
| 31 | stopAndRedraw | animation | 2C | scene_object_stop_and_redraw_default | animated3d_stop_and_redraw: exit control_panel; actor_stop_and_redraw: player |
| 32 | tick | animation | 2D | scene_object_tick_default | exit_tick: exit; player_tick: player; control_panel_tick: control_panel |
| 33 | stop | animation | 2E | scene_object_stop_default | animated3d_stop: exit player control_panel |
| 34 | moveTo | movement | 2F | scene_object_move_to_default | moveable_move_to: portable player |
| 35 | moveToEdgeH | movement | 30 | scene_object_move_to_edge_h_default | moveable_move_to_edge_h: portable player |
| 36 | moveToEdgeV | movement | 31 | scene_object_move_to_edge_v_default | moveable_move_to_edge_v: portable player |
| 37 | stopMovingDc | movement | 32 | scene_object_stop_moving_dc_default | moveable_stop_moving_dc: portable; actor_stop_moving_dc: player |
| 38 | stopMoving | movement | 33 | scene_object_stop_moving_default | moveable_stop_moving: portable; actor_stop_moving: player |
| 39 | moveTick | movement | 34 | scene_object_move_tick_default | moveable_move_tick: portable; player_move_tick: player |
| 3A | getTimerId | animation | 35 | scene_object_get_timer_id_default | moveable_get_timer_id: portable; animated3d_get_timer_id: exit control_panel; actor_get_timer_id: player |
| 3B | isMoving | movement | 36 | scene_object_is_moving_default | moveable_is_moving: portable player |
| 3C | isRunning | animation | 37 | scene_object_is_running_default | animation_is_running: exit player control_panel |
| 3D | moveToAndDrop | space3d | 38 | scene_object_move_to_and_drop_default | portable_move_to_and_drop: portable; object3d_move_to_and_drop: exit control_panel; moveable_move_to_and_drop: player |
| 3E | setPosition | position | 39 | scene_object_set_position | moveable_set_position: portable player |
| 3F | isScrollTarget | position | – | scene_object_is_scroll_target | player_is_scroll_target: player |
| 40 | slot43 | position | – | scene_object_slot43_default |  |
| 53 | redrawOverlapping | visibility | 4D | scene_object_redraw_overlapping_default | object3d_redraw_overlapping: portable exit player control_panel |
| 54 | hitboxOverlaps | position | 4E | scene_object_hitbox_overlaps |  |
| 55 | boundsOverlap | position | 4F | scene_object_bounds_overlap |  |
| 56 | slot5B | position | 50 | scene_object_slot5b_default |  |
| 57 | slot5C | position | 51 | scene_object_slot5c_default |  |
| 5A | isEnabled | position | 54 | scene_object_is_enabled_default | exit_is_enabled: exit |
| 5B | getExitIndex | position | 55 | scene_object_get_exit_index_default | exit_get_exit_index: exit |
| 5C | slot61 | position | – | scene_object_slot61_default |  |
| 5D | slot62 | position | – | scene_object_slot62_default |  |
| 5E | slot63 | position | – | scene_object_slot63_default |  |
| 5F | slot64 | position | – | scene_object_slot64_default |  |
| 60 | slot65 | position | – | scene_object_slot65_default |  |
| 41–52, 58, 59 | type tests | (Object.is/as) | | | |

### Other vtables

`docs/jardim/SLOTS.tsv` is this table for the tracker (`unit dep infer`).

| vtable | slots → unit |
|---|---|
| Object3DVtbl (8) | `space3d`: slot00, findSupport, isBelow, isAboveOnScreen, isInFrontOf, overlaps3d, moveToAtElev, dropToSupport (Object3D's, Moveable's, Portable's) |
| MoverVtbl (1) | `movement.placeAt` (moveable_place_at: every live Mover is a Moveable) |
| AnimationVtbl (6) | `animation`: lock, isLocked, slot02–04 (the three stubs), playOnce |
| ControlPanelVtbl (14) | 00–05 `animation` (the AnimationVtbl part); 06–0D `panels` |
| GameVtbl (7) | 00 `game_input.handleMessage`; 01–06 `game` (createPlayer … onCreate) |
| SceneVtbl (16) / LabyrinthSceneVtbl (24) | `world.SceneVtbl` through `Scene.vtbl` (above): 00, 05–07, 10–17 per phase (`phase1..3`, createScreen and the ctors in `labyrinth_scene`); 01–04, 08–0F `scene` |
| BackdropVtbl (23) / LabyrinthBackdropVtbl (24) | 00 `labyrinth.create` (labyrinth_backdrop_create; Backdrop's `backdrop_create` is its base call); 01–16 `backdrop` (defaults); 17 `labyrinth_input.handleMessage` |
| ConditionVtbl (3) | `game` (FlagCondition; CompoundCondition is dead) |
| FrameVtbl (1) | `object_create.getCell` |

## State

`core/game.zig`'s `Game` is JardimGame + Game flattened (`g_game` and `g_jardimGame` are the
game itself) plus every DGROUP global (`g_carryHealth` → `g.carryHealth` …; the strip tables;
the backdrop handler's latches `g_keyLeftDown` … and the shot's `g_shotSec/Csc`,
`g_shotCellObject`; the phase wave tables; `g_columnDepth[120]`; `g_labyrinthTables` →
`g.tables`). `noite -p jardim initdata` checks the `// @orig g_*` defaults against DGROUP. No
counterpart: the timer pointers, the module handle, `g_biosTickPtr` (dead), the FP constants and
`g_angleRadians` (the tables are precomputed), the minimap's pens and brushes (their colours, in
`hud`), the occupancy matrices (dead in JARDIM). Leaf units take the narrowest thing, as in NOITE.
One `Game` per running JARDIM.

`core/world.zig`:
- **`Scene`**: Scene + LabyrinthScene + the phases' fields flattened (one Portable per object
  type, the Exit and its index, the goal), `phase` and `vtbl`. The base Scene fields are
  TIRO's with far pointers (LabyrinthScene's `handlerEnabled` at +0x60 confirms the sum); `scene`
  confirms them.
- **`Backdrop`**: the Backdrop base (NOITE's layout, one top-down 640×480 WinG bitmap,
  `surface()`: NOITE's pixel contract) + the LabyrinthBackdrop: the player (`playerX/Y` in 1/32
  cell, `viewAngle` 0–2879), the start, the scrolls, the velocity, the view rectangle, the speed,
  `secAt`/`cscAt` (the original's far pointers into tables 5 and 6 at the view angle: indices
  here), the map (`wallRows[80][58]` i8, `objectRows[80][57]` ?*Object), `health`, `lives`,
  `ammo`, `level`, `score` (16-bit), the face, hands, shot, wall strip, the scene, `active`,
  `shotInFlight`.
- **`SpriteQueue`**: 100 `SpriteQueueEntry` nodes {object, dist, angle, col, row, left, right},
  `root`, `nextFree`.
- **`Tables`**: the seven 16.16 tables as slices into the task heap (unit `tables`).
- `DrawList`, `UpdateList` (30), `Condition` (FlagCondition).

The variant (`g.variant`, 0x40b's wParam) only picks the goal's picture (`espanf` for 1,
`vamanf` for 0). `g_startTick` is `GetTickCount()` of the first backdrop: `g.plat.ticks()` of the
virtual clock (J1's penalty, and its division by zero when the low word of the win's tick equals
the start tick, follow from it).

## Reading JARDIM (large model, /Od)

- Code is far: one segment per module, `CALLF`, `RETF n`. Game code is far pascal, Ghidra
  `__stdcall16far`, parameters listed **reversed** (`phase1_scene_hit(this, row, col, obj)` is
  source `(obj, col, row)` → `hit(g, s, obj, col, row)`); `this` is a **far** pointer at
  `[BP+6]`, reloaded with `LES BX,[BP+6]` before each access. `__cdecl16far*` where the caller
  pops (the scaled copies, the 16:32 gateways).
- Data is far: DS = DGROUP `10d0` (loaded once by the CRT, no `PUSH DS; MOV DS` prologue);
  pointers are 4 bytes; strings and globals are `10d0:xxxx`, except the engine strings and
  `opcaoN.bmp` in `10c0`.
- A virtual call is `LES BX,[obj]; LES BX,ES:[BX]; CALLF ES:[BX+off]`: slot = off / 4. Every
  call site has a call-site override with the slot's definition (FUNCTIONS.md "Cleanup"), so the
  decompile reads `(**ppSVar7)(obj)` with `ppSVar7 = &vtbl->nextFrame`. The vtables are in
  `10c0`; the adjustor thunks (`<target>_thunk[_k]`) adjust `this` through the vbtable.
- Every function starts `PUSH BP; MOV BP,SP; MOV AX,frame; CALLF _aFchkstk` (a call-fixup:
  ignore it). `/Od` adds a `JMP` to the epilogue after each return, long jumps, compare chains
  for every `switch`, and four dead arms folded into their functions (`JardimDeadBlocks`).
- SceneObject fields reached through the virtual base read as `*(int *)(&((Portable
  *)p)[0x10].field_0x1a + vbptr->sceneObjectOffset)`: the SceneObject field at that offset
  (here +0x496, `worldX`). 32-bit arithmetic is `_aFlmul`/`_aFldiv` and `CONCAT22` pairs: take
  the signedness from the asm.
- `1028:2609` (6 KB) and the phase handlers are long; the plates of every `1028` function
  describe its cases (units, angle wraps, the tables' use).

## The 32-bit routines

Four segments (Ghidra `1000–1018`) switch themselves to 32-bit code through DPMI on first entry;
Ghidra decodes them as 16-bit, so their listing is garbage past the prologue (the tracker's `.ref`
files warn for `1000` only; `1008`, `1010` and `1018` are the same case). Six routines:

| Address | Name | Unit | Called by | What |
|---|---|---|---|---|
| `1000:0024` | `blit_scaled_column` | `scaled` | `dib_blit_scaled_column` 1068:0000 | a 4-px wall column: texture row (v+1)/2 − 1 scaled to h rows (nearest row), clipped to the 300-row view; depth shading `k·0x17171717` added to each dword, k = min(3, dist >> 6) |
| `1000:0148` | `dib_rows_copy_transparent32` | `dib` | the transparent copies | NOITE's 1000:0024 (delegates) |
| `1000:0234` | `dib_rows_copy32` | `dib` | the opaque copies | NOITE's 1000:0114 (delegates; B12) |
| `1008:0024` | `raycast_walk_horizontal` | `raycast` | `raycast_render_view` | DDA along y = 32k: ray length, cell value, hit x; queues the objects of the empty cells crossed |
| `1010:0024` | `raycast_walk_vertical` | `raycast` | `raycast_render_view` | DDA along x = 32k (the same with x and y swapped; odd/even doors see-through/recessed the other way) |
| `1018:0024` | `blit_scaled_sprite_transparent` | `scaled` | `dib_stretch_copy_transparent` 1068:1336 | column-by-column 2-D Bresenham stretch, key colour 10 transparent; BUGS.md J5 |

**How they are ported.**
1. The listing: extract the segment and disassemble it as 32-bit code (it starts at offset
   0x24 after the DPMI prologue):

   ```sh
   nix develop -c python3 -I -c "import sys; sys.path.insert(0,'tools/oracle'); from noiteemu import NE
   n=NE('assets/JARDIM/JARDIM.EXE'); s=n.segs[2]   # segs[0..3] = 1000, 1008, 1010, 1018
   open('zig-out/seg_1010.bin','wb').write(n.data[s['off']:s['off']+s['len']])"
   nix develop -c objdump -D -b binary -mi386 zig-out/seg_1010.bin > zig-out/seg_1010.lst
   ```

   (in the worktree's `zig-out/`; phase 4's listings and Python models are in the main checkout's
   `zig-out/jardim/g4/`, not committed). The far calls of the walks into `1028:4b04`/`4b81` are
   NE-relocated (`n.relocs(s)`): the listing shows the unrelocated selector.
2. The Zig: one function per routine, transcribed instruction-group by instruction-group with the
   register semantics kept (32-bit wrapping arithmetic, `SAR` as `>>` on `i32`, `IDIV`
   truncation, `IMUL` low halves, the loop-counter tests exactly as compiled). The arguments are
   the 16-bit caller's pushes (`dib_blit_scaled_column`'s and `dib_stretch_copy_transparent`'s
   frames, `raycast_render_view`'s), as slices and integers instead of far pointers. The walks'
   callbacks (`sprite_enqueue_from32`, `object_set_visible_from32`, 16:32 gateways) are direct
   calls to `sprites.insert` and the visibility store, in the same order and with the same
   arguments; the gateways' own `@orig` tags go on those call wrappers in `raycast`.
3. Where the original loops 2³² times or runs off its selector (J5, the latent 1-row source, the
   border doors' reads outside the map), the port does the same thing up to the first write or
   read out of bounds and then panics naming the BUGS.md entry; J5's fix draws the remaining rows.
4. **Oracle tests** (`oracle=emulated`, required for these six, optional elsewhere): a committed
   generator, `tools/oracle/jardim32.py` (from `zig-out/jardim/g4/walk_test.py`,
   `blit_test*.py`, `sprite_test*.py`), runs the original routine in `tools/oracle` (Unicorn,
   `Emu('assets/JARDIM/JARDIM.EXE')`; the DPMI switch is emulated) on seeded random and edge
   inputs and writes the vectors to `src/jardim/testdata/<routine>.zig`; the unit's tests run
   the port on each vector and compare every output byte (blits: the whole destination buffer;
   walks: dist, cell, hit coordinate and the ordered list of gateway calls). Sizes: the walks
   2,000 rays over the three shipped maps (random positions in floor cells, every angle class,
   rays along the axes, positions on a grid line, doors of both parities) plus the map-border
   cases; `blit_scaled_column` 1,000 (every shading k, slices shorter and taller than the view,
   odd heights: the harmless off-by-one rows); the sprite blit 1,000 (magnify and minify, clips
   at every edge, widths up to 400, the J5 row-478 case asserted as the port's documented panic,
   or with the fix the rows drawn). The tag on each test:
   `// @orig 1008:0024 raycast_walk_horizontal oracle=emulated`.

The two 16-bit wrappers (`dib_blit_scaled_column`, `dib_stretch_copy_transparent`, huge pointers
and the clip) are oracle-tested the same way (whole destination buffers), with their dead 16-bit
workers (`dead_*_huge16`, the `/Od` constant-false branch) marked dead.

## The tables

`raycast_build_tables` (1028:0077, once per backdrop create) fills seven `_fmalloc`'d tables of
16.16 longs with the CRT's x87 math (GAME.md "Units"): for i = 0…2880, a(i) =
`raycast_angle_to_radians(i)`, then [0] = tan·65536, [1] = 65536/tan, [2] = ±32·|tan|·65536 (sign
by i < 1440), [3] = ±32·|cot|·65536 (sign by 720 ≤ i < 2160), [5] = 65536/cos, [6] = 65536/sin,
each clamped to ±2³¹ and truncated by `_ftol`; [4][i+240] = 22500/cos(a(i))·65536 for i =
−240…240. Every wall, sprite and step of the game reads them, so an entry off by one can move a
hit across a cell boundary. They depend on nothing but constants.

**Options.**
- *Port the CRT routines* (`sin`/`cos`/`tan` → `_trandisp1` → the FP library, 10b8:2f87–4b37,
  26 unnamed 8087 entry points with register arguments): it would still need a model of the x87's
  `FPTAN`/`FPATAN`/`F2XM1` (the library's primitives) to the last bit, which no Zig or host
  library gives. Rejected.
- *Compute them at run time with the host's math* (`std.math.tan` on f64): the results differ
  from the original's in the last bits and the truncation turns that into ±1 in the entries
  where the exact value is close to an integer; it also varies with the target (wasm). Rejected.
- *Precompute with exact x87 semantics and verify against the oracle*: **chosen.**

**The generator** `tools/jardim_tables.py` (unit `tables`, committed with it):
1. The reference model, from the asm of 1028:003b and 1028:0077 (not the decompile, which the plate
   calls garbled) and the CRT's `tan`/`sin`/`cos`/`fabs`/`_ftol`:
   - the angle: `FILD` (2·(i|1)) → `FMUL m64` [10d0:13ee] (π/2880 as stored) → `FADD m64` [13f6]
     (0.0003272 as stored), each rounded to the x87's 64-bit significand (round to nearest even;
     the precision control is 64 bits: WIN87EM's init, and the FP library forces it itself at
     10b8:319e), then `FSTP m32` into `g_angleRadians`: **the angle is a binary32**, which moves
     many entries by far more than an ulp;
   - the transcendental of that binary32 value evaluated to well beyond 64 bits (Python
     `decimal`, 60 digits, Taylor series), rounded to the 64-bit significand on ST(0), then
     **`FSTP m64` into `__fac`** (10d0:0c3e) by `_trandisp`: the result the caller gets back is a
     **binary64**;
   - every `FMUL`/`FDIVR` with `g_fixedOne16`/`g_cellSize`/`g_wallHeightK` in extended; [2] and [3]
     go through `fabs`, which takes and returns a binary64 (another round to 53 bits before the
     last multiply);
   - **`FSTP m32` of the scaled value**: each table entry is a binary32 before `_ftol`; the clamps
     against the f32 constants ±2³¹ (only the lower bound for [0], [1], [5], [6]), `FCHS` for the
     signed [2]/[3], and the truncation toward zero of `_ftol` (`FISTP m64` with RC = chop), the
     low 32 bits kept.
2. The oracle: `raycast_build_tables` itself run in `tools/oracle` (with `_fmalloc` stubbed to a
   scratch selector, or the CRT heap with its two KERNEL imports stubbed), the seven tables read
   back. Unicorn computes the transcendental instructions on host doubles, so where the model and
   the oracle disagree the exact value lies within about 2⁻⁴⁰ of an integer: such entries are
   printed and settled by the model (and listed in the commit body). Expected: none.
3. Output: `src/jardim/tables.bin`, the seven tables back to back as little-endian i32 (6 × 2881 +
   481 = 17,767 entries, 71,068 bytes), written only when the model and the oracle agree; its
   SHA-256 is printed and recorded in the unit's test.

**The port.** `tables.build(g)` (`@orig 1028:0077 raycast_build_tables`) allocates the seven
tables from `g.local()` (three times per game, as the original never frees them) and fills them
from `@embedFile("tables.bin")` (`std.mem.readInt` per entry: the embedded bytes have no
alignment). `tables.angleToRadians(i)` (`@orig 1028:003b`) is ported literally with Zig's `f80`
(IEEE extended, round to nearest even: the x87 at 64-bit precision; compiler-rt soft-float on
wasm32) and an `f32` result; only the tests call it. Tests: the SHA-256 of `tables.bin`; 50 entries
across the seven tables against oracle values (`oracle=emulated`); `angleToRadians` against the
oracle's `g_angleRadians` for 20 indices including 0, 1, 719, 720, 1439, 2879, 2880.

## Fixes (BUGS.md J section)

| Bug | Flag | Unit | What the fix changes | In `all` |
|---|---|---|---|---|
| J1 the win's time bonus is a penalty | `jardim_time_bonus` | labyrinth_input | the WM_DESTROY win branch subtracts the whole 32-bit `g_startTick` from the whole 32-bit tick: score += 10⁹ / ms played (16-bit truncation kept) | yes |
| J2 Chato is never removed | `jardim_chato_removed` | phase3 | `phase3_scene_hit` clears Chato's cell (`objectRows[row][col] = NULL`) as every other kill | yes |
| J3 a weapon picked up while a shot flies is lost | `jardim_weapon_waits_for_shot` | phase1, phase2, phase3 | the weapon branches of `touch`, with `shotInFlight`, leave the pickup in its cell and play nothing (as a refused pickup), so it can be taken once the shot has stopped | yes |
| J4 wall textures stay on the screen | `jardim_texture_per_pixel` | raycast, scaled | every pixel of a wall or door column takes its texture column from its own point on the wall (the exact hit, interpolated towards the next column's on the same plane): walls 4 textures a cell, doors 1; a fix-only blit gathers the 4 bytes of a row | yes |
| Harmless: an odd slice taller than the view sits a row high | `jardim_wall_odd_height_row` | raycast | the slice's top one row lower, so its 300 rows land on the view's | yes |
| J5 a sprite with its top on row 478 crashes | `jardim_sprite_last_rows` | scaled | the magnifying row loop draws the 1–2 rows left on the surface; the Original port panics "BUGS.md J5" where the original faults | yes |
| J6 a held key into a life-taking enemy takes a life every tick | `jardim_enemy_once_per_contact` | labyrinth_input (and `wolf.zig`) | an enemy touched becomes the contact; a step into it again is blocked without `touch` until the player is more than 16 units from its cell or it has left: one life, or 5 health, per contact (the owner's rule) | yes |
| J7 the variant (and NOITE's ack) never reaches JARDIM | `jardim_variant_hello` | app | AppWndProc posts 0x40c only after NOITE's 0x40b (the FindWindow branches post nothing) and lets 0x40b and 0x40a reach its own cases before `game_handle_message`, so `espquete`'s timer finds JARDIM, sends the hello and variant 1 arrives (the goal is `espanf`), and the ack stops the 0x40c | yes |
| J8 every system timer ticks the game (timer 10 doubles it) | `jardim_game_timer_only` | labyrinth_input | the backdrop's `WM_SYSTIMER` ticks only for timer 1 (55 ms); the others are answered 1 and dropped | yes |

Each unit ports the buggy code and keeps the fixed path only under its flag
(`g.fixes.jardim_…`). The Latent entries get no flag: where the port would run them it panics
naming the entry (the sprite queue's 101st node, a border door's read outside the map, the
1-row source of `blit_scaled_column`, every other unchecked cell, table entry and divisor) or behaves as the original's data allows (a short map
file: `_filbuf`'s −1, i.e. 0xff, as the cell value). The Harmless entries get none either
(the blit's off-by-one rows, the overwritten placements, the constructor
positions in walls, the phase destructors, `passo1.bmp`, phase 3's dead exit branch, Chato's
silent attack, the repeated loss reports, `WinMain`'s return).

## Integration

**Finished**: every unit is ported, `ready = true`; NOITE's `espquete` and `4fjarvamp` run the
real JARDIM, `--minigame jardim` plays it alone and the web loader offers it ("Jogo" = Jardim,
the owner's touch pad). Port bugs found while integrating:
- **The phase handlers never ran.** `game_input.handleMessage` called the base
  `labyrinth_scene.handleMessage` instead of the scene's slot 00 (`CALLF [BX]` at 1058:003b), so
  the phases' own cases were dead: SPACE on an exit door did nothing (no phase 2 or 3), the
  scream's end never respawned the player, the music never restarted and `WM_DESTROY` left the
  waves and MCI open. It now dispatches through the scene.
- **J7's fix lost every result.** `jardim_variant_hello` stopped the FindWindow posts but left
  the hello to AppWndProc's 0x40b case, which never runs once `WM_CREATE` has run: every message
  goes to `game_handle_message` first, whose labyrinth scene answers 1 for 0x40b and 0x40a. So
  `g_noiteWnd` stayed 0 and the result went nowhere: in the Corrigida NOITE found the window gone
  and reported a loss with no score, a win included. The fix now also lets 0x40b and 0x40a reach
  their cases. (The same swallowing is the original's: it is part of J7.)
- **The enemies never animated.** `animation.nextFrame`/`prevFrame` took the SceneObject defaults
  (`scene_object_next_frame_default` 10c0:38ea, `_prev_` 10c0:393a) for the empty stubs they are in
  NOITE and TIRO; in JARDIM they are the 79-byte wraps of `animation_next_frame` (as SAUNA's). So
  the enemies stayed on frame 0: they stepped a cell on every frame they were drawn (about 38 cells
  a second), never reached their attack frame, and the crossbow's and bazooka's firing pose never
  showed. They now wrap; every JARDIM script was planned again.

### The launch from NOITE

Two scenes launch it (`src/handlers/espquete.zig`, `src/handlers/4fjarvamp.zig`, as ported):
- `handler_espquete`, the garden cutscene: at the video's end (`MM_MCINOTIFY`, 19665 into
  `--scene espquete`) `WinExec("<CD>jardim\jardim.exe")` and timer 0x14 (100 ms), whose tick
  posts **0x40b with variant 1** once `FindWindow("Noite Animal Jardim")` succeeds;
- `handler_4fjarvamp`, the vampire's garden: the same at the scene start (0x401), **variant 0**.

The host matches `jardim` to `jardim.program` and starts the task `--minigame-startup` ms later
(1500; its WinMain: `app.start`, after `init_static_conditions` as `_cinit` runs it): WM_CREATE
at 21165 from `espquete`, 1500 from `4fjarvamp`. JARDIM's AppWndProc (unlike TIRO's) does not
wait for the hello: at the top of **every** message, while `g_noiteWnd` is 0 it calls
`FindWindow("Noite Animal")` (task 0's title) and posts **0x40c** (wParam its window) to what it
found; then, until `g_noiteAcked`, it posts 0x40c again on every message; timer 10 (50 ms)
retries the FindWindow. Once `WM_CREATE` has run, 0x40b and 0x40a go to `game_handle_message`
first and are swallowed (BUGS.md J7): the variant stays 0 and the ack is never seen. So, in the
Original:
- `espquete` takes JARDIM's first 0x40c (queued inside CreateWindow, before NOITE's timer can find
  the window) as the reply: it kills timer 0x14, hides itself and acks to window 0; the hello is
  never sent. JARDIM re-posts 0x40c on every message, each a no-op for NOITE. Final enemy `vamanf`.
- `4fjarvamp` ignores a 0x40c while it does not know JARDIM's window; its timer finds it and posts
  the hello (swallowed) and, from then on, answers every 0x40c with an ack (swallowed, so JARDIM
  posts 0x40c again): the two tasks bounce messages for the whole game. Windows keeps running
  (its clock moves and timers fire when a queue is momentarily empty); the port's headless loop
  moves its clock 1 ms per `main.busy_messages` (64) messages at one tick with a message from
  another task among them, and the web loop gives the page its frame back as soon (a busy loop
  otherwise freezes the virtual clock: "message storm"). The 8-message queues stay full, posts
  fail, and JARDIM's result is lost; NOITE's `WM_SYSTIMER` then finds the window gone and posts
  itself a loss with no score: game over, whatever JARDIM's result (BUGS.md J7).
With `jardim_variant_hello` JARDIM posts nothing until the hello, which `espquete`'s and
`4fjarvamp`'s timers send every 100 ms (neither kills its timer when the 0x40c follows the
hello): JARDIM stores the variant and NOITE's window and answers 0x40c, NOITE acks, JARDIM stops.

**The result.** The win (touching phase 3's goal) posts JARDIM's own `WM_DESTROY` with
wParam 0xffff; a loss (lives 0, at an enemy's attack or a touch) posts it with 0. The phase
handler stops and frees the waves, closes WaveMix and `close musica`, and the backdrop's case
posts **0x40a** to `g_noiteWnd` (won: wParam 1, lParam score + the J1 bonus; lost: wParam 0,
score − 1000); AppWndProc kills timer 10 and posts WM_QUIT, which comes after the posted
messages (`core/queue.zig`), so the further `WM_DESTROY`s of a loss post their 0x40a too (lost
−2000 in `jardim-alone-lose.input`). The host then runs `app.exit`, destroys the window and
activates NOITE, which shows itself, adds the first result's score and goes to `6fsai1`
(espquete won), `6fsai2` (4fjarvamp won) or `6fsaida` (lost; no life is taken); the second report
finds `6fsaida` and is ignored. ESC quits JARDIM without a result (`PostQuitMessage` from the
backdrop): NOITE's `WM_SYSTIMER` check finds the window gone and posts itself a loss with no score
change; closing the window is a loss with −1000. `--minigame-stub` (or `--minigame-stub=jardim`)
keeps the stub.

### Standalone

- `noite --minigame jardim [--headless …]`: JARDIM alone (task 0, its title, `\JARDIM`); its
  FindWindow("Noite Animal") fails on every message (nothing is posted), the variant stays 0;
  the result (0x40a to window 0) is recorded and printed by the host.
- Web: `web_main.minigames` has JARDIM as `noite_start`'s minigame 9 (after SAUNA), `MINIGAMES` in
  `web/noite.js` ("Noite Animal Jardim") and the "Jogo" select an entry ("Jogar só o minijogo:
  Jardim"); `tools/web/files.py` `MINIGAMES` `"jardim"` finds its names in `JARDIM\` (`DOOM.MID`
  at the root). **The touch pad** (one-button mode, or a minigame alone on a touch screen;
  `PAD_KEYS` follows the program on top), the owner's: the four arrows (turn, walk), SPACE in the
  centre relabelled "Abrir" (a door; `PAD_LABELS`), CTRL bottom right ("Tiro", fire): `PAD_KEYS.jardim
  = [37, 38, 39, 40, 32, 17]`, `#dpad [data-key="17"] { grid-area: 3 / 3; }`. Running (SHIFT) and
  strafing (CAPS LOCK held) are left out.

### The harness, smoke and full.input

- Script keys: `key`/`hold` take `ctrl` (0x11), `shift` (0x10) and `capslock` (0x14); `hold
  shift 3000` with `hold up 3000` runs. The scripts walk with `hold KEY 1` presses: a press with no
  tick while the key is down is one 16-unit step or one 48-unit turn (`key` holds 50 ms, over a
  tick or two). The Corrigida's scripts hold `w`, `s`, `a`, `d`, `left`, `right` (with `shift`)
  for as long as the move takes (the motion step polls the keys every 14 ms) and press `e` and
  `space`; their first line takes the controls screen down (`key return`).
- `tools/smoke.py --minigame jardim [--fix all] [--monkey SEED]`: random presses and holds of the
  arrows, CTRL and SPACE (with `--fix all`: Enter first for the controls screen, and W, A, S, D and
  E too), some under a held SHIFT or CAPS LOCK (no ESC), 60 s: no panic but an
  "orig" one (J5, a latent entry), no leak; a result or none (a monkey seldom wins or loses in
  60 s). The scene smoke starts JARDIM from `espquete` (after its 19.7-s video: not within the 6-s
  run) and from `4fjarvamp` (at 1.5 s; the Original's ping-pong runs on).
- `full.input` and `onebutton.input` reach `espquete` and keep the stub there
  (`--minigame-stub=jardim`, Decisions).

## Platform

What JARDIM needed that the other minigames did not (on main, outside the tracker):
- **Keys.** The minigame task gets VK_CONTROL (0x11, fire), VK_SHIFT (0x10) and VK_CAPITAL
  (0x14) as WM_KEYDOWN/WM_KEYUP, besides the arrows, Space, Enter and Esc: SDL (LCTRL/RCTRL,
  LSHIFT/RSHIFT, CAPSLOCK), the web page (`GAME_KEYS` 16, 17, 20; `web.Key`) and the script's
  names; `Sim.filterInput` passes them to a minigame and drops them for NOITE (`minigame_keys`:
  NOITE ignores them). The Corrigida's keys add W (0x57) and E (0x45) to the fights' A, S, D, F:
  SDL's letters, `GAME_KEYS` 87 and 69, `web.Key` `w`/`e`, the script's `w`/`e` (NOITE gets them
  and ignores them, as the fights' letters).
- **`GetKeyState`** is the task queue's synchronous key state, `Queue.keyState(vk)` (bit 15:
  down, bit 0: toggled), as of the key messages the queue has handed out (Windows' rule), so it
  is the same in SDL, the web and headless runs. JARDIM reads SHIFT (run) on the tick and CAPS LOCK
  **held down** (`< 0`, strafe) on the turn keys (`labyrinth_input.keyHeld`). The Caps Lock key's
  events: some systems (macOS, some browsers) report only the toggles (down on the first press, up
  on the second); then strafing needs Caps Lock locked, an accepted difference.
- **Repeats.** The backdrop latches each key (`g_keyLeftDown` …): a repeat only records
  `g_keyAltContext`; the 55-ms tick drives held keys. The `Sim` repeat generator needs nothing.
- **Timers.** The game tick is `WM_SYSTIMER` from system timer 1 (55 ms) **and** from timer 10
  (50 ms, AppWndProc's FindWindow retry): the backdrop does not check the id, so the game ticks
  about 38 times a second (the queue's exact periods). In Windows 3.1 both fire on the 55-ms
  hardware tick (36 a second, in pairs). The port keeps the queue's exact periods (the owner's
  decision); J8's fix (Corrigida) ticks on timer 1 only, and the Corrigida's motion timer (id 0x57,
  14 ms) counts Wolf3D's tics against the clock, so its speed depends on no period.
- **Frame cost** (the owner's decision, both versions; platform emulation, not a `Fixes` flag).
  On a 1995 PC each game tick drew the whole raycast view, and Windows 3.1 makes a timer's
  message only when the queue is empty, never queuing the periods missed: a frame slower than the
  timer lowered the tick rate, and 1995 footage shows slow enemies. The port draws at once. So
  after a tick (`labyrinth_input.handleMessage`, `frameCost`) the two timers that tick the game
  (1 and 10) give no message for `render_cost_ms` (`core/game.zig`, **100 ms**: a 486DX2-66 drawing
  the 480×300 view at ~10 frames a second; tune it there, e.g. against a video), through
  `Queue.postpone`: one message when free, as Windows coalesces. J8 stays in the Original (both
  timers tick, whichever is due first), but with a cost above 50 ms the rate is 1/cost either
  way: 10 ticks a second. Not charged: the frame a key press draws (it is not a timer's) and the
  Corrigida's motion frames (view only, modern drawing); the Corrigida's enemies use the same cost
  through the tick, so they move as the Original's. Measured (headless, one copy of an enemy in
  view, standing still): one cell per F ticks, F the enemy's frames, i.e. 2 cells a second for a
  Seios (F 5, and 2 health a second), 2.5 for Bussuf and Siri (F 4), 3.3 for Bicho (3), 5 for
  Alemão and Chato (2); several copies of a kind in view share its frame and step that much
  faster (the original's rule). The Original's held keys: walk 24 units a tick (7.5 cells a
  second, plus the coast after the release), run 64 (20 cells a second), turn 48 a tick (≈ 63° a
  second with the press, 120 with Shift); a press is still one step or turn at once.
- **A busy ping-pong moves the clock** (`main.busy_messages`, above): only the Original's
  `4fjarvamp` does it.

## Tests

- **Planning.** The 1995 routes were planned against the port with a temporary probe (not
  committed): a build printing JARDIM's state on every game tick (position, angle, health, lives,
  ammo, level, score, weapon, shot, variant) and the object and wall map when it changes, driven
  by a closed-loop planner: each step re-runs the script so far and reads the end state; a BFS
  over the current walls and objects (enemies and the cells next to them are obstacles; a bra or
  bazooka too while the crossbow is held) gives the path; the planner picks up a crossbow first,
  detours to a medkit within 14 cells when health is under 45, shoots (after turning to the axis)
  the first shootable enemy in a clear line ahead within 7 cells (not the Original's Chato: J2
  keeps him), opens a door on the way, takes the exit doors and in phase 3 walks into the final
  enemy wherever it has moved. The 1995 controls: presses only (48-unit turns, 15-unit steps
  along the axes, 30 ms apart; CTRL, SPACE); the loss walks into the nearest Seios. Planned with
  the enemies' animation fixed and the frame cost in place, so the enemies animate, attack at
  range per drawn copy and step one cell per animation cycle. The Corrigida's routes come from the
  committed planner (below).
- **Scripts** (`tools/play/`). The 1995 controls, each Original and with every bug fix on the 1995
  controls (`--fix all` less `jardim_smooth_movement`, `jardim_wolf_keys`,
  `jardim_controls_screen`, `jardim_game_timer_only`, `jardim_wall_margin`):
  - `jardim-alone-win.input` (`--minigame jardim --ms 75000`): the three phases (phase 2 at
    25.3 s, phase 3 at 40.4 s), the goal touched at 72250 (lives 2, 1500 points):
    `result won 19370 | won 15340` (J1);
  - `jardim-alone-lose.input` (`--ms 9000`): the last presses walk into a Seios, each a life
    (J6): lost at 7430, reported four times (−4000 checked); with J6's fix no result;
  - `jardim-espquete-win.input` (`--scene espquete --ms 96000`): the alone win shifted to 21165,
    `won 19370 | won 15340`, NOITE goes to `6fsai1`;
  - `jardim-espquete-lose.input` (`--ms 32000`): the alone loss shifted, `6fsaida` (with J6's fix
    no result: NOITE stays in `espquete`);
  - `jardim-4fjarvamp-win.input` (`--scene 4fjarvamp --ms 76000`): the alone win from 1500; the
    Original's result is lost in the ping-pong (`6fsaida`, J7), the fixed run's reaches NOITE
    (`6fsai2`).
  The Corrigida (`--fix all`, the fair enemies; planned by `tools/jardim_plan.py`, below):
  - `jardim-corrigida-alone-win.input` (`--ms 132000`): Enter at 300, phase 2 at 39.2 s, phase 3
    at 77.4 s, 11 enemies shot on the way (2 Bussufs, 5 Alemaos, 3 Chatos, a Bicho), the final
    enemy at 129547 (lives 3, 3200 points): `won 10937`;
  - `jardim-corrigida-alone-lose.input` (`--ms 77000`): towards the Seios of column 38, faced from
    within 4 cells; health stays 100 % until it stands next to the player (`pixel 395 415 251` at
    11400, the HUD's "1"; its first blow at 11730: 90 %, `pixel … 10` at 11900); three lives to
    it and two more enemies: lost at 76130, −2000;
  - `jardim-corrigida-idle.input` (`--ms 61000`): standing at phase 1's start for a minute, the
    window closed: `lost -1000` (no life lost), with and without the fair enemies;
  - `jardim-corrigida-espquete-win.input` / `-lose` and `jardim-corrigida-4fjarvamp-win.input`: the
    same shifted to 21165 and 1500; J7's check: the goal is `espanf` after `espquete`
    (`pixel 262 250 228` at 150625) and `vamanf` after `4fjarvamp` (231 at the same moment);
  - `jardim-controls.input` (`--ms 7500`): the controls screen up until Enter (its frame's pixel),
    then ← to north, W 1 s, D (strafe east), → twice, Shift+W back: the minimap marker's pixels
    after each move.
  - `jardim-close.input` (`--ms 3000`), both versions: the window closed at 2 s (in the Corrigida
    with the controls screen up), `lost -1000`.
  JARDIM has no randomness (the fair enemies' reaction times use the CRT's rand(), never
  seeded): the plans depend only on the key times relative to its WM_CREATE (its timers run from
  there), so a script moves with JARDIM's start time by a shift.
- **The Corrigida's planner** (`tools/jardim_plan.py`, committed): the fair enemies react to where
  the player is, so it asks the port. `zig build -Djardim-probe --prefix zig-out/probe` builds the
  probe: the fair enemies' log on every tick from the start (the player, every enemy's cell and
  state) and the map's objects and closed doors when they change, and no drawing (the motion
  frames and, with the fair enemies, the tick's frames change no state): about 2 s for 130 s of
  play. `--win` crosses the three phases (a crossbow first; an enemy the weapon kills, chasing or
  near, shot when within 7 cells in a clear line; a BFS around the rest; a medkit under 55 health;
  arrows or a crossbow when ammunition is low; doors and exit doors with E; the goal walked
  into), `--lose` walks to the nearest Seios and stands facing it once one is within 4 cells.
  Runs of at most 4 cells, A/D to centre across a run, re-planned after each move (about 170
  probes for the win).
- **Measured** (headless, the probe, `jardim-controls.input`'s moves): the Corrigida walks 178.7
  units a second (5.59 cells; Wolf3D 5.61), runs 358 (11.2; 11.2), backs 119 (3.72; 3.74),
  strafes 179 (5.59), turns 980 angle units a second (122.5°; 122.5°), 1960 running (245°).
- **Smoke**: `tools/smoke.py --minigame jardim` (above).
- **Web**: `tools/web/test.py` plays "Jogo" = Jardim: JARDIM starts, a held Up moves the
  minimap's square and a held Ctrl punches; on a touch screen the pad shows the arrows, Abrir and
  Tiro, and a held ▲ walks. In the Corrigida: the controls screen (the key that takes it down does
  not walk), a held W walks, A strafes, Space punches; on a phone the Corrigida pad, a tap takes
  the screen down and a held ▲ walks.
- **Unit tests**: the six 32-bit routines and the tables (`oracle=emulated`), `Queue.keyState`,
  `wolf.zig` (the speeds in JARDIM's units, the box), `controls.zig` (the screen keeps the game,
  the key translation), `enemies.zig` (the tuning, the line of sight), the per-pixel wall blit
  against the 1995 blit's rows (`scaled.zig`), `renderView` with `jardim_texture_per_pixel`.

## Units

29 units, 399 functions to port; 113 dead, 402 absorbed (276 thunks, 86 defaults, 40 type
tests), 246 replaced (153 CRT, the FP library included: `sin`, `cos`, `tan`, `fabs`, `_ftol`,
`_trandisp1/2` and the 26 unnamed 8087 entries of 10b8:2f87–4b37, replaced by the precomputed
tables; 93 imports). Hard deps are direct calls into another unit (`noite -p jardim next
--blocked`); virtual calls are soft (`unit dep show`). Level = the longest chain of hard deps
below the unit: the units of one level can run in parallel once the levels below are done.

| Level | Unit | Fns | Size | Calls into |
|---|---|---|---|---|
| 0 | `dib` | 9 | 4.5 KB | — |
| 0 | `position` | 34 | 1.8 KB | — |
| 0 | `scaled` | 4 | 2.0 KB | — |
| 0 | `sound` | 9 | 0.9 KB | — |
| 0 | `tables` | 2 | 1.2 KB | — |
| 1 | `backdrop` | 12 | 2.6 KB | dib, position |
| 1 | `labmap` | 4 | 0.7 KB | position |
| 1 | `render` | 20 | 4.0 KB | dib, position |
| 1 | `space3d` | 33 | 5.9 KB | position |
| 2 | `animation` | 33 | 4.8 KB | position, render |
| 2 | `hud` | 9 | 1.7 KB | dib, position, render |
| 2 | `lists` | 16 | 3.0 KB | position, render |
| 2 | `occupancy` | 16 | 2.0 KB | position, render |
| 2 | `sprites` | 6 | 2.9 KB | labmap, position, scaled |
| 3 | `movement` | 19 | 4.2 KB | animation, backdrop, position, render |
| 3 | `object_create` | 37 | 7.6 KB | dib, lists, position |
| 3 | `panels` | 10 | 1.1 KB | animation, dib, lists, position |
| 3 | `raycast` | 9 | 2.9 KB | position, scaled, sprites |
| 4 | `labyrinth` | 7 | 4.9 KB | backdrop, dib, hud, labmap, raycast, render, sprites, tables |
| 4 | `scene` | 20 | 1.6 KB | backdrop, lists, object_create |
| 4 | `visibility` | 16 | 2.4 KB | lists, panels, position, render |
| 5 | `labyrinth_input` | 2 | 7.4 KB | hud, labyrinth, position, raycast, sprites |
| 5 | `labyrinth_scene` | 10 | 1.4 KB | labyrinth, scene, sound |
| 6 | `game` | 18 | 3.0 KB | labyrinth_scene, lists, object_create, occupancy, scene |
| 6 | `phase1` | 11 | 12.6 KB | labmap, labyrinth, labyrinth_scene, object_create, position, sound |
| 6 | `phase2` | 11 | 15.3 KB | labmap, labyrinth, labyrinth_scene, object_create, position, sound |
| 6 | `phase3` | 10 | 10.5 KB | labmap, labyrinth, labyrinth_scene, object_create, position, sound |
| 7 | `app` | 9 | 1.6 KB | backdrop, dib, game |
| 7 | `game_input` | 3 | 6.9 KB | game, lists, movement, position, render, space3d |

Ready first (parallel): `dib`, `position`, `scaled`, `sound`, `tables`; then `backdrop`,
`labmap`, `render`, `space3d`; then `animation`, `hud`, `lists`, `occupancy`, `sprites`; then
`movement`, `object_create`, `panels`, `raycast`; then `labyrinth`, `scene`, `visibility`;
then `labyrinth_input`, `labyrinth_scene`; then `game`, `phase1`, `phase2`, `phase3`; then
`app`, `game_input`. The largest single functions: `phase2_scene_place_objects` (8.5 KB, a list
of placements), `phase1_scene_place_objects` (6.3 KB), `labyrinth_backdrop_handle_message`
(6.2 KB, `labyrinth_input`), `game_handle_message` (5.9 KB, `game_input`).

Placement choices that keep the call graph acyclic: `labyrinth_place_object`/`remove_object` are
in `labmap` (the sprites move enemies between cells, and the frame calls the sprites); the
phases' ctors and `createScreen` are in `labyrinth_scene` (phase 1's `createNewScene` builds a
Phase2Scene: with the ctors in the phase units the phases would form a chain); the panel's texts
are drawn in `render`, `object_list_delete_all` (it deletes objects) is in `object_create`,
`exit_has_key_object` in `animation`, `portable_draw_icon` in `panels`;
`message_box_printf` is in `position` (the lowest unit that calls it).

## Tracker

`noite -p jardim …` (or `NOITE_PROGRAM=jardim`): DB `db/jardim.sqlite` (local; `noite -p jardim
import` rebuilds it from Ghidra and the plan), plan `db/jardim-plan.tsv` (committed), tree
`src/jardim/`, index `src/jardim/units.zig`, worktrees `work/jardim-<unit>/` on branches
`port/jardim-<unit>`. A worktree's `.ref/env.sh` sets `NOITE_PROGRAM`, so `noite test`/`check`
there need no `-p`. The program's layout (`tools/cli/src/noite/program.py` `JARDIM`): CRT `10b8`,
imports `10e8`, DGROUP `10d0`, far 4-byte vtable slots, virtual calls `CALLF [BX+off]`. The
non-SceneObject slot owners are `docs/jardim/SLOTS.tsv`.

```
noite -p jardim next [--blocked]      # units ready to claim
noite -p jardim start <unit>          # worktree work/jardim-<unit>/
noite -p jardim show <addr|name>      # row, decompile (--asm), callers/callees
noite -p jardim unit show <unit>
noite -p jardim check -w <unit>       # @orig tags vs JARDIM's DB
noite -p jardim initdata -w <unit>    # `// @orig g_*` defaults vs JARDIM's DGROUP
noite -p jardim finish <unit>         # from the main checkout
noite -p jardim failed <unit> "why" / release <unit>
```

## How to port a JARDIM unit

1. `noite -p jardim next`, `noite -p jardim start <unit>`, then work in `work/jardim-<unit>/`
   (`. .ref/env.sh`; tools via `nix develop -c`). Scratch output, listings and frame dumps go in
   the worktree's `zig-out/`, never `/tmp`.
2. Read the unit's `.ref/*.c` (plate, decompile, disassembly), `.ref/types.md`,
   `.ref/strings.md`; GAME.md / DATA.md for the rules and the class. Ghidra
   (`mcp__ghidra__*`, `program="JARDIM.EXE"`) for anything else. For `1000–1018` the `.ref`
   listing is garbage: use objdump ("The 32-bit routines").
3. Read the twin: TIRO's unit of the same name (`src/tiro/<unit>.zig`) for the engine code,
   NOITE's for the classes and slots TIRO lacks; JARDIM's offsets are NOITE's. Transcribe each
   JARDIM function from JARDIM's own decompile/asm, reusing the twin's Zig where they agree; note
   in the commit body every function whose code differs from the twin's (and how). Never call a
   TIRO or NOITE unit, except the state-free delegation of Decisions.
4. Write only your unit's file (and, for `tables`, `raycast`, `scaled`: their generated data and
   generator, `src/jardim/tables.bin`, `src/jardim/testdata/`, `tools/…`): replace each declared
   dispatcher's body, keep its signature; one `// @orig <seg:off> <ghidra_name>` per function
   (JARDIM addresses; `(absorbed)` for the defaults and thunks an arm covers). Public names: the
   Ghidra name minus the unit's class prefix, camelCase (`sprite_queue_insert` in `sprites` →
   `sprites.insert`). A field missing from `core/` is added there with its `@orig` offset.
5. Faithful first: port each J-bug as the code does it and put the fix only behind its flag
   (`g.fixes.jardim_…`, table above). NOITE's conventions hold (`i16`/`i32` with wrapping where
   the original overflows, `cstr`, `?*T`, message boxes through `plat.messageBox`, every
   PostMessage/SendMessage/SetSystemTimer at the same point, `error.Fatal` only where the original
   ends). Allocate what the original `new`s or `_fmalloc`s from `g.local()`.
6. Call other units' dispatchers and the `Scene` wrappers, never a local copy. If a declared
   signature cannot express the original, `noite -p jardim failed <unit> "slot <name> (<owner>)
   needs …"`.
7. Tests: required for the 32-bit routines and the tables (`oracle=emulated`), optional elsewhere
   (`oracle=emulated` from tools/oracle, `asset` from `assets/JARDIM/`, `documented` from Ghidra).
8. `noite test`, commit (commit skill), `noite -p jardim finish <unit>` from the main checkout.

