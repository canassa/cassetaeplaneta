# Native port of ENCAIXE.EXE — design

ENCAIXE.EXE ("Encaixe Perfeito", the pharaoh's falling-blocks minigame) in
Zig, next to NOITE's port. NOITE's `docs/DESIGN.md` and the zig-developer
skill hold for everything this file does not override. Ghidra (program
`ENCAIXE.EXE`, through the tracker snapshot `noite -p encaixe show`) is the
specification; `GAME.md` (rules, protocol), `DATA.md` (classes, vtables,
globals), `FUNCTIONS.md` (names, dead code), BUGS.md E1–E9.

## Decisions

- **Own tree, ENCAIXE's code.** ENCAIXE is NOITE's engine rebuilt in the
  small model and simplified; the same names do not mean the same code:
  - `occupancy_grid_occupy` 1008:8124 inlines NOITE's per-cell
    `occupancy_grid_occupy_cell` (pointers first, then counts);
  - `object_list_add` 1008:7f72 silently drops an object past capacity,
    where NOITE shows a fatal box;
  - the update list has no functions (its code is inlined at the callers)
    and holds 30, not 100;
  - the Backdrop has two WinG DCs/bitmaps; `game_handle_message` is 3.5 KB
    of a different default; SceneObjectVtbl has 93 slots (9 dropped, 3 new,
    renumbered), `Frame` has a vtable, Mover lost `allowOffscreen`;
  - every layout differs (2-byte pointers).
  So ENCAIXE gets its own units under `src/encaixe/`, ported from its own
  functions with its own `@orig` addresses. NOITE's units are not called.
- **Shared, because identical or not game code:** the platform layer
  (`src/platform/`), `core/msg.zig`, `core/queue.zig`, `core/cstr.zig`,
  `core/crt.zig` (the CRT `rand`), `core/stub.zig`, `core/errors.zig`,
  `core/fixes.zig` (one `Fixes`, E-flags prefixed `encaixe_`), the Win16
  data types (`Dib`, `BitmapInfoHeader`, `RgbQuad`, `Rect`). Segment 1000
  is byte-identical to NOITE's: ENCAIXE's `dib.rowsCopy32` /
  `rowsCopyTransparent32` (tagged with ENCAIXE's 1000:0114 / 1000:0024) may
  call NOITE's `src/dib.zig` versions. Any other reuse of a NOITE function
  needs the two decompiles shown identical in the unit's commit.
- **Faithful first, the owner's rule.** E1–E9 are reproduced as they are by
  default. Each fix exists only behind its own `Fixes` flag (off by default,
  on in the Corrigida version, `Fixes.all()`). A unit ports the buggy code
  and keeps the fixed path only under its flag.
- **Two programs in one process** (`src/platform/host.zig`): NOITE and
  ENCAIXE are tasks with their own state, queue, timers, window and screen;
  the protocol (0x40b/0x40c/0x40a, FindWindow, the hidden NOITE window, the
  vanished-window loss) runs through the platform as in Windows.

## Source layout

```
src/encaixe/root.zig       program root: core, units, `ready`, `program` (host.Program)
src/encaixe/core/          types only (not units)
  game.zig                 Game: TetrisGame + every ENCAIXE DGROUP global; queue, send/post, timers
  object.zig               Object (kinds piece / control_panel / status_bar), parts, Frame, ObjectList
  world.zig                Scene, Backdrop (two bitmaps), OccupancyGrid + Occupancy, DrawList, UpdateList, Condition
src/encaixe/<unit>.zig     module units
src/encaixe/behaviour/     behaviour units (one group of SceneObject slots)
src/encaixe/units.zig      generated index (`noite -p encaixe unit sync`)
src/platform/host.zig      the tasks (shared platform code)
```

## Object model

As NOITE's (one `Object`, a `kind`, every part present), with ENCAIXE's
classes. Three kinds are constructed:

| Kind | Class (vtables) | Parts live |
|---|---|---|
| `piece` | Piece ← Player2D ← Actor2D ← Mover + Animation (0f8a, 0f90, 0f92) | base, mover, anim, player2d, piece |
| `control_panel` | TetrisPanel ← ControlPanel ← Animated3D ← Animation + Object3D (0b0e, 0b20, 0bda) | base, o3d, anim, panel |
| `status_bar` | StatusBar (0dc2) | base, status |

`Object.is/as` are the type-test slots 3C–4D and 54/55. Portable, Moveable,
Mover, Animation, Animated3D, Actor, Player, Exit and PerspectiveBackdrop are
never constructed: their methods are `dead` in the plan (90 functions), but
`portable_pick_up/drop/draw_icon` are called from live code (`game_input`,
`panels`) and keep the `portable` part. `Piece.board` is reached through
`PiecePart.cell(col, row)` (flat `col * 14 + row`, the original's
addressing: E2's row 14 lands in the next column). Struct origins are
`// @orig Struct+0xNN` with ENCAIXE's offsets; the vtordisp words and the
virtual bases have no counterpart.

## Virtual slots

Each slot is one `pub fn` dispatcher (named after the vtable field) in the
unit that owns it, already declared in the skeleton with its final
signature and a `stub.unported` body; it switches on `obj.kind` and calls one
function per original implementation, each tagged `@orig`. The default stub
(`scene_object_*_default`, absorbed) is the `else` arm. Thunks (286),
defaults (70) and type tests (40) are `absorbed`. Signatures:
`(g: *Game, obj: *Object, <args in source order>)`; hwnd and hdc parameters
are dropped; `Backdrop *` stays; out-parameters join the return value
(`space3d.Support`, `world.RectQuery`). Flattened single-class tables are
plain functions: Game (`game`, `game_input`), Scene (`scene`, `tetris`),
Backdrop (`backdrop`), ControlPanel (`panels`), Piece (`piece`), Condition
(`game`), Frame (`object_create`).

### SceneObject slots (kinds: piece, panel = control_panel, status = status_bar)

ENCAIXE's slot numbers (byte offset = 2 × slot); field names are NOITE's.
58–5C (slot61–65) are defaults never called and have no dispatcher.

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
| 08 | getX | position | scene_object_get_x | mover_get_x: piece |
| 09 | getY | position | scene_object_get_y | mover_get_y: piece |
| 0A | getStepX | position | scene_object_get_step_x_default | mover_get_step_x: piece |
| 0B | getStepY | position | scene_object_get_step_y_default | mover_get_step_y: piece |
| 0C | slot11 | position | scene_object_slot11_default |  |
| 0D | setElevation | space3d | scene_object_set_elevation_default | object3d_set_elevation: panel |
| 0E | setAnchor | space3d | scene_object_set_anchor_default | object3d_set_anchor: panel |
| 0F | setSize | space3d | scene_object_set_size_default | object3d_set_size: panel |
| 10 | setWorldElev | space3d | scene_object_set_world_elev_default |  |
| 11 | unk11 | space3d | scene_object_unk11_default | object3d_unk11: panel |
| 12 | drawBounds | space3d | scene_object_draw_bounds_default | object3d_draw_bounds: panel |
| 13 | addDirtyRect | render | scene_object_add_dirty_rect |  |
| 14 | computeOverlap | render | scene_object_compute_overlap |  |
| 15 | restoreBackground | render | scene_object_restore_background | te_piece_restore_background: piece |
| 16 | drawDirtyTo | render | scene_object_draw_dirty_to | mover_draw_dirty_to: piece |
| 17 | draw | render | scene_object_draw | te_piece_draw: piece; control_panel_draw (panels): panel |
| 18 | unk18 | render | scene_object_unk18 |  |
| 19 | drawClipTo | render | scene_object_draw_clip_to |  |
| 1A | drawClip | render | scene_object_draw_clip |  |
| 1B | erase | render | scene_object_erase | animation_erase: piece panel |
| 1C | slot1F | render | scene_object_slot1f_default | animation_slot1f: piece panel |
| 1D | redraw | visibility | scene_object_redraw | actor2d_redraw: piece; animated3d_redraw: panel |
| 1E | hideAndInvalidate | visibility | scene_object_hide_and_invalidate |  |
| 1F | blitToDc | visibility | scene_object_blit_to_dc | actor2d_blit_to_dc: piece |
| 20 | invalidate | visibility | scene_object_invalidate | mover_invalidate: piece |
| 21 | slot24 | visibility | scene_object_slot24 | mover_slot24: piece |
| 22 | hide | visibility | scene_object_hide | mover_hide: piece |
| 23 | show | visibility | scene_object_show | actor2d_show: piece; animated3d_show: panel |
| 24 | occupy | occupancy | scene_object_occupy | control_panel_occupy: panel; status_bar_occupy: status |
| 25 | vacate | occupancy | scene_object_vacate | control_panel_vacate: panel; status_bar_vacate: status |
| 26 | attach | occupancy | scene_object_attach | actor2d_attach: piece; control_panel_attach: panel; status_bar_attach: status |
| 27 | canStep | occupancy | scene_object_can_step_default | actor2d_can_step: piece |
| 28 | isStepBlocked | occupancy | scene_object_is_step_blocked |  |
| 29 | nextFrame | animation | scene_object_next_frame_default | actor2d_next_frame: piece; animated3d_next_frame: panel |
| 2A | prevFrame | animation | scene_object_prev_frame_default | actor2d_prev_frame: piece; animated3d_prev_frame: panel |
| 2B | play | animation | scene_object_play_default | animation_play: piece; animated3d_play: panel |
| 2C | playIdle | animation | scene_object_play_idle_default |  |
| 2D | stopAndRedrawDc | animation | scene_object_stop_and_redraw_dc_default | actor2d_stop_and_redraw_dc: piece; animated3d_stop_and_redraw_dc: panel |
| 2E | stopAndRedraw | animation | scene_object_stop_and_redraw_default | actor2d_stop_and_redraw: piece; animated3d_stop_and_redraw: panel |
| 2F | tick | animation | scene_object_tick_default | player2d_tick: piece; control_panel_tick (panels): panel |
| 30 | stop | animation | scene_object_stop_default | actor2d_stop: piece; animated3d_stop: panel |
| 31 | moveTo | movement | scene_object_move_to_default | mover_move_to: piece |
| 32 | moveToEdgeH | movement | scene_object_move_to_edge_h_default | mover_move_to_edge_h: piece |
| 33 | moveToEdgeV | movement | scene_object_move_to_edge_v_default | mover_move_to_edge_v: piece |
| 34 | stopMovingDc | movement | scene_object_stop_moving_dc_default | te_piece_stop_moving_dc: piece |
| 35 | stopMoving | movement | scene_object_stop_moving_default | te_piece_stop_moving: piece |
| 36 | moveTick | movement | scene_object_move_tick_default | player2d_move_tick: piece |
| 37 | getTimerId | animation | scene_object_get_timer_id_default | actor2d_get_timer_id: piece; animated3d_get_timer_id: panel |
| 38 | isMoving | movement | scene_object_is_moving_default | actor2d_is_moving: piece |
| 39 | isRunning | animation | scene_object_is_running_default | animation_is_running: piece panel |
| 3A | moveToAndDrop | space3d | scene_object_move_to_and_drop_default | object3d_move_to_and_drop: panel |
| 3B | setPosition | position | scene_object_set_position | actor2d_set_position: piece |
| 3C–4D, 54/55 | type tests | (Object.is/as) | | |
| 4E | unk4E | position | scene_object_unk4e |  |
| 4F | redrawOverlapping | visibility | scene_object_redraw_overlapping | object3d_redraw_overlapping: panel |
| 50 | hitboxOverlaps | position | scene_object_hitbox_overlaps |  |
| 51 | boundsOverlap | position | scene_object_bounds_overlap |  |
| 52 | slot5B | position | scene_object_slot5b_default |  |
| 53 | slot5C | position | scene_object_slot5c_default |  |
| 56 | isEnabled | position | scene_object_is_enabled_default |  |
| 57 | getExitIndex | position | scene_object_get_exit_index_default |  |

### Other vtables

| vtable | slots → unit |
|---|---|
| Object3DVtbl (8) | `space3d`: slot00, findSupport, isBelow, isAboveOnScreen, isInFrontOf, overlaps3d, moveToAtElev, dropToSupport (Object3D's, the panel) |
| AnimationVtbl (1) | `animation.playOnce` |
| MoverVtbl (1) | `movement.placeAt` (mover_place_at) |
| PieceVtbl (3) | 00 `movement.placeAt`; 01 `piece.tryStep` (te_piece_try_move); 02 `piece.moveTick` (te_piece_step_move) |
| ControlPanelVtbl (9) | 00 `animation.playOnce`; 01–08 `panels` (TetrisPanel's getVisibleHeight) |
| GameVtbl (7) | 00 `game_input.handleMessage`; 01–06 `game` (createPlayer … onCreate) |
| SceneVtbl (13) | 00, 05, 07 `tetris` (handleMessage, createScreen, create); the rest `scene` |
| Backdrop/GridBackdropVtbl (19/20) | `backdrop` (slot 00 create = TetrisBackdrop's walls; 01–06 grid; 07–12 defaults; 13 createWithGrid) |
| ConditionVtbl (3) | `game` (FlagCondition; CompoundCondition is dead) |
| FrameVtbl (1) | `object_create.getCell` |

## State

`core/game.zig`'s `Game` is TetrisGame + Game flattened (`g_game` and
`g_tetrisGame` are the game itself) plus every DGROUP global
(`g_score` → `g.score`, `i16`; `g_noiteWnd` → `g.noiteWnd`; the piece strip
tables; the WaveMix state; `g_occupancyCount/Object` → `g.occupancy`; `g_piece`
→ `g.piece`; `g_mainWindow` = `plat.windowHandle()`). No counterpart:
`g_setSystemTimer`/`g_killSystemTimer` (`g.setSystemTimer`), the instance and
module handles, the module path (the host's `Program.dir`). Leaf units take
the narrowest thing, as in NOITE. One `Game` per running ENCAIXE.

The backdrop: NOITE's pixel contract (top-down WinG DIBs, `wingBitBlt`,
`textOut` into a `Surface`) for both bitmaps, `surface()` and `surface2()`.
The score (`te_draw_score`) and the row clear draw on both.

## Reading ENCAIXE (small model)

- One code segment `1008`: calls are near (`E8`), returns `RET n`; game code
  is near pascal, Ghidra `__stdcall16near`, parameters listed in stack order
  = **source order reversed** (`set_anchor(this, y, x)` → `setAnchor(g, obj, x, y)`),
  `this` at `[BP+4]`; `__cdecl16near` where the caller pops.
- Pointers are 2 bytes; DS = SS = DGROUP `1018`; strings and globals are
  `1018:xxxx`, pushed as one word (far API arguments as `PUSH DS`/`PUSH off`).
- A virtual call is `MOV BX,[SI]; CALL word ptr [BX+off]`: slot = off / 2.
  A method overriding a SceneObject slot gets `this` = the SceneObject
  subobject and reads its own fields at negative offsets; the adjustor
  thunks (`<target>_thunk_<k>`, `_m<k>` subtracts) say by how much.
- The decompile drops arguments of untyped virtual calls: take the pushes
  from the disassembly (`.ref/*.c`, the `/* disassembly */` block).
- "Null tests of an adjusted this" (`this == (word *)&g_keyDown`, …) are
  `if (sub == NULL)` (FUNCTIONS.md, "Decompiler artifacts").

## Running two programs

`src/platform/host.zig` (platform code, implemented). Every program is a
*task*: its `Game`, its queue and timers (`core/queue.zig`), its window
(handle, title, shown/hidden, z-order) and `Screen`, an inbox of events, its
own `Platform` (`Task.platform()`), which forwards to the backend as that
task (`Sim.task`).

- **Task 0** is what `main` started (NOITE, or a minigame alone) and drives
  its own loop (`main.run`, `web_main.noite_frame`, `main.runAlone`). Alone,
  task 0's platform behaves call for call as the backend's (NOITE's traces
  are unchanged). The other tasks run inside task 0's `poll` (`Host.pump`),
  as a Win16 task's GetMessage yields; `wait` includes their timers.
- **WinExec** of a registered, `ready` program creates a task whose WinMain
  runs after `--minigame-startup` ms (the EXE load, 1500): then FindWindow
  finds its window (hwnd 0x100 + task), it is shown, on top and active, and
  the previous active task gets WM_ACTIVATE(0). The program activates
  itself (its `app.start` sends WM_ACTIVATEAPP/WM_ACTIVATE/
  WM_QUERYNEWPALETTE as NOITE's does). Other WinExecs reach the backend's
  stub (`Sim.winExec`), which stays for the 8 unported minigames, and for
  all with `--minigame-stub`.
- **PostMessage** to another task's window lands in its inbox (delivered as
  a posted message at its next turn); to a window that is gone it fails.
  Cross-task SendMessage is not needed (ENCAIXE sends only to itself and
  `WM_FONTCHANGE` to hwnd 0, which goes nowhere).
- **ShowWindow**: showing makes a window the top, active one; hiding the
  active one activates the top visible one left. A task the host
  deactivated gets WM_ACTIVATE(1) back when it becomes active again (NOITE
  after the minigame: its music and WaveMix resume). Activation goes
  through the inbox, not a nested send (unverified ordering detail).
- **The end**: when a task's loop gets WM_QUIT the host runs its `exit`
  (app_exit), destroys its window (FindWindow fails from then on: NOITE's
  3ffarao WM_SYSTIMER check posts itself the 0x40a loss if no result came)
  and activates the next visible window.
- **Presentation**: the backend shows the top visible window's screen
  (`presentScreen`): SDL its one window, the web its one canvas, headless
  its dumps (`Host.shownScreen`). With every window hidden, the backend's
  own `showMain(false)` (SDL hides, the web shows the "Minijogo" notice).
- **Input and focus**: the backend's input, focus changes and the close
  button go to the active window's task (the arrows reach ENCAIXE while it
  is up; the window's close button sends it WM_CLOSE, a loss).
- **Audio**: MCI aliases are per task (NOITE's and ENCAIXE's `musica` are
  two devices; the one synthesizer plays the last started); each task has
  its own WaveMix session (handle = task + 1) and channel bank in the mixer,
  silenced by its WaveMixActivate(false). NOITE's go quiet because NOITE
  pauses them on WM_ACTIVATE(0), as on Windows.
- **Files**: a relative name the disc root lacks is looked for in the
  task's EXE directory (`Program.dir`, `\ENCAIXE`), as OpenFile searches
  the task's directory. NOITE's lookups are unchanged.
- **Results**: every 0x40a a minigame posts is recorded (`Host.results`):
  the harness's `result` command, `runAlone`'s report.

The protocol (GAME.md): NOITE's 3ffarao WinExecs, polls FindWindow every
100 ms, posts 0x40b (lParam = its window); ENCAIXE stores `g_noiteWnd`,
answers 0x40c (wParam = its window) on its first message after
`g_started`; NOITE hides itself; ENCAIXE's WM_DESTROY posts 0x40a (won,
score delta) and quits; NOITE shows itself, records the result, scores and
switches scene. A minigame alone posts 0x40a to hwnd 0: the host records it
and PostMessage fails.

## Front ends

- `noite --minigame encaixe [--headless …]`: ENCAIXE alone (task 0, its
  title, `\ENCAIXE` directory); prints its result. Refused while `ready` is
  false. `--minigame win|lose` stays the stub's result; `--minigame-stub`
  keeps the stub even for ported minigames (scripts written for it).
- Web: the loader's "Jogo" choice ("Jogar só o minijogo: Encaixe
  Perfeito") passes `noite_start(…, minigame)` (1 = ENCAIXE); disabled
  while `MINIGAMES[i].ready` (web/noite.js) is false. On a touch screen the
  arrow pad shows. A new minigame: add its `Program` to `main.minigames`,
  `web_main.minigames` and `MINIGAMES`, a radio in web/index.html.
- Neither changes NOITE: with ENCAIXE not `ready`, 3ffarao still gets the
  stub.

## Tests

- **Harness**: `--input` scripts drive the active window (keys to ENCAIXE
  while it is up: `key left`, `hold down 400`), `dump` writes the shown
  window, `result won|lost|none [SCORE]` checks the last minigame result.
  Alone, the program-neutral commands work (input, dump, log, focus,
  freeze, result, quit); the NOITE ones fail the run.
- **Scripts** (written once the units are ported; the piece sequence is
  deterministic, `srand(time(NULL))` on the virtual clock):
  `tools/play/encaixe-lose.input` (no input: the stack reaches the top
  rows), `tools/play/encaixe-win.input` (10 lines, `result won 1500`),
  both with `--minigame encaixe`; `tools/play/encaixe-3ffarao-win.input` /
  `-lose.input` with `--scene 3ffarao` (the hall after a win, 3fcasame and
  one life less after a loss). The win script is generated from the piece
  sequence (a planner placing each piece, or by hand from `dump`s).
- **Smoke**: `tools/smoke.py --minigame encaixe [--monkey SEED]` (to add
  with the scripts): random arrows for 60 s, no panic, a result.
- **Oracle**: `tools/oracle/oracle.py --exe assets/ENCAIXE/ENCAIXE.EXE
  --near 1008:xxxx …` runs a near function (near return to a HLT at
  `sel:0000`; near pointers are words in DGROUP 1018; seed the board with
  `--mem 1018:<piece+0x52>=…`). Worth `oracle=emulated` tests:
  `piece_sideways` and `piece_vertical` (every kind × rotation × a few
  positions, E1/E2), `piece` (`te_piece_clear_full_lines`,
  `te_piece_clear_row`, `te_piece_calc_right_col`, `te_piece_spawn_shape`),
  `backdrop` (`te_grid_backdrop_create_with_walls`' cells, E9;
  `occupancy_grid_*`). OS-driving code (app, tetris, sound) is a poor
  target.

## Fixes (BUGS.md E-section)

| Bug | Flag | Unit |
|---|---|---|
| E1 O piece left | `encaixe_o_piece_moves_left_whole` | piece_sideways |
| E2 rotation past row 13 | `encaixe_rotation_stays_on_board` | piece_vertical |
| E3 unknown kind | `encaixe_clear_lines_unknown_kind` | piece |
| E4 frame cells | `encaixe_status_frame_cells` | object_create |
| E5 down-key flag | `encaixe_down_key_guard` | tetris |
| E6 landing after a loss | `encaixe_loss_stops_landing` | piece |
| E7 skipped speed-up | `encaixe_speed_up_on_crossing` | piece |
| E8 strip cells | `encaixe_strip_cells_by_count` | object_create |
| E9 grid walls | `encaixe_grid_walls_match_board` | backdrop |

All in `Fixes.all()`. E4's uninitialised stack word is taken as 0 (no
cells). E3 cannot happen (`rand() % 6`).

## Units

21 units, 234 functions (90 dead, 396 absorbed, 180 replaced). Hard deps
are direct calls into another unit (`noite -p encaixe next --blocked`);
virtual calls are soft (`unit dep show`).

| Unit | Fns | Calls into |
|---|---|---|
| `dib` | 7 | — |
| `lists` | 9 | — (owns message_box_printf) |
| `position` | 12 | — |
| `animation` | 21 | — |
| `sound` | 8 | — |
| `piece_sideways` | 2 (5.4 KB) | — |
| `piece_vertical` | 2 (5.4 KB) | — |
| `render` | 16 | dib |
| `backdrop` | 15 | dib |
| `space3d` | 25 | position |
| `occupancy` | 15 | position |
| `object_create` | 10 | dib, position |
| `scene` | 11 | dib, lists |
| `visibility` | 17 | lists, render |
| `panels` | 12 | animation, dib |
| `movement` | 12 | backdrop, render |
| `piece` | 11 | dib, movement, piece_sideways, piece_vertical, sound, visibility |
| `tetris` | 3 | animation, dib, lists, movement, piece, scene, sound |
| `game` | 14 | dib, lists, movement, object_create, occupancy, piece, position, scene |
| `game_input` | 3 (3.5 KB) | game, lists, position, space3d |
| `app` | 9 | dib, game |

Ready first (parallel): dib, lists, position, animation, sound,
piece_sideways, piece_vertical; then render, backdrop, space3d, occupancy,
object_create, scene; then visibility, panels, movement; then piece; then
tetris, game; then game_input, app.

## Tracker

`noite -p encaixe …` (or `NOITE_PROGRAM=encaixe`): DB `db/encaixe.sqlite`
(local; `noite -p encaixe import` rebuilds it from Ghidra and the plan),
plan `db/encaixe-plan.tsv` (committed), tree `src/encaixe/`, index
`src/encaixe/units.zig`, worktrees `work/encaixe-<unit>/` on branches
`port/encaixe-<unit>`. A worktree's `.ref/env.sh` sets `NOITE_PROGRAM`, so
`noite test`/`check` there need no `-p`. `@orig` tags are checked per program
(NOITE scans `src/` minus `src/encaixe/`; ENCAIXE scans `src/encaixe/`);
`finish` refuses files outside the program's tree.

```
noite -p encaixe next [--blocked]      # units ready to claim
noite -p encaixe start <unit>          # worktree work/encaixe-<unit>/
noite -p encaixe show <addr|name>      # row, decompile (--asm), callers/callees
noite -p encaixe unit show <unit>
noite -p encaixe check -w <unit>       # @orig tags vs ENCAIXE's DB
noite -p encaixe initdata -w <unit>    # `// @orig g_*` defaults vs ENCAIXE's DGROUP
noite -p encaixe finish <unit>         # from the main checkout
noite -p encaixe failed <unit> "why" / release <unit>
```

## How to port an ENCAIXE unit

1. `noite -p encaixe next`, `noite -p encaixe start <unit>`, then work in
   `work/encaixe-<unit>/` (`. .ref/env.sh`; tools via `nix develop -c`).
2. Read the unit's `.ref/*.c` (plate, decompile, disassembly), `.ref/types.md`,
   `.ref/strings.md`; DATA.md / GAME.md for the class and the rules. Ghidra
   (`mcp__ghidra__*`, `program="ENCAIXE.EXE"`) for anything else.
3. Write only `src/encaixe/<unit>.zig` (or `behaviour/<unit>.zig`): replace
   each declared dispatcher's body, keep its signature; one
   `// @orig 1008:xxxx <ghidra_name>` per function (ENCAIXE addresses;
   `(absorbed)` for the defaults and thunks a dispatcher's arm covers).
   Public names: the Ghidra name minus the unit's class prefix, camelCase
   (`te_piece_on_landed` in `piece` → `piece.onLanded`).
4. Faithful first: port each E-bug as the code does it and put the fix only
   behind its flag (`g.fixes.encaixe_…`, table above). NOITE's conventions
   hold (integers `i16`/`i32` with wrapping where the original overflows,
   `cstr`, `?*T`, message boxes through `plat.messageBox`, every
   PostMessage/SendMessage/SetSystemTimer at the same point, `error.Fatal`
   only where the original ends).
5. Call other units' dispatchers, never a local copy. If a declared
   signature cannot express the original, `noite -p encaixe failed <unit>
   "slot <name> (<owner>) needs …"`.
6. Tests optional; when written, `oracle=emulated` from tools/oracle
   (`--near`), `asset` from `assets/ENCAIXE/`, `documented` from Ghidra.
7. `noite test`, commit (commit skill), `noite -p encaixe finish <unit>`
   from the main checkout.

## Finishing (after the last unit)

Not a unit: set `ready = true` (`src/encaixe/root.zig`) and
`MINIGAMES[0].ready` (web/noite.js); add the ENCAIXE files to the web
manifest (`tools/web/files.py`: TETRFUN.BMP, PECA*.BMP, PANEL.BMP,
DOOM2.MID, TETRIS2.WAV under `ENCAIXE/`); write the four scripts and the
smoke option; re-tune `tools/play/full.input` for the real minigame at
3ffarao (or run it with `--minigame-stub`); check NOITE's music and WaveMix
after the minigame on SDL and the web.
