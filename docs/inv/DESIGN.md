# Native port of INV.EXE — design

INV.EXE ("Invasores", window and class "Invasores", the Space Invaders
minigame of the flying-saucer scene) in Zig, next to NOITE's, ENCAIXE's
and TIRO's ports. NOITE's `docs/DESIGN.md`, TIRO's `docs/tiro/DESIGN.md`
and the zig-developer skill hold for everything this file does not
override. Ghidra (program `INV.EXE`, through the tracker snapshot `noite
-p inv show`) is the specification; `GAME.md` (rules, protocol),
`DATA.md` (classes, vtables, globals), `FUNCTIONS.md` (names, dead code,
the engine functions that differ from TIRO), `QUALITY.md` (the medium /Od
build), BUGS.md I1–I2 and its INV Harmless list.

## Decisions

- **Own tree, TIRO's Zig as the template.** INV is TIRO's build one
  engine revision later (QUALITY.md §0): the same toolchain and options
  (medium model, `/Od`, stack probes), the same 19 segments, the same
  engine classes and vtables slot for slot (FUNCTIONS.md: 588 functions
  pair 1:1 with TIRO's, every engine table matches a TIRO table). TIRO is
  now ported (`src/tiro/`), so every engine unit has a checked Zig twin.
  But the two builds are not the same program:
  - 11 engine bodies differ (table below), among them the base
    `restoreBackground` (a transparent copy, TIRO's is opaque),
    `backdrop_create` (no static colours), `animation_set_strip` and
    `scene_object_hide_and_invalidate` (a direct `blitToDc` on a DC of
    their own, TIRO's the virtual `invalidate`), `slot24` (no palette
    selection), `wave_play` (flags 7 without a notify window) and
    AppWndProc (no wave on WM_PAINT); `dib_copy_rect` and
    `backdrop_set_static_colors` are dead here;
  - the game is other classes: Cannon (← Player2D), Saucer, Missile →
    Bomb / Shot, InvaderColumn and InvaderExplosion (← Actor2D), three new
    vtable kinds (SaucerVtbl, MissileVtbl, InvaderVtbl), five own type
    tests in SceneObject slots 56–5A (TIRO's three there are base
    defaults here), and InvGame/InvScene/InvPanel/InvBackdrop in TIRO's
    Tiro* roles;
  - INV has no `srand`/`rand`: nothing in it is random.

  So INV gets its own units under `src/inv/`, ported from its own
  functions with its own `@orig` addresses, and it calls neither TIRO's
  nor ENCAIXE's units. **Sharing TIRO's units was weighed and rejected,
  for TIRO's own reasons against sharing ENCAIXE's:**
  - every engine function takes TIRO's `Game`/`Object`/`Backdrop`;
    sharing means making 20 finished, checked TIRO units generic over the
    program (comptime `Game`/`Object`, kinds, the globals), which changes
    TIRO's code for INV's sake (and SALGIN's, XILINDRO's and SERIAL's,
    the other medium twins designed at the same time);
  - an `@orig` tag maps to one program's address and `noite finish`
    refuses a unit that edits another program's tree: a shared function
    needs two tags and a tracker that checks one file against two DBs,
    and an INV unit could not land a fix in it;
  - where the builds differ (the 11 bodies) a shared body carries
    `if (inv)` branches; a copy keeps each port a plain transcription of
    its binary.

  The copy is cheap: for every engine function the TIRO unit of the same
  name holds the ported Zig of the same source (same names, same
  signatures, same struct offsets; the INV skeleton's dispatchers are
  TIRO's, signature for signature). An INV agent transcribes each
  function from INV's decompile/asm, reuses TIRO's Zig where the two
  agree (the plates say "same-source body" or name the difference), and
  says in its commit body which functions differ from TIRO's and how.
  Where FUNCTIONS.md says an INV body equals SALGIN's or XILINDRO's
  (AppWndProc, `wave_play`) and that sibling is ported first, its Zig is
  the closer template.
- **Shared, because identical or not game code:** the platform layer
  (`src/platform/`, host included), `core/msg.zig`, `core/queue.zig`,
  `core/cstr.zig`, `core/stub.zig`, `core/errors.zig`, `core/fixes.zig`
  (one `Fixes`, I-flags prefixed `inv_`), the Win16 data types (`Dib`,
  `BitmapInfoHeader`, `RgbQuad`, `Rect`). Segment 1000 is byte-identical
  to NOITE's and TIRO's: INV's `dib.rowsCopy32`/`rowsCopyTransparent32`
  (tagged 1000:0114 / 1000:0024) call NOITE's `src/dib.zig`, as TIRO's
  do; segment 1010 (DIB load) is byte-identical to TIRO's. An INV
  function may delegate to a NOITE, ENCAIXE or TIRO function only when
  that function takes no program state (in practice the `dib` copies and
  `read_dib_info`) and the two decompiles are shown identical in the
  unit's commit; the INV wrapper carries INV's `@orig` tag.
- **Faithful first, the owner's rule.** I1 and I2 are reproduced as they
  are by default; each fix exists only behind its own `Fixes` flag (off
  by default). Corrigida (`Fixes.all()`) takes both (owner question 1).
  The Harmless items get no flag (Fixes, below).
- **Two programs in one process**, as ENCAIXE and TIRO
  (`src/platform/host.zig`, docs/encaixe/DESIGN.md "Running two
  programs"): INV is a task with its own state, queue, timers, window and
  screen; the protocol runs through the platform as in Windows. The host
  needs nothing new for INV (Platform, below).
- **The local heap**, as TIRO's: `Game.local()` is the task's local heap
  (an arena freed by `Game.destroy`); every `operator new` / `_nmalloc`
  allocates there, so the original's never-freed objects and strips are
  not a leak of the port.
- **The playthroughs stay on their route** (the owner's decision).
  `full.input` and `onebutton.input` take the sportsman's route at
  `4fbar` and never the esoteric's detour (`4fsacaet`, INV, `4fmarte2`,
  the `ESOTEBOY` cutscene). INV is tested by its own scripts only
  (`inv-*.input`, alone and from `--scene 4fsacaet`).
- **The touch pad** (the owner's decision): ◀, a fire button (SPACE)
  and ▶ (`PAD_KEYS.inv`).

## Source layout

```
src/inv/root.zig          program root: core, units, `ready`, `program` (host.Program)
src/inv/core/             types only (not units)
  game.zig                Game: InvGame + every INV DGROUP global; queue, send/post, timers, local heap
  object.zig              Object (8 kinds), parts, InvaderCell, Frame, ObjectList
  world.zig               Scene, Backdrop (one bitmap), OccupancyGrid + Occupancy, DrawList, UpdateList, Condition
src/inv/<unit>.zig        module units
src/inv/behaviour/        behaviour units (one group of SceneObject slots)
src/inv/units.zig         generated index (`noite -p inv unit sync`)
```

## Object model

As TIRO's (one `Object`, a `kind`, every part present), with INV's
classes. Eight kinds are constructed:

| Kind | Class (vtables) | Parts live |
|---|---|---|
| `cannon` | Cannon ← Player2D ← Actor2D ← Mover + Animation (1876, 187a, 187e) | base, mover, anim, player2d, cannon |
| `saucer` | Saucer ← Actor2D (SaucerVtbl 1dba, 1dca, 1dce) | base, mover, anim, saucer |
| `bomb` | Bomb ← Missile ← Actor2D (MissileVtbl 20c6, 20d2, 20d6) | base, mover, anim, missile |
| `shot` | Shot ← Missile ← Actor2D (MissileVtbl 224a, 2256, 225a) | base, mover, anim, missile |
| `invader_column` | InvaderColumn ← Actor2D (InvaderVtbl 2552, 255e, 2562) | base, mover, anim, invader (cells) |
| `invader_explosion` | InvaderExplosion ← Actor2D (InvaderVtbl 23ce, 23da, 23de) | base, mover, anim, invader (frameCounter) |
| `control_panel` | InvPanel ← ControlPanel ← Animated3D ← Animation + Object3D (0fc4, 0fe8, 1154) | base, o3d, anim, panel |
| `status_bar` | StatusBar (170a) | base, status |

`Object.is/as` are the type-test slots 3A–4B, 52/53 and INV's own 56
(`isShot`), 57 (`isInvader`: column and explosion), 58 (`isSaucer`), 59
(`isCannon`), 5A (`isBomb`); `missile_can_step` sorts a blocker with them
into `Missile.hitState`. Bomb and Shot share every override (Missile's)
and differ only by their type test, so they are two kinds of one part.
The explosion shares the column's overrides but `restoreBackground` and
`draw` and carries the column's fields unused (`lowestAlive` −1), so the
two share the `invader` part (`cells` the column's, `frameCounter` the
explosion's). Mover, Animation, Actor2D, Player2D, Missile, Animated3D,
Moveable, Portable, Actor, Player, Exit and PerspectiveBackdrop are never
constructed on their own: their methods no live table reaches are `dead`
in the plan, but `portable_pick_up/drop/draw_icon` are called from live
code (`game_input`) and keep the `portable` part. Struct origins are
`// @orig Struct+0xNN` with INV's offsets (DATA.md); the vtordisp words and
the virtual bases have no counterpart.

The game objects are DGROUP pointers: `g.cannon` (the player, also
`Game.player`), `g.saucer`, `g.shots[0]`, `g.bombs[0..1]`,
`g.invaderColumns[0..3]`, `g.invaderExplosion`. A method that overrides a
SceneObject slot gets the SceneObject subobject in the original and reads
its class at negative offsets (Cannon −0x4c, Saucer −0x52, Missile −0x4e,
column −0x72, explosion −0x78; DATA.md "Vtables and classes"): in the port
that is just `obj`. `Missile.hitState` is never initialised in the
original (LocalAlloc does not clear): the port's field starts at 0, a run
of the original whose garbage is no '1'–'4' (BUGS.md, INV Harmless).

## Virtual slots

As TIRO's: each slot is one `pub fn` dispatcher (named after the vtable
field) in the unit that owns it, already declared in the skeleton with
its final signature (TIRO's) and a `stub.unported` body; it switches on
`obj.kind` and calls one function per original implementation, each
tagged `@orig`. The default stub is the `else` arm. Thunks (449), defaults
(69) and type tests (45) are `absorbed`. Signatures: `(g: *Game, obj:
*Object, <args in source order>)`; hwnd and hdc parameters are dropped;
`Backdrop *` stays. Flattened single-class tables are plain functions:
Game (`game`, `game_input`), Scene (`scene`, `invasion`), Backdrop
(`backdrop`), ControlPanel (`panels`), Saucer (`saucer`), Missile
(`missiles`), Invader (`invaders`), Condition (`game`), Frame
(`object_create`).

A class's override of a SceneObject slot lives in the slot's unit, next
to its dispatcher: the Cannon's `canStep` and the Missile's and the
column's in `occupancy`, the Saucer's, the Missile's and the column's
`stopMoving(Dc)` and `moveTick` in `movement` (the column's right-edge
descent and landing with them), the column's and the explosion's
`restoreBackground`/`draw` in `render`, `cannon_blit_to_dc` in
`visibility`, `cannon_play`/`cannon_tick` in `animation`. The class
units (`invaders`, `saucer`, `missiles`) hold what is not a SceneObject
slot.

**One move from TIRO's plan: `mover_place_at` (Mover `placeAt`, slot 0
of every Mover-derived table) is in `occupancy`, not `movement`.**
`cannon_can_step` (occupancy) calls it, and `missile_move_step` and
`invader_column_move_tick` (movement) call `missile_can_step` and
`invader_column_can_step` (occupancy): with `placeAt` in `movement` the
two units would need each other. In `occupancy` (vacate, set position,
restore, occupy, draw: it is a re-occupation) the edge goes one way. For
the same reason `invader_column_init_cells` and `invader_column_set_cell`
(the ctor's and the column tick's cell writes) are in `object_create`.

### SceneObject slots (kinds: cannon, saucer, bomb, shot, column = invader_column, explosion = invader_explosion, panel = control_panel, status = status_bar)

INV's slot numbers (byte offset = 4 × slot) are TIRO's, slot for slot,
and the owners are TIRO's; field names are TIRO's (ENCAIXE's), so the
Ghidra field names of 56–5A are still TIRO's (`isProjectile`, `slot62`,
`isTarget`, `isCrossbow`, `slot65`) for INV's `isShot`, `isInvader`,
`isSaucer`, `isCannon`, `isBomb`. Generated from the tracker's vtables
(thunks resolved).

| slot | behaviour | unit | default | overrides (impl: kinds) |
|---|---|---|---|---|
| 00 | getWorldX | space3d | scene_object_get_world_x_default | object3d_get_world_x: panel |
| 01 | getWorldDepth | space3d | scene_object_get_world_depth_default | object3d_get_world_depth: panel |
| 02 | getWorldElev | space3d | scene_object_get_world_elev_default | object3d_get_world_elev: panel |
| 03 | getSizeW | space3d | scene_object_get_size_w_default | object3d_get_size_w: panel |
| 04 | getSizeH | space3d | scene_object_get_size_h_default | object3d_get_size_h: panel |
| 05 | getSizeD | space3d | scene_object_get_size_d_default | object3d_get_size_d: panel |
| 06 | getAnchorX | space3d | scene_object_get_anchor_x_default | object3d_get_anchor_x: panel |
| 07 | getAnchorY | space3d | scene_object_get_anchor_y_default | object3d_get_anchor_y: panel |
| 08 | getX | position | scene_object_get_x | mover_get_x: cannon saucer bomb shot column explosion |
| 09 | getY | position | scene_object_get_y | mover_get_y: cannon saucer bomb shot column explosion |
| 0A | getStepX | position | scene_object_get_step_x_default | mover_get_step_x: cannon saucer bomb shot column explosion |
| 0B | getStepY | position | scene_object_get_step_y_default | mover_get_step_y: cannon saucer bomb shot column explosion |
| 0C | slot11 | position | scene_object_slot11_default |  |
| 0D | setElevation | space3d | scene_object_set_elevation_default | object3d_set_elevation: panel |
| 0E | setAnchor | space3d | scene_object_set_anchor_default | object3d_set_anchor: panel |
| 0F | setSize | space3d | scene_object_set_size_default | object3d_set_size: panel |
| 10 | setWorldElev | space3d | scene_object_set_world_elev_default |  |
| 11 | drawBounds | space3d | scene_object_draw_bounds_default | object3d_draw_bounds: panel |
| 12 | addDirtyRect | render | scene_object_add_dirty_rect |  |
| 13 | computeOverlap | render | scene_object_compute_overlap |  |
| 14 | restoreBackground | render | scene_object_restore_background | mover_restore_background: cannon saucer bomb shot; invader_column_restore_background: column; invader_explosion_restore_background: explosion |
| 15 | drawDirtyTo | render | scene_object_draw_dirty_to | mover_draw_dirty_to: cannon saucer bomb shot column explosion |
| 16 | draw | render | scene_object_draw | player2d_draw: cannon; animation_draw: saucer bomb shot; invader_column_draw: column; invader_explosion_draw: explosion; control_panel_draw: panel |
| 17 | drawClipTo | render | scene_object_draw_clip_to |  |
| 18 | drawClip | render | scene_object_draw_clip |  |
| 19 | erase | render | scene_object_erase | animation_erase: cannon saucer bomb shot column explosion panel |
| 1A | slot1F | render | scene_object_slot1f_default | animation_slot1f: cannon saucer bomb shot column explosion panel |
| 1B | redraw | visibility | scene_object_redraw | actor2d_redraw: cannon saucer bomb shot column explosion; animated3d_redraw: panel |
| 1C | hideAndInvalidate | visibility | scene_object_hide_and_invalidate |  |
| 1D | blitToDc | visibility | scene_object_blit_to_dc | cannon_blit_to_dc: cannon; actor2d_blit_to_dc: saucer bomb shot column explosion |
| 1E | invalidate | visibility | scene_object_invalidate | mover_invalidate: cannon saucer bomb shot column explosion |
| 1F | slot24 | visibility | scene_object_slot24 | mover_slot24: cannon saucer bomb shot column explosion |
| 20 | hide | visibility | scene_object_hide | mover_hide: cannon saucer bomb shot column explosion |
| 21 | show | visibility | scene_object_show | actor2d_show: cannon saucer bomb shot column explosion; animated3d_show: panel |
| 22 | occupy | occupancy | scene_object_occupy | control_panel_occupy: panel; status_bar_occupy: status |
| 23 | vacate | occupancy | scene_object_vacate | control_panel_vacate: panel; status_bar_vacate: status |
| 24 | attach | occupancy | scene_object_attach | actor2d_attach: cannon saucer bomb shot column explosion; control_panel_attach: panel; status_bar_attach: status |
| 25 | canStep | occupancy | scene_object_can_step_default | cannon_can_step: cannon; actor2d_can_step: saucer; missile_can_step: bomb shot; invader_column_can_step: column explosion |
| 26 | isStepBlocked | occupancy | scene_object_is_step_blocked |  |
| 27 | nextFrame | animation | scene_object_next_frame_default | actor2d_next_frame: cannon saucer bomb shot column explosion; animated3d_next_frame: panel |
| 28 | prevFrame | animation | scene_object_prev_frame_default | actor2d_prev_frame: cannon saucer bomb shot column explosion; animated3d_prev_frame: panel |
| 29 | play | animation | scene_object_play_default | cannon_play: cannon; animation_play: saucer bomb shot column explosion; animated3d_play: panel |
| 2A | playIdle | animation | scene_object_play_idle_default |  |
| 2B | stopAndRedrawDc | animation | scene_object_stop_and_redraw_dc_default | actor2d_stop_and_redraw_dc: cannon saucer bomb shot column explosion; animated3d_stop_and_redraw_dc: panel |
| 2C | stopAndRedraw | animation | scene_object_stop_and_redraw_default | actor2d_stop_and_redraw: cannon saucer bomb shot column explosion; animated3d_stop_and_redraw: panel |
| 2D | tick | animation | scene_object_tick_default | cannon_tick: cannon; animation_tick: saucer bomb shot column explosion; control_panel_tick: panel |
| 2E | stop | animation | scene_object_stop_default | actor2d_stop: cannon saucer bomb shot column explosion; animated3d_stop: panel |
| 2F | moveTo | movement | scene_object_move_to_default | mover_move_to: cannon saucer bomb shot column explosion |
| 30 | moveToEdgeH | movement | scene_object_move_to_edge_h_default | mover_move_to_edge_h: cannon saucer bomb shot column explosion |
| 31 | moveToEdgeV | movement | scene_object_move_to_edge_v_default | mover_move_to_edge_v: cannon saucer bomb shot column explosion |
| 32 | stopMovingDc | movement | scene_object_stop_moving_dc_default | actor2d_stop_moving_dc: cannon; saucer_stop_moving_dc: saucer; missile_stop_moving_dc: bomb shot; invader_column_stop_moving_dc: column explosion |
| 33 | stopMoving | movement | scene_object_stop_moving_default | actor2d_stop_moving: cannon; saucer_stop_moving: saucer; missile_stop_moving: bomb shot; invader_column_stop_moving: column explosion |
| 34 | moveTick | movement | scene_object_move_tick_default | player2d_move_tick: cannon; actor2d_move_tick: saucer; missile_move_step: bomb shot; invader_column_move_tick: column explosion |
| 35 | getTimerId | animation | scene_object_get_timer_id_default | actor2d_get_timer_id: cannon saucer bomb shot column explosion; animated3d_get_timer_id: panel |
| 36 | isMoving | movement | scene_object_is_moving_default | actor2d_is_moving: cannon saucer bomb shot column explosion |
| 37 | isRunning | animation | scene_object_is_running_default | animation_is_running: cannon saucer bomb shot column explosion panel |
| 38 | moveToAndDrop | space3d | scene_object_move_to_and_drop_default | object3d_move_to_and_drop: panel |
| 39 | setPosition | position | scene_object_set_position | actor2d_set_position: cannon saucer bomb shot column explosion |
| 4C | unk4E | position | scene_object_unk4e |  |
| 4D | redrawOverlapping | visibility | scene_object_redraw_overlapping | object3d_redraw_overlapping: panel |
| 4E | hitboxOverlaps | position | scene_object_hitbox_overlaps |  |
| 4F | boundsOverlap | position | scene_object_bounds_overlap |  |
| 50 | slot5B | position | scene_object_slot5b_default |  |
| 51 | slot5C | position | scene_object_slot5c_default |  |
| 54 | isEnabled | position | scene_object_is_enabled_default |  |
| 55 | getExitIndex | position | scene_object_get_exit_index_default |  |
| 3A–4B, 52/53, 56–5A | type tests | (Object.is/as) | | |

### Other vtables

`docs/inv/SLOTS.tsv` is this table for `noite -p inv unit dep infer`.

| vtable | slots → unit |
|---|---|
| Object3DVtbl (8) | `space3d` (Object3D's, the panel) |
| AnimationVtbl (1) | `animation.playOnce` |
| MoverVtbl (1) | `occupancy.placeAt` (mover_place_at; moved from TIRO's `movement`, above) |
| SaucerVtbl (4) | 00 `occupancy.placeAt`; 01 `saucer.armTimer` (saucer_arm_timer); 02 moveTickOrStop (`saucer_move_tick_or_stop`, dead: no call site); 03 `saucer.checkEdge` (saucer_check_edge) |
| MissileVtbl (3) | 00 `occupancy.placeAt`; 01 `missiles.armTimer` (missile_arm_timer); 02 `missiles.moveTick` (missile_move_tick) |
| InvaderVtbl (3) | 00 `occupancy.placeAt`; 01 `invaders.step` (invader_column_step, the explosion's too); 02 moveTickOrStop (`invader_column_move_tick_or_stop`, dead) |
| ControlPanelVtbl (9) | 00 `animation.playOnce`; 01–08 `panels` (InvPanel's getVisibleHeight) |
| GameVtbl (7) | 00 `game_input.handleMessage`; 01–06 `game` (createPlayer … onCreate) |
| SceneVtbl (13) | 00, 05, 07 `invasion` (handleMessage, createScreen, create); the rest `scene` |
| Backdrop/GridBackdropVtbl (19/20) | `backdrop` (slot 00 create = InvBackdrop's 32-px grid, no wall cells; 01–06 grid; 07–12 defaults; 13 createWithGrid) |
| ConditionVtbl (3) | `game` (FlagCondition; CompoundCondition is dead) |
| FrameVtbl (1) | `object_create.getCell` |

`armTimer` returns the object (the original returns `this`); the INV
creators call it directly, not through the slot.

## State

`core/game.zig`'s `Game` is InvGame + Game flattened (`g_game` and
`g_invGame` are the game itself) plus every DGROUP global (`g_score` →
`g.score`, `i16`, BSS so 0 at start; `g_noiteWnd` → `g.noiteWnd`; the six
strip tables, the bomb timer tables, `g_formationDir` 2,
`g_invaderPeriod` 500, `g_formationMaxY` 60, `g_invadersLeft` 20,
`g_unk0284` 1, all checked by `noite -p inv initdata`; the key latches
`g_keyRightHeld`/`g_keyLeftHeld`/`g_keySpaceHeld`; `g_invadersLanded`,
`g_bombHitCannon[2]`; the WaveMix state and the eight waves;
`g_occupancyCount/Object` → `g.occupancy`; the game objects above;
`g_mainWindow` = `plat.windowHandle()`). No counterpart:
`g_setSystemTimer`/`g_killSystemTimer` (`g.setSystemTimer`), the instance
and module handles, the module path (the host's `Program.dir`, `\INV`),
`g_unk027E`/`g_unk0280` (no access). INV has no random state. One `Game`
per running INV. Leaf units take the narrowest thing, as in NOITE.

The backdrop: NOITE's pixel contract (top-down WinG DIB, `wingBitBlt`,
`textOut` into a `Surface`) for its one bitmap, `surface()`. The score box
(`inv_draw_score`: " %04d" / "-%04d", one `TextOut` per character at x
460 + 32·i, y 445, `0xedeeee`, transparent, the DC's default font) draws
on it and `inv_blit_score_box` blits the 192×20 box at (416, 437).

## Reading INV (medium model, /Od)

TIRO's section holds as written ("Reading TIRO"): far pascal game code
(Ghidra `__stdcall16far`, parameters listed **reversed**, `this` at
`[BP+6]`), near data (DGROUP 1090), virtual calls `MOV BX,[SI]; CALLF
[BX+off]` (slot = off / 4), adjustor thunks, `_aFchkstk` at every entry
(ignore it), `/Od`'s long literal bodies, the virtual-base residue, the 14
sub-object NULL tests printed as `this == s_coordFormat + 8`. INV's
specifics:
- The SceneObject overrides in `1068` take the SceneObject and reach
  their class at negative offsets (Object model, above).
- The creators in `1068` (`inv_create_*`) are far cdecl `(hwnd,
  backdrop)` and call `saucer_arm_timer`, `missile_arm_timer`,
  `scene_object_attach` directly.
- `inv_scene_handle_message` (5,736 bytes) has a plate with its whole
  case map, timer chain, hit test, speed-up and end: read it first.
- The engine functions that differ from TIRO (FUNCTIONS.md; each plate
  says DIFFERENCE):

| INV | Function | Unit | Difference from TIRO |
|---|---|---|---|
| `1028:00a8` | `scene_object_slot24` | visibility | no SelectPalette/RealizePalette |
| `1028:01ee` | `mover_slot24` | visibility | the same |
| `1028:02e1` | `scene_object_restore_background` | render | `dib_copy_transparent` with key `g_unk00A8` (TIRO: the opaque `dib_copy_rect`) |
| `1030:033c` | `backdrop_create` | backdrop | no `backdrop_set_static_colors` |
| `1038:0335` | APPWNDPROC | app | no wave on WM_PAINT (SALGIN's and XILINDRO's body) |
| `1048:0029` | `inv_game_create_player` | game | the Cannon at (340, 380), 4 lives |
| `1048:01ff` | `inv_game_on_create` | game | `game_init`, then the six INV creators |
| `1078:01e6` | `wave_play` | sound | flags 5, \| 2 without a notify window (SALGIN's, XILINDRO's) |
| `1080:001a` | `entry` | (CRT, replaced) | |
| `1088:17a4` | `scene_object_hide_and_invalidate` | visibility | hide, then a direct `scene_object_blit_to_dc` on its hdc (TIRO: the virtual `invalidate`) |
| `1088:310c` | `animation_set_strip` | animation | its own GetDC/ReleaseDC and direct `blitToDc` after hide and show (TIRO: `invalidate`) |

## Fixes (BUGS.md I-section)

| Bug | Flag | Unit | What the fix changes | In `all` |
|---|---|---|---|---|
| I1 SPACE latch never set | `inv_space_latch` | invasion | the SPACE key-down branch, taken when `g_keySpaceHeld` is 0, sets it to 1 (WM_KEYUP already clears it): a held SPACE fires at most once, on the press; key repeats do nothing (TIRO's T1 fix) | yes |
| I2 a direction key cuts the cannon's explosion short | `inv_explosion_holds_cannon` | invasion | while the explosion strip is on (`curStrip` 1, from `cannon_lose_life` to the last frame; `hitFrame` is still −1 until the cannon's first tick), LEFT/RIGHT key-down set their latch and key-up clears it, but neither moves, resumes or stops the cannon, and SPACE does not fire: the cannon stays put for the whole `Brocha.bmp` explosion (7 frames of 60 ms), and the explosion's end resumes a held key, as the original's already does | yes (owner question 1) |

Each unit ports the buggy code and keeps the fixed path only under its
flag (`g.fixes.inv_…`). I1 matters only with key repeats (on by default:
TIRO's Platform section). The Harmless list gets no flag; the port does
what the original does, with these notes for the units:
- **Null-pointer writes in `inv_create_bombs`/`inv_create_shot`**
  (`missiles`): not ported (the port has no DGROUP bytes at 0x42; they
  land in a message-box text the game never shows); a comment at the site
  names the entry.
- **The last kill's speed-up** (`invasion`): ported as is; `period -%=
  100` leaves −45 and `setSystemTimer(0xf, @bitCast(period))` re-arms the
  columns 65,491 ms away; the win goes out through the next WM_SYSTIMER's
  step 0; the dead `< 1` branch is ported.
- **A landing sends WM_DESTROY several times** (`movement`, `invaders`,
  `invasion`): ported as is, each nested `g.send` running the teardown
  and posting one 0x40a; `sound`'s close/free/stop and MCI `close musica`
  must be harmless when repeated (Platform).
- **`invader_column_init_cells` adds 44·i twice**, **a bomb dropped during
  its impact animation**, **a '2' shot that matches no column**,
  **`Player2D.score`** (wrapping `i32` adds), **the dead `MM_WOM_DONE`
  case**: ported as is.
- **`Missile.hitState` never initialised**: 0 in the port (Object model).
- **Dead code**: `saucer_move_tick_or_stop`,
  `invader_column_move_tick_or_stop` and `invader_column_start_right_dup`
  are `dead` in the plan. `cannon_play` and `cannon_tick` sit in live
  slots (`play`, `tick`) that only `game_handle_message`'s mouse and timer
  code would call: they are ported (unit `animation`), as TIRO's
  `crossbow_play`/`crossbow_tick` are.
- **`WinMain`'s uninitialised return**: not ported (the host ignores exit
  codes).

## Integration

Every unit is ported and `src/inv/root.zig` has `ready = true`: NOITE's
WinExec runs INV and `--minigame inv` plays it alone. The check of the
finished port found one port bug: `game_init` called the base Scene's
`create` instead of the InvScene's slot 07 (`invasion.create`), so the
music, WaveMix, the waves and the score box were never set up (and the
first WM_ACTIVATE showed "Erro Wave Mix"); fixed.

### The launch from NOITE

`handler_4fsacaet` (`src/handlers/4fsacaet.zig`, ported): on the scene's
start the saucer (`disco`, 0xf3) plays its animation and wave; its
`MM_WOM_DONE` runs `WinExec("<CD>Inv\Inv.exe")` and timer 0x14 (100 ms).
The host matches `Inv` to `inv.program` (`main.minigames`, by
`exeBase`, case-insensitive): INV's task starts `--minigame-startup` ms
later (1500; its WinMain: `app.start`, which first runs the static
initialiser `initStaticConditions`, as `_cinit` does before WinMain).
FindWindow("Invasores") succeeds on NOITE's next 0x14 tick, NOITE posts
**0x40b** (lParam = NOITE's window); AppWndProc stores `g_noiteWnd` and,
on its next message after `g_started`, posts **0x40c**; NOITE hides
itself. The end:
- **Win**: the kill that leaves `g_invadersLeft` 0; the next WM_SYSTIMER
  of any id (step 0 of the chain) sends INV's own WM_DESTROY with wParam
  **0xffff** (nested, as SendMessage; the chain then goes on, as the
  original's) and sets `g_invadersLeft` −1.
- **Loss**, WM_DESTROY with wParam **0**: `cannon_lose_life` at 0 lives
  (inside the bomb's tick), or a column landing (inside the formation
  step, up to 5 times in that tick: BUGS.md, INV Harmless).

INV's WM_DESTROY case stops and frees the waves, closes WaveMix and MCI
and posts **0x40a** (wParam = WM_DESTROY's own wParam, lParam the
sign-extended `g_score`) to `g_noiteWnd`; it returns 0, so AppWndProc
kills timer 1 and posts WM_QUIT, which comes after the posted messages and
before any timer (`core/queue.zig`): no INV timer runs again. The host
then runs `app.exit`, destroys the window and activates NOITE, which shows
itself, adds lParam to the score (a negative score lowers it) and goes to
`4fmarte2` (won: the Martian speaks, then the `ESOTEBOY` cutscene and
back to `4fbar`) or `4fmarte` (lost: the Martian, then a life less and
`4fbar`, or `6fsaida` at 0 lives). From `--scene 4fsacaet` the saucer's
wave ends at 25308 ms (the WinExec) and INV's WM_CREATE is at 26808. A landing's extra 0x40a reach NOITE after the scene switch;
`4fmarte`/`4fmarte2` ignore them (GAME.md), so the score is added once.
NOITE's WM_SYSTIMER check (window gone without a result → 0x40a loss) is
covered by the host's window lifetime. Nothing changes in NOITE.
`--minigame-stub` keeps the stub (a win after the hello) instead.

### Standalone

- `noite --minigame inv [--headless …]`: INV alone (task 0, its title,
  `\INV` directory); prints its result (0x40a to hwnd 0 goes nowhere; the
  host records it, the last one wins).
- Web: `web_main.minigames` lists INV after SALGIN (its index + 1 is
  `noite_start`'s `minigame`), `MINIGAMES` in `web/noite.js` the same
  entry at the same position (`{ name: "inv", title: "Invasores", ready:
  true }`), the "Jogo" select of `web/index.html` "Jogar só o minijogo:
  Invasores"; `tools/web/files.py` looks INV's names up at the root, then
  in `INV\` (`DOOM1.MID` is at the root). The on-screen pad (one-button
  mode, or a minigame alone on a touch screen) follows the program on top
  (`noite_top_program`): `PAD_KEYS.inv = [37, 32, 39]`, ◀, a fire button
  and ▶, as TIRO's.

## Platform

Nothing new: INV uses what TIRO needed.
- **Keys**: LEFT, RIGHT, SPACE to a minigame task (`Sim.filterInput`),
  key repeat on the program's clock (TIRO's "Platform" section). I1 needs
  the repeats; the scripts hold SPACE with `--key-repeat 500,33`.
- **MCI sequencer** with notify (`doom1.mid`, alias `musica`, the loop
  on `MM_MCINOTIFY`, pause/play on WM_ACTIVATE), as TIRO's `pac.mid`.
- **WaveMix**: 8 waves, `WaveMixPlay` with flags 7 and no notify window.
  The repeated teardown of a landing (`wave_stop_all`, `wave_free_all`,
  `wave_mix_close` with session 0, MCI `close musica` on a closed alias)
  must return errors, not panic, as the original's calls do.
- **WinG/GDI**: GetDC/ReleaseDC around a `blitToDc` (the explosion end,
  `animation_set_strip`, `scene_object_hide_and_invalidate`), `TextOut`
  into the backdrop: TIRO's.

## Tests

INV has no randomness: a game follows from the key times relative to
INV's WM_CREATE (0 alone, 26808 from `--scene 4fsacaet`), and a script
moved by that offset plays the same game. The scripts are checked in
both versions (Original and `--fix all`); the plans press each key (SPACE
never held: I1 never matters) and take no bomb hit (I2 never matters), so
both versions play the same game.
- **Planner** `tools/inv_plan.py (--win|--lose) [--start MS]
  [--relative-to MS]`: instead of a simulation (TIRO's and SERIAL's
  planners model `rand()`), it probes the port: a run of `--minigame inv`
  with the keys so far and a `close` at a time T reports `g_score` at T
  (WM_CLOSE → WM_DESTROY wParam 0 → 0x40a with the score). A depth-first
  search, one kill at a time, from 600 ms (after the first formation step:
  an earlier kill shows the `init_cells` Harmless): wait, then nothing / an
  arrow pressed or held, then SPACE, shortest first; the first that kills
  one invader (+100, +600 with the saucer) with no bomb hit is kept, its
  kill time bisected, and it backs up a kill when none works. It checks
  the plan in both versions. `--win`: 20 kills in 10.6 s, `won 2000`;
  `--lose`: no key, four bomb hits, `lost -2000` at 12275 ms.
- **Scripts** (`tools/play/`), each Original and `--fix all`, the same
  script, the result checked after the later end (README.md, "INV"):
  - `inv-alone-win.input`, `inv-alone-lose.input` (the planner's);
  - `inv-held-space.input` (`--key-repeat 500,33`): one step left, SPACE
    held 4 s. The Original fires on the repeats (I1) and the formation
    lands at 19762 ms with +500; the Corrigida fires once, -1900 at 14330
    (`result lost 500 | lost -1900`);
  - `inv-explosion-move.input`: the first bomb hit (2370–2390 ms), LEFT
    held from 2400 (the explosion's first tick) and SPACE at 2600: the
    Original drives off and fires, a kill (-1900 at 8440); the Corrigida
    holds still and cannot fire (-2000 at 12275);
  - `inv-4fsacaet-win.input` / `inv-4fsacaet-lose.input` (`--scene
    4fsacaet`): the planner's keys from 26808, `result won 2000`, then
    `4fmarte2`, `ESOTEBOY` and `4fbar` with the score added / `result lost
    -2000`, `4fmarte`, then `4fbar` with a life less and the score lowered.
- **Playthroughs**: `full.input` and `onebutton.input` take the
  sportsman's route at `4fbar`; INV is on the esoteric's, a detour that
  comes back to the bar (Decisions). They stay green with INV
  `ready`.
- **Smoke**: `tools/smoke.py --minigame inv [--fix all] [--monkey SEED]`:
  TIRO's random LEFT/RIGHT and SPACE presses, 110 ms or more apart, for
  60 s; the bombs or the landing end every game in 10 to 30 s. The scene
  sweep's `4fsacaet` runs the real INV too (it ends by itself).
- **Web**: `tools/web/test.py` plays "Jogo" = Invasores: SPACE sends the
  shot up from the cannon, and on a touch screen the pad shows ◀, fire,
  ▶ and its fire button fires.
- **Unit tests** (optional, tagged): `oracle=emulated` from tools/oracle
  (far code, DGROUP 1090, `_aFchkstk` 1080:00e4 runs as is), as worth it:
  `missile_can_step` (the blocker classes), `invader_column_step` /
  `invader_column_stop_moving_dc` (the turn, the descent, the landing),
  `invader_column_update_lowest_alive`, `inv_draw_score` (`asset` with
  Espaco.bmp), the handler's second hit stage and speed-up (`documented`).

## Units

22 units, 343 functions to port; 115 dead, 563 absorbed (449 thunks, 69
defaults, 45 type tests), 172 replaced (79 CRT, 93 imports). Every engine
function is in the unit TIRO's plan gave its TIRO twin (by name), but
`mover_place_at` (occupancy) and the dead ones; the INV functions are
assigned by role. Hard deps are direct calls into another unit (`noite -p
inv next --blocked`); virtual calls are soft (`unit dep show`). Level =
the longest chain of hard deps below the unit: the units of one level can
run in parallel once the levels below are done.

| Level | Unit | Fns | Size | Calls into |
|---|---|---|---|---|
| 0 | `dib` | 7 | 3.0 KB | — |
| 0 | `position` | 27 | 1.2 KB | — |
| 0 | `sound` | 8 | 0.9 KB | — |
| 1 | `backdrop` | 27 | 3.4 KB | dib, position |
| 1 | `object_create` | 32 | 3.6 KB | dib, position |
| 1 | `render` | 21 | 3.0 KB | dib, position |
| 1 | `score` | 10 | 0.8 KB | dib, sound |
| 1 | `space3d` | 24 | 4.0 KB | position |
| 2 | `lists` | 17 | 2.0 KB | object_create, position, render |
| 2 | `occupancy` | 20 | 2.3 KB | position, render |
| 3 | `scene` | 15 | 0.8 KB | backdrop, lists, object_create |
| 3 | `visibility` | 19 | 1.6 KB | lists, position, render |
| 4 | `animation` | 26 | 1.8 KB | occupancy, position, render, visibility |
| 5 | `movement` | 22 | 3.7 KB | animation, backdrop, object_create, occupancy, position, render, score, visibility |
| 5 | `panels` | 17 | 1.6 KB | animation, dib, lists, object_create, position, render |
| 6 | `invaders` | 7 | 1.1 KB | animation, movement, object_create, position |
| 6 | `missiles` | 6 | 1.2 KB | animation, movement, object_create, occupancy |
| 6 | `saucer` | 4 | 0.7 KB | animation, movement, object_create, occupancy, position |
| 7 | `game` | 19 | 2.1 KB | invaders, lists, missiles, object_create, occupancy, panels, saucer, scene |
| 7 | `invasion` | 4 | 6.1 KB | animation, backdrop, invaders, missiles, movement, occupancy, position, saucer, scene, score, sound |
| 8 | `app` | 8 | 1.3 KB | backdrop, dib, game |
| 8 | `game_input` | 3 | 4.2 KB | game, lists, position, render, space3d |

Ready first (parallel): `dib`, `position`, `sound`; then `backdrop`,
`object_create`, `render`, `score`, `space3d`; then `lists`,
`occupancy`; then `scene`, `visibility`; then `animation`; then
`movement`, `panels`; then `invaders`, `missiles`, `saucer`; then `game`,
`invasion`; then `app`, `game_input`. The largest single functions:
`inv_scene_handle_message` (5.7 KB, `invasion`), `game_handle_message`
(3.7 KB, `game_input`). The INV game units:
- `invaders`: `inv_create_invader_columns`, `inv_create_invader_explosion`,
  `invader_column_start_right`, `invader_column_step` (InvaderVtbl.step),
  `invader_column_turn`, `invader_column_update_lowest_alive`,
  `invader_explosion_start`;
- `saucer`: `inv_create_saucer`, `saucer_arm_timer`, `saucer_check_edge`,
  `saucer_explode`;
- `missiles`: `inv_create_shot`, `inv_create_bombs`, `missile_arm_timer`,
  `missile_move_tick`, `shot_vanish`, `bomb_shot_down`;
- `score`: the eight `inv_play_*_wave` / `inv_score_*_hit` helpers,
  `inv_draw_score`, `inv_blit_score_box`;
- `invasion`: `inv_scene_handle_message`, `inv_scene_create`,
  `inv_scene_create_screen`, `cannon_lose_life` (only the handler calls
  it);
- the class ctors (`cannon_ctor`, `saucer_ctor`, `missile_ctor`,
  `bomb_ctor`, `shot_ctor`, `invader_column_ctor` with
  `invader_column_init_cells`/`_set_cell`, `invader_explosion_ctor`,
  `inv_panel_ctor`) are in `object_create`, `inv_scene_ctor` in `scene`,
  `inv_backdrop_ctor`/`_create` in `backdrop`, `inv_game_*` and the empty
  `inv_on_create_hook` in `game`, the overrides in their slots' units.

`position` also owns `message_box_printf`, as TIRO's (the SceneObject
constructor calls it).

The 115 dead: 57 of classes never constructed in INV, 8 only in tables of
base classes or classes never constructed, 46 unreferenced (TIRO's 5
`FUN_` twins among them, APPABOUT, `invader_column_start_right_dup`), the
2 moveTickOrStop slots nothing calls, and `dib_copy_rect` /
`backdrop_set_static_colors` (TIRO's callers call them, INV's do not).

## Tracker

`noite -p inv …` (or `NOITE_PROGRAM=inv`): DB `db/inv.sqlite` (local;
`noite -p inv import` rebuilds it from Ghidra and the plan), plan
`db/inv-plan.tsv` (committed), tree `src/inv/`, index `src/inv/units.zig`,
worktrees `work/inv-<unit>/` on branches `port/inv-<unit>`. A worktree's
`.ref/env.sh` sets `NOITE_PROGRAM`, so `noite test`/`check` there need no
`-p`. `@orig` tags are checked per program; `finish` refuses files
outside `src/inv/`. The program's layout (`tools/cli/src/noite/program.py`
`INV`): CRT 1080, imports 10a8, DGROUP 1090, far 4-byte vtable slots,
virtual calls `CALLF [BX+off]`. The "Other vtables" owners are
`docs/inv/SLOTS.tsv`; the SceneObject owners the table above.

```
noite -p inv next [--blocked]       # units ready to claim
noite -p inv start <unit>           # worktree work/inv-<unit>/
noite -p inv show <addr|name>       # row, decompile (--asm), callers/callees
noite -p inv unit show <unit>
noite -p inv check -w <unit>        # @orig tags vs INV's DB
noite -p inv initdata -w <unit>     # `// @orig g_*` defaults vs INV's DGROUP
noite -p inv finish <unit>          # from the main checkout
noite -p inv failed <unit> "why" / release <unit>
```

An INV function's TIRO twin has the same name (`noite -p tiro show
<name>`, `grep -rn '<name>$' src/tiro/`); its `@orig` tag in the INV
file carries INV's address (`noite -p inv show <name>`).

## How to port an INV unit

1. `noite -p inv next`, `noite -p inv start <unit>`, then work in
   `work/inv-<unit>/` (`. .ref/env.sh`; tools via `nix develop -c`).
   Scratch output and frame dumps go in the worktree's `zig-out/`, never
   `/tmp`.
2. Read the unit's `.ref/*.c` (plate, decompile, disassembly),
   `.ref/types.md`, `.ref/strings.md`; DATA.md / GAME.md for the class
   and the rules. Ghidra (`mcp__ghidra__*`, `program="INV.EXE"`) for
   anything else.
3. Read the TIRO unit of the same name (`src/tiro/<unit>.zig`, ported and
   checked; for `invasion` read `src/tiro/gallery.zig`, for `missiles`
   `arrow.zig`, for `saucer`/`invaders` `target.zig`): the engine
   functions are the same source. Transcribe each INV function from INV's
   own decompile/asm, reusing TIRO's Zig where they agree; mind the 11
   bodies that differ (table above) and note in the commit body every
   function whose code differs from TIRO's (and how). Never call a TIRO
   or ENCAIXE unit, except the state-free delegation allowed in
   Decisions.
4. Write only `src/inv/<unit>.zig` (or `behaviour/<unit>.zig`): replace
   each declared dispatcher's body, keep its signature; one
   `// @orig <seg:off> <ghidra_name>` per function (INV addresses;
   `(absorbed)` for the defaults and thunks a dispatcher's arm covers).
   Public names: the Ghidra name minus the unit's class prefix, camelCase
   (`saucer_explode` in `saucer` → `saucer.explode`).
5. Faithful first: port each I-bug as the code does it and put the fix
   only behind its flag (`g.fixes.inv_…`, table above); the Harmless
   notes above say what to do with each Harmless item. NOITE's
   conventions hold (integers `i16`/`i32` with wrapping where the original
   overflows, `cstr`, `?*T`, message boxes through `plat.messageBox`,
   every PostMessage/SendMessage/SetSystemTimer at the same point,
   `error.Fatal` only where the original ends). Allocate what the
   original `new`s from `g.local()`.
6. Call other units' dispatchers, never a local copy. If a declared
   signature cannot express the original, `noite -p inv failed <unit>
   "slot <name> (<owner>) needs …"`.
7. Tests optional; when written, `oracle=emulated` from tools/oracle,
   `asset` from `assets/INV/`, `documented` from Ghidra.
8. `noite test`, commit (commit skill), `noite -p inv finish <unit>` from
   the main checkout.

## Finishing

Done: `ready = true` in `src/inv/root.zig`; the web entries
(Standalone, above); `KEYS_FOR["inv"]` in `tools/smoke.py`; the planner
and the scripts (Tests); the INV lines of README.md ("Running the port",
"Testing the port"); BUGS.md I1/I2 "Port:" lines naming the flags. The
INV scripts, `smoke.py --minigame inv` (both versions), the scene sweep,
both playthroughs and `tools/web/test.py` pass.

## Owner questions

1. **I2 in Corrigida.** The fix holds the cannon still, and its fire,
   for its whole explosion (420 ms), the arcade behaviour; it is in `all`. If the
   original's cut-short explosion should stay in Corrigida too, the flag
   moves to `Fixes.choices`.
