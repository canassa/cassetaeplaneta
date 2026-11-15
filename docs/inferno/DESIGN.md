# Native port of INFERNO.EXE — design

INFERNO.EXE ("Inferno", the platformer in hell that NOITE's `3fpapmal`
starts when the pope's punishment video ends) in Zig, next to NOITE's,
ENCAIXE's and TIRO's ports. NOITE's `docs/DESIGN.md`, TIRO's
`docs/tiro/DESIGN.md` and the zig-developer skill hold for everything this
file does not override. Ghidra (program `INFERNO.EXE`, through the tracker
snapshot `noite -p inferno show`) is the specification; `GAME.md` (rules,
protocol), `DATA.md` (classes, vtables, globals), `FUNCTIONS.md` (names,
dead code), `QUALITY.md` (the large-model `/Od` build), BUGS.md H1–H8.

## Decisions

- **Own tree, INFERNO's code; TIRO's Zig as the template.** INFERNO runs
  TIRO's engine sources at nearly the same version (the same 91-slot
  SceneObjectVtbl, "Faltou redefinir…", `MAX_OBJECT_QTY`, the occupancy
  matrix, the same module order), but it is not the same program:
  - it is built **large model** (far code *and* far data, `/Od`, stack
    probes): `this`, the vptr, the vbptr and every data pointer are far,
    the vtables live in the code segment `1080`, and every engine struct
    is wider than TIRO's (Mover/Animation fields +4, Player2D +8, the
    SceneObject tail moved: DATA.md §4). The layouts are NOITE-like, the
    code TIRO's;
  - the engine version differs in four vtables: Object3DVtbl has 7 slots
    (no `isInFrontOf`), BackdropVtbl 20 (no `queryRectFirst`; new
    `isGridBackdrop`, `asGridBackdrop`), GridBackdropVtbl 21; SceneObject
    slots 56–5A are INFERNO's own (`isBig`, `isPlatform`, `isProp`,
    `isHazard`, `isPowerUp`);
  - there is **no StatusBar, no draw list, no Animated3D/Object3D, no
    ControlPanel class**: no table, no ctor. The Frame has no hit box (the
    SceneObject has one), the ObjectList is the far `head` only, the
    exit message is 0x401 (TIRO 0x402), the draw and tick paths realise
    the palette and skip TIRO's `PostMessage` notifications;
  - four own classes, all Actor2D: Hero (← Player2D, the player), Platform,
    Prop (drinks, rocks, the cross) and Hazard (← Prop), and
    InfernoGame/InfernoScene/InfernoBackdrop in the roles of TIRO's Tiro*
    classes; the game code (`1068`, 23 KB) is twice TIRO's.

  So INFERNO gets its own units under `src/inferno/`, ported from its own
  functions with its own `@orig` addresses, and it calls no TIRO unit.
  **Sharing TIRO's units was weighed and rejected,** for TIRO's reasons
  against sharing ENCAIXE's (docs/tiro/DESIGN.md "Decisions"), which
  weigh more here:
  - every engine function takes TIRO's `Game`/`Object`/`Backdrop`; sharing
    means making 20 finished, checked TIRO units generic over the program
    (comptime types, renumbered Backdrop slots, the hit box in the Frame
    or in the object, a draw list or none, StatusBar/ControlPanel kinds or
    none), which changes TIRO's code after it was checked, for INFERNO's
    sake;
  - an `@orig` tag maps to one program's address (`noite check` scans only
    the program's own tree), and `noite finish` refuses a unit that edits
    another program's tree: a shared function would need two tags and a
    tracker that checks one file against two DBs;
  - the two builds' code differs in many small ways (FUNCTIONS.md: 23 of
    the 775 shared names differ in callees or return kind; the far-pointer
    NULL tests, the palette realisations), so a shared body would carry
    `if (inferno)` branches. A copy keeps each port a plain transcription
    of its own binary.

  The copy is cheap: the TIRO unit of the same name (`src/tiro/<unit>.zig`,
  ported and checked) is the starting point for every engine unit (same
  slot names, same signatures, the same fields under other offsets). An
  INFERNO agent transcribes each function from INFERNO's decompile/asm,
  reuses TIRO's Zig where the two agree, and says in its commit body which
  functions differ from TIRO's and how.
- **Shared, because identical or not game code:** the platform layer
  (`src/platform/`, host included), `core/msg.zig`, `core/queue.zig`,
  `core/cstr.zig`, `core/stub.zig`, `core/errors.zig`, `core/fixes.zig`
  (one `Fixes`, H-flags prefixed `inferno_`), the Win16 data types (`Dib`,
  `BitmapInfoHeader`, `RgbQuad`, `Rect`). INFERNO calls no `rand`. Segment
  1000 is byte-identical to NOITE's and TIRO's: INFERNO's
  `dib.rowsCopy32`/`rowsCopyTransparent32` (1000:0114 / 1000:0024)
  delegate to NOITE's `src/dib.zig`, as TIRO's do. An INFERNO function may
  delegate to a NOITE or TIRO function only when that function takes no
  program state (in practice the `dib` copies and `read_dib_info`) and the
  two decompiles are shown identical in the unit's commit; the INFERNO
  wrapper carries INFERNO's `@orig` tag.
- **Faithful first, the owner's rule.** H1–H8 are reproduced as they are
  by default; each fix exists only behind its own `Fixes` flag (off by
  default). Corrigida (`Fixes.all()`) takes the clear bugs (H1, H2, H5,
  H6, H7, H8); H3 and H4 change what a result is worth and are `choices`
  until the owner says (Owner questions).
- **The class methods live in their class units.** TIRO puts a class's
  SceneObject overrides in the slot's behaviour unit (Target's moveTick in
  `movement`). INFERNO's overrides call the game code directly
  (`hero_move_tick` → `hero_jump_step`, `platform_tick`, `prop_rock_tick`;
  `hazard_move_tick` → `hazard_hit_player` → `hazard_tick`), so that
  would make `movement` call `hero`/`ledge`/`prop` and those call
  `movement` back: a hard-dependency cycle. Every method of the four game
  classes (segment 1068) is in its class unit (`hero`, `ledge`, `prop`,
  `hazard`); the slot units' dispatchers call them by their declared
  names (`movement.moveTick`'s `.hero` arm is `hero.moveTick`). The
  skeleton declares those overrides in the class units, as it declares
  the dispatchers, so a dispatcher compiles before its class is ported.
- **What INFERNO never builds is dead.** Besides the code nothing reaches
  (no caller, no live vtable slot: 147 functions), 13 functions are
  reached only through a class INFERNO has no table or ctor for, or
  through a slot nothing calls: the ControlPanel and StatusBar destructor
  chains behind `Game.controlPanel`/`Game.statusBar` (always NULL),
  `status_bar_draw_text`, `portable_pick_up`/`portable_drop` and
  `perspective_project_point` (behind `isPortable`), `hero_is_big` (slot
  56). They are `dead` in the plan; their callers keep the original
  guard, and the guarded body, which cannot run, is a panic naming the
  class (`@panic("INFERNO builds no ControlPanel")`) with the address range
  in a comment. Nothing else changes: `game_handle_message`'s input cases,
  dead by flow (GAME.md), and `game_take_exit` are ported as written.
- **Two programs in one process**, as ENCAIXE and TIRO (`src/platform/
  host.zig`): INFERNO is a task with its own state, queue, timers, window
  and screen; the protocol runs through the platform as in Windows, and
  BUGS.md H1/H2 come out of it unchanged (Integration). The host needs
  nothing new for INFERNO.
- **The task's heap.** INFERNO's `operator new` is `_fmalloc`; it frees
  little. `Game.local()` (an arena on the task's allocator, freed by
  `Game.destroy`) takes every `new` of INFERNO, as TIRO's.
- **The playthroughs stay on their route** (the owner's decision).
  `full.input` and `onebutton.input` never take the pope's door (3fpapmal),
  so they never start INFERNO. It is tested by its own scripts only
  (`inferno-*.input`, alone and from `--scene 3fpapmal`).

## Source layout

```
src/inferno/root.zig          program root: core, units, `ready`, `program` (host.Program)
src/inferno/core/             types only (not units)
  game.zig                    Game: InfernoGame + every INFERNO DGROUP global; queue, send/post, timers, heap
  object.zig                  Object (kinds hero / platform / prop / hazard), parts, Frame, ObjectList
  world.zig                   Scene, Backdrop (one bitmap), OccupancyGrid + Occupancy, UpdateList, Condition
src/inferno/<unit>.zig        module units
src/inferno/behaviour/        behaviour units (one group of SceneObject slots)
src/inferno/units.zig         generated index (`noite -p inferno unit sync`)
```

## Object model

As TIRO's (one `Object`, a `kind`, every part present), with INFERNO's
classes and layouts. Four kinds are constructed:

| Kind | Class (vtables `1080:`) | Parts live | Globals |
|---|---|---|---|
| `hero` | Hero ← Player2D ← Actor2D ← Mover + Animation (7dc0, 7dc4, 7dc8) | base, mover, anim, player2d, hero | `g_hero` (= `Game.player`) |
| `platform` | Platform ← Actor2D (PlatformVtbl 89c2, 89ca, 89ce) | base, mover, anim, platform | `g_platforms[4]` |
| `prop` | Prop ← Actor2D (PropVtbl 8b42, 8b52, 8b56) | base, mover, anim, prop | `Platform.item`, `g_rocks[6]`, `g_cross` |
| `hazard` | Hazard ← Prop (PropVtbl 8cca, 8cda, 8cde) | base, mover, anim, prop | `g_hazards[6]` |

`Object.is/as` are the type-test slots 3A–4B, 52/53 and 57–59
(`isPlatform`, `isProp`: prop and hazard, `isHazard`); `isPowerUp` (5A) is
a real slot (Prop's returns `powerUp`), `isBig` (56) is never called. The
Hazard's own fields (`index`, `unk4A`, `active`, `unk4E`) sit where the
Prop's are: `obj.prop`. Struct origins are `// @orig Struct+0xNN` with
INFERNO's offsets (DATA.md §4); the vtordisp words and the virtual bases
have no counterpart. A method that overrides a SceneObject slot gets the
SceneObject subobject in the original and reads its class at negative
offsets (`HeroSO`: Hero = this − 0x62; Platform/Prop/Hazard − 0x52): in the
port that is just `obj`. `core/object.zig` marks the SceneObject fields
measured for the skeleton (+0x450–0x46e); a unit that finds one wrong
fixes it there in its own commit.

## Virtual slots

Each slot is one `pub fn` dispatcher (named after the vtable field) in the
unit that owns it, already declared in the skeleton with its final
signature and a `stub.unported` body; it switches on `obj.kind` and calls
one function per original implementation, each tagged `@orig`. The default
stub (`scene_object_*_default`, absorbed) is the `else` arm; slots with
only a default (00–07, 0C–11, 38, 4C, 50/51, 54/55) are a dispatcher
whose one arm is it. Thunks (464), defaults (71) and type tests (43) are
`absorbed`. Signatures: `(g: *Game, obj: *Object, <args in source order>)`;
hwnd and hdc parameters are dropped; `Backdrop *` stays; out-parameters
join the return value (`world.RectQuery`). They are TIRO's signatures
(the same sources). Flattened single-class tables are plain functions:
Game (`game`, `game_input`), Scene (`scene`, `hell`), Backdrop
(`backdrop`), Condition (`game`), Frame (`object_create`).

The game classes' overrides are in their class units ("Decisions") and
declared there in the skeleton: `hero.play/tick/moveToEdgeV/stopMovingDc/
stopMoving/moveTick`, `ledge.play/moveToEdgeH/moveTick`,
`prop.restoreBackground/moveToEdgeH/moveTick`, `hazard.stopMoving/
moveTick`. Slot 5A's dispatcher `isPowerUp` is in `prop` (its only
override).

### SceneObject slots (kinds: hero, platform, prop, hazard)

INFERNO's slot numbers (byte offset = 4 × slot), the same as TIRO's for
every slot below 56; field names are TIRO's (4C `getSceneName` is TIRO's
`unk4E`). Generated from the tracker's vtables (thunks resolved); an impl
in backquotes is a class unit's function.

| slot | behaviour | unit | default | overrides (impl: kinds) |
|---|---|---|---|---|
| 00 | getWorldX | position | scene_object_get_world_x_default |  |
| 01 | getWorldDepth | position | scene_object_get_world_depth_default |  |
| 02 | getWorldElev | position | scene_object_get_world_elev_default |  |
| 03 | getSizeW | position | scene_object_get_size_w_default |  |
| 04 | getSizeH | position | scene_object_get_size_h_default |  |
| 05 | getSizeD | position | scene_object_get_size_d_default |  |
| 06 | getAnchorX | position | scene_object_get_anchor_x_default |  |
| 07 | getAnchorY | position | scene_object_get_anchor_y_default |  |
| 08 | getX | position | scene_object_get_x | mover_get_x: hero platform prop hazard |
| 09 | getY | position | scene_object_get_y | mover_get_y: hero platform prop hazard |
| 0A | getStepX | position | scene_object_get_step_x_default | mover_get_step_x: hero platform prop hazard |
| 0B | getStepY | position | scene_object_get_step_y_default | mover_get_step_y: hero platform prop hazard |
| 0C | slot11 | position | scene_object_slot11_default |  |
| 0D | setElevation | position | scene_object_set_elevation_default |  |
| 0E | setAnchor | position | scene_object_set_anchor_default |  |
| 0F | setSize | position | scene_object_set_size_default |  |
| 10 | setWorldElev | position | scene_object_set_world_elev_default |  |
| 11 | drawBounds | position | scene_object_draw_bounds_default |  |
| 12 | addDirtyRect | render | scene_object_add_dirty_rect |  |
| 13 | computeOverlap | render | scene_object_compute_overlap |  |
| 14 | restoreBackground | render | scene_object_restore_background | mover_restore_background: hero platform; prop_restore_background (`prop.restoreBackground`): prop hazard |
| 15 | drawDirtyTo | render | scene_object_draw_dirty_to | mover_draw_dirty_to: hero platform prop hazard |
| 16 | draw | render | scene_object_draw | animation_draw: hero platform prop hazard |
| 17 | drawClipTo | render | scene_object_draw_clip_to |  |
| 18 | drawClip | render | scene_object_draw_clip |  |
| 19 | erase | render | scene_object_erase | animation_erase: hero platform prop hazard |
| 1A | slot1F | render | scene_object_slot1f_default | animation_slot1f: hero platform prop hazard |
| 1B | redraw | visibility | scene_object_redraw | actor2d_redraw: hero platform prop hazard |
| 1C | hideAndInvalidate | visibility | scene_object_hide_and_invalidate |  |
| 1D | blitToDc | visibility | scene_object_blit_to_dc | actor2d_blit_to_dc: hero platform prop hazard |
| 1E | invalidate | visibility | scene_object_invalidate | mover_invalidate: hero platform prop hazard |
| 1F | slot24 | visibility | scene_object_slot24 | mover_slot24: hero platform prop hazard |
| 20 | hide | visibility | scene_object_hide | mover_hide: hero platform prop hazard |
| 21 | show | visibility | scene_object_show | actor2d_show: hero platform prop hazard |
| 22 | occupy | occupancy | scene_object_occupy |  |
| 23 | vacate | occupancy | scene_object_vacate |  |
| 24 | attach | occupancy | scene_object_attach | actor2d_attach: hero platform prop hazard |
| 25 | canStep | occupancy | scene_object_can_step_default | actor2d_can_step: hero platform prop hazard |
| 26 | isStepBlocked | occupancy | scene_object_is_step_blocked |  |
| 27 | nextFrame | animation | scene_object_next_frame_default | actor2d_next_frame: hero platform prop hazard |
| 28 | prevFrame | animation | scene_object_prev_frame_default | actor2d_prev_frame: hero platform prop hazard |
| 29 | play | animation | scene_object_play_default | hero_play (`hero.play`): hero; platform_play (`ledge.play`): platform; animation_play: prop hazard |
| 2A | playIdle | animation | scene_object_play_idle_default |  |
| 2B | stopAndRedrawDc | animation | scene_object_stop_and_redraw_dc_default | actor2d_stop_and_redraw_dc: hero platform prop hazard |
| 2C | stopAndRedraw | animation | scene_object_stop_and_redraw_default | actor2d_stop_and_redraw: hero platform prop hazard |
| 2D | tick | animation | scene_object_tick_default | hero_tick (`hero.tick`): hero; animation_tick: platform prop hazard |
| 2E | stop | animation | scene_object_stop_default | actor2d_stop: hero platform prop hazard |
| 2F | moveTo | movement | scene_object_move_to_default | mover_move_to: hero platform prop hazard |
| 30 | moveToEdgeH | movement | scene_object_move_to_edge_h_default | mover_move_to_edge_h: hero; platform_move_to_edge_h (`ledge.moveToEdgeH`): platform; prop_move_to_edge_h (`prop.moveToEdgeH`): prop hazard |
| 31 | moveToEdgeV | movement | scene_object_move_to_edge_v_default | hero_move_to_edge_v (`hero.moveToEdgeV`): hero; mover_move_to_edge_v: platform prop hazard |
| 32 | stopMovingDc | movement | scene_object_stop_moving_dc_default | hero_stop_moving_dc (`hero.stopMovingDc`): hero; actor2d_stop_moving_dc: platform prop hazard |
| 33 | stopMoving | movement | scene_object_stop_moving_default | hero_stop_moving (`hero.stopMoving`): hero; actor2d_stop_moving: platform prop; hazard_stop_moving (`hazard.stopMoving`): hazard |
| 34 | moveTick | movement | scene_object_move_tick_default | hero_move_tick (`hero.moveTick`): hero; platform_move_tick (`ledge.moveTick`): platform; prop_move_tick (`prop.moveTick`): prop; hazard_move_tick (`hazard.moveTick`): hazard |
| 35 | getTimerId | animation | scene_object_get_timer_id_default | actor2d_get_timer_id: hero platform prop hazard |
| 36 | isMoving | movement | scene_object_is_moving_default | actor2d_is_moving: hero platform prop hazard |
| 37 | isRunning | animation | scene_object_is_running_default | animation_is_running: hero platform prop hazard |
| 38 | moveToAndDrop | position | scene_object_move_to_and_drop_default |  |
| 39 | setPosition | position | scene_object_set_position | actor2d_set_position: hero platform prop hazard |
| 4C | getSceneName | position | scene_object_get_scene_name_default |  |
| 4D | redrawOverlapping | visibility | scene_object_redraw_overlapping |  |
| 4E | hitboxOverlaps | position | scene_object_hitbox_overlaps |  |
| 4F | boundsOverlap | position | scene_object_bounds_overlap |  |
| 50 | slot5B | position | scene_object_slot5b_default |  |
| 51 | slot5C | position | scene_object_slot5c_default |  |
| 54 | isEnabled | position | scene_object_is_enabled_default |  |
| 55 | getExitIndex | position | scene_object_get_exit_index_default |  |
| 56 | isBig | — | scene_object_slot56_default | hero_is_big: hero (dead: nothing calls the slot; no dispatcher) |
| 5A | isPowerUp | prop | scene_object_slot5a_default | prop_is_power_up (`prop.isPowerUp`): prop hazard |
| 3A–4B, 52/53, 57–59 | type tests | (Object.is/as) | | |

### Other vtables

`docs/inferno/SLOTS.tsv` is this table for the tracker (`unit dep infer`).

| vtable | slots → unit |
|---|---|
| Object3DVtbl (7) | no live table (no Object3D is built); its calls are in dead code only (mapped to `position`) |
| AnimationVtbl (1) | `animation.playOnce` (animation_play_once in every table) |
| MoverVtbl (1), PlatformVtbl (2), PropVtbl (4) | 00 `movement.placeAt` (mover_place_at in every table); PlatformVtbl 01 moveTick = `platform_tick` (`ledge`); PropVtbl 01 moveTick (`prop_rock_tick`, Hazard's `hazard_tick`), 02 stepMove (`prop_drink_step`), 03 tryStep (`prop_drink_respawn`): `prop`. Slots 01–03 are only called directly: no dispatcher |
| GameVtbl (7) | 00 `game_input.handleMessage`; 01–06 `game` (createPlayer … onCreate; 03/04 defaults) |
| SceneVtbl (13) | 00, 05, 07 `hell` (handleMessage, createScreen, create); the rest `scene` |
| Backdrop/GridBackdropVtbl (20/21) | `backdrop` (00 create = InfernoBackdrop's floor wall; 01–05 grid; 06–11 defaults; 12 isGridBackdrop, 13 asGridBackdrop; 14 createWithGrid) |
| ConditionVtbl (3) | `game` (FlagCondition; CompoundCondition is dead) |
| FrameVtbl (1) | `object_create.getCell` |

## State

`core/game.zig`'s `Game` is InfernoGame + Game flattened (`g_game` and
`g_infernoGame` are the game itself; no draw list) plus every DGROUP
global (`g_score` → `g.score`, `i16`, BSS so 0 at start; `g_lives` 5;
`g_noiteWnd`; `g_started`; the twelve strip tables, checked by `noite -p
inferno initdata`; the key latches `g_key*Held`; the clock `g_startTick`,
`g_timeUp`, `g_lastReportTick`; the WaveMix state and the four wave
handles; `g_occupancyCount/Object` → `g.occupancy`; `g_hero`, `g_rocks`,
`g_platforms`, `g_cross`, `g_hazards`, `g_rockOrder`, `g_hazardOrder`;
`g_mainWindow` = `plat.windowHandle()`) and the far BSS segment 1088's
`g_conditionTrue/False`. One field has no counterpart: `readyPosted`, the
state of H1's fix. No counterpart either: `g_setSystemTimer`/
`g_killSystemTimer` (`g.setSystemTimer`), the instance and module handles,
the module path (the host's `Program.dir`, `\INFERNO`). Leaf units take
the narrowest thing, as in NOITE. `GetTickCount` is `g.plat.ticks()` (the
virtual clock headless): the 3-minute limit follows from it, and there is
no `rand`, so a run is the same for the same input times.

The backdrop: NOITE's pixel contract (top-down WinG DIB, `wingBitBlt`,
`textOut` into a `Surface`) for its one bitmap, `surface()`. The score box
(`inferno_draw_score`: " %04d" / "-%04d", one `TextOut` per character,
colour 0x00EDEEEE, transparent) draws on it and `inferno_blit_score_box`
blits the 192×32 box at (416, 400).

## Reading INFERNO (large model, /Od)

- Code is far: one segment per module, calls `CALLF`, returns `RETF n`.
  Game code is far pascal, Ghidra `__stdcall16far`, parameters listed
  **reversed** (`hero_move_to_edge_v(this, dir, backdrop, seg, hwnd)` is
  source `(hwnd, backdrop, dir)` → `moveToEdgeV(g, obj, bd, dir)`); a far
  pointer split into `p, p_seg` is one parameter. `__cdecl16far*` where
  the caller pops (the 1068 helpers `inferno_score_add_*`,
  `inferno_create_*` take `(hwnd, backdrop)`).
- Data is far: `this` is a far pointer at `[BP+6]`, objects are reached
  as `LES BX,[BP+6]; … ES:[BX+k]`; DGROUP is `1090`, the engine's strings
  are in `1080` (`PUSH 0x1080; PUSH off`), the game's in DGROUP.
- A virtual call is `LES BX,[obj]; LES BX,ES:[BX]; CALLF ES:[BX+off]`:
  slot = off / 4. The vtables are in `1080`; the adjustor thunks
  (`<target>_thunk[_k]`) subtract 0x49e/0x4a0 through the large-model
  vtordisp form. The 376 live call sites carry Ghidra call-site overrides
  with the slot's signature; when one looks wrong, take the pushes from
  the disassembly (`.ref/*.c`).
- Every function starts `PUSH BP; MOV BP,SP; MOV AX,frame; CALLF
  1078:00f8` (`_aFchkstk`, modelled by a call-fixup: ignore it). `/Od`
  adds a `JMP` to the epilogue after each `return`, long-form jumps and a
  compare chain for every `switch`.
- The decompile keeps SceneObject fields reached through the virtual base
  as `*(int *)((int)&p[k].vtbl + vbptr->sceneObjectOffset + n)`: the field
  is at SceneObject + (that offset − 4); `mover_step`'s `&this[0x15].vtbl
  + off + 2` is `nextX` (+0x46c). The far NULL test is `SUB AX,k; OR
  DX,AX; JNZ`: `if (p == NULL)`.

## Fixes (BUGS.md H-section)

| Bug | Flag | Unit | What the fix changes | In `all` |
|---|---|---|---|---|
| H1 0x40c before every message | `inferno_ready_once` | app | AppWndProc posts 0x40c only while `g_noiteWnd` is set and `readyPosted` is not, then sets `readyPosted`: one "ready", after the hello | yes |
| H2 the time-out result reposted | `inferno_report_once` | hell | the clock block's grace second posts nothing; the result goes once, at the time-out; `WM_DESTROY` still comes 1 s later | yes |
| H3 a loss reports nothing | `inferno_loss_reports` | score | `inferno_lose_life` at 0 lives posts 0x40a (0, `g_score` − 1000) to `g_noiteWnd` before its `WM_DESTROY` | no (choice) |
| H4 End Task with a life left is a win | `inferno_close_forfeits` | hell | `WM_CLOSE` posts 0x40a (0, 0) — (0, `g_score` − 1000) with `inferno_loss_reports` — instead of the time-out's report | no (choice) |
| H5 running into a hazard is free | `inferno_side_hit_costs_life` | hero | `hero_collide`'s side hit of a small hero also calls `inferno_lose_life` (−500, a life, `sonicmor`, `WM_DESTROY` at 0) | yes |
| H6 a life lost wipes the grid | `inferno_hit_keeps_grid` | hazard | `hazard_hit_player` does not call `occupancy_grid_clear(grid, NULL)`: every object keeps its cells (the parked hazard vacates its own), the floor wall stays | yes |
| H7 scroll-zone landing keeps the stomp latch | `inferno_scroll_landing_clears_stomp` | hero | `hero_move_tick`'s scroll-zone landing clears `g_stompScored` too | yes |
| H8 every WM_DESTROY posts another | `inferno_destroy_once` | hell | the grace second's end posts one `WM_DESTROY` (`Game.destroyPosted`), so WM_QUIT comes; without it the clock panics naming H8 when the posted `WM_DESTROY` would post the next | yes |

Each unit ports the buggy code and keeps the fixed path only under its
flag (`g.fixes.inferno_…`). H1 and H2 are fixed where they start, in
INFERNO: NOITE's `3fpapmal` and `3fhall` stay as the original (they are
ported and faithful), and with the two flags on they simply receive one
0x40c and one 0x40a. H6's fix leaves `occupancy_grid_clear` unreached in
the Corrigida (clearing only the hazard's cells would not do: the parking
that follows vacates those cells again, and a vacate of a cell at 0 leaves
a phantom occupant, BUGS.md L11). The Harmless entries (the fourth hazard
strip, the rocks' hit boxes, the hero 2 px above the floor, the floor
wall's overrun, the dead branches, `WinMain`'s return) get no flag.

## Integration

**Finished**: every unit is ported, `ready = true`; NOITE's `3fpapmal`
runs the real INFERNO, `--minigame inferno` plays it alone, and the web
loader offers it ("Jogo" = Inferno, the four arrows on the touch pad).
Two things were found and fixed while integrating, in the port: the
handler's hero-animation timer called the `tick` slot (`hero_tick`, which
never counts a play-once strip down) instead of `animation_tick`
(1028:230f, a direct call in the original), so the first death strip
looped and the hero never lost a second life; and BUGS.md H8 (below).

### The launch from NOITE

`handler_3fpapmal` (`src/handlers/3fpapmal.zig`, ported) at the pope's
video's successful end: `WinExec("<CD>inferno\inferno.exe")` and timer
0x14. The host matches `inferno` to `inferno.program` (`main.minigames`);
while `inferno.ready` is false it keeps the stub (`Sim.winExec`: the hello
answered with one 0x40c, then a win), as now. Once ready: INFERNO's task
starts `--minigame-startup` ms later (1500; its WinMain: `app.start`,
which first runs `init_static_conditions`, as `_cinit` does), its
WM_CREATE builds the game (`inferno_game_on_create`), sets `g_started` and
starts system timer 1; FindWindow("Inferno") succeeds on NOITE's next 0x14
tick and NOITE posts **0x40b** (lParam = NOITE's window), which
AppWndProc stores in `g_noiteWnd`.

**H1/H2, reproduced.** From WM_CREATE on, AppWndProc posts **0x40c**
(wParam = its window) before every message it handles; before 0x40b that
is a PostMessage to window 0, which fails (the host's `postTo` returns
false for hwnd 0), and afterwards each one lands in NOITE's inbox. NOITE
(`3fpapmal`) hides itself on each. At the time-out the handler posts
**0x40a** (`g_lives`, `g_lives ? 500 : g_score − 1000`), restarts the
clock, reposts the same every ≥ 100 ms for a second (H2) and then posts
itself `WM_DESTROY` (waves stopped and freed, WaveMix and MCI closed);
AppWndProc posts WM_QUIT (it never kills timer 1) and the host runs
`app.exit` and destroys the window. NOITE's `3fpapmal` takes the first
0x40a (shows itself, `g_score += 500`, `3fhall`); the 0x40c and 0x40a
INFERNO posts after it reach the hall, whose ported handler reads them as
TIRO's (H1: it hides NOITE and marks its minigame running, and its
WM_SYSTIMER test, finding no "Tiro ao Alvaro" window, posts itself a lost
result: a life; H2: the next 0x40a is a TIRO win, +500 and `3fprisao`).
Nothing is added for this: the host already delivers what a task posts
to another task's window in order, at the poster's turn (a Win16 task runs
until its queue is empty, then the next: the host's `pump` loop), into
the receiver's posted queue (`core/queue.zig`, 8 messages; PostMessage to
a full queue fails, as Windows 3.1's default queue does). Traced
(`tools/play/inferno-3fpapmal-win.input`, INFERNO started at 17403): the
first 0x40a at 197403 sends NOITE to `3fhall`; the 0x40c that follow make
the hall's WM_SYSTIMER post itself a TIRO loss at 197453 and again at
197503 (3 lives → 1), and H2's repost, handled right after, is a TIRO
win: `3fprisao`, score +1000. At 2 lives or fewer H1 ends the game
(`6fsaida`).

**H8.** One second after the time-out the clock posts `WM_DESTROY` on
every message, the posted `WM_DESTROY` included, so the queue never
empties and WM_QUIT never comes: the original spins there for good
(Windows 3.1 runs no other task). The host would run the loop 50,000
messages a frame with NOITE going on, which is not what Windows did, so
the Original stops on a panic naming H8 (an "orig" line in the smoke);
`inferno_destroy_once` posts one `WM_DESTROY` and INFERNO quits at 181 s.

**H3, the FindWindow fallback.** At 0 lives `inferno_lose_life` posts
itself `WM_DESTROY`: no 0x40a. INFERNO quits, the host ends the task and
its window goes: FindWindow("Inferno") then fails (no live task has that
title, and the backend's stub never ran), so `3fpapmal`'s WM_SYSTIMER
test (`minigameRunning`, set by the 0x40c) posts itself 0x40a (0, 0): a
life, `3fhall` (or `6fsaida`), score unchanged. The trailing 0x40c land in
`3fpapmal` itself, where they only hide NOITE again before the loss shows
it.

`--minigame-stub` keeps the stub (one 0x40c, one 0x40a) instead: no H1/H2
there.

### Standalone

- `noite --minigame inferno [--headless …]`: INFERNO alone (task 0, title
  "Inferno", `\INFERNO` directory). `g_noiteWnd` stays 0, so every
  0x40c and 0x40a goes nowhere; the host records each 0x40a and prints
  the last (the harness's `result`).
- Web: `web_main.minigames` has INFERNO as `noite_start`'s minigame 7
  (after XILINDRO), `MINIGAMES` in `web/noite.js` and
  the "Jogo" select of `web/index.html` an entry ("Jogar só o minijogo:
  Inferno"), `tools/web/files.py` `MINIGAMES` `"inferno"` (files looked up
  in `\INFERNO`; `MARIO.MID` is found at the root), `tools/web/test.py`
  an INFERNO alone check (it starts; a held RIGHT, from the keyboard and
  the pad, walks the hero off his spot). **The touch pad**: INFERNO is played
  with LEFT, RIGHT (walk), UP (the jump) and DOWN (the low jump), so its
  `PAD_KEYS` entry is the four arrows, `inferno: [37, 38, 39, 40]` (the
  default pad's keys; listed so the pad follows the program on top as for
  TIRO), a proposal for the owner. The numpad + and − (0x6b/0x6d) jump
  too; the pad does not need them.

## Platform

Nothing new is needed to run INFERNO; what it relies on, all present
(one harness command is added for a test):

- **Keys**: LEFT/RIGHT/UP/DOWN reach a minigame task with key repeat
  (`Sim.filterInput`, `sim.KeyRepeat`). INFERNO latches every key
  (`g_key*Held`, cleared on WM_KEYUP), so repeats do nothing; a held
  LEFT/RIGHT walks until released, as on Windows. The numpad + and −
  (VK_ADD/VK_SUBTRACT) are not mapped by SDL or the page; scripts can send
  them (`key 107`, `key 109`). Optional, platform code: map SDL's keypad
  plus/minus and the page's `NumpadAdd`/`NumpadSubtract` to them for a
  minigame task.
- **Mouse**: swallowed by the handler; nothing needed.
- **Timers**: SetTimer/SetSystemTimer ids 10 (55 ms), 15 (180 ms), 0xc,
  3 (120 ms), 0xe (60 ms) and system timer 1 (55 ms): `core/queue.zig`.
- **Clock**: GetTickCount = `plat.ticks()`; a headless run needs `--ms` ≥
  the 3 minutes plus the grace second (and the startup from NOITE).
- **MCI**: `open mario.mid type sequencer alias musica`, `play musica
  notify`, `play musica from 0 notify` on MM_MCINOTIFY success, `pause
  musica`, `close musica`: `Sim.mciString` (aliases per task, as TIRO's).
- **WaveMix**: five waves, `sonicf.WAV` looped (`wave_play_loop`, loops
  0xffff), `sonicpul.wav` opened twice: `Sim`'s WaveMix.
- **Window close**: the backend's close goes to the active task as
  WM_CLOSE (the host), so closing the window while INFERNO is on top is
  BUGS.md H4's End Task: a win reported in the Original. The script
  command `close` delivers it (`tools/play/inferno-close.input`).

## Tests

INFERNO has no `rand`: the hazards, platforms, drinks and rocks follow a
fixed schedule from INFERNO's WM_CREATE (the hazards walk 5 px per 60 ms,
10 while the world scrolls), changed only by what the hero does. A
standing hero is reached by a hazard every 5.46 s.

- **Planner**: `tools/inferno_plan.py [--start MS] [-o FILE]` asks the
  port, as `tools/inv_plan.py` does: a probe plays the jumps planned so
  far and closes the window at T with `inferno_close_forfeits` and
  `inferno_loss_reports` on, so the report carries the score at T (+150 a
  stomp, −500 a life), and `inferno_side_hit_costs_life` on, so a side
  hit (H5) shows too. Greedy: bisect the first life lost, then try an UP
  press from 2.5 s before it, 60 ms apart, until one removes the hit. The
  hero stands at x 153 (under no platform, out of the scroll zone) and
  stomps all 32 hazards of the 3 minutes; the plan is checked in both
  versions.
- **Alone** (`tools/play/`), each the same with `--fix all`:
  - `inferno-alone-win.input` (`--minigame inferno --ms 180900`): the
    planner's 32 jumps, `result won 500` at 180.5 s (the score 4800 is not
    reported). It stops before 181 s, where the Original panics (H8);
    with `--fix all` INFERNO quits at 181000.
  - `inferno-alone-lose.input` (`--ms 30000`): no key; five hits, the last
    at 27300, `result none` (H3).
  - `inferno-close.input` (`--ms 3000`): `close` at 2 s, `result won 500`
    (H4; `--fix all,inferno_close_forfeits` gets lost 0).
- **From NOITE** (`--scene 3fpapmal`; the pope's video ends at 15903,
  INFERNO starts at 17403):
  - `inferno-3fpapmal-win.input` (`--ms 198300`): the planner's jumps
    shifted by 17403, `result won 500`, then `expect 3fprisao | 3fhall`:
    the Original's H1/H2 (2 lives lost, +1000, the prison), the fixed
    run's hall (+500). The harness's `expect NAME | NAME` checks the
    second name when a fix is on, as `result` does.
  - `inferno-3fpapmal-lose.input` (`--ms 50000`): no key; no report (H3),
    NOITE's WM_SYSTIMER finds the window gone at 44750: `3fhall`, a life
    less, the score unchanged, in both versions.
- **full.input / onebutton.input**: unchanged. Their route takes the
  hall's TIRO, pharaoh and disco doors, never the pope's punishment, so
  they never start INFERNO (Decisions).
- **Smoke**: `tools/smoke.py --minigame inferno [--fix all] [--monkey
  SEED]` (190 s): random holds of LEFT/RIGHT (100–1500 ms) and presses of
  UP/DOWN; a run passes with a result or none (the lives ran out, H3),
  and an Original run that reaches the time-out is an "orig" line (H8).
  `tools/smoke.py` (every scene) starts the real INFERNO from `3fpapmal`.
- **Unit tests** (optional, tagged): `oracle=emulated` from tools/oracle
  (large model: far code and far data, DGROUP 1090, `_aFchkstk` 1078:00f8
  runs as is; the oracle's large-model support is for NOITE), as worth
  it: `hero_start_jump`/`hero_jump_step` (the rise and fall ticks),
  `hazard_tick` (the spawn order), `platform_tick` (the respawn slot),
  `occupancy_grid_clear` (H6's wipe), `inferno_backdrop_create` (the
  floor row, its overrun), `inferno_draw_score` (`asset` with
  `Fundo.bmp`).

## Units

21 units, 244 functions to port; 160 dead (147 unreferenced, 13 behind a
class INFERNO never builds or a slot nothing calls), 578 absorbed (464
thunks, 71 defaults, 43 type tests), 178 replaced (92 CRT, 86 imports).
Hard deps are direct calls into another unit (`noite -p inferno next
--blocked`); virtual calls are soft (`unit dep show`). Level = the longest
chain of hard deps below the unit: the units of one level can run in
parallel once the levels below are done.

| Level | Unit | Fns | Size | Calls into |
|---|---|---|---|---|
| 0 | `dib` | 7 | 3.0 KB | — |
| 0 | `position` | 19 | 1.1 KB | — |
| 0 | `sound` | 9 | 1.0 KB | — |
| 1 | `animation` | 16 | 1.7 KB | position |
| 1 | `backdrop` | 29 | 4.8 KB | dib, position |
| 1 | `object_create` | 17 | 2.9 KB | dib |
| 1 | `render` | 12 | 2.6 KB | dib, position |
| 1 | `score` | 6 | 0.7 KB | dib, sound |
| 2 | `lists` | 12 | 1.7 KB | object_create, position, render |
| 2 | `movement` | 13 | 3.7 KB | animation, backdrop, position, render |
| 2 | `occupancy` | 9 | 1.3 KB | position, render |
| 3 | `scene` | 15 | 0.9 KB | backdrop, lists |
| 3 | `visibility` | 14 | 1.7 KB | lists, position, render |
| 4 | `ledge` | 6 | 3.3 KB | animation, movement, object_create, occupancy, position, score, visibility |
| 4 | `prop` | 11 | 5.2 KB | dib, movement, object_create, occupancy, position, visibility |
| 5 | `hazard` | 7 | 4.0 KB | animation, backdrop, movement, object_create, occupancy, position, prop, score, visibility |
| 5 | `hero` | 13 | 6.2 KB | animation, backdrop, ledge, movement, position, prop, render, score, visibility |
| 6 | `game` | 17 | 3.0 KB | hazard, ledge, lists, object_create, occupancy, prop, scene |
| 6 | `hell` | 3 | 3.5 KB | animation, backdrop, hazard, hero, ledge, movement, prop, scene, score, sound, visibility |
| 7 | `app` | 8 | 1.3 KB | backdrop, dib, game |
| 7 | `game_input` | 1 | 4.8 KB | game, lists, position |

Ready first (parallel): `dib`, `position`, `sound`; then `animation`,
`backdrop`, `object_create`, `render`, `score`; then `lists`, `movement`,
`occupancy`; then `scene`, `visibility`; then `ledge`, `prop`; then
`hazard`, `hero`; then `game`, `hell`; then `app`, `game_input`. The
largest single functions: `game_handle_message` (4.9 KB, `game_input`),
`inferno_scene_handle_message` (3.3 KB, `hell`), `hazard_hit_player` (1.9
KB, `hazard`), `hero_collide` (1.9 KB, `hero`), `hero_jump_step` (1.8 KB,
`hero`), `prop_cross_tick` (1.6 KB, `prop`).

Names that differ from TIRO's units: `ledge` is the Platform class (the
name `platform` is the platform layer's: `platform_tick` → `ledge.tick`,
`platform_play` → `ledge.play`); `hell` is InfernoScene (TIRO's
`gallery`); `score` holds the score helpers TIRO keeps in `target`;
`position` also owns TIRO's `space3d` slots (INFERNO builds no Object3D:
only their defaults are live, and `perspective_project_point` is dead);
there is no `panels`, `space3d`, `target` or `arrow`. `position` owns
`message_box_printf`, as TIRO's.

## Tracker

`noite -p inferno …` (or `NOITE_PROGRAM=inferno`): DB
`db/inferno.sqlite` (local; `noite -p inferno import` rebuilds it from
Ghidra and the plan), plan `db/inferno-plan.tsv` (committed), tree
`src/inferno/`, index `src/inferno/units.zig`, worktrees
`work/inferno-<unit>/` on branches `port/inferno-<unit>`. A worktree's
`.ref/env.sh` sets `NOITE_PROGRAM`, so `noite test`/`check` there need no
`-p`. `@orig` tags are checked per program; `finish` refuses files outside
the program's tree. The program's layout (`tools/cli/src/noite/
program.py` `INFERNO`): CRT segment 1078, imports 10a8, DGROUP 1090 plus
the far BSS 1088, far 4-byte vtable slots in `1080`, virtual calls
`CALLF ES:[BX+off]`. The non-SceneObject slot owners are
`docs/inferno/SLOTS.tsv` (rerun `noite -p inferno unit dep infer` after
changing it or the slot table above).

```
noite -p inferno next [--blocked]      # units ready to claim
noite -p inferno start <unit>          # worktree work/inferno-<unit>/
noite -p inferno show <addr|name>      # row, decompile (--asm), callers/callees
noite -p inferno unit show <unit>
noite -p inferno check -w <unit>       # @orig tags vs INFERNO's DB
noite -p inferno initdata -w <unit>    # `// @orig g_*` defaults vs INFERNO's DGROUP
noite -p inferno finish <unit>         # from the main checkout
noite -p inferno failed <unit> "why" / release <unit>
```

## How to port an INFERNO unit

1. `noite -p inferno next`, `noite -p inferno start <unit>`, then work in
   `work/inferno-<unit>/` (`. .ref/env.sh`; tools via `nix develop -c`).
   Scratch output and frame dumps go in the worktree's `zig-out/`, never
   `/tmp`.
2. Read the unit's `.ref/*.c` (plate, decompile, disassembly),
   `.ref/types.md`, `.ref/strings.md`; DATA.md / GAME.md for the class and
   the rules. Ghidra (`mcp__ghidra__*`, `program="INFERNO.EXE"`) for
   anything else.
3. Read the TIRO unit of the same name (`src/tiro/<unit>.zig`, ported and
   checked; for `hell` read `gallery`, for `score` `target`'s score
   helpers): most engine functions are the same source. Transcribe each
   INFERNO function from INFERNO's own decompile/asm (far pointers, the
   new offsets, the engine-version changes of "Decisions"), reusing TIRO's
   Zig where they agree; note in the commit body every function whose
   code differs from TIRO's (and how). Never call a TIRO unit, except the
   state-free delegation allowed in Decisions.
4. Write only `src/inferno/<unit>.zig` (or `behaviour/<unit>.zig`):
   replace each declared dispatcher's or override's body, keep its
   signature; one `// @orig <seg:off> <ghidra_name>` per function
   (INFERNO addresses; `(absorbed)` for the defaults and thunks a
   dispatcher's arm covers). Public names: the Ghidra name minus the
   unit's class prefix, camelCase, and without the program prefix
   `inferno_` (as TIRO drops `tiro_`): `hazard_hit_player` in `hazard` →
   `hazard.hitPlayer`; `platform_*` in `ledge` → `ledge.*`;
   `inferno_score_add_150` in `score` → `score.add150`,
   `inferno_lose_life` → `score.loseLife`; `inferno_create_hazards` →
   `hazard.createHazards`. Where that collides with an engine name, keep
   the class (`inferno_scene_ctor` in `scene` → `scene.infernoSceneCtor`).
   A dispatcher's arm for a game class calls that class unit's declared
   override.
5. Faithful first: port each H-bug as the code does it and put the fix
   only behind its flag (`g.fixes.inferno_…`, table above). NOITE's
   conventions hold (integers `i16`/`i32` with wrapping where the original
   overflows — `g_score` is 16-bit and can go negative —, `cstr`, `?*T`,
   message boxes through `plat.messageBox`, every PostMessage/SendMessage/
   SetTimer at the same point, `error.Fatal` only where the original ends).
   Allocate what the original `new`s from `g.local()`. A branch that needs
   a class INFERNO never builds keeps its guard and panics in its body
   ("Decisions").
6. Call other units' dispatchers, never a local copy. If a declared
   signature cannot express the original, `noite -p inferno failed <unit>
   "slot <name> (<owner>) needs …"`.
7. Tests optional; when written, `oracle=emulated` from tools/oracle,
   `asset` from `assets/INFERNO/`, `documented` from Ghidra.
8. `noite test`, commit (commit skill), `noite -p inferno finish <unit>`
   from the main checkout.

## Owner questions

1. **H3 in the Corrigida?** `inferno_loss_reports` makes a loss on lives
   report (0, `g_score` − 1000), the formula the time-out report already
   has, so INFERNO's points reach NOITE. After five −500 hits that is
   typically −3000 or less off NOITE's score, where the Original takes 0.
   A choice (off in `all`) until you say.
2. **H4 in the Corrigida?** `inferno_close_forfeits` makes closing
   INFERNO's window (End Task; in the port, the window's close while
   INFERNO is on top) a loss, (0, 0), instead of a 500 win. A choice (off
   in `all`) until you say.
3. **Numpad + and −** (the original's second jump keys): map them in SDL
   and the page (platform code), or leave the arrows only?
4. **H8 in the Original**: the original hangs a second after the time-out
   (every survived game). The port's Original stops there on a panic
   naming H8 (the web page shows its crash report); the alternative is to
   let the Original end as the Corrigida does. Which?
5. **The touch pad**: the four arrows (UP the high jump, DOWN the low
   one), a proposal like the other pads.
