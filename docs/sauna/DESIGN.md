# Native port of SAUNA.EXE — design

SAUNA.EXE ("Sauna Mista", the sauna's Pac-Man minigame) in Zig, next to
NOITE's, ENCAIXE's and TIRO's ports. NOITE's `docs/DESIGN.md`, TIRO's
`docs/tiro/DESIGN.md`, ENCAIXE's `docs/encaixe/DESIGN.md` and the
zig-developer skill hold for everything this file does not override.
Ghidra (program `SAUNA.EXE`, through the tracker snapshot `noite -p sauna
show`) is the specification; `GAME.md` (rules, protocol), `DATA.md`
(classes, vtables, globals, the maze), `FUNCTIONS.md` (names, dead code),
`QUALITY.md` (the large /Od build), BUGS.md P1–P8.

## Decisions

- **Own tree, SAUNA's code; TIRO's Zig as the template.** SAUNA is the
  engine TIRO is built from (the same sources and the same `/Od` code
  bodies: its module segments align to TIRO's in order, FUNCTIONS.md), but
  the builds are not the same program:
  - **large model**: far data, so every layout is NOITE's far one
    (`SceneObject.x` at +0x12, `Game.scene` at +4, pointers 4 bytes) and
    no `@orig Struct+0xNN` offset of TIRO's holds;
  - the **SceneObjectVtbl has 98 slots**: TIRO's 91 renumbered, plus NOITE's
    `slot00`, `slot01`, `enableRle`, `isRle`, `getSceneName` (0–4),
    ENCAIXE's `unk18` (1C) and the `isScrollTarget`/`slot43` pair (40/41),
    without TIRO's `unk4E`; the Scene (16), Backdrop (23) and GridBackdrop
    (24) tables are NOITE's (three more add-exit variants, the backdrop type
    tests), the AnimationVtbl has 6 slots (five AVI stubs before
    `playOnce`), the ControlPanelVtbl 14;
  - the Backdrop has **two** WinG bitmaps, as ENCAIXE's (TIRO one): the
    second holds the background with the dots, which `unk18` and the
    restores copy from;
  - the RLE machinery is linked (`enableRle`, `isRle`, `transrle.cpp`, the
    scaled and stretched copies of `1068`, two more 32-bit segments) but
    nothing calls `enableRle`: the whole RLE path is dead;
  - `game_handle_message` is a 5.9 KB revision whose mouse arms are live
    (the SAUNA handler returns 0 for the mouse: a left click walks Pacman);
  - its own classes: Pacman (← Player2D), Ghost (← Actor2D), the plain
    SceneObject dots, SaunaGame/SaunaScene/SaunaBackdrop in the roles of
    TIRO's Tiro* classes; the ControlPanel is concrete (no subclass).

  So SAUNA gets its own units under `src/sauna/`, ported from its own
  functions with its own `@orig` addresses, and it does not call TIRO's
  units. **Sharing them was weighed and rejected**, for TIRO's reasons
  against sharing ENCAIXE's, only stronger:
  - every engine function takes TIRO's `Game`/`Object`/`Backdrop`; sharing
    means making 17 finished TIRO units generic over the program (layouts,
    one or two bitmaps, renumbered and extra slots, kinds), which changes
    TIRO's code after it was checked, for SAUNA's sake;
  - an `@orig` tag maps to one program's address (`noite check` scans only
    the program's own tree) and `noite finish` refuses a unit that edits
    another program's tree: a shared function would need two tags, a
    tracker that checks one file against two DBs, and a SAUNA unit could
    not land a fix in it;
  - where the builds differ (above), a shared body would carry `if (sauna)`
    branches; a copy keeps each port a plain transcription of its binary.

  The copy is cheap: the TIRO unit of the same name (`src/tiro/<unit>.zig`,
  ported and checked) is the starting point for every engine unit (same
  slot names, same signatures; 372 of the 483 SAUNA functions left to
  port or classify carry the name of a TIRO function). A SAUNA agent
  transcribes each function from SAUNA's decompile/asm, uses TIRO's Zig
  where the two agree (ENCAIXE's for the second bitmap and `unk18`,
  NOITE's for the AVI and add-exit slots), and says in its commit body
  which functions differ from TIRO's and how. JARDIM is SAUNA's closest twin (large model, the same
  RLE code, FUNCTIONS.md "RLE path"), but it is being designed now, not
  ported, so it is no template.
- **Shared, because identical or not game code:** the platform layer
  (`src/platform/`, host included), `core/msg.zig`, `core/queue.zig`,
  `core/cstr.zig`, `core/crt.zig` (the CRT `rand`: SAUNA's `srand`/`rand`
  are MSVC's), `core/stub.zig`, `core/errors.zig`, `core/fixes.zig` (one
  `Fixes`, P-flags prefixed `sauna_`), the Win16 data types (`Dib`,
  `BitmapInfoHeader`, `RgbQuad`, `Rect`). SAUNA's `1000:0148`/`0234` are
  NOITE's 32-bit row copies (`dib_rows_copy_transparent32`/`dib_rows_copy32`):
  SAUNA's `dib` wrappers carry SAUNA's tags and may call NOITE's
  `src/dib.zig`, as TIRO's do, once the bytes are shown identical in the
  unit's commit. A SAUNA function may delegate to a TIRO, ENCAIXE or NOITE
  function only when that function takes no program state (in practice the
  `dib` copies and `read_dib_info`) and the decompiles are shown identical.
- **Faithful first, the owner's rule.** P1–P8 are reproduced as they are by
  default. Each fix exists only behind its own `Fixes` flag (off by
  default). Corrigida (`Fixes.all()`) takes the seven clear bugs; P3 is a
  choice (`Fixes.choices`) until the owner says (Owner questions).
- **Two programs in one process**, as ENCAIXE and TIRO (`src/platform/host.zig`):
  SAUNA is a task with its own state, queue, timers, window and screen; the
  protocol runs through the platform as in Windows. The host needs nothing
  new for SAUNA (Platform, below).
- **The heap.** SAUNA never frees most of what it allocates (the scene's
  dtor is dead; the strips and frames of the eight objects live until the
  end). `Game.local()` is the task's heap (an arena freed by
  `Game.destroy`), as TIRO's: every `operator new` / `_fmalloc` allocates
  there.

## Source layout

```
src/sauna/root.zig          program root: core, units, `ready`, `program` (host.Program)
src/sauna/core/             types only (not units)
  game.zig                  Game: SaunaGame + every SAUNA DGROUP global (the maze too); queue, send/post, timers, heap
  object.zig                Object (kinds pacman / ghost / dot / control_panel), parts, Frame, ObjectList
  world.zig                 Scene (+ SaunaScene), Backdrop (two bitmaps), OccupancyGrid + Occupancy, DrawList, UpdateList, Condition
src/sauna/<unit>.zig        module units
src/sauna/behaviour/        behaviour units (one group of SceneObject slots)
src/sauna/units.zig         generated index (`noite -p sauna unit sync`)
docs/sauna/SLOTS.tsv        the non-SceneObject slot owners and type tests (`unit dep infer`)
```

## Object model

As TIRO's (one `Object`, a `kind`, every part present), with SAUNA's
classes. Four kinds are constructed:

| Kind | Class (vtables) | Parts live | Built by |
|---|---|---|---|
| `pacman` | Pacman ← Player2D ← Actor2D ← Mover + Animation (80f6, 80fe, 8116) | base, mover, anim, player2d | `sauna_game_create_player` (`g_pacman`, `Game.player`) |
| `ghost` | Ghost ← Actor2D (9a90, 9a9c, 9ab4) | base, mover, anim | `sauna_scene_ctor` ×4, the same arguments |
| `dot` | SceneObject (41fc) | base | `sauna_scene_ctor`: `g_peanut` (3o1amend.bmp), `g_cork` (3o1rolha.bmp), pictures only |
| `control_panel` | ControlPanel ← Animated3D ← Animation + Object3D (7f0c, 7f44, 80cc) | base, o3d, anim, panel | `sauna_game_create_control_panel` (y 592: never seen) |

There is no status bar (`createStatusBar` returns NULL). `Object.is/as`
are the type-test slots 40–53 and 59/5A by the four live tables:
Pacman is a `scroll_target` (Player2D's `isScrollTarget`/`slot43`), a
`mover`, an `actor2d` and an `animation`, but **not** a `player` (Player2D
keeps SceneObject's `isPlayer`, so `asPlayer()` is NULL and the engine's
player paths in `game_handle_message` skip him); a Ghost is a `mover`,
`actor2d`, `animation`; the panel an `animation`, `object3d`,
`control_panel`; a dot nothing. Pacman and Ghost have no fields of their
own: the game state is in globals (`Game`). Struct origins are
`// @orig Struct+0xNN` with SAUNA's offsets (DATA.md); the vtordisp words
and the virtual bases have no counterpart. A method that overrides a
SceneObject slot gets the SceneObject subobject and reads its class at
negative offsets (Pacman −0x54, Ghost −0x4e): in the port that is `obj`.

## Virtual slots

Each slot is one `pub fn` dispatcher (named after the vtable field) in the
unit that owns it, already declared in the skeleton with its final
signature and a `stub.unported` body; it switches on `obj.kind` and calls
one function per original implementation, each tagged `@orig`. The default
(`scene_object_*_default`, absorbed) is the `else` arm. Signatures:
`(g: *Game, obj: *Object, <args in source order>)`; hwnd and hdc
parameters are dropped; `Backdrop *` stays; out-parameters join the return
value (`space3d.Support`, `world.RectQuery`). The signatures are TIRO's
skeleton's, plus the slots TIRO lacks (`isRle`, `getSceneName`, `unk18`,
the AVI stubs, the add-exit variants, `refreshPowerStrip`,
`chooseDirection`, `isNextStepFree`, `sendGhostsHome`). Flattened
single-class tables are plain functions: Game (`game`, `game_input`),
Scene (`scene`, `maze`), Backdrop (`backdrop`), ControlPanel (`panels`),
Condition (`game`), Frame (`object_create`).

A class's override of a SceneObject slot lives in the slot's unit, next to
its dispatcher (TIRO's rule; it keeps the hard dependencies acyclic):
Pacman's and the Ghosts' `occupy`/`vacate`/`canStep` are in `occupancy`
(and with them P1, P2, P6), their `restoreBackground` in `render` (the
eating and the win: P3), their moves and stops in `movement` (the click
walk: P5), Pacman's `tick`/`playIdle`/`stopAndRedraw(Dc)` in `animation`.
The class units hold what is no SceneObject slot: `ghost` (the AI and
`sendGhostsHome`), `score` (the score helpers the overrides call), `maze`
(the scene's handler).

`slot00`, `slot01` (defaults) and `enableRle` (dead) have no dispatcher:
nothing calls them. `slot62` (5E) and `slot65` (61) neither (TIRO's 57,
5A).

### SceneObject slots (kinds: pacman, ghost, panel = control_panel; dot = the SceneObject default)

SAUNA's slot numbers (byte offset = 4 × slot); `tiro` is TIRO's slot of
the same field (SAUNA *i* = TIRO *i*+5 for TIRO 00–16, *i*+6 for 17–39,
*i*+8 for 3A–4B, *i*+7 from 4D; — = no TIRO slot). Field names are DATA.md's
(TIRO's, NOITE's for 00–04 and 40/41, ENCAIXE's `unk18`). The `default`
column is SceneObject's own entry (what a dot runs); the overrides are the
three other live tables. Generated from the tracker's vtables (thunks
resolved). 00–02, 5E and 61 have no dispatcher (nothing calls them).

| slot | behaviour | unit | tiro | default | overrides (impl: kinds) |
|---|---|---|---|---|---|
| 03 | isRle | render | — | scene_object_is_rle |  |
| 04 | getSceneName | position | — | scene_object_get_scene_name |  |
| 05 | getWorldX | space3d | 00 | scene_object_get_world_x_default | object3d_get_world_x: panel |
| 06 | getWorldDepth | space3d | 01 | scene_object_get_world_depth_default | object3d_get_world_depth: panel |
| 07 | getWorldElev | space3d | 02 | scene_object_get_world_elev_default | object3d_get_world_elev: panel |
| 08 | getSizeW | space3d | 03 | scene_object_get_size_w_default | object3d_get_size_w: panel |
| 09 | getSizeH | space3d | 04 | scene_object_get_size_h_default | object3d_get_size_h: panel |
| 0A | getSizeD | space3d | 05 | scene_object_get_size_d_default | object3d_get_size_d: panel |
| 0B | getAnchorX | space3d | 06 | scene_object_get_anchor_x_default | object3d_get_anchor_x: panel |
| 0C | getAnchorY | space3d | 07 | scene_object_get_anchor_y_default | object3d_get_anchor_y: panel |
| 0D | getX | position | 08 | scene_object_get_x | mover_get_x: pacman ghost |
| 0E | getY | position | 09 | scene_object_get_y | mover_get_y: pacman ghost |
| 0F | getStepX | position | 0A | scene_object_get_step_x_default | mover_get_step_x: pacman ghost |
| 10 | getStepY | position | 0B | scene_object_get_step_y_default | mover_get_step_y: pacman ghost |
| 11 | slot11 | position | 0C | scene_object_slot11_default |  |
| 12 | setElevation | space3d | 0D | scene_object_set_elevation_default | object3d_set_elevation: panel |
| 13 | setAnchor | space3d | 0E | scene_object_set_anchor_default | object3d_set_anchor: panel |
| 14 | setSize | space3d | 0F | scene_object_set_size_default | object3d_set_size: panel |
| 15 | setWorldElev | space3d | 10 | scene_object_set_world_elev_default |  |
| 16 | drawBounds | space3d | 11 | scene_object_draw_bounds_default | object3d_draw_bounds: panel |
| 17 | addDirtyRect | render | 12 | scene_object_add_dirty_rect |  |
| 18 | computeOverlap | render | 13 | scene_object_compute_overlap |  |
| 19 | restoreBackground | render | 14 | scene_object_restore_background | pacman_restore_background: pacman; ghost_restore_background: ghost |
| 1A | drawDirtyTo | render | 15 | scene_object_draw_dirty_to | mover_draw_dirty_to: pacman ghost |
| 1B | draw | render | 16 | scene_object_draw | control_panel_draw: panel; player2d_draw: pacman; animation_draw: ghost |
| 1C | unk18 | render | — | scene_object_unk18 |  |
| 1D | drawClipTo | render | 17 | scene_object_draw_clip_to |  |
| 1E | drawClip | render | 18 | scene_object_draw_clip |  |
| 1F | erase | render | 19 | scene_object_erase | animation_erase: panel pacman ghost |
| 20 | slot1F | render | 1A | scene_object_slot1f_default | animation_slot1f: panel pacman ghost |
| 21 | redraw | visibility | 1B | scene_object_redraw | animated3d_redraw: panel; actor2d_redraw: pacman ghost |
| 22 | hideAndInvalidate | visibility | 1C | scene_object_hide_and_invalidate |  |
| 23 | blitToDc | visibility | 1D | scene_object_blit_to_dc | actor2d_blit_to_dc: pacman ghost |
| 24 | invalidate | visibility | 1E | scene_object_invalidate | mover_invalidate: pacman ghost |
| 25 | slot24 | visibility | 1F | scene_object_slot24 | mover_slot24: pacman ghost |
| 26 | hide | visibility | 20 | scene_object_hide | mover_hide: pacman ghost |
| 27 | show | visibility | 21 | scene_object_show | animated3d_show: panel; actor2d_show: pacman ghost |
| 28 | occupy | occupancy | 22 | scene_object_occupy | control_panel_occupy: panel; pacman_occupy: pacman; ghost_occupy: ghost |
| 29 | vacate | occupancy | 23 | scene_object_vacate | control_panel_vacate: panel; pacman_vacate: pacman; ghost_vacate: ghost |
| 2A | attach | occupancy | 24 | scene_object_attach | control_panel_attach: panel; actor2d_attach: pacman ghost |
| 2B | canStep | occupancy | 25 | scene_object_can_step_default | pacman_can_step: pacman; ghost_can_step: ghost |
| 2C | isStepBlocked | occupancy | 26 | scene_object_is_step_blocked |  |
| 2D | nextFrame | animation | 27 | scene_object_next_frame_default | animated3d_next_frame: panel; actor2d_next_frame: pacman ghost |
| 2E | prevFrame | animation | 28 | scene_object_prev_frame_default | animated3d_prev_frame: panel; actor2d_prev_frame: pacman ghost |
| 2F | play | animation | 29 | scene_object_play_default | animated3d_play: panel; animation_play: pacman ghost |
| 30 | playIdle | animation | 2A | scene_object_play_idle_default | pacman_play_idle: pacman |
| 31 | stopAndRedrawDc | animation | 2B | scene_object_stop_and_redraw_dc_default | animated3d_stop_and_redraw_dc: panel; pacman_stop_and_redraw_dc: pacman; actor2d_stop_and_redraw_dc: ghost |
| 32 | stopAndRedraw | animation | 2C | scene_object_stop_and_redraw_default | animated3d_stop_and_redraw: panel; pacman_stop_and_redraw: pacman; actor2d_stop_and_redraw: ghost |
| 33 | tick | animation | 2D | scene_object_tick_default | control_panel_tick: panel; pacman_tick: pacman; animation_tick: ghost |
| 34 | stop | animation | 2E | scene_object_stop_default | animated3d_stop: panel; actor2d_stop: pacman ghost |
| 35 | moveTo | movement | 2F | scene_object_move_to_default | pacman_move_to: pacman; mover_move_to: ghost |
| 36 | moveToEdgeH | movement | 30 | scene_object_move_to_edge_h_default | pacman_move_to_edge_h: pacman; mover_move_to_edge_h: ghost |
| 37 | moveToEdgeV | movement | 31 | scene_object_move_to_edge_v_default | pacman_move_to_edge_v: pacman; mover_move_to_edge_v: ghost |
| 38 | stopMovingDc | movement | 32 | scene_object_stop_moving_dc_default | pacman_stop_moving_dc: pacman; ghost_stop_moving_dc: ghost |
| 39 | stopMoving | movement | 33 | scene_object_stop_moving_default | pacman_stop_moving: pacman; ghost_stop_moving: ghost |
| 3A | moveTick | movement | 34 | scene_object_move_tick_default | pacman_move_tick: pacman; ghost_move_tick: ghost |
| 3B | getTimerId | animation | 35 | scene_object_get_timer_id_default | animated3d_get_timer_id: panel; actor2d_get_timer_id: pacman ghost |
| 3C | isMoving | movement | 36 | scene_object_is_moving_default | actor2d_is_moving: pacman ghost |
| 3D | isRunning | animation | 37 | scene_object_is_running_default | animation_is_running: panel pacman ghost |
| 3E | moveToAndDrop | space3d | 38 | scene_object_move_to_and_drop_default | object3d_move_to_and_drop: panel |
| 3F | setPosition | position | 39 | scene_object_set_position | actor2d_set_position: pacman ghost |
| 54 | redrawOverlapping | visibility | 4D | scene_object_redraw_overlapping | object3d_redraw_overlapping: panel |
| 55 | hitboxOverlaps | position | 4E | scene_object_hitbox_overlaps |  |
| 56 | boundsOverlap | position | 4F | scene_object_bounds_overlap |  |
| 57 | slot5B | position | 50 | scene_object_slot5b_default |  |
| 58 | slot5C | position | 51 | scene_object_slot5c_default |  |
| 5B | isEnabled | position | 54 | scene_object_is_enabled_default |  |
| 5C | getExitIndex | position | 55 | scene_object_get_exit_index_default |  |
| 40–53, 59/5A, 5D, 5F, 60 | type tests | (Object.is/as) | 3A–4B, 52/53, 56, 58, 59 | | |

### Other vtables

`docs/sauna/SLOTS.tsv` is this table for `noite -p sauna unit dep infer`.

| vtable | slots → unit |
|---|---|
| Object3DVtbl (8) | `space3d`: slot00, findSupport, isBelow, isAboveOnScreen, isInFrontOf, overlaps3d, moveToAtElev, dropToSupport (the panel's) |
| AnimationVtbl (6) | `animation`: 00 setAvi, 01 isAvi, 02–04 aviSlot2–4 (stubs: call isAvi, return 0), 05 playOnce |
| ControlPanelVtbl (14) | 00–05 `animation` (as AnimationVtbl); 06–0D `panels` (isOpen … drawInventoryItem) |
| MoverVtbl (1) | `movement.placeAt` (mover_place_at) |
| PacmanVtbl (2) | 00 `movement.placeAt`; 01 `animation.refreshPowerStrip` (pacman_refresh_power_strip, P4) |
| GhostVtbl (3) | 00 `movement.placeAt`; 01 `ghost.chooseDirection`; 02 `ghost.isNextStepFree` |
| GameVtbl (7) | 00 `game_input.handleMessage`; 01–06 `game` (createPlayer … onCreate) |
| SceneVtbl (16) / SaunaSceneVtbl (17) | 00, 05, 07 `maze` (handleMessage, createScreen, create); 10 `ghost.sendGhostsHome`; the rest `scene` |
| Backdrop/GridBackdropVtbl (23/24) | `backdrop` (slot 00 create = SaunaBackdrop's grid and walls; 01–06 grid; 07–12 defaults; 13–16 type tests, absorbed; 17 createWithGrid) |
| ConditionVtbl (3) | `game` (FlagCondition; CompoundCondition is dead) |
| FrameVtbl (1) | `object_create.getCell` |

## State

`core/game.zig`'s `Game` is SaunaGame + Game flattened (`g_game` and
`g_saunaGame` are the game itself) plus every DGROUP global: `g_score` →
`g.score` (`i16`, from 0), `g_lives` (3), `g_dotsLeft` (100),
`g_powerStrip` (0/4), `g_powerStartPending`, `g_pacmanDying`,
`g_deathFramesLeft`, the key latches (`g_keyLeftHeld` …, and
`game_handle_message`'s own `g_keyLeft` …), `g_noiteWnd`, `g_started`,
`g_handshakePending` (1), the two strip tables (`g_pacmanStripFiles` …,
`g_ghostStripFiles` …), `g_transparentColor` (0x0b), the WaveMix state and
the six waves, `g_occupancyCount/Object` → `g.occupancy`, `g_pacman`,
`g_peanut`, `g_cork`, `g_saunaScene`, and the two static conditions of
the far BSS segment 10a8. All initial values are checked against the EXE
by `noite -p sauna initdata` (53 fields; the five `initdata=skip` are
pointers the port keeps as slices or builds before WinMain). No
counterpart: `g_setSystemTimer`/`g_killSystemTimer` (`g.setSystemTimer`),
the instance and module handles, the module path (the host's
`Program.dir`, `\SAUNA`), `g_unk0F94` (read only by dead code).

**The maze** is `g.maze` (`g_maze`, DGROUP 031a): 30 rows of 40
characters plus the NUL (`core.game.initial_maze`, checked against the
EXE byte for byte): `1` wall, `2` peanut (96), `3` cork (4), space empty;
rows 27–29 are wall below the 460-px background. A dot eaten becomes a
space. The walls are marked once in the occupancy grid (16-px cells,
`sauna_backdrop_create`: count −1); the dots are drawn into the
backdrop's second bitmap (`sauna_scene_create`) and cleared from it when
eaten. Cell (col, row) covers x 16·col…+15, y 16·row…+15; Pacman sits at
x = 16c − 4, y = 16r and occupies a 2×3 block of cells (DATA.md).

**`rand()`** is MSVC's (`core/crt.zig` `Rand`, `g.rand`), seeded on
message 0x401 with `srand(GetTickCount())` = `g.rand.seed(plat.ticks())`:
the ghosts' random turns follow from the virtual time at which SAUNA
dispatches 0x401, which `game_init` posts during WM_CREATE. Headless runs
are deterministic: alone, WM_CREATE and 0x401 come at a fixed virtual
time; from NOITE, at the WinExec time plus `--minigame-startup` (1500 ms).
`ghost_choose_direction`'s rule 3 (`rand() % 4`) is the game's only
`rand()`; it runs whenever a ghost stops and every tick while a ghost is
aligned with Pacman within 16 px, so the sequence of calls depends on the
whole game, as in the original. Nothing else in SAUNA reads the clock.

The backdrop: NOITE's pixel contract for both bitmaps (`surface()`,
`surface2()`), as ENCAIXE's. The score box (`sauna_draw_score`: the box
restored from the background, then " %04d" / "-%04d", one `TextOut` per
character every 32 px from x 460, colour 0x00EDEEEE) draws on the first
and `sauna_blit_score_box` blits the 192×20 box at (416, 437).

## Reading SAUNA (large model, /Od)

- Code is far: one segment per module, calls `CALLF`, returns `RETF n`.
  Game code is far pascal, Ghidra `__stdcall16far`, parameters listed
  **reversed** (`pacman_refresh_power_strip(this, dir, backdrop, hwnd)` is
  source `(hwnd, backdrop, dir)` → `refreshPowerStrip(g, obj, bd, dir)`);
  `this` is a **far** pointer at `[BP+6]`.
- Data is far: pointers and `this` are 4 bytes, loaded with `LES BX`;
  DS = DGROUP `10b0` everywhere; a far pointer argument is two words
  (`backdrop`, `backdrop_seg` in Ghidra). The vtables are in code segment
  `10a0`; a virtual call is `LES BX,[obj]; LES BX,ES:[BX]; CALLF
  ES:[BX+off]`: slot = off / 4.
- Every function starts `MOV AX,frame; CALLF _aFchkstk` (1098:00f8, the
  stack probe, modelled by a call-fixup: ignore it). `/Od` adds a `JMP` to
  the epilogue after each `return`, long-form jumps and a compare chain for
  every `switch`: the bodies are long but literal.
- The decompile reaches SceneObject fields through the virtual base as
  `*(int *)((int)&p->…mover.lineErr + vbptr->sceneObjectOffset)` (the
  field at the same offset of the SceneObject: `+0x22` is `curStrip`);
  DATA.md "Decompiler residue". The virtual-call arguments are typed on all
  469 sites (FUNCTIONS.md "Cleanup"); when one looks wrong, take the pushes
  from the disassembly (`.ref/*.c`). Some calls in the 1080 overrides are
  left as raw `+0xd8`-style offsets: divide by 4 and read the slot table
  above.
- `isRle` is always 0 (`enableRle` is never called): the RLE branches of
  `scene_object_draw_clip_to`/`draw_dirty_to` are ported as unreachable
  (`@panic`, naming the dead path), as TIRO's dead arms are.

## Fixes (BUGS.md P-section)

| Bug | Flag | Unit | What the fix changes | In `all` |
|---|---|---|---|---|
| P1 only a move left or up meets the other actor | `sauna_meet_any_direction` | occupancy | `pacman_can_step`/`ghost_can_step` look through every occupied cell of the 2×2 block of the next position, skipping the mover's own, for the other kind (a ghost for Pacman, Pacman for a ghost); the first one found in row-major order decides as before | yes |
| P2 vacate clears other actors' cells | `sauna_vacate_own_cells` | occupancy | `pacman_vacate`/`ghost_vacate` clear only cells whose object is the mover; `occupy` does not take over a cell held by another actor (count and object stay), and a cell the mover leaves that lies under another actor's hit box is given back to that actor | yes |
| P3 a dot is eaten after Pacman leaves it | `sauna_eat_on_arrival` | render | `pacman_restore_background`'s four-cell dot test reads the new position (x, y) instead of (prevX, prevY), so the dot, its score and the win come with the step onto it | **no: a choice** |
| P4 power start/end face Pacman right | `sauna_power_keeps_heading` | animation | `pacman_refresh_power_strip` sets `g_powerStrip` + the strip of Pacman's heading (`Mover.direction` 1, 2, 4, 8 → strip 0, 1, 2, 3) whatever `dir` | yes |
| P5 a click shows the up or right picture | `sauna_click_faces_walk` | movement | `pacman_move_to` picks `g_powerStrip` + left 0 / right 1 / up 2 / down 3 by the larger leg of the line (x on a tie) | yes |
| P6 a ghost can take another life during the death | `sauna_no_catch_while_dying` | occupancy | while `g_pacmanDying`, `pacman_can_step`/`ghost_can_step` take no life (the meeting is ignored: the ghost walks on as through an empty cell) | yes |
| P7 an arrow restarts the death | `sauna_no_arrows_while_dying` | maze | while `g_pacmanDying`, `WM_KEYDOWN`'s arrows do nothing (no latch, no moveToEdge): the death strip plays once and Pacman reappears standing | yes |
| P8 five digits show a tenth of the score | `sauna_score_fits_box` | score | when the text is six characters (10000 or more), `sauna_draw_score` starts at x 428 instead of 460, so all six land inside the restored and blitted box (416–608) | yes |

Each unit ports the buggy code and keeps the fixed path only under its
flag (`g.fixes.sauna_…`). The flags live in their own block of
`core/fixes.zig`. Harmless entries get no flag: the dead
`pacman_stop_and_redraw_dc` strip, the power start one message late, the
`WM_DESTROY` that runs on with WaveMix closed, the right-click `playOnce`,
the off-screen panel, the dead code, `Player2D.lives/score`, and
`WinMain`'s uninitialised return (not ported: the host ignores exit codes).
The "left out as design" list (End Task forfeits, the shared ghost timer,
no turn buffering, eating a ghost stops Pacman, the AI, the cork's 0
points, the last life's missing −500, `ROLHAS01.WAV` on every `WM_PAINT`,
the game running while inactive) is ported as it is, with no flag.

## Integration

SAUNA is not ported yet: `src/sauna/root.zig` `ready = false`, so
NOITE's WinExec keeps the stub (`--minigame-result`), `--minigame sauna`
refuses with "not ported yet", and the web page does not offer it. The
root is wired in `src/main.zig`'s `minigames` already, as TIRO's was.

### The launch from NOITE

`handler_3fsauna` (`src/handlers/3fsauna.zig`, unchanged): the first right
click in the sauna plays the attendant once and its wave (GLOBO2.WAV,
1.415 s); its `MM_WOM_DONE` runs `WinExec("<CD>sauna\sauna.exe")` and
timer 0x14 (100 ms). The host matches `sauna` to `sauna.program`
(`main.minigames`): SAUNA's task starts `--minigame-startup` ms later
(1500; its WinMain: `app.start`, which first runs the static initialiser
`init_static_conditions`, as `_cinit` does before WinMain). WM_CREATE
builds the game and `game_init` posts **0x401** (srand, the ghosts start).
FindWindow("Sauna Mista") succeeds on NOITE's next 0x14 tick, NOITE posts
**0x40b** (lParam = NOITE's window); AppWndProc stores `g_noiteWnd` and
the first message that finds it set (timer 1 brings one within 50 ms)
posts **0x40c**, once; NOITE sets
`minigameRunning` and hides itself.

The end: the last dot's `pacman_restore_background` (win, wParam 0xffff)
or the third catch's `sauna_lose_life` (loss, wParam 0) sends SAUNA's own
`WM_DESTROY`, nested, as SendMessage, while the step or the tick that
caused it is still running (the original's order; the step then goes on,
"after the losing WM_DESTROY the current message runs on with WaveMix
closed"). The handler stops and frees the waves, closes WaveMix and MCI,
adds ±1000 and posts **0x40a** (wParam, lParam the sign-extended score) to
`g_noiteWnd`; it returns 0, so AppWndProc kills timer 1 and posts
WM_QUIT, which comes after the posted messages and before any timer
(`core/queue.zig`): no tick runs again and one result is posted (the
handler has no guard against a second `WM_DESTROY`; none can come before
the WM_QUIT). The host then runs `app.exit`, destroys the window and
activates NOITE, whose 0x40a handler realizes the palette, shows itself,
sets `minigameWon[4]`, adds the score and goes to `3fhall` (0xf0, 200),
or, on a loss that takes the last life, to `6fsaida`.

**NOITE's FindWindow fallback.** While `minigameRunning`, NOITE's
WM_SYSTIMER arm calls FindWindow("Sauna Mista") and posts itself
`(0x40a, 0, 0)` (a loss, no score) when the window is gone. The host
answers FindWindow from the task's window lifetime: SAUNA's window lives
until the host has run its WM_QUIT and `app.exit`, which is after its
0x40a is in NOITE's queue, so the fallback finds the window until the real
result is queued and never fires in a normal game; it fires (as on
Windows) only if SAUNA's task dies without a result (a panic in a SAUNA
unit during development). A window closed from outside (the host's
`.quit`, End Task) reaches the handler's `WM_DESTROY` with wParam 0: a
reported loss with −1000, as on Windows. The stubbed SAUNA (`--minigame-stub`, or `ready = false`)
keeps the stub's hello/ready/result instead.

The attendant's stale timer (BUGS.md, the 3ffarao `JTETRIS` race) depends
on when SAUNA's window appears and answers: the real SAUNA answers 0x40b
within 50 ms (timer 1), a different time than the stub's
`--minigame-reply`. `full.input` visits the sauna after the
pharaoh (below), so it never meets the race.

### Standalone

- `noite --minigame sauna [--headless …]`: SAUNA alone (task 0, its
  title, `\SAUNA` directory); prints its result (0x40a to hwnd 0 goes
  nowhere; the host records it).
- Web: `web_main.minigames` gets SAUNA as one of `noite_start`'s
  minigames; `MINIGAMES` in `web/noite.js` and the "Jogo" select of
  `web/index.html` ("Jogar só o minijogo: Sauna Mista"); `tools/web/files.py`
  finds SAUNA's names in `SAUNA\` (the EXE's directory). On the
  on-screen pad (one-button mode, or a minigame alone on a touch screen)
  the keys follow the program on top (`noite_top_program`): SAUNA's pad is
  the four arrows (`PAD_KEYS.sauna = [37, 38, 39, 40]`). A tap on the
  picture is a left click that SAUNA receives as is (the minigame filter
  passes the mouse): Pacman walks to it, so a touch screen can play by
  tapping as well as with the pad. A long press would be a right click on
  NOITE only; SAUNA's right click (playOnce) is harmless.

### Harness, smoke and full.input

- **Harness** (`--input`): `key left|right|up|down` (a press, released
  50 ms later), `hold KEY MS` for a held arrow, `click X Y` to walk Pacman
  (with its mouse move: below y 440 it also starts the off-screen panel's
  slide, harmless); `result` checks the 0x40a; `dump` frames. Nothing new.
- **Smoke**: `tools/smoke.py --minigame sauna [--fix all] [--monkey
  SEED]`: random arrow presses and holds plus random left clicks
  (`KEYS_FOR["sauna"]`), 60 s, seeds 1–5: no panic or leak; a result is
  not required (random play usually loses its three lives within the
  minute, and never clears the 100 dots). The scene smoke (`tools/smoke.py`
  over every scene) reaches `3fsauna` and, once `ready`, starts the real
  SAUNA when it right-clicks: it must keep running or end without a panic.
- **full.input**: today it does not enter the sauna. Once SAUNA is ready,
  the run gets a sauna detour with a planned win, placed after the
  pharaoh's ENCAIXE (back in the hall, before door 5, the disco): the
  hall door this run's shuffle gives the sauna, a right click on the
  attendant, the planner's keys from SAUNA's computed start, `result won`,
  back in the hall with the score added. Everything after it moves in time:
  re-plan what depends on the clock (the bar quiz question) and re-check
  the ending, in both versions (`--fix all,-avi_exit_ignores_timer`).
  `onebutton.input` stays as it is (optional: SAUNA can be played there by
  clicks).

## Platform

Nothing new is needed; what SAUNA uses already exists for TIRO and
ENCAIXE:
- every key and the mouse to a minigame task (`Sim.filterInput`); the key
  repeat (SAUNA latches its arrows, so repeats do nothing until a key-up);
- system timers (1, 10, 0x10, 0x11; 0xc for the panel) in USER's order
  (`core/queue.zig`), SendMessage nesting (`Game.send`);
- MCI's sequencer with `notify` (`pac.mid`, alias `musica`, replayed on
  `MM_MCINOTIFY` success; paused and resumed on `WM_ACTIVATE`);
- WaveMix: a looped wave (`control.wav`, `wLoops` 0xffff, so no
  `MM_WOM_DONE`), flush, free; `ROLHAS01.WAV` on every `WM_PAINT`;
- two WinG bitmaps per backdrop (ENCAIXE's), `TextOut` into a `Surface`;
- FindWindow by title ("Sauna Mista", already in `Sim.titles`).

To be checked when porting (not expected to need changes): the host
delivers `WM_PAINT` to a minigame task when it is shown (the paint wave),
and `GetTickCount` (`plat.ticks()`) is the task's virtual clock.

## Tests

- **Planner** `tools/sauna_plan.py --start MS (--win|--lose)
  [--relative-to MS]` (MS: SAUNA's WM_CREATE: 0 alone, the WinExec time +
  1500 from NOITE): an independent model of the game on the virtual clock,
  as `tools/tiro_plan.py` is for TIRO, down to what decides a catch and a
  turn: USER's timer order (Pacman's 0x10 before the ghosts' 0x11, the
  power's 10, timer 1), the MSVC `rand()` seeded at 0x401, each ghost's
  `ghost_choose_direction` (alignment within 16 px, `isNextStepFree`'s
  wall look-ahead, rule 3), the Bresenham moves in 16-px steps, the
  occupancy cells with the overwrite and clear of P1/P2, Pacman's dot
  test (P3) and the power's start one message late, the death's ticks.
  `--check FILE` / `--trace FILE` simulate a script; the trace is the
  port's, tick for tick (to be checked on random games, Original and
  Corrigida). The search: a tour of the 100 dots over the maze graph (16-px
  cells), driven by arrow presses timed to the step when the turn's first
  cell is free (no turn buffering), with a lookahead that keeps Pacman two
  cells or more from every ghost; a catch or a near meeting backtracks to
  the last decision and waits or takes another branch. Corks are eaten
  when it helps escape (eating ghosts is allowed but not needed).
  **One script for both versions**: `--fix all` leaves P3 out (a choice), and
  P1, P2, P6, P7 act only when an actor meets Pacman, P4, P5, P8 only on
  the picture, so a plan that keeps its distance plays the same in the
  Original and the Corrigida; the planner checks both and rejects a plan
  whose outcome or score differs. A loss plans three catches spread apart
  (each one after the previous death has ended, so P6 and P7 cannot add or
  remove one): the same −1000 in both versions. A plan with
  `--fix sauna_eat_on_arrival` is a separate script (its dots fall one step
  earlier, the power and the ghosts' random turns with them).
- **Scripts** (`tools/play/`), each run Original and `--fix all`, the same
  script, its result checked after the later of the two ends:
  - `sauna-alone-win.input` (`--minigame sauna --ms 300000`): the 100
    dots, `result won 10600` (9600 + 1000, if no ghost is eaten and no
    life lost; the planner prints the exact score);
  - `sauna-alone-lose.input` (`--ms 120000`): three catches, `result lost
    S` (S = 100 per peanut eaten − 500 − 500 − 1000);
  - `sauna-held-keys.input` (`--key-repeat 500,33`): arrows held for
    seconds; the latches swallow the repeats (no change against the same
    presses without repeat);
  - `sauna-click.input`: Pacman walked by left clicks, the picture shown
    (P5, `dump`) in both versions;
  - `sauna-3fsauna-win.input` / `sauna-3fsauna-lose.input` (`--scene
    3fsauna`): the right click on the attendant, NOITE hidden (`dump`), the
    planner's keys (`--start` = the click's time + 1415 + 1500, rounded to
    the host's step), `result won` and `3fhall` with the score added /
    `result lost`, `3fhall` with a life less and the score lowered;
  - `full.input` (and its `--fix` run): the sauna detour (above).
- **Smoke**: `tools/smoke.py --minigame sauna [--fix all] [--monkey SEED]`
  (above).
- **Web**: `tools/web/test.py` plays "Jogo" = Sauna Mista: SAUNA starts and
  an arrow moves Pacman (two dumps differ).
- **Unit tests** (optional, tagged): `oracle=emulated` from tools/oracle
  (large model: far code and data, DGROUP 10b0; `_aFchkstk` 1098:00f8 is
  in the EXE and runs as is), as worth it: `pacman_can_step` and
  `ghost_can_step` (P1, P2, P6), `ghost_choose_direction` with a seeded
  `rand`, `pacman_restore_background`'s dot test (P3), `sauna_backdrop_create`'s
  wall cells, `pacman_move_to`'s strip (P5), `sauna_draw_score`
  (`asset` with 3fpac2.bmp; P8).

## Units

20 units, 321 functions to port. Of SAUNA's 1,171 functions: 157 dead,
506 absorbed (387 thunks, 74 defaults, 40 type tests, and 5 set by hand:
the `slot00`/`slot01` defaults and the three `isScrollTarget`/`slot43`
tests), 187 replaced (98 CRT, 89 imports). Hard deps are direct calls into
another unit (`noite -p sauna next --blocked`); virtual calls are soft
(`unit dep show`). Level = the longest chain of hard deps below the unit:
the units of one level can run in parallel once the levels below are done.

| Level | Unit | Fns | Size | Calls into |
|---|---|---|---|---|
| 0 | `dib` | 8 | 3.6 KB | — |
| 0 | `position` | 27 | 1.4 KB | — |
| 0 | `sound` | 10 | 1.1 KB | — |
| 1 | `backdrop` | 27 | 4.1 KB | dib, position |
| 1 | `score` | 7 | 0.7 KB | dib, sound |
| 1 | `space3d` | 24 | 5.4 KB | position |
| 2 | `render` | 20 | 5.3 KB | dib, position, score |
| 3 | `object_create` | 22 | 4.0 KB | dib, position, render |
| 4 | `lists` | 17 | 3.2 KB | object_create, position, render |
| 5 | `scene` | 21 | 2.3 KB | backdrop, lists, object_create |
| 5 | `visibility` | 18 | 2.0 KB | lists, position, render |
| 6 | `animation` | 34 | 2.9 KB | position, render, visibility |
| 6 | `occupancy` | 17 | 4.3 KB | backdrop, position, render, score, visibility |
| 7 | `ghost` | 3 | 3.0 KB | animation, backdrop, position, visibility |
| 7 | `maze` | 3 | 4.4 KB | animation, backdrop, lists, scene, score, sound, visibility |
| 7 | `movement` | 17 | 4.7 KB | animation, occupancy, position, render, visibility |
| 7 | `panels` | 17 | 2.2 KB | animation, dib, lists, object_create, position, render |
| 8 | `game` | 18 | 3.0 KB | lists, object_create, occupancy, panels, scene |
| 9 | `app` | 8 | 1.4 KB | backdrop, dib, game, sound |
| 9 | `game_input` | 3 | 6.9 KB | game, lists, position, render, space3d |

Ready first (parallel): `dib`, `position`, `sound`; then `backdrop`,
`score`, `space3d`; then `render`; then `object_create`; then `lists`;
then `scene`, `visibility`; then `animation`, `occupancy`; then `ghost`,
`maze`, `movement`, `panels`; then `game`; then `app`, `game_input`.
The largest single functions: `game_handle_message` (5.9 KB,
`game_input`), `sauna_scene_handle_message` (3.5 KB, `maze`),
`sauna_scene_send_ghosts_home` (1.7 KB, `ghost`), `pacman_restore_background`
(1.7 KB, `render`).

Notes on the split:
- `render` owns `scene_object_is_rle` (slot 03), which
  `scene_object_dtor` (`object_create`) calls directly: so `object_create`
  waits for `render`, and `render` for `score` (the dot eaten by
  `pacman_restore_background` scores and sounds).
- `score` is a unit of its own so that the overrides in `render` and
  `occupancy` can call it without a cycle through `maze`.
- `position` owns `message_box_printf`, as TIRO's (the SceneObject
  constructor calls it).
- Six raw `+0x4` virtual calls (`animation_play`,
  `object3d_move_to_and_drop`, `ghost_stop_moving[_dc]`, `ghost_move_tick`
  and the handler) go through the Mover/Pacman/Ghost/Animation tables'
  slot 1 (`refreshPowerStrip`, `chooseDirection`, `isAvi`): `unit dep
  infer` cannot tell the table and adds no dep; they are soft anyway.

### Function statuses

- **dead (157)**: unreferenced code, and methods only in the tables of
  classes SAUNA never constructs (Mover, Moveable, Portable, Actor, Player,
  Exit, DirectionalPlayer, StatusBar, PerspectiveBackdrop,
  CompoundCondition) or of base classes whose slots Pacman/Ghost override
  (`mover_restore_background`, `mover_can_step`, `player2d_move_tick` …);
  the second draw list, the DIB extras (`dib_create`, `dib_map_to_palette`,
  the remaps), `sauna_scene_dtor` (the scene is never deleted),
  `wave_pump`, `APPABOUT`; `directional_player_move_to_edge_h` and
  `moveable_move_to_edge_h` (reached only from `game_handle_message`'s
  `WM_KEYDOWN` arm, which the scene handler shadows). **The RLE path (15,
  13 KB)**: `scene_object_enable_rle` (a slot nothing calls), so `rleMode`
  stays 0 and `rle_blit_transparent` (1088:0000), the encoder and the whole
  blit (`1088`), the scaled and stretched copies (`1068`, 8), the 32-bit
  `1000:0024` and `1008:0024`, `FUN_1010_0960`/`0c49` never run.
- **absorbed (506)**: the adjustor thunks, the `*_default` slot bodies,
  the type tests (`Object.is/as`), `scene_object_slot00`/`slot01` (slots
  nothing calls) and the scroll-target tests.
- **replaced (187)**: the CRT (`core/crt.zig`, Zig's std) and the imports
  (`Platform`).

## Tracker

`noite -p sauna …` (or `NOITE_PROGRAM=sauna`): DB `db/sauna.sqlite`
(local; `noite -p sauna import` rebuilds it from Ghidra and the plan),
plan `db/sauna-plan.tsv` (committed), tree `src/sauna/`, index
`src/sauna/units.zig`, worktrees `work/sauna-<unit>/` on branches
`port/sauna-<unit>`. A worktree's `.ref/env.sh` sets `NOITE_PROGRAM`, so
`noite test`/`check` there need no `-p`. `@orig` tags are checked per
program; `finish` refuses files outside the program's tree. The program's
layout (`tools/cli/src/noite/program.py` `SAUNA`): CRT segment 1098,
imports 10c8, DGROUP 10b0, far 4-byte vtable slots in code segment 10a0,
virtual calls `CALLF [BX+off]`. The "Other vtables" table above is
`docs/sauna/SLOTS.tsv`; rerun `noite -p sauna unit dep infer` after an
import.

```
noite -p sauna next [--blocked]      # units ready to claim
noite -p sauna start <unit>          # worktree work/sauna-<unit>/
noite -p sauna show <addr|name>      # row, decompile (--asm), callers/callees
noite -p sauna unit show <unit>
noite -p sauna check -w <unit>       # @orig tags vs SAUNA's DB
noite -p sauna initdata -w <unit>    # `// @orig g_*` defaults vs SAUNA's DGROUP
noite -p sauna finish <unit>         # from the main checkout
noite -p sauna failed <unit> "why" / release <unit>
```

## How to port a SAUNA unit

1. `noite -p sauna next`, `noite -p sauna start <unit>`, then work in
   `work/sauna-<unit>/` (`. .ref/env.sh`; tools via `nix develop -c`).
   Scratch output and frame dumps go in the worktree's `zig-out/`, never
   `/tmp`.
2. Read the unit's `.ref/*.c` (plate, decompile, disassembly),
   `.ref/types.md`, `.ref/strings.md`; DATA.md / GAME.md for the class and
   the rules. Ghidra (`mcp__ghidra__*`, `program="SAUNA.EXE"`) for anything
   else.
3. Read the TIRO unit of the same name (`src/tiro/<unit>.zig`, ported and
   checked; `gallery` for `maze`, `target` for `score`'s pattern):
   most engine functions are the same source. Transcribe each SAUNA
   function from SAUNA's own decompile/asm, reusing TIRO's Zig where they
   agree, ENCAIXE's for the second bitmap (`unk18`, the restores) and
   NOITE's for the AVI and add-exit slots; note in the commit body every
   function whose code differs from TIRO's (and how). Never call a TIRO,
   ENCAIXE or NOITE unit, except the state-free delegation allowed in
   Decisions.
4. Write only `src/sauna/<unit>.zig` (or `behaviour/<unit>.zig`): replace
   each declared dispatcher's body, keep its signature; one
   `// @orig <seg:off> <ghidra_name>` per function (SAUNA addresses;
   `(absorbed)` for the defaults and thunks a dispatcher's arm covers).
   Public names: the Ghidra name minus the unit's class prefix, camelCase
   (`sauna_eat_peanut` in `score` → `score.eatPeanut`).
5. Faithful first: port each P-bug as the code does it and put the fix
   only behind its flag (`g.fixes.sauna_…`, table above). NOITE's
   conventions hold (integers `i16`/`i32` with wrapping where the original
   overflows, `cstr`, `?*T`, message boxes through `plat.messageBox`,
   every PostMessage/SendMessage/SetSystemTimer at the same point,
   `error.Fatal` only where the original ends). Allocate what the
   original `new`s from `g.local()`.
6. Call other units' dispatchers, never a local copy. If a declared
   signature cannot express the original, `noite -p sauna failed <unit>
   "slot <name> (<owner>) needs …"`.
7. Tests optional; when written, `oracle=emulated` from tools/oracle,
   `asset` from `assets/SAUNA/`, `documented` from Ghidra.
8. `noite test`, commit (commit skill), `noite -p sauna finish <unit>` from
   the main checkout.

## Owner questions

1. **P3 in Corrigida?** `sauna_eat_on_arrival` makes Pacman eat the dot he
   steps onto instead of the one he has just left: the score, the sounds,
   the power mode and the win come one step (55 ms) earlier, and the last
   dot no longer waits for one more move. BUGS.md rates "the old position
   was not meant" 7/10, so it is left out of `--fix all` until you say.
2. **P6's fix: immunity or a pause?** The flag as designed lets the ghosts
   walk on during the 0.7-s death but takes no life from a meeting then.
   The alternative is to stop the ghosts' timer arm while Pacman dies (they
   freeze, as in the arcade game). The first changes less; say if you
   prefer the second.
3. **P2's fix** keeps every actor's cells marked (vacate clears only its
   own, occupy does not overwrite another actor's). With it ghosts that
   overlap at home (all four start at the same point) stay detectable
   wherever they are: catches are a little more likely in the Corrigida.
   It is in `all` as a bug fix; say if that should be a choice.
4. **full.input**: add the sauna detour (a planned win between the pharaoh
   and the disco), or keep the full run on its current route and leave
   SAUNA to its own scripts?

## Finishing

When every unit is ported: the planner and the scripts above, the smoke
option, then `ready = true` in `src/sauna/root.zig`, SAUNA in
`web_main.minigames`, `MINIGAMES`/`PAD_KEYS` in `web/noite.js`, the "Jogo"
option in `web/index.html`, the web manifest (`tools/web/files.py`), the
README's minigame list, BUGS.md's P-entries' "Port:" lines (ported, the
script that shows each), and a deploy (the owner's standing rule).
