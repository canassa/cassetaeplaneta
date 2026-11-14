# JARDIM.EXE: function inventory

The Ghidra program `/JARDIM.EXE` after the phase-2 mapping: every function found, every function
classified, the engine twins and the CRT named. Addresses are Ghidra `seg:off`. JARDIM is a
large-model `/Od` build (far code, far data, `this` a far pointer at `[BP+6]`, far vtables in the
code segment `10c0`); see `QUALITY.md` §0. NOITE is the reference for the class set, the vtable
layouts and the CRT; TIRO (the other `/Od` build) for the code shape and most engine names.
The data is in `DATA.md`.

## Counts

**1,160 functions:** 93 import thunks, 276 adjustor thunks and 791 code functions. **458 of the
791 are named, 333 stay `FUN_`.** Every named function has a plate saying where the name comes
from.

| Kind | Fns | Named | Where |
|---|---|---|---|
| Import thunk | 93 | 93 | `10e8`, typed (all but `__FPMATH`) |
| Adjustor thunk | 276 | (after targets) | `10c0:00e2–17a0`; `<target>_thunk[_k]` |
| CRT | 153 | 91 | `10b8` (62 `FUN_`, nearly all in the FP math library, `2f87–4b37`) |
| 32-bit routines | 6 | 0 | `1000` (3), `1008`, `1010`, `1018` |
| App shell | 10 | 10 | `1020` |
| Engine | 529 | 357 | `1030–1080`, `1090`, `10a0`, `10c0` (338, including ~20 ctors of the JARDIM classes) |
| JARDIM game | 93 | 0 | `1028` (47), `1068` (8), `1088` (3), `1098` (12), `10a8` (12), `10b0` (11) |

108 code functions have **no reference at all** (no call, no jump, no vtable slot, no data
reference; listed below): dead code, or reached only through a code-pointer immediate (as
`APPABOUT`, `APPWNDPROC`, the scene ctors).

By segment (code functions other than the adjustor thunks):

| Seg | Fns | Named | `FUN_` | Seg | Fns | Named | `FUN_` |
|---|---|---|---|---|---|---|---|
| `1000` | 3 | 0 | 3 | `1060` | 6 | 4 | 2 |
| `1008` | 1 | 0 | 1 | `1068` | 8 | 0 | 8 |
| `1010` | 1 | 0 | 1 | `1070` | 7 | 7 | 0 |
| `1018` | 1 | 0 | 1 | `1078` | 18 | 16 | 2 |
| `1020` | 10 | 10 | 0 | `1080` | 11 | 9 | 2 |
| `1028` | 47 | 0 | 47 | `1088` | 3 | 0 | 3 |
| `1030` | 9 | 9 | 0 | `1090` | 6 | 6 | 0 |
| `1038` | 53 | 47 | 6 | `1098` | 12 | 0 | 12 |
| `1040` | 11 | 11 | 0 | `10a0` | 11 | 11 | 0 |
| `1048` | 53 | 49 | 4 | `10a8` | 12 | 0 | 12 |
| `1050` | 4 | 4 | 0 | `10b0` | 11 | 0 | 11 |
| `1058` | 2 | 2 | 0 | `10b8` | 153 | 91 | 62 |
| | | | | `10c0` | 338 | 182 | 156 |

Conventions after `NearSignatures.java`: 576 `__stdcall16far` (far pascal, parameters listed
reversed, `this` first as two words), 137 `__cdecl16far`, 43 CRT near helpers, 98 tagged `sig?`
(the frameless CRT entries, varargs `sprintf` and `message_box_printf`, and functions no caller
cleans up after). The adjustor thunks have no signature.

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
slot 1 and returns 0) stay `FUN_`: they sit where NOITE has its AVI methods, and JARDIM has no AVI.

**Names to verify in phase 4** (method weaker than the rest):
- `1070:014d/01a8/0206/026a/02b6` (Scene `addObject`/`addExit*`): the SceneVtbl slot order is
  NOITE's, the TIRO alignment agrees only for `addObject` and `addExitAt`.
- `1038:274a/2776/27a5` (`player2d_*`): TIRO's names by alignment (0.8); they are unreferenced
  here, and JARDIM has no Player2D class: dead copies of the module's Player2D code.
- The CRT names between 0.6 and 0.85 (`rn_crt.tsv`).

## Segment inventory

| Seg | What | Status |
|---|---|---|
| `1000` | 32-bit blitters: `0024` (scaled, for `1068:0000`), `0148` (transparent rows, for `dib_copy_transparent*`), `0234` (rows, for `dib_copy*`) | `FUN_`; read with objdump |
| `1008`, `1010` | 32-bit raycasting loops (`0024` each), called by `1028:0951` | `FUN_` |
| `1018` | 32-bit scaled sprite copy (`0024`), called by `1068:1336` | `FUN_` |
| `1020` | App shell (TIRO `1038`) | all named |
| `1028` | The labyrinth: raycasting backdrop (`4842` table: `2191` create, `2609` slot 23 handler: movement, hits, result), map placement `2034` ("Objeto posicionado fora do labirinto / dentro de parede"), render `0951`/`134f`, the labyrinth scene's handler `5dba` and slot 23 `5ef1` (table `810a`) | `FUN_` (game) |
| `1030` | Occupancy grid, Backdrop | named |
| `1038` | SceneObject/Mover/Animation, object list; dead Player2D copy | named but 7: `161c` (empty member, TIRO's `FUN_1028_0e71`), `295c` (`object_list_remove`? 0.54), `2d98` (TIRO's `FUN_1028_1cb7`), and the 3 AnimationVtbl stubs `2362–23c2` |
| `1040` | DIB load/palette/remap | named |
| `1048` | Object3D/Moveable/Portable/Player/Exit | named; `2510`, `2aed` (third Portable ctor), `30c3`/`32d6` (pick-up/drop?) `FUN_` |
| `1050` | Conditions | named |
| `1058` | `game_handle_message`, `game_take_exit` | named |
| `1060` | DIB copies; `0960`, `0c49` new (unreferenced) | named but 2 |
| `1068` | Scaled DIB copies (huge pointers): outer/inner pairs `0000/01f5` (via `1000:0024`), `0583/0702`, `09fc/0c8e`, `1336/16ec` (via `1018:0024`) | `FUN_` (game) |
| `1070` | Scene | named |
| `1078` | StatusBar, ControlPanel | named but `01a6`, `086e` |
| `1080` | Draw lists (live and dead copy) | named but `0717`, `096c` (insert/remove of the live list, < 0.6) |
| `1088` | `transrle.cpp` 16-bit side (`0000` called from the SceneObject draw code; `0389`, `06ce` unreferenced) | `FUN_` |
| `1090` | JARDIM Game subclass | named |
| `1098` | Phase 1 scene (table `834c`): handler `3159`, createNewScene `0000`, create `0078`, slots 16–23 (`2dd3`, `2823`, `0f6e` = the 6 KB tick, `2f3c`, `300b`, `30df`, `3131`, `2f13`), ctor `0dd2` | `FUN_` (game) |
| `10a0` | WaveMix | named |
| `10a8` | Phase 2 scene (table `91aa`), the same layout (`3c60` handler, `1103` 8 KB tick, ctor `0f38`) | `FUN_` (game) |
| `10b0` | Phase 3 scene (table `92da`, 23 slots), the same layout (`29af` handler, `10d0` tick, ctor `0ed6`) | `FUN_` (game) |
| `10b8` | CRT; `2f87–4b37` the math library | named but 62 |
| `10c0` | Thunks; SceneObject defaults (`3394–3e59`, all named); Animation/Mover/Object3D/Animated3D/Actor/Player/Exit/Portable/ControlPanel overrides (`17a0–2a79`); Game defaults and `game_init` (`2a7a–3393`); Backdrop defaults (`439a–458a`); SceneObject accessors (`45a4–4c70`, `FUN_`); ctors and dtors (`4cc4–933a`, mostly `FUN_`) | 182 named |

## Unreferenced functions (108)

No reference of any kind. Engine dead code is expected (the module linked whole):
`dead_scene_object_empty_dc_hook`, the `player2d_*` trio, `object_list_erase_all`/`draw_all`,
the second draw list (`dead_draw_list_*`), `draw_list_invalidate_chain`/`_all`, the
StatusBar/ControlPanel text helpers, `occupancy_grid_occupy`/`vacate`/`is_rect_occupied`,
`dib_set_usage`, `dib_create`, `dib_map_to_palette`, `dib_copy_transparent_whole`,
`wave_play_loop`, `wave_stop`, `compound_condition_new_and`/`_or`, `portable_ctor`, `_halloc`,
`_cexit`, `_c_exit`, and 23 FP-library entries.

Not dead, reached only through an immediate: `APPABOUT` (dialog procedure),
`init_static_conditions_entry` (a CRT init table), the three phase scene ctors `1098:0dd2`,
`10a8:0f38`, `10b0:0ed6` (no direct call; how the phases are constructed is a phase-4 question).

Game code without a reference, to check in phase 4: `1028:0000`, `067e`, `069b`, `0796`, `0ecb`,
`0f85`, `4b4d`, `4bca` (899 bytes), `4f4d` (859 bytes); `1048:2aed`; `1060:0960`, `0c49`;
`1068:0583`, `09fc` (two of the scaled-copy pairs); `1078:01a6`; `1088:0389`, `06ce`;
`10c0:003e`, `1e8e–2212` (19 small functions after the Mover getters), `5994`, `6442–68ca`.

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

Inline (`zig-out/jardim/gs/`, not committed): `JardimStats` (counts and coverage),
`JardimSweepAll` (the gap sweep over all segments), `JardimVtScan` (read-only store scan),
`JardimVtDump`/`JardimExportRawOps`/`JardimCensus` (dumps), `JardimImports` (the 9 hand-typed
imports), `JardimSpec` (the spec extensions and the call-fixup).
