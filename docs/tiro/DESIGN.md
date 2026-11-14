# Native port of TIRO.EXE — design

TIRO.EXE ("Tiro ao Álvaro", window "Tiro ao Alvaro", the hall door's
crossbow shooting gallery) in Zig, next to NOITE's and ENCAIXE's ports.
NOITE's `docs/DESIGN.md`, ENCAIXE's `docs/encaixe/DESIGN.md` and the
zig-developer skill hold for everything this file does not override.
Ghidra (program `TIRO.EXE`, through the tracker snapshot `noite -p tiro
show`) is the specification; `GAME.md` (rules, protocol), `DATA.md`
(classes, vtables, globals), `FUNCTIONS.md` (names, dead code),
`QUALITY.md` (the medium /Od build), BUGS.md T1–T6.

## Decisions

- **Own tree, TIRO's code; ENCAIXE's Zig as the template.** TIRO is the
  engine ENCAIXE is built from (same sources: "Faltou redefinir…",
  `MAX_OBJECT_QTY`, the occupancy matrix), compiled medium model `/Od`
  with far 4-byte vtable slots. The memory model is not ported, but the
  builds are not the same program either:
  - the Backdrop has **one** WinG DC/bitmap (ENCAIXE two; fields 8 bytes
    lower);
  - the SceneObjectVtbl has 91 slots (ENCAIXE's 93 without `unk11` and
    `unk18`, renumbered) plus TIRO's type tests `isProjectile`/`isTarget`/
    `isCrossbow`; `scene_object_dtor` frees nothing (NOITE's frees the
    strips);
  - `/Od` keeps ENCAIXE's inlined code out of line: the update list (5
    functions; ENCAIXE inlines it at every caller), 12 SceneObject and
    frame accessors, `occupancy_grid_occupy_cell`/`vacate_cell`, the
    Object3D ctor;
  - the DIB module is a newer one (`FindResource`/`GetObject` paths), the
    Portable class is linked (never built), a second draw-list class is
    linked (never used), `perspective_backdrop_set_layer` exists;
  - five own classes: Crossbow (← Player2D), Target (← Actor2D),
    Projectile and Arrow (← Actor2D), and TiroGame/TiroScene/TiroPanel/
    TiroBackdrop in the roles of ENCAIXE's Tetris* classes;
  - its handler (`tiro_scene_handle_message`, 5.6 KB) answers every key,
    timer and mouse message, so `game_handle_message`'s input paths never
    run (they are ported all the same, as in ENCAIXE).

  So TIRO gets its own units under `src/tiro/`, ported from its own
  functions with its own `@orig` addresses, and it does not call
  ENCAIXE's units. **Sharing them was weighed and rejected:**
  - every engine function takes ENCAIXE's `Game`/`Object`/`Backdrop`;
    sharing them means making 21 finished ENCAIXE units generic over the
    program (comptime `Game`/`Object` types, kinds, Backdrop with one or
    two bitmaps, renumbered slots), which changes ENCAIXE's code after
    it was checked, for the sake of TIRO;
  - an `@orig` tag maps to one program's address (`noite check` scans
    only the program's own tree: NOITE `src/` minus `src/encaixe/` and
    `src/tiro/`, ENCAIXE `src/encaixe/`, TIRO `src/tiro/`), and `noite
    finish` refuses a unit that edits another program's tree: a shared
    function would need two tags and a tracker that checks a file against
    two DBs, and a TIRO unit could not land a fix in it;
  - where the two programs do differ (above), a shared body would carry
    `if (tiro)` branches; a copy keeps each port a plain transcription of
    its own binary.

  The copy is cheap: the ENCAIXE unit of the same name is the starting
  point for every engine unit (same slot names, same signatures, same
  struct offsets). A TIRO agent transcribes each function from TIRO's
  decompile/asm, uses the ENCAIXE Zig to save typing where the two
  decompiles agree, and says in its commit body which functions differ
  from ENCAIXE's and how.
- **Shared, because identical or not game code:** the platform layer
  (`src/platform/`, host included), `core/msg.zig`, `core/queue.zig`,
  `core/cstr.zig`, `core/crt.zig` (the CRT `rand`: TIRO's `srand`/`rand`
  are MSVC's), `core/stub.zig`, `core/errors.zig`, `core/fixes.zig` (one
  `Fixes`, T-flags prefixed `tiro_`), the Win16 data types (`Dib`,
  `BitmapInfoHeader`, `RgbQuad`, `Rect`). Segment 1000 is byte-identical
  to NOITE's: TIRO's `dib.rowsCopy32`/`rowsCopyTransparent32` (tagged
  1000:0114 / 1000:0024) call NOITE's `src/dib.zig`, as ENCAIXE's do. A
  TIRO function may delegate to an ENCAIXE or NOITE function only when
  that function takes no program state (no `Game`, `Object`, `Backdrop`
  of its program: in practice the `dib` copies and `read_dib_info`) and
  the two decompiles are shown identical in the unit's commit; the TIRO
  wrapper carries TIRO's `@orig` tag.
- **Faithful first, the owner's rule.** T1–T6 are reproduced as they are
  by default. Each fix exists only behind its own `Fixes` flag (off by
  default). Corrigida (`Fixes.all()`) takes the clear bug fixes; T2 and
  T4 change how many shots a game has, so they sit in `Fixes.choices`
  until the owner decides (questions at the end).
- **Two programs in one process**, as ENCAIXE (`src/platform/host.zig`,
  docs/encaixe/DESIGN.md "Running two programs"): TIRO is a task with its
  own state, queue, timers, window and screen; the protocol runs through
  the platform as in Windows. The host needs nothing new for TIRO but the
  keys (Platform, below).
- **The local heap.** TIRO never frees most of what it allocates
  (`scene_object_dtor` frees nothing; the strips and frames of the six
  objects live until the end). On Windows the task's local heap goes with
  the task. `Game.local()` is that heap (an arena on the task's
  allocator, freed by `Game.destroy`): every `operator new` /
  `_nmalloc` of TIRO allocates there and `operator delete` is what the
  original does (the units may free into it, or not, as the code does).
  So the faithful leak is not a leak of the port.

## Source layout

```
src/tiro/root.zig          program root: core, units, `ready`, `program` (host.Program)
src/tiro/core/             types only (not units)
  game.zig                 Game: TiroGame + every TIRO DGROUP global; queue, send/post, timers, local heap
  object.zig               Object (kinds crossbow / target / arrow / control_panel / status_bar), parts, Frame, ObjectList
  world.zig                Scene, Backdrop (one bitmap), OccupancyGrid + Occupancy, DrawList, UpdateList, Condition
src/tiro/<unit>.zig        module units
src/tiro/behaviour/        behaviour units (one group of SceneObject slots)
src/tiro/units.zig         generated index (`noite -p tiro unit sync`)
```

## Object model

As ENCAIXE's (one `Object`, a `kind`, every part present), with TIRO's
classes. Five kinds are constructed:

| Kind | Class (vtables) | Parts live |
|---|---|---|
| `crossbow` | Crossbow ← Player2D ← Actor2D ← Mover + Animation (16c6, 16ca, 16ce) | base, mover, anim, player2d, crossbow |
| `target` | Target ← Actor2D (TargetVtbl 1dfa, 1e06, 1e0a) | base, mover, anim, target |
| `arrow` | Arrow ← Projectile ← Actor2D (ProjectileVtbl 2106, 2116, 211a) | base, mover, anim, projectile |
| `control_panel` | TiroPanel ← ControlPanel ← Animated3D ← Animation + Object3D (1038, 105c, 11c8) | base, o3d, anim, panel |
| `status_bar` | StatusBar (18c6) | base, status |

`Object.is/as` are the type-test slots 3A–4B, 52/53 and 56/58/59
(`isProjectile`, `isTarget`, `isCrossbow`: `projectile_try_step` calls
`isTarget`). The flattened `Target`/`Projectile` structs are Actor2D's
layout with their own vtable: their Mover fields are `obj.mover`, their
Animation `obj.anim`, their own fields `obj.target` / `obj.projectile`.
Mover, Animation, Actor2D, Player2D, Projectile, Animated3D, Moveable,
Portable, Actor, Player, Exit and PerspectiveBackdrop are never
constructed on their own: their methods that no live table reaches are
`dead` in the plan (112 functions), but `portable_pick_up/drop/draw_icon`
are called from live code (`game_input`) and keep the `portable` part.
Struct origins are `// @orig Struct+0xNN` with TIRO's offsets (DATA.md);
the vtordisp words and the virtual bases have no counterpart.

The game objects are DGROUP pointers: `g.crossbow` (the player, also
`Game.player`), `g.targets[0..3]`, `g.arrows[0]`. A method that overrides
a SceneObject slot gets the SceneObject subobject in the original and
reads its class at negative offsets (Crossbow −0x4a, Target −0x50,
Projectile −0x48; DATA.md "Classes"): in the port that is just `obj`.

## Virtual slots

Each slot is one `pub fn` dispatcher (named after the vtable field) in the
unit that owns it, already declared in the skeleton with its final
signature and a `stub.unported` body; it switches on `obj.kind` and calls
one function per original implementation, each tagged `@orig`. The default
stub (`scene_object_*_default`, absorbed) is the `else` arm. Thunks (368),
defaults (66) and type tests (46) are `absorbed`. Signatures:
`(g: *Game, obj: *Object, <args in source order>)`; hwnd and hdc
parameters are dropped; `Backdrop *` stays; out-parameters join the return
value (`space3d.Support`, `world.RectQuery`), except the Projectile's
`int *outDir`, an in/out `*i16`. The signatures are ENCAIXE's skeleton's (the same
sources: FUNCTIONS.md finds the same parameter bytes for 395 of the 404
functions both programs have). Flattened
single-class tables are plain functions: Game (`game`, `game_input`),
Scene (`scene`, `gallery`), Backdrop (`backdrop`), ControlPanel
(`panels`), Target (`target`), Projectile (`arrow`), Condition (`game`),
Frame (`object_create`).

A class's override of a SceneObject slot lives in the slot's unit, next
to its dispatcher (as ENCAIXE's Piece overrides do): Target's
`restoreBackground` is in `render` (and with it BUGS.md T6), Target's and
Projectile's `stopMoving(Dc)` and `moveTick` in `movement`,
`crossbow_play`/`crossbow_tick`/`target_tick` in `animation`, and so on.
The class units (`target`, `arrow`, `gallery`) hold what is not a
SceneObject slot.

### SceneObject slots (kinds: crossbow, target, arrow, panel = control_panel, status = status_bar)

TIRO's slot numbers (byte offset = 4 × slot); `enc` is ENCAIXE's slot of
the same field (TIRO *i* = ENCAIXE *i* below 0x11, *i*+1 for 0x11–0x16,
*i*+2 from 0x17). Field names are ENCAIXE's. 57 (`slot62`) and 5A
(`slot65`) are defaults nothing calls and have no dispatcher. Generated
from the tracker's vtables (thunks resolved).

| slot | behaviour | unit | enc | default | overrides (impl: kinds) |
|---|---|---|---|---|---|
| 00 | getWorldX | space3d | 00 | scene_object_get_world_x_default | object3d_get_world_x: panel |
| 01 | getWorldDepth | space3d | 01 | scene_object_get_world_depth_default | object3d_get_world_depth: panel |
| 02 | getWorldElev | space3d | 02 | scene_object_get_world_elev_default | object3d_get_world_elev: panel |
| 03 | getSizeW | space3d | 03 | scene_object_get_size_w_default | object3d_get_size_w: panel |
| 04 | getSizeH | space3d | 04 | scene_object_get_size_h_default | object3d_get_size_h: panel |
| 05 | getSizeD | space3d | 05 | scene_object_get_size_d_default | object3d_get_size_d: panel |
| 06 | getAnchorX | space3d | 06 | scene_object_get_anchor_x_default | object3d_get_anchor_x: panel |
| 07 | getAnchorY | space3d | 07 | scene_object_get_anchor_y_default | object3d_get_anchor_y: panel |
| 08 | getX | position | 08 | scene_object_get_x | mover_get_x: crossbow target arrow |
| 09 | getY | position | 09 | scene_object_get_y | mover_get_y: crossbow target arrow |
| 0A | getStepX | position | 0A | scene_object_get_step_x_default | mover_get_step_x: crossbow target arrow |
| 0B | getStepY | position | 0B | scene_object_get_step_y_default | mover_get_step_y: crossbow target arrow |
| 0C | slot11 | position | 0C | scene_object_slot11_default |  |
| 0D | setElevation | space3d | 0D | scene_object_set_elevation_default | object3d_set_elevation: panel |
| 0E | setAnchor | space3d | 0E | scene_object_set_anchor_default | object3d_set_anchor: panel |
| 0F | setSize | space3d | 0F | scene_object_set_size_default | object3d_set_size: panel |
| 10 | setWorldElev | space3d | 10 | scene_object_set_world_elev_default |  |
| 11 | drawBounds | space3d | 12 | scene_object_draw_bounds_default | object3d_draw_bounds: panel |
| 12 | addDirtyRect | render | 13 | scene_object_add_dirty_rect |  |
| 13 | computeOverlap | render | 14 | scene_object_compute_overlap |  |
| 14 | restoreBackground | render | 15 | scene_object_restore_background | mover_restore_background: crossbow arrow; target_restore_background: target |
| 15 | drawDirtyTo | render | 16 | scene_object_draw_dirty_to | mover_draw_dirty_to: crossbow target arrow |
| 16 | draw | render | 17 | scene_object_draw | player2d_draw: crossbow; animation_draw: target arrow; control_panel_draw: panel |
| 17 | drawClipTo | render | 19 | scene_object_draw_clip_to |  |
| 18 | drawClip | render | 1A | scene_object_draw_clip |  |
| 19 | erase | render | 1B | scene_object_erase | animation_erase: crossbow target arrow panel |
| 1A | slot1F | render | 1C | scene_object_slot1f_default | animation_slot1f: crossbow target arrow panel |
| 1B | redraw | visibility | 1D | scene_object_redraw | actor2d_redraw: crossbow target arrow; animated3d_redraw: panel |
| 1C | hideAndInvalidate | visibility | 1E | scene_object_hide_and_invalidate |  |
| 1D | blitToDc | visibility | 1F | scene_object_blit_to_dc | actor2d_blit_to_dc: crossbow target arrow |
| 1E | invalidate | visibility | 20 | scene_object_invalidate | mover_invalidate: crossbow target arrow |
| 1F | slot24 | visibility | 21 | scene_object_slot24 | mover_slot24: crossbow target arrow |
| 20 | hide | visibility | 22 | scene_object_hide | mover_hide: crossbow target arrow |
| 21 | show | visibility | 23 | scene_object_show | actor2d_show: crossbow target arrow; animated3d_show: panel |
| 22 | occupy | occupancy | 24 | scene_object_occupy | control_panel_occupy: panel; status_bar_occupy: status |
| 23 | vacate | occupancy | 25 | scene_object_vacate | control_panel_vacate: panel; status_bar_vacate: status |
| 24 | attach | occupancy | 26 | scene_object_attach | actor2d_attach: crossbow target arrow; control_panel_attach: panel; status_bar_attach: status |
| 25 | canStep | occupancy | 27 | scene_object_can_step_default | actor2d_can_step: crossbow arrow; target_can_step: target |
| 26 | isStepBlocked | occupancy | 28 | scene_object_is_step_blocked |  |
| 27 | nextFrame | animation | 29 | scene_object_next_frame_default | actor2d_next_frame: crossbow target arrow; animated3d_next_frame: panel |
| 28 | prevFrame | animation | 2A | scene_object_prev_frame_default | actor2d_prev_frame: crossbow target arrow; animated3d_prev_frame: panel |
| 29 | play | animation | 2B | scene_object_play_default | crossbow_play: crossbow; animation_play: target arrow; animated3d_play: panel |
| 2A | playIdle | animation | 2C | scene_object_play_idle_default |  |
| 2B | stopAndRedrawDc | animation | 2D | scene_object_stop_and_redraw_dc_default | actor2d_stop_and_redraw_dc: crossbow target arrow; animated3d_stop_and_redraw_dc: panel |
| 2C | stopAndRedraw | animation | 2E | scene_object_stop_and_redraw_default | actor2d_stop_and_redraw: crossbow target arrow; animated3d_stop_and_redraw: panel |
| 2D | tick | animation | 2F | scene_object_tick_default | crossbow_tick: crossbow; target_tick: target; animation_tick: arrow; control_panel_tick: panel |
| 2E | stop | animation | 30 | scene_object_stop_default | actor2d_stop: crossbow target arrow; animated3d_stop: panel |
| 2F | moveTo | movement | 31 | scene_object_move_to_default | mover_move_to: crossbow target arrow |
| 30 | moveToEdgeH | movement | 32 | scene_object_move_to_edge_h_default | mover_move_to_edge_h: crossbow target arrow |
| 31 | moveToEdgeV | movement | 33 | scene_object_move_to_edge_v_default | mover_move_to_edge_v: crossbow target arrow |
| 32 | stopMovingDc | movement | 34 | scene_object_stop_moving_dc_default | actor2d_stop_moving_dc: crossbow; target_stop_moving_dc: target; projectile_stop_moving_dc: arrow |
| 33 | stopMoving | movement | 35 | scene_object_stop_moving_default | actor2d_stop_moving: crossbow; target_stop_moving: target; projectile_stop_moving: arrow |
| 34 | moveTick | movement | 36 | scene_object_move_tick_default | player2d_move_tick: crossbow; target_move_tick: target; actor2d_move_tick: arrow |
| 35 | getTimerId | animation | 37 | scene_object_get_timer_id_default | actor2d_get_timer_id: crossbow target arrow; animated3d_get_timer_id: panel |
| 36 | isMoving | movement | 38 | scene_object_is_moving_default | actor2d_is_moving: crossbow target arrow |
| 37 | isRunning | animation | 39 | scene_object_is_running_default | animation_is_running: crossbow target arrow panel |
| 38 | moveToAndDrop | space3d | 3A | scene_object_move_to_and_drop_default | object3d_move_to_and_drop: panel |
| 39 | setPosition | position | 3B | scene_object_set_position | actor2d_set_position: crossbow target arrow |
| 4C | unk4E | position | 4E | scene_object_unk4e |  |
| 4D | redrawOverlapping | visibility | 4F | scene_object_redraw_overlapping | target_redraw_overlapping: target; projectile_redraw_overlapping: arrow; object3d_redraw_overlapping: panel |
| 4E | hitboxOverlaps | position | 50 | scene_object_hitbox_overlaps |  |
| 4F | boundsOverlap | position | 51 | scene_object_bounds_overlap |  |
| 50 | slot5B | position | 52 | scene_object_slot5b_default |  |
| 51 | slot5C | position | 53 | scene_object_slot5c_default |  |
| 54 | isEnabled | position | 56 | scene_object_is_enabled_default |  |
| 55 | getExitIndex | position | 57 | scene_object_get_exit_index_default |  |
| 3A–4B, 52/53, 56, 58, 59 | type tests | (Object.is/as) | 3C–4D, 54/55, 58, 5A, 5B | | |

### Other vtables

| vtable | slots → unit |
|---|---|
| Object3DVtbl (8) | `space3d`: slot00, findSupport, isBelow, isAboveOnScreen, isInFrontOf, overlaps3d, moveToAtElev, dropToSupport (Object3D's, the panel) |
| AnimationVtbl (1) | `animation.playOnce` |
| MoverVtbl (1) | `movement.placeAt` (mover_place_at) |
| TargetVtbl (3) | 00 `movement.placeAt`; 01 moveTick (`target_move_tick_or_stop`, dead: nothing calls the slot); 02 `target.checkEdge` (target_wrap_at_edge) |
| ProjectileVtbl (4) | 00 `movement.placeAt`; 01 moveTick (`projectile_move_tick`, dead); 02 `arrow.stepMove` (projectile_step_move); 03 `arrow.tryStep` (projectile_try_step) |
| ControlPanelVtbl (9) | 00 `animation.playOnce`; 01–08 `panels` (TiroPanel's getVisibleHeight) |
| GameVtbl (7) | 00 `game_input.handleMessage`; 01–06 `game` (createPlayer … onCreate) |
| SceneVtbl (13) | 00, 05, 07 `gallery` (handleMessage, createScreen, create); the rest `scene` |
| Backdrop/GridBackdropVtbl (19/20) | `backdrop` (slot 00 create = TiroBackdrop's grid and walls; 01–06 grid; 07–12 defaults; 13 createWithGrid) |
| ConditionVtbl (3) | `game` (FlagCondition; CompoundCondition is dead) |
| FrameVtbl (1) | `object_create.getCell` |

## State

`core/game.zig`'s `Game` is TiroGame + Game flattened (`g_game` and
`g_tiroGame` are the game itself) plus every DGROUP global (`g_score` →
`g.score`, `i16`, BSS so 0 at start; `g_noiteWnd` → `g.noiteWnd`; the three
strip tables, checked by `noite -p tiro initdata`; the key latches
`g_keyRightHeld`/`g_keyLeftHeld`/`g_keySpaceHeld`; the WaveMix state and
the five waves; `g_occupancyCount/Object` → `g.occupancy`; `g_crossbow`,
`g_targets[4]`, `g_arrows[1]` → `g.crossbow`, `g.targets`, `g.arrows`;
`g_mainWindow` = `plat.windowHandle()`). No counterpart:
`g_setSystemTimer`/`g_killSystemTimer` (`g.setSystemTimer`), the instance
and module handles, the module path (the host's `Program.dir`,
`\TIRO`). Leaf units take the narrowest thing, as in NOITE. One `Game`
per running TIRO. `srand(GetTickCount())` in `tiro_create_targets` is
`g.rand.seed(plat.ticks())`: the targets' identities follow from the
virtual time of TIRO's WM_CREATE.

The backdrop: NOITE's pixel contract (top-down WinG DIB, `wingBitBlt`,
`textOut` into a `Surface`) for its one bitmap, `surface()`. The score box
(`tiro_draw_score`: " %04d" / "-%04d", one `TextOut` per character, the
DC's default font) draws on it and `tiro_blit_score_box` blits the box.

## Reading TIRO (medium model, /Od)

- Code is far: one segment per module, calls `CALLF`, returns `RETF n`.
  Game code is far pascal, Ghidra `__stdcall16far`, parameters listed
  **reversed** (`target_hit(this, index, backdrop, hwnd)` is source
  `(hwnd, backdrop, index)` → `hit(g, obj, bd, index)`); `this` at
  `[BP+6]`. `__cdecl16far*` where the caller pops.
- Data is near: pointers and `this` are 2 bytes, DS = SS = DGROUP `1090`;
  strings and globals are `1090:xxxx`, pushed as one word (far API
  arguments as `PUSH DS`/`PUSH off`).
- A virtual call is `MOV BX,[SI]; CALLF [BX+off]`: slot = off / 4. The
  vtables are DGROUP tables of far `seg:off` slots; the adjustor thunks
  (`<target>_thunk[_k]`, `JMPF` to the target) adjust `SS:[BX+4]`.
- Every function starts `MOV AX,frame; CALLF _aFchkstk` (the stack probe,
  modelled by a call-fixup: ignore it). `/Od` adds a `JMP` to the epilogue
  after each `return`, long-form jumps and a compare chain for every
  `switch`: the bodies are long but literal.
- The decompile keeps SceneObject fields reached through the virtual base
  as `*(int *)((int)&p->…stepY + vbptr->sceneObjectOffset)` (the field at
  the same offset of the SceneObject); DATA.md "Decompiler residue". The
  14 sub-object NULL tests print as `this == s_coordFormat + 8` (a PRE
  comment says so): they are `if (sub == NULL)`.
- The virtual-call arguments are typed (FUNCTIONS.md "Decompiler setup");
  when one looks wrong, take the pushes from the disassembly (`.ref/*.c`).

## Fixes (BUGS.md T-section)

| Bug | Flag | Unit | What the fix changes | In `all` |
|---|---|---|---|---|
| T1 SPACE latch never set | `tiro_space_latch` | gallery | the fire branch sets `g_keySpaceHeld` = 1 (WM_KEYUP already clears it): a held SPACE fires once, key repeats do nothing | yes |
| T2 arrow spent on a press that fires nothing | `tiro_arrow_spent_on_shot` | gallery | `lives` is decremented only when the arrow is free and fires | **choice** (owner) |
| T3 `lives == 1` end test skipped | `tiro_end_test_at_most_one` | gallery | the four target-tick tests are `lives <= 1`: the game always ends | yes |
| T4 the 15th arrow cut off, 16th never fired | `tiro_last_arrow_lands` | gallery | the end test becomes `lives <= 0` and the arrow not moving, and SPACE with `lives <= 0` does nothing: 16 shots, each flies to its end and can score (implies T3) | **choice** (owner) |
| T5 hit by x alone | `tiro_hit_needs_row` | gallery | the second stage matches a target when the x ranges overlap with touching edges counted (`a <= t+75 and t <= a+55`) **and** the y ranges overlap (arrow y..y+27, target y..y+95), in the same 2, 3, 1, 0 order | yes |
| T6 restore strip one step too wide | `tiro_target_restore_one_step` | render | `target_restore_background`'s rect (and its `addDirtyRect`) adds \|stepX\| once, as `mover_restore_background` | yes |

Each unit ports the buggy code and keeps the fixed path only under its
flag (`g.fixes.tiro_…`). T1 matters only with key repeats (Platform). The
Latent (`perspective_backdrop_set_layer`, dead) and Harmless (`WinMain`'s
uninitialised return, not ported: the host ignores exit codes) entries get
no flag.

## Integration

TIRO is ported and on (`src/tiro/root.zig` `ready`): NOITE's WinExec runs
it, `--minigame tiro` plays it alone, the web page offers it.

### The launch from NOITE

`handler_3fhall` (`src/handlers/3fhall.zig`) right-click on the door
shuffled to 1: `WinExec("<CD>tiro\tiro.exe")` and timer 0x14. The host
matches `tiro` to `tiro.program` (`main.minigames`): TIRO's task starts
`--minigame-startup` ms later (1500; its WinMain: `app.start`, which first
runs the static initialiser `initStaticConditions`, as `_cinit` does before
WinMain), FindWindow("Tiro ao Alvaro")
succeeds on NOITE's next 0x14 tick, NOITE posts **0x40b** (lParam =
NOITE's window); AppWndProc stores `g_noiteWnd` and, on its next message,
posts **0x40c**; NOITE hides itself. The end test sends TIRO's own
WM_DESTROY (nested, as SendMessage, while the target tick is still
running; the tick then goes on, as the original's): the handler stops and
frees the waves, closes WaveMix and MCI and posts **0x40a** (wParam
`g_score > 0`, lParam the sign-extended score) to `g_noiteWnd`;
AppWndProc kills timer 1 and posts WM_QUIT, which comes after the posted
messages and before any timer (`core/queue.zig`), so no target tick runs
again and one result is posted. The host then runs `app.exit`, destroys
the window and activates NOITE, which shows itself, adds the score (a
negative one lowers it) and goes to `3fprisao` (won) or back to `3fhall`
with a life less (or `6fsaida`). NOITE's 0x40a handler, as the original,
has no guard: it would act on a second result too; TIRO cannot post one
before its WM_QUIT. NOITE's WM_SYSTIMER check (window gone without a
result → 0x40a loss) is covered by the host's window lifetime. Nothing
changed in NOITE. `--minigame-stub` keeps the stub (a win after the
hello) instead.

### Standalone

- `noite --minigame tiro [--headless …]`: TIRO alone (task 0, its title,
  `\TIRO` directory); prints its result (0x40a to hwnd 0 goes nowhere; the
  host records it).
- Web: `web_main.minigames` has TIRO as `noite_start`'s minigame 2;
  `MINIGAMES` in `web/noite.js` and the "Jogo" select of `web/index.html`
  ("Jogar só o minijogo: Tiro ao Álvaro"); `tools/web/files.py` looks a
  minigame's names up at the disc root, then in its directory (`TIRO\`),
  as `Sim.open` does. On the on-screen pad (one-button mode, or a
  minigame alone on a touch screen) the keys follow the program whose
  window is on top (`noite_top_program`): for TIRO LEFT, a fire button
  (key 32) and RIGHT instead of the four arrows (`PAD_KEYS` in
  `web/noite.js`, a proposal: question 6).

## Platform: every key to a minigame, key repeat

- **Keys.** SDL and the web page pass the arrows, Enter, Esc and Space;
  `Sim.filterInput` decides: NOITE (task 0 being NOITE) gets Enter, Esc
  and Space only with `--skip-videos` (to skip a video, as before), a
  minigame task (or a minigame alone, `Sim.minigame_alone`) gets every
  key and skips no video.
- **Repeat.** One generator, in `Sim`, on the program's clock, for every
  backend: a WM_KEYDOWN that passes the filter starts it (`delay` ms to
  the first repeat, then one every `period` ms, each a WM_KEYDOWN with
  lParam `0x40000001`); its WM_KEYUP or a focus loss (SDL, the page, the
  harness's `focus 0`) ends it; only the last key pressed repeats, and a
  press the filter swallows ends it. The repeats come from `Sim.poll` (the
  host routes them to the active window) and their deadline is in
  `Sim.nextDue`, so the headless clock steps to them. SDL drops the OS's
  repeats (`SDL_KeyboardEvent.repeat`), the page the browser's
  (`e.repeat`).
- **Rate and defaults** (`sim.KeyRepeat`): Windows 3.1's 500 ms delay and
  33 ms period; `--key-repeat DELAY,PERIOD|off`. On by default in the SDL
  window and the web page (`interactive_default`), off headless
  (`headless_default`, one constant to flip: question 4), so the scripts
  written before the repeats play as they did.
- **Held keys elsewhere.** NOITE latches its arrows (BUGS.md B50): its
  scripts play the same with the repeats on (`full.input`,
  `b50-arrow-overlap.input`). ENCAIXE's DOWN restarts its 55 ms fall
  timer on every repeat (E5): held, with 33 ms repeats, the piece stops
  falling, the original's behaviour; `--fix all` closes the guard.

## Tests

- **Planner** `tools/tiro_plan.py --start MS (--win|--lose) [--relative-to
  MS]` (MS: TIRO's WM_CREATE, 0 alone, WinExec + 1500 from NOITE):
  simulates the game on the virtual clock, down to what decides a hit
  (USER's timer table order, every `rand()`, the targets' steps, wraps,
  pair guards, hit animations and respawns, the arrow's Bresenham flight
  and the occupancy grid it queries, stale cells included, both hit
  stages), and plans 15 SPACE presses with the arrow free, 110 ms or more
  apart, each with the same outcome in the Original and the Corrigida: a
  win hits girls only, a loss travecos or nothing. `--check FILE` /
  `--trace FILE` simulate a script; the trace is the port's, tick for
  tick (checked on random games, Original and Corrigida). Rerun it when
  the start time moves.
- **Scripts** (`tools/play/`), each Original and `--fix all`:
  - `tiro-alone-win.input` (`--minigame tiro --ms 60000`): 14 girls,
    `result won 2100`;
  - `tiro-alone-lose.input` (`--ms 60000`): `result lost -750`;
  - `tiro-endless.input` (`--ms 30000 --key-repeat 500,33`): SPACE held
    3 s. Original: the repeats take `lives` past 1 between target ticks
    (T1, T3), no result; `--fix all`: one shot, the game goes on, no
    result either;
  - `tiro-3fhall-win.input` / `tiro-3fhall-lose.input` (`--scene 3fhall`):
    the door this run's shuffle gives TIRO, NOITE hidden (`dump`), the
    planner's shots (`--start 3500`), `result won 2100` and `3fprisao`
    with the score added / `result lost -1050`, `3fhall` with a life
    less and the score lowered;
  - `full.input` and `onebutton.input`: hall door 2 is the real TIRO with
    the planner's winning shots (in the one-button run too: TIRO is played
    with its keys).
- **Smoke**: `tools/smoke.py --minigame tiro [--monkey SEED]`: random
  LEFT/RIGHT and SPACE presses 110 ms or more apart for 60 s, seeds 1–5;
  no panic or leak, and a result.
- **Web**: `tools/web/test.py` plays "Jogo" = Tiro ao Álvaro: TIRO
  starts and SPACE unloads the crossbow (`bestse`).
- **Unit tests** (optional, tagged): `oracle=emulated` from tools/oracle
  (far code, the default mode; DGROUP is 1090; `_aFchkstk` 1080:00e4 is
  in the EXE and runs as is), as worth it: `target_wrap_at_edge`,
  `target_restore_background` (T6), `crossbow_aim`,
  `tiro_backdrop_create`'s wall cells, `projectile_try_step`,
  `tiro_draw_score` (`asset` with Fundtiro.bmp).

## Units

20 units, 318 functions to port; 112 dead, 480 absorbed (368 thunks, 66
defaults, 46 type tests), 175 replaced (81 CRT, 94 imports). Hard deps are
direct calls into another unit (`noite -p tiro next --blocked`); virtual
calls are soft (`unit dep show`). Level = the longest chain of hard deps
below the unit: the units of one level can run in parallel once the
levels below are done.

| Level | Unit | Fns | Size | Calls into |
|---|---|---|---|---|
| 0 | `dib` | 8 | 3.7 KB | — |
| 0 | `position` | 27 | 1.2 KB | — |
| 0 | `sound` | 8 | 0.9 KB | — |
| 1 | `backdrop` | 28 | 3.7 KB | dib, position |
| 1 | `object_create` | 27 | 3.0 KB | dib, position |
| 1 | `render` | 18 | 2.7 KB | dib, position |
| 1 | `space3d` | 24 | 4.0 KB | position |
| 2 | `lists` | 17 | 2.0 KB | object_create, position, render |
| 2 | `occupancy` | 17 | 1.4 KB | position, render |
| 3 | `scene` | 15 | 0.8 KB | backdrop, lists, object_create |
| 3 | `visibility` | 20 | 2.0 KB | lists, position, render |
| 4 | `animation` | 27 | 1.8 KB | position, render, visibility |
| 5 | `movement` | 20 | 3.0 KB | animation, backdrop, position, render, visibility |
| 5 | `panels` | 17 | 1.6 KB | animation, dib, lists, object_create, position, render |
| 6 | `arrow` | 5 | 1.0 KB | movement, object_create, occupancy, position, sound, visibility |
| 6 | `target` | 8 | 3.0 KB | animation, dib, movement, object_create, occupancy, position, sound, visibility |
| 7 | `gallery` | 3 | 5.8 KB | animation, arrow, backdrop, movement, position, scene, sound, target |
| 7 | `game` | 18 | 2.1 KB | arrow, lists, object_create, occupancy, panels, scene, target |
| 8 | `app` | 8 | 1.3 KB | backdrop, dib, game, sound |
| 8 | `game_input` | 3 | 4.2 KB | game, lists, position, render, space3d |

Ready first (parallel): `dib`, `position`, `sound`; then `backdrop`,
`object_create`, `render`, `space3d`; then `lists`, `occupancy`; then
`scene`, `visibility`; then `animation`; then `movement`, `panels`; then
`arrow`, `target`; then `gallery`, `game`; then `app`, `game_input`.
The largest single functions: `tiro_scene_handle_message` (5.6 KB,
`gallery`), `game_handle_message` (3.7 KB, `game_input`), `target_respawn`
(1.2 KB, `target`).

`position` also owns `message_box_printf` (ENCAIXE's `lists` has it): in
TIRO the SceneObject constructor calls it, and with it in `lists` the
call graph had a cycle (lists → object_create → lists).

## Tracker

`noite -p tiro …` (or `NOITE_PROGRAM=tiro`): DB `db/tiro.sqlite` (local;
`noite -p tiro import` rebuilds it from Ghidra and the plan), plan
`db/tiro-plan.tsv` (committed), tree `src/tiro/`, index
`src/tiro/units.zig`, worktrees `work/tiro-<unit>/` on branches
`port/tiro-<unit>`. A worktree's `.ref/env.sh` sets `NOITE_PROGRAM`, so
`noite test`/`check` there need no `-p`. `@orig` tags are checked per
program (NOITE scans `src/` minus `src/encaixe/` and `src/tiro/`; TIRO
scans `src/tiro/`); `finish` refuses files outside the program's tree.
The program's layout (`tools/cli/src/noite/program.py` `TIRO`): CRT
segment 1080, imports 10a8, DGROUP 1090, far 4-byte vtable slots, virtual
calls `CALLF [BX+off]`; the far adjustor thunks' targets come from their
`JMPF` (the importer reads it: Ghidra lists no callee for a `JMPF`). The
"Other vtables" table above is `deps.TIRO_OTHER_VTABLES`.

```
noite -p tiro next [--blocked]      # units ready to claim
noite -p tiro start <unit>          # worktree work/tiro-<unit>/
noite -p tiro show <addr|name>      # row, decompile (--asm), callers/callees
noite -p tiro unit show <unit>
noite -p tiro check -w <unit>       # @orig tags vs TIRO's DB
noite -p tiro initdata -w <unit>    # `// @orig g_*` defaults vs TIRO's DGROUP
noite -p tiro finish <unit>         # from the main checkout
noite -p tiro failed <unit> "why" / release <unit>
```

## How to port a TIRO unit

1. `noite -p tiro next`, `noite -p tiro start <unit>`, then work in
   `work/tiro-<unit>/` (`. .ref/env.sh`; tools via `nix develop -c`).
   Scratch output and frame dumps go in the worktree's `zig-out/`, never
   `/tmp`.
2. Read the unit's `.ref/*.c` (plate, decompile, disassembly),
   `.ref/types.md`, `.ref/strings.md`; DATA.md / GAME.md for the class and
   the rules. Ghidra (`mcp__ghidra__*`, `program="TIRO.EXE"`) for anything
   else.
3. Read the ENCAIXE unit of the same name (`src/encaixe/<unit>.zig`,
   ported and checked): most engine functions are the same source.
   Transcribe each TIRO function from TIRO's own decompile/asm, reusing
   ENCAIXE's Zig where they agree; note in the commit body every function
   whose code differs from ENCAIXE's (and how). Never call an ENCAIXE
   unit, except the state-free delegation allowed in Decisions.
4. Write only `src/tiro/<unit>.zig` (or `behaviour/<unit>.zig`): replace
   each declared dispatcher's body, keep its signature; one
   `// @orig <seg:off> <ghidra_name>` per function (TIRO addresses;
   `(absorbed)` for the defaults and thunks a dispatcher's arm covers).
   Public names: the Ghidra name minus the unit's class prefix, camelCase
   (`target_respawn` in `target` → `target.respawn`).
5. Faithful first: port each T-bug as the code does it and put the fix
   only behind its flag (`g.fixes.tiro_…`, table above). NOITE's
   conventions hold (integers `i16`/`i32` with wrapping where the original
   overflows, `cstr`, `?*T`, message boxes through `plat.messageBox`,
   every PostMessage/SendMessage/SetSystemTimer at the same point,
   `error.Fatal` only where the original ends). Allocate what the
   original `new`s from `g.local()`.
6. Call other units' dispatchers, never a local copy. If a declared
   signature cannot express the original, `noite -p tiro failed <unit>
   "slot <name> (<owner>) needs …"`.
7. Tests optional; when written, `oracle=emulated` from tools/oracle,
   `asset` from `assets/TIRO/`, `documented` from Ghidra.
8. `noite test`, commit (commit skill), `noite -p tiro finish <unit>` from
   the main checkout.

## Questions for the owner

1. **T2 in Corrigida?** (`tiro_arrow_spent_on_shot`) A SPACE press while
   the arrow flies costs an arrow. It may be a penalty for spamming the
   key; the fix makes only shots count. Now in `Fixes.choices`.
2. **T4 in Corrigida?** (`tiro_last_arrow_lands`) The game ends right
   after the 15th press, so only 14 shots can score. The fix lets all 16
   fly and score (a different end condition). Now in `Fixes.choices`.
3. **T1 in Corrigida** (`tiro_space_latch`, in `all`): auto-fire on a held
   SPACE goes away. The unused latch says it was meant, but players may
   have liked holding the key. Keep it in `all`?
4. **Key repeat in headless runs.** Off by default now
   (`sim.KeyRepeat.headless_default`); on everywhere would be faithful
   (the scripts already pass with it on).
5. **The repeat rate**: 500 ms / 33 ms (Windows 3.1's usual defaults),
   unless you know the machine the game was tuned on.
6. **Touch screens**: the fire button in place of UP/DOWN on the pad for
   TIRO (`PAD_KEYS`) — keep it?
