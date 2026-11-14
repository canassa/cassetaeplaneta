# JARDIM.EXE: function inventory

The Ghidra program `/JARDIM.EXE` after phase 4 and the cleanup: every function found, classified,
named or noted, and plated; the plate says where the name comes from. Addresses are Ghidra
`seg:off`. JARDIM is a large-model `/Od` build (far code, far data, `this` a far pointer at
`[BP+6]`, far vtables in the code segment `10c0`); see `QUALITY.md` §0. NOITE is the reference for
the class set, the vtable layouts and the CRT; TIRO (the other `/Od` build) for the code shape and
most engine names. The data is in `DATA.md`, the game in `GAME.md`.

## Counts

**1,160 functions:** 93 import thunks, 276 adjustor thunks and **791 code functions**, 1,053
plated (all but the import thunks, 13 FP-library entries and `___EXPORTEDSTUB`). **760 are
named, 31 stay `FUN_`**: 26 in the FP math library and 5 dead engine functions (§Remaining `FUN_`).

| Kind | Fns | Named | Where |
|---|---|---|---|
| Import thunk | 93 | 93 | `10e8`, typed (all but `__FPMATH`) |
| Adjustor thunk | 276 | 276 | `10c0:00e2–17a0`; `<target>_thunk[_k]`, renamed after their targets |
| CRT | 153 | 127 | `10b8` (the 26 `FUN_` are the FP math library, `2f87–4b37`) |
| 32-bit routines | 6 | 6 | `1000` (3 blitters), `1008`, `1010` (the ray walks), `1018` (the sprite blitter) |
| App shell | 10 | 10 | `1020` |
| Engine | 529 | 524 | `1030–1080`, `1090`, `10a0`, `10c0` (338, including the ctors of the JARDIM classes) |
| JARDIM game | 87 | 87 | `1028` (47), `1068` (8), `1088` (3), `1098` (12), `10a8` (12), `10b0` (11), plus the phase ctors and slot defaults in `10c0` |

By segment (code functions other than the adjustor thunks):

| Seg | Fns | Named | `FUN_` | Seg | Fns | Named | `FUN_` |
|---|---|---|---|---|---|---|---|
| `1000` | 3 | 3 | 0 | `1060` | 6 | 4 | 2 |
| `1008` | 1 | 1 | 0 | `1068` | 8 | 8 | 0 |
| `1010` | 1 | 1 | 0 | `1070` | 7 | 7 | 0 |
| `1018` | 1 | 1 | 0 | `1078` | 18 | 17 | 1 |
| `1020` | 10 | 10 | 0 | `1080` | 11 | 11 | 0 |
| `1028` | 47 | 47 | 0 | `1088` | 3 | 3 | 0 |
| `1030` | 9 | 9 | 0 | `1090` | 6 | 6 | 0 |
| `1038` | 53 | 51 | 2 | `1098` | 12 | 12 | 0 |
| `1040` | 11 | 11 | 0 | `10a0` | 11 | 11 | 0 |
| `1048` | 53 | 53 | 0 | `10a8` | 12 | 12 | 0 |
| `1050` | 4 | 4 | 0 | `10b0` | 11 | 11 | 0 |
| `1058` | 2 | 2 | 0 | `10b8` | 153 | 127 | 26 |
| | | | | `10c0` | 338 | 338 | 0 |

Conventions (code functions): 582 `__stdcall16far` (far pascal, parameters listed reversed,
`this` first), 150 far cdecl (120 `__cdecl16far`, 27 `__cdecl16far_dxax_ptr`, 3
`__cdecl16far_dx_ax`), 43 near (CRT), 16 unknown (frameless CRT entries). 97 carry `sig?`, 79 of
them in the CRT; the 18 others are dead functions no caller cleans up after (`labyrinth_wait_ticks`,
`labyrinth_set_fixed12`, `labyrinth_minimap_line`, `labyrinth_draw_rect`, the two dead ray casters,
the unused DIB, RLE and wave functions). 53 carry `review` (§Remaining `FUN_`). The adjustor thunks
have no signature.

## Function discovery

Auto-analysis left 634 code functions. The phase-1 fixes (`QUALITY.md` §3) added the rest:

| Step | Added |
|---|---|
| `JardimFarVtSlots.java`: far vptr stores → 65 tables in `10c0` (44 with slots, 1,460 slots, 500 targets) | 349 functions |
| `NearAdjustorThunks.java 10c0 00e2 17a0 far` | 1 (275 thunks already were slot targets); 16 thunk bodies cut back to their `JMPF` |
| `CodeGapSweep.java` on every 16-bit segment | 43 (15 CRT, 24 in `10c0`) |
| `DeadJumps.java` | 70 dead epilogue jumps folded in |
| `JardimDeadBlocks.java 1028:5982 1028:59c9 1068:0167 1068:162b` | 4 dead arms folded in (63–84 bytes) |

What is left uncovered (4,806 bytes outside the 32-bit segments):
- the FP math library in `10b8` (8087 code with register-argument entries, no prologue, and its
  constant tables; nothing outside the CRT calls it): ~3.4 KB;
- the engine strings and the vbtables in `10c0`, one-byte pads.

## Names and how they were applied

`RenameFunctions.java` applied the TSVs `zig-out/jardim/rn_auto.tsv`, `rn_crt.tsv`,
`rn_manual.tsv`, `rn_fix.tsv`; the adjustor-thunk pass was then rerun to name the thunks after
their targets.

| Method | Names |
|---|---|
| **Vtable slot against NOITE** (`vtname.py`): slot *i* of a JARDIM class table gets the name of NOITE's function in the mapped slot of the same class's table (thunks resolved). For SceneObjectVtbl the slot map of `QUALITY.md` §5; the other tables slot for slot (Object3D, Mover, Backdrop) or by alignment of the targets (Animation, ControlPanel, only pairs with a body ratio ≥ 0.5). A JARDIM function in several tables takes the base table's name, else the majority. Where NOITE's target is unnamed the name is NOITE's field: `scene_object_<field>_default` | 264 |
| Vtable slot by hand: SceneVtbl (`6c64`, NOITE's 16 field names), GameVtbl (`4092`, TIRO's 7), the JARDIM game table (`816a`), FrameVtbl | 22 |
| **In-order alignment against TIRO** (`align.py`), pair score ≥ 0.6, the engine module segments only, no TIRO-specific names | 91 |
| **CRT against NOITE's large-model CRT** (`crtmatch.py`): normalised-op ratio ≥ 0.85, or ≥ 0.6 where NOITE's link order agrees | 76 |
| CRT by TIRO alignment (≥ 0.96) or by body | 14 |
| By role, by hand | 8 (`APPABOUT`, `APPWNDPROC`, `game_take_exit`, `jardim_game_ctor`, the two `_virtual` ControlPanel copies, …) |
| Adjustor thunks after their targets | 276 |

Two class identities were swapped by the first pass and fixed: the table pair at `10c0:7d6a`
(ctor `10c0:6cdc`, created by `jardim_game_create_player` with 0x516 bytes) is **Player**
(it overrides `isScrollTarget`/`isPlayer`/`asPlayer`, occupy/vacate, draw, tick, moveTick),
and the one at `7f3a` (ctor `72be`) is **Actor**. The table `8e60` (one override, `attach` =
`1028:47d6`) is a JARDIM class, not StatusBar.

Pairs that share a body keep distinct names by slot: `control_panel_draw_inventory_item`
(`1078:0a0f`) / `_virtual` (`0b10`), `control_panel_get_inventory_item_at` (`0a68`) / `_virtual`
(`0b69`). The three identical stubs `1038:2362/2392/23c2` (AnimationVtbl slots 2–4: each calls
`animation_is_locked` and returns 0) are `animation_slot02/03/04_stub`: they sit where NOITE has
its AVI methods, and JARDIM has no AVI.

The names phase 2 marked as weaker were confirmed in phase 4: the Scene slots
`1070:014d/01a8/0206/026a/02b6` against NOITE's bodies (`scene_add_object`, `scene_add_exit_at`,
`scene_add_exit_to_scene`, `scene_add_exit`, `scene_add_exit_alt`); `1038:274a/2776/27a5` are dead
copies of TIRO's Player2D overrides (JARDIM has no Player2D class; `review`).

## Segment inventory

| Seg | What |
|---|---|
| `1000` | 32-bit blitters: `blit_scaled_column` `0024` (the wall column, depth shading), `dib_rows_copy_transparent32` `0148`, `dib_rows_copy32` `0234` (NOITE's two). Read with `objdump -mi386`; verified in `tools/oracle` |
| `1008`, `1010` | 32-bit ray walks: `raycast_walk_horizontal`, `raycast_walk_vertical` (`0024` each), called by `raycast_render_view`; verified in `tools/oracle` |
| `1018` | 32-bit `blit_scaled_sprite_transparent` (`0024`), called by `dib_stretch_copy_transparent`; verified in `tools/oracle` |
| `1020` | App shell (TIRO `1038`) |
| `1028` | **The labyrinth** (table below) |
| `1030` | Occupancy grid, Backdrop (`backdrop_autoscroll` never scrolls here) |
| `1038` | SceneObject/Mover/Animation, object list; the dead Player2D copy |
| `1040` | DIB load/palette/remap |
| `1048` | Object3D/Moveable/Portable/Player/Exit (`exit_has_key_object` `2510`, `portable_ctor_hitbox` `2aed` dead, `portable_pick_up` `30c3`, `portable_drop` `32d6`) |
| `1050` | Conditions |
| `1058` | `game_handle_message` (only its `0x402` case is live here), `game_take_exit` |
| `1060` | DIB copies; `FUN_1060_0960`, `0c49` (dead, new in JARDIM) |
| `1068` | Scaled copies: `dib_blit_scaled_column` `0000` (→ `1000:0024`), `dib_stretch_copy_transparent` `1336` (→ `1018:0024`); their dead 16-bit workers and the dead byte-column and opaque-stretch pairs (`dead_*`) |
| `1070` | Scene |
| `1078` | StatusBar (unused), ControlPanel; `FUN_1078_01a6` (dead) |
| `1080` | Draw lists (live and dead copy) |
| `1088` | `transrle.cpp`'s 16-bit side: `rle_blit_transparent` (live code, never reached: RLE is never enabled), `dead_rle_blit_transparent_whole`, `dead_rle_encode_dib` |
| `1090` | JARDIM Game subclass (`jardim_game_*`) |
| `1098`, `10a8`, `10b0` | The phase scenes (tables `834c`, `91aa`, `92da`): `phaseN_scene_create_new_scene`, `_create`, `_dtor` (never run), `_place_objects`, `_touch`, `_hit`, `_on_life_lost`, the four `_play_*_sound`, `_handle_message` (phase 3 has no `create_new_scene`) |
| `10a0` | WaveMix |
| `10b8` | CRT; `2f87–4b37` the FP math library (26 `FUN_`, unused by the game) |
| `10c0` | Thunks; the SceneObjectVtbl defaults; the Animation/Mover/Object3D/Animated3D/Actor/Player/Exit/Portable/ControlPanel overrides; Game defaults and `game_init`; Backdrop defaults; SceneObject accessors; the ctors and dtors, among them `labyrinth_scene_ctor` `7462`, `phase1/2/3_scene_ctor` `7076`/`8afc`/`920a`, `phaseN_scene_create_screen` `7630`/`8cb0`/`925a`, the LabyrinthScene slot defaults `758c–761a`, `wall_strip_ctor` `8a76`, `sprite_queue_ctor` `4704` |

## The JARDIM game

| `1028:` | Function | Role |
|---|---|---|
| `0000`, `067e`, `069b`, `0796` | `labyrinth_wait_ticks`, `labyrinth_set_fixed12`, `labyrinth_minimap_line`, `labyrinth_draw_rect` | dead (a BIOS-tick wait from the DOS prototype, debug helpers) |
| `003b`, `0077` | `raycast_angle_to_radians`, `raycast_build_tables` | the 7 trigonometric tables (FP emulator) |
| `04fe`, `056c` | `labyrinth_alloc_map_rows`, `labyrinth_load_map` | the 57×80 map |
| `075a`, `07d8`, `0851`, `111a`, `257f` | `labyrinth_fill_rect`, `labyrinth_minimap_player`, `labyrinth_minimap_walls`, `labyrinth_present_minimap`, `labyrinth_refresh_map_panel` | the minimap |
| `0951`, `134f` | `raycast_render_view`, `labyrinth_draw_sky_floor` | the 3D view |
| `0dfb`, `0ecb` (dead), `0f85`, `2191` | `labyrinth_backdrop_ctor`, `_ctor_default`, `_dtor`, `labyrinth_backdrop_create` | LabyrinthBackdrop (slot 0 create) |
| `114e`, `11b3`, `12ce`, `438d`, `43e9` | `labyrinth_present_view`, `labyrinth_draw_hud_strip`, `labyrinth_present_hud_strip`, `labyrinth_present_hud`, `labyrinth_draw_hud` | presenting the view and the HUD |
| `2034`, `214e` | `labyrinth_place_object`, `labyrinth_remove_object` | the object grid |
| `2406`, `251d` | `labyrinth_paint`, `labyrinth_blit_to_dc` | full redraws |
| `2609` | `labyrinth_backdrop_handle_message` | **slot 0x17: keys, the tick, the shot, doors, the result** (6 KB) |
| `3e23`, `4655` | `labyrinth_move_and_render`, `labyrinth_render_frame` | a step with collisions; a frame |
| `47d6`, `482c–4a4e` | `wall_strip_attach`, `wall_strip_draw_wall_a/b`, `wall_strip_draw_door_a/b` | the wall strip and its four identical column drawers |
| `4b04`, `4b81`, `4b4d` | `sprite_enqueue_from32`, `object_set_visible_from32`, `dead_object_get_visible_from32` | 16:32 gateways for the 32-bit walks |
| `4bca`, `4f4d` | `dead_ray_cast_horizontal_lines`, `dead_ray_cast_vertical_lines` | the C ray casters the 32-bit walks replaced |
| `52a8`, `5ac6`, `5cea`, `5d6d` | `labyrinth_draw_sprite_entry`, `sprite_queue_insert`, `sprite_queue_draw_tree`, `sprite_queue_flush` | the sprites |
| `5dba`, `5ef1` | `labyrinth_scene_handle_message`, `labyrinth_scene_respawn` | LabyrinthScene slot 0 (the `0x402` carry) and the respawn |

## Remaining `FUN_` and `review`

`FUN_` (31): the 26 FP-library entries in `10b8` (register-argument code, nothing outside the CRT
calls them) and 5 dead engine functions: `1038:161c` (empty member, TIRO's `FUN_1028_0e71`),
`1038:2d98` (huge-pointer arithmetic, TIRO's `FUN_1028_1cb7`), `1060:0960`/`0c49` (a row-table
copy and its inner loop, new in JARDIM, no caller), `1078:01a6` (an Animation-like ctor body,
no caller).

`review` (53), each with its reason in the plate: those 5; 30 in the CRT (`10b8`: the FP
library, among them `_ctrandisp1/2` and `_trandisp1/2`); the dead ray casters (signatures not
pinned: they call the 32-bit gateways with the wrong frame); the dead Player2D copy (3); the
slot-0x24 and restore overrides `1038:00b1`, `0260`, `0435` (TIRO names, score 7);
`animation_slot1f` (no NOITE name); and the SceneObjectVtbl defaults NOITE leaves unnamed
(`slot11`, `slot43`, `slot5b`, `slot5c`, `slot61–65`).

## Dead code

No caller, slot or data reference (the engine modules are linked whole): the DOS and debug
helpers of `1028` above, the C ray casters, `dead_object_get_visible_from32`, the 16-bit scaled
copies of `1068`, the RLE whole blit and encoder, `labyrinth_backdrop_ctor_default`,
`dead_scene_object_empty_dc_hook`, the `player2d_*` trio and the `actor2d_*` overrides
`10c0:1e8e–2212`, the dead Player methods `10c0:6442–684a` (`player_move_to_edge_h` `65ae` is
called by `game_handle_message`'s dead key branch), `frame_vector_dtor`, `object_list_erase_all`/`draw_all`,
the second draw list, `draw_list_invalidate_chain`/`_all`, the StatusBar text helpers,
`occupancy_grid_occupy`/`vacate`/`is_rect_occupied`, `dib_set_usage`, `dib_create`,
`dib_map_to_palette`, `dib_copy_transparent_whole`, `wave_play_loop`, `wave_stop`,
`compound_condition_new_and`/`_or`, `portable_ctor`, `portable_ctor_hitbox`, `_halloc`, `_cexit`,
`_c_exit`, the FP library, and the phase scenes' destructors (`BUGS.md`, JARDIM harmless). Most of
`game_handle_message` and the control panel's slide and inventory code are reachable in TIRO but
not here (`GAME.md`).

Reached only through an immediate: `APPABOUT`, `APPWNDPROC`, `init_static_conditions_entry`,
`frame_cell_ctor` (`crt_array_construct`), `sprite_queue_entry_ctor`. Reached only from 32-bit code
(a 16:32 far call Ghidra does not see): `sprite_enqueue_from32`, `object_set_visible_from32`.

## Phase-4 groups

One `ghidra-investigate` agent per group. "Mechanical" groups are named from the twins and need
verification, signatures and `this` types; "game" groups need real reading. Do the CRT and
engine first (they anchor the callees), then `10c0`, then the game. The vtable structs
(`DATA.md`) and `FarSlotSignatures.java` should run before the game groups, so virtual calls
read as slot names.

| # | Range | Fns | Content | Kind / effort |
|---|---|---|---|---|
| 1 | `10b8:0000–118f` | 55 | CRT startup, exit, `_aFchkstk`, strings, long math, arrays, `_setargv`/`_setenvp`, `_flsbuf`, buffers | mechanical, low |
| 2 | `10b8:1190–2f86` | 63 | `_output` and helpers, heap, I/O, `_NMSG_*`, dosret, `_write`/`_close`/`_commit` | mechanical, low |
| 3 | `10b8:2f87–4b37` | 35 + 3.4 KB uncovered | CRT tail and the FP math library (`sin`, `cos`, `tan`, `pow`, `log`, `exp`, `_fmemset`…); unused by the game | mechanical, low priority |
| 4 | `1000`, `1008`, `1010`, `1018` | 6 | The 32-bit routines: transrle blitters (compare NOITE's), the two raycaster loops, the scaled copies. Read with `objdump -mi386`, don't type | game, high |
| 5 | `1020`, `1050`, `1090`, `1058:16ff` | 21 | App shell, Conditions, JARDIM Game subclass, `game_take_exit` | mechanical, low |
| 6 | `1058:0000` | 1 (5.9 KB) | `game_handle_message`, from TIRO's/NOITE's | mechanical, high (alone) |
| 7 | `1030`, `1040`, `1060` | 26 | Occupancy grid, Backdrop/WinG, DIB load/remap, DIB copies (+ `1060:0960`, `0c49`) | mechanical, medium |
| 8 | `1038:0000–143a` | 22 | SceneObject/Mover blit, restore, draw, attach, overlap | mechanical, medium |
| 9 | `1038:143b–2e33` | 31 | Mover step/move/edge, Animation, the dead Player2D copy, object list | mechanical, medium |
| 10 | `1048:0000–1497` | 29 | Object3D/Moveable/Portable attach, projection, draw bounds, getters, drop, elevation | mechanical, medium |
| 11 | `1048:1498–35c8` | 24 | Object3D below/support/front, Moveable tick, Player, Exit, Portable ctors/pick-up/drop/icon | mixed, medium |
| 12 | `1070`, `1078` | 25 | Scene, StatusBar, ControlPanel (verify the Scene slot names) | mechanical, medium |
| 13 | `1080`, `10a0` | 22 | Draw lists, WaveMix | mechanical, low |
| 14 | `10c0:00e2–17a0`, `10c0:17a0–1e8d` | 276 thunks + 23 | Thunk names (rerun only), Animation/Mover slot overrides | mechanical, low |
| 15 | `10c0:1e8e–2231` | 20 | The 20 unreferenced small functions after the Mover getters, and Object3D/Animated3D overrides | mixed, low |
| 16 | `10c0:2232–2a79` | 44 | Object3D/Animated3D/Moveable/Actor/Player/Exit/Portable/ControlPanel slot overrides; `2956` (Game dtor) | mechanical, medium |
| 17 | `10c0:2a7a–3393` | 21 | Game defaults, `game_init`, SceneObject ctor/dtor/occupy (`2f5c–3274`) | mixed, medium |
| 18 | `10c0:3394–3e59` | 82 | The SceneObjectVtbl defaults (all named; 2–10 instructions each): verify and sign only | mechanical, low |
| 19 | `10c0:3e5a–4537` | 25 | Animated3D, Backdrop defaults, the Backdrop ctors (`41b4`, `41de`, `42ae`, stores `48a2`) | mixed, medium |
| 20 | `10c0:4538–4cc3` | 28 | Backdrop type tests, the out-of-line SceneObject accessors (`45a4`: 40 callers, `45d2`, `45fc`, …), `4c70` (SceneObject ctor) | mixed, medium |
| 21 | `10c0:4cc4–6225` | 20 | Object3D/Moveable/Mover/Animation ctors, Frame ctor/init, `606c–610e` | mixed, medium |
| 22 | `10c0:6226–6cdb` | 31 | Dtors, update list, Scene ctor and getters, ControlPanel/StatusBar ctors | mixed, medium |
| 23 | `10c0:6cdc–7b77` | 29 | Player (`6cdc`), ControlPanel (`6e2e`), Actor (`72be`), Animated3D (`7166`), Animation (`76a4`), Scene (`7a30`), the phase-1 scene (`7076`), the labyrinth scene (`7462`) ctors | mixed, medium |
| 24 | `10c0:7b78–933a` | 12 | Exit (`8892`), the `8e60` class (`8a76`), Conditions, `8afc` (a scene/backdrop ctor with "Labirinto"), phase-2/3 helpers (`8cb0`, `925a`) | game, medium |
| 25 | `1028:0000–2033` | 20 | Labyrinth A: map load/parse (`0077`), render (`0951`, `134f`), the four sprite drawers `482c–4a4e` | game, high |
| 26 | `1028:2034–3e22` | 7 | Labyrinth B: object placement `2034`, backdrop create `2191`, the 6 KB slot-23 handler `2609` (movement, hits, 0x40a) | game, high |
| 27 | `1028:3e23–5fd6` | 20 | Labyrinth C: player turn/move (`3e23`, `4655`), the unreferenced `4bca`/`4f4d`, object spawning `52a8`, the labyrinth scene handler `5dba` and slot 23 `5ef1` | game, high |
| 28 | `1068`, `1088` | 11 | Scaled DIB copies with huge pointers; `transrle.cpp` 16-bit side | game, high |
| 29 | `1098` | 12 (13 KB) | Phase 1 scene: handler, create (bitmaps, map, waves, music), the tick `0f6e` | game, high |
| 30 | `10a8` | 12 (16 KB) | Phase 2 scene (compare with 29; mostly the same source) | game, high |
| 31 | `10b0` | 11 (11 KB) | Phase 3 scene (compare with 29) | game, high |

## Phase 4 results

All 31 groups are done. The game is described in `GAME.md`, its bugs in `BUGS.md` (section
JARDIM, J1–J6). What phase 4 corrected in the earlier picture:
- **The 32-bit routines** are the two ray walks (`1008`, `1010`), the wall column blit with depth
  shading (`1000:0024`) and the scaled transparent sprite blit (`1018:0024`); `1000:0148`/`0234`
  are NOITE's two row copies. All six were checked against the original code in `tools/oracle`.
- **The walks call back into 16-bit code** with 32-bit far calls: `1028:4b04` and `4b81` are not
  dead but the gateways `sprite_enqueue_from32` and `object_set_visible_from32`; their prologue
  moves the frame 4 bytes to turn the 16:32 return address into a 16:16 one. The C ray casters
  `4bca`/`4f4d`, which call them with a normal far call, are the dead ones.
- **The sprite queue** is a binary tree of 100 nodes keyed by depth (`SpriteQueueEntry` +0xc/+0x10
  are the children), drawn farthest first; it is the painter's algorithm of the sprites.
- **`1028:134f` is the sky and floor** (`labyrinth_draw_sky_floor`), not a second renderer; the
  4 "sprite drawers" `482c–4a4e` are the wall and door column drawers.
- **The phase scenes' slot 0x12 is `placeObjects`**, not a per-phase tick: 72/97/42 placements of
  one object per type in many cells, run again at every respawn. The other new LabyrinthScene
  slots: 0x10 `hit`, 0x11 `touch`, 0x13/0x14 the enemy attack/step waves, 0x15 the fire wave,
  0x16 the door wave, 0x17 `onLifeLost` (the base table's 0x17 is `labyrinth_scene_respawn`).
- **The phase scenes' destructors** (`1098:0dd2`, `10a8:0f38`, `10b0:0ed6`) never run; the scenes
  are built by `phaseN_scene_create_new_scene` from the exit index of the SPACE door.
- **The variant** only picks the final enemy's picture (`espanf` for 1, `vamanf` for 0).
- **`g_startX/g_startY`** are set by the exit doors to the next phase's start: (1744, 48) for phase
  2, (48, 112) for phase 3; the `g_carry*` globals (`00a2–00aa`) carry health, lives, ammo, level
  and score + 500.
- **`LabyrinthBackdrop.prevX/prevY` are `startX/startY`** (the respawn point); `hudCounter2/3` are
  `level`/`ammo`; `state738` is `shotInFlight`.
- **`SceneObject` +0x496/+0x498** hold the labyrinth world position (NOITE's `rleBits`, copied
  from x/y by the state initialiser), +0x49a is the enemy flag (NOITE's `playOnceRewinds`), +0x49c
  the wall strip's texture height.

## Cleanup

- **Virtual calls:** `FarSlotSignatures.java 10c0 defs large` rewrote the 224 slot definitions
  from their first targets (`SceneVtbl.handleMessage` has none: slot 0 is `_purecall`), then
  `10c0 calls large` wrote 390 of the 421 `CALLF [BX+k]` call-site overrides. The 31 left were read
  and applied with `site large` (MoverVtbl `placeAt` on a Mover reached through its vbase,
  AnimationVtbl `isLocked`/`playOnce`, Object3DVtbl `findSupport`/`isInFrontOf`, BackdropVtbl
  `create`/`setView`/`setAxis`/`queryRect`, SceneVtbl `createNewScene`, ControlPanelVtbl
  `drawInventory`, ConditionVtbl `evaluate`, SceneObjectVtbl `getSceneName`/`setElevation`). Once
  the Condition and Mover types were on the callers, `calls` resolved 410 by itself; all 421 sites
  have an override. Three `__stdcall16far_pop<n>` models were installed for odd argument counts.
- **Names:** `sprite_enqueue_from32`, `object_set_visible_from32`,
  `dead_object_get_visible_from32` (1028:4b04/4b81/4b4d); `game_scalar_dtor` (10c0:0000),
  `frame_vector_dtor` (003e), `backdrop_blit_to_dc` (1794, the WinGBitBlt of the whole surface);
  `sprite_queue_ctor`/`sprite_queue_entry_ctor` (4704/47d6); `animation_lock`/`animation_is_locked`
  (7102/7122, AnimationVtbl slots 0/1); `player_move_to_edge_h` (65ae, NOITE's
  `directional_player_move_to_edge_h`, the callee group 6 named in `game_handle_message`) and the
  dead Player methods `dead_player_*` (6442–684a); the LabyrinthScene slot defaults
  `labyrinth_scene_hit_default` … `play_door_sound_default` (758c–761a); the two HUD pairs that
  shared names are `labyrinth_draw_hud_strip`/`present_hud_strip` (11b3/12ce, the whole strip with
  the control panel) and `labyrinth_draw_hud`/`present_hud` (43e9/438d, the numbers and the face).
  The other callees group 6 named (`update_list_is_empty`, `update_list_flush`,
  `update_list_discard`) were already applied.
- **Structs:** `SpriteQueueEntry` {object far, dist, angle, col, row, left far, right far} and
  `SpriteQueue.root`/`nextFree`; `SceneObject.slot00Flag` (+0x48e, the word the slot00/01 defaults
  set and read, over NOITE's wave pointer), `worldX`/`worldY` (+0x496/+0x498), `isEnemy` (+0x49a);
  the LabyrinthBackdrop fields above; `Animation.locked` (+0x14); the new `ObjectList` fields,
  `OccupancyGrid`, `UpdateList` (30 entries), `Condition`/`FlagCondition`/`CompoundCondition`,
  typed on their functions. `DrawList` and `StatusBar` are left as `void *` (the draw list's node
  layout differs from NOITE's; the status bar is never built).
- **Tags:** 27 `review` tags resolved (the gateways, the renamed `FUN_`, the dead Player methods,
  the AnimationVtbl stubs, `backdrop_autoscroll`, the slot00/01 defaults, the CRT string twins);
  53 left with a note (§Remaining `FUN_` and `review`).
- **Plates:** `raycast_render_view` (which parity is see-through in which walk),
  `sprite_queue_insert` (its callers), the plates naming the renamed fields and functions.
- `NearAdjustorThunks.java 10c0 00e2 17a0 far` rerun: 276 thunks (53 fixed, 223 vtordisp), every
  name matching its target.

## Scripts

`ghidra/scripts/`:

| Script | Use here |
|---|---|
| `CopyTypesFromProgram.java` | `/NOITE.EXE` only (SDK structs and 83 import signatures) |
| `JardimFarVtSlots.java` (new) | far vtables in `10c0` → functions, slot typing, store references. Args: `[dry] [seg:off …]` |
| `NearAdjustorThunks.java` | `10c0 00e2 17a0 far`; rerun after renaming |
| `CodeGapSweep.java` | per 16-bit code segment, `create` |
| `DeadJumps.java` | all 16-bit code segments |
| `JardimDeadBlocks.java` (new) | the four dead arms |
| `NearSignatures.java` | all 16-bit code segments, `regargs=10b8:0000-4b37` |
| `ExportFunctionOps.java` | op dumps for the matchers |
| `RenameFunctions.java` | the name TSVs |
| `FarSlotSignatures.java` (`large`) | `10c0 defs large`, `10c0 calls large`, `10c0 site large <addr>=<Vtbl> …` |

Inline (`zig-out/jardim/gs/`, not committed): `JardimStats` (counts and coverage),
`JardimSweepAll` (the gap sweep over all segments), `JardimVtScan` (read-only store scan),
`JardimVtDump`/`JardimExportRawOps`/`JardimCensus` (dumps), `JardimImports` (the 9 hand-typed
imports), `JardimSpec` (the spec extensions and the call-fixup). The cleanup's, in
`zig-out/jardim/cleanup/`: `JardimClStructFix` (the struct fixes), `JardimClApply` (renames,
prototypes, parameter types, plates and tags from the `edits*.txt` lists), `JardimClDump` (the
plate dump).
