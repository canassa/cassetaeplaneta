# SAUNA.EXE: function inventory

The Ghidra program `/SAUNA.EXE` after phase 4 and the cleanup: every function bounded, classified,
named where the evidence allows, and plated (but 15, below) with where its name comes from. Addresses are
Ghidra `seg:off`. SAUNA is a large-model `/Od` build (far code and data, `this` a far pointer at
`[BP+6]`, vtables of far slots in code segment `10a0`); see `QUALITY.md` §0. TIRO (`docs/tiro/`) is
the reference for the names, NOITE for the slots TIRO lacks. The data is in `DATA.md`.

## Counts

**1,171 functions:** 89 import thunks, 387 adjustor thunks and 695 code functions. **673 of the
695 are named, 22 stay `FUN_`** ("Remaining `FUN_` functions"); 680 have a plate. 384 of the 387
thunks are named after named targets; 3 carry their dead target's `FUN_` name (`5b8c`, `5ba2`,
`5c00`).

| Kind | Fns | Where / names |
|---|---|---|
| Import thunk | 89 | `10c8`, all typed (§Imports in `QUALITY.md`) |
| Adjustor thunk | 387 | `10a0:0170–1e78` (349), `59ce–5a72` (8), `61d6–6290` (9), `68de–6aa0` (21): 59 fixed, 328 vtordisp; `<target>_thunk[_k]` |
| CRT | 98 | `1098`, all named |
| 32-bit blitters | 4 | `1000:0024` (new), `0148` `dib_rows_copy_transparent32`, `0234` `dib_rows_copy32`; `1008:0024` (new), all named and typed (twins of JARDIM's, §RLE path) |
| DIB | 17 | `1010` (6), `1018` (11) |
| RLE | 11 | `1068` (8, scaled and stretched DIB copies), `1088` (3, `transrle.cpp`); JARDIM's twins, §RLE path |
| App shell | 10 | `1058` |
| WaveMix | 11 | `1090` |
| Engine | 460 | `1020–1040`, `1050`, `1060`, `1070`, `1078`, `10a0` |
| SAUNA game | 47 | `1048` (6), `1080` (38), `10a0` (`pacman_ctor`, `ghost_ctor`, `sauna_backdrop_ctor`); `GAME.md` |

By segment (code functions other than the adjustor thunks; named / total):

| Seg | Named | Seg | Named | Seg | Named |
|---|---|---|---|---|---|
| `1000` | 3/3 | `1038` | 7/7 | `1070` | 11/11 |
| `1008` | 1/1 | `1040` | 2/2 | `1078` | 17/18 |
| `1010` | 4/6 (`0960`, `0c49` plated, `FUN_`) | `1048` | 6/6 | `1080` | 38/38 |
| `1018` | 11/11 | `1050` | 4/4 | `1088` | 3/3 |
| `1020` | 51/53 | `1058` | 10/10 | `1090` | 11/11 |
| `1028` | 9/9 | `1060` | 7/7 | `1098` | 98/98 |
| `1030` | 53/53 | `1068` | 8/8 | `10a0` | 332/336 |

Conventions (Ghidra's): 542 `__stdcall16far`, 95 `__cdecl16far`, 13 on the `ghidra/cspec` far
cdecl extensions (`_dx_ax` 2, `_dxax_ptr` 11), 22 near (CRT helpers), 23 unknown (the 32-bit
routines, the CRT entries and the unmapped RLE module).

## Function discovery

In this order (scripts in `ghidra/scripts/`, run through Sauna-prefixed copies):
1. **Adjustor thunks** — `NearAdjustorThunks.java 10a0 0000 1e84 far`, then `59ca 5a80`, `61d0 62a0`,
   `68d0 6ab0`, kept off the vtable ranges so no data byte can become a thunk. 387 thunks; 55
   bodies that had run into their `JMPF` target were cut back. Vtordisp thunks have the
   large-model shape `MOV BX,SP; LES BX,SS:[BX+4]; MOV AX,ES:[BX-2]; …`.
2. **Gap sweep** — `CodeGapSweep.java` on `1010–10a0`: 92 more, among them `game_handle_message`
   (`1040:0000`), APPABOUT (`1058:0000`), 77 in `10a0` and 10 CRT entries.
3. **Vtable slots** — `FarVtSlots.java 10a0 <lo> <hi> large` on the six table ranges: 1,404 slots,
   all typed as 4-byte pointers with a DATA reference to their target, and 69 vptr-store pairs
   referencing their table. Only one slot target was not a function yet.
4. **Dead jumps** — `DeadJumps.java` on all code segments: 51 `/Od` epilogue jumps folded in.
   `SaunaDeadBlock.java` added three unreachable blocks to their functions: `1068:0167–01a5`,
   `1068:162b–167e` (the `else` of constant conditions) and `1080:402f–4034` (two chained jumps).
5. **CRT by hand** (`zig-out/sauna/gs/SaunaCrtFix.java`): the two `INC BP` prologues (`1b26`, `1ba6`)
   re-made one byte earlier; `_output`'s jump table at `1098:0b04` typed `word[8]` with
   COMPUTED_JUMP references, and the body re-flowed (1,062 bytes, as NOITE's); the frameless
   entries `_aNchkstk` `00d8`, `_cintDIV` `09ae`, `crt_dosret_maperr` `1941`, `crt_ltoa_body`
   `2008`; `_output`'s seven near helpers `0f2f–0fce`.

What is left uncovered, all proven data or padding:
- `1000` and `1008` past their DPMI prologues (32-bit code Ghidra cannot decode; 690 bytes);
- `1098:0000–0011`, the segment prefix, and `1098:0b04` the jump table;
- in `10a0`: the 42 vtables and 13 vbtable groups, and 411 one-byte alignment fillers.

## Vtables

All 42 tables are in `10a0`, each reached by a far vptr store pair (`MOV ES:[BX+k],off; MOV
ES:[BX+k+2],0x10a0`). Each was matched to its TIRO class by its targets (names from the module
alignment) and by its ctor; the small tables by slot count against NOITE. `S` = SceneObjectVtbl
(98), `O` = Object3DVtbl (8), `M` = MoverVtbl (1 slot, `placeAt`), `A` = AnimationVtbl (6).

| `10a0:` | Class | TIRO / NOITE table | Ctor (vptr store) |
|---|---|---|---|
| `41f8` | Frame (1) | TIRO `0692` | `frame_ctor` `51b2`, `frame_dtor` `1e84` |
| `41fc` S | SceneObject | TIRO `0696` | `scene_object_ctor` `45c2`, `_ctor_bmp` `91fe`, `_dtor` `219e` |
| `5326` M, `532a` S, `54b2` O | Moveable | TIRO `0ca0/0ca4/0e10` | `46be`, `4840`, `49bc` (three ctors, unnamed) |
| `54dc` M, `54e0` S, `5668` O | Portable | TIRO `0b06/0b0a/0c76` | `portable_ctor` `1030:2ed8`, `_ctor_zoom` `2cee`, `1030:2aed` |
| `5692` O, `56b2` S | Object3D | TIRO `0802/0822` | `object3d_ctor` `4630` |
| `583e` M, `5842` S | Mover | TIRO `0992/0996` | `mover_ctor` `7810`; `4b20`, `4c88`, `4dec` (unnamed) |
| `79ea` M, `79ee` A, `7a06` S | Actor2D | TIRO `13ce/13d2/13d6` | `actor2d_ctor_strips` `762e` |
| `7b96` M, `7b9a` A, `7bb2` S | Player2D | TIRO `154a/154e/1552` | `player2d_ctor` `718c` |
| `7d42` A, `7d5a` S, `7ee2` O | Animated3D | TIRO `1c3c/1c40/1dac` | `animated3d_ctor_strips_no_hitbox` `72c2` |
| `7f0c` (14), `7f44` S, `80cc` O | ControlPanel (concrete; no TIRO-style subclass) | TIRO `1a32/1a56/1bc2` + `1038` | `control_panel_ctor` `6aac` |
| `80f6` (2), `80fe` A, `8116` S | **Pacman** (derives Player2D, keeps its `isScrollTarget`/`slot43`; MoverVtbl + 1 slot) | — | `pacman_ctor` `7018` |
| `82a6` (7) | Game (slot 6 `_purecall`) | TIRO `0eee` | `game_ctor` `6c40`, `game_dtor` `86fc` |
| `82c2` A, `82da` S | Animation | TIRO `125a/125e` | `animation_ctor` `7782`, `_ctor_strips_no_hitbox` `7502` |
| `8466` (7) | **SaunaGame** (slots 1–4, 6 in `1048`) | role of TIRO `11f2` | `sauna_game_ctor` `1048:0000` |
| `869a`, `86a6`, `86b2` (3) | FlagCondition, Condition (slot 0 `_purecall`), CompoundCondition | TIRO `1dd6/1dee/1de2` | `8482`, `863c`, `8524` |
| `8f9c` (16) | Scene (slot 0 `_purecall`) | NOITE `1010:a7b6` | `scene_ctor` `934e`, `scene_dtor` `1060:0075` |
| `8fdc` (23) | Backdrop | NOITE `g_backdropVtbl` | `backdrop_ctor` `9882`, `backdrop_dtor` `89ae` |
| `99ec` (17) | **SaunaScene** (SceneVtbl + 1 slot) | role of TIRO `1004` | `sauna_scene_ctor` `1080:2aca`, `_dtor` `1080:2daa` |
| `9a30` (24) | GridBackdrop | NOITE `g_gridBackdropVtbl` | `grid_backdrop_ctor` `965c` |
| `9a90` (3), `9a9c` A, `9ab4` S | **Ghost** (derives Actor2D; MoverVtbl + 2 slots) | — | `ghost_ctor` `9406` |
| `9c44` (24) | **SaunaBackdrop** (slot 0 `sauna_backdrop_create`) | role of TIRO `1bec` | `sauna_backdrop_ctor` `9500` |

There is no StatusBar table (`sauna_game_create_status_bar` returns NULL), no Exit, Player or
PerspectiveBackdrop table, though their methods are linked (`1030`, `1038`; dead).

**SceneObjectVtbl (98 slots).** SAUNA slot *i* = TIRO slot *i*−5 for 5–27, *i*−6 for 29–63,
*i*−8 for 66–83 and *i*−7 for 84–97 (TIRO's `unk4E` has no SAUNA slot). The SAUNA-only slots are
NOITE's `slot00`, `slot01`, `enableRle`, `isRle`, `getSceneName` (0–4), ENCAIXE's `unk18` (28) and
the is/as pair `isScrollTarget`/`slot43` (64, 65; NOITE's and JARDIM's names, placed by the callers
`backdrop_autoscroll` and `exit_tick`). The alignment (`zig-out/sauna/slotmap.py`) scores
every matched slot 0.81–0.98 from the override pattern over ten class pairs and the default bodies;
`DATA.md` lists the fields. TIRO's own type tests `isProjectile`/`isTarget`/`isCrossbow` are
ENCAIXE's `slot61`/`slot63`/`slot64` and stay so here: no SAUNA class overrides them.

**AnimationVtbl (6).** NOITE has seven AVI slots and `playOnce`; SAUNA keeps five: `setAvi`
(sets `+0x14`), `isAvi` (reads it) and three stubs that call `isAvi` and return 0, then
`playOnce`. **ControlPanelVtbl (14)** = those 6 + TIRO's 8 after `playOnce`.

Other far pointers: DGROUP `0120–0143` and `02c2–02e5` (the Pacman and Ghost strip-file tables),
`0bb2–0bcd` (7 CRT float hooks to `_fptrap`), `0bf6` (`init_static_conditions_entry`), `0c08`
(`crt_endstdio`).

## Names and how they were applied

Every name has a plate: `Name from TIRO|NOITE <name> at <addr> (<method>; <evidence>)` or
`Role: …`. The TSVs are `zig-out/sauna/rn_p2*.tsv`, applied with `RenameFunctions.java`, and the
thunks were renamed after their targets with `NearAdjustorThunks` again.

| Method | Names |
|---|---|
| CRT: NOITE bytes with relocations masked (45), NOITE link-order alignment ≥0.9, TIRO link-order alignment ≥0.85, frameless entries and `_output` helpers by position | 98 |
| Module segments, in-order alignment against TIRO (`align.py`), pairs ≥0.4 inside a segment whose alignment beats the next TIRO segment by 3× or more | 102 |
| Vtable slot: slot *i* of a SAUNA table gets the name in the mapped slot of the same class's TIRO table (thunks resolved on both sides); NOITE's tables for Scene, Backdrop, GridBackdrop; SaunaGame/SaunaScene/Pacman/Ghost overrides by slot field | 302 |
| Role: ctors and dtors by their vptr stores, checked against TIRO's ctor of the class (0.78–0.93), the 32-bit blitters by bytes, the SaunaScene and score functions (5 of them in phase 3) | 67 |

Slot names took precedence: alignment and slot agree on 79 of the 82 functions both name; the
3 others are next to functions SAUNA inserted (`enableRle` `1020:0877`, the AVI stubs
`1020:23c6–2426`), where the alignment slipped by one. Where alignment and slot gave the same
name to two addresses (`1078:0a0f`/`0b10` draw_inventory_item, `0a68`/`0b69`
get_inventory_item_at), the slot target kept it and the other stays `FUN_`.

`1060` was misaligned by the matcher (to TIRO's drop-to-support functions); its seven functions
are named from NOITE's Scene table instead: `scene_create`, `scene_add_object`,
`scene_add_exit`, `scene_add_exit_to_scene`, `scene_add_exit_at`, `scene_add_exit_alt`, and
`scene_dtor` (`0075`, the only other store of the Scene vptr).

The Pacman/Ghost/SaunaScene overrides were named by the slot they fill in phase 2 and by their
bodies in phase 4 (`pacman_refresh_power_strip`, `ghost_choose_direction`,
`sauna_scene_send_ghosts_home`, "Phase 4 results").

## Remaining `FUN_` functions

- **The RLE path (13 named, 2 `FUN_` with a plate and `review`):** see §RLE path.
- **Dead, role unproven (7, noted in their plates):** `1020:1680` (empty, this + five words),
  `1020:2dfc` (huge-pointer add), `1078:01a6` (an Animation-like ctor body, as JARDIM's),
  `10a0:52e6` (zeroes 8 bytes), `10a0:5b8c`, `5ba2`, `5c00` (empty members reached only by thunks
  no vtable holds; TIRO and INFERNO leave their twins unnamed too).

## Dead code

No call and no live slot: the DIB extras (`dib_copy_transparent_whole`, `dib_set_usage`,
`dib_create`, `dib_map_to_palette`), the PerspectiveBackdrop and Portable methods, the second draw
list (`1070:0050–0593`), the StatusBar methods, `sauna_scene_dtor`, `wave_pump`, the Exit and
Player methods (`exit_*`, `player_*`), the DirectionalPlayer overrides `10a0:6436–68be` (NOITE's
names; SAUNA builds no DirectionalPlayer), `frame_vector_deleting_dtor` and its huge part, and 126
adjustor thunks whose vtables the linker did not keep (`10a0:1052–1b28`, `59ce–5a68`,
`61d6–6286`). In `game_handle_message` the `WM_KEYDOWN`, `WM_KEYUP` and `WM_SYSTIMER` arms are
dead (the scene handler answers those messages), as are `0x205` and `0x402`.

## Phase 4: function groups

Counts are code functions without the adjustor thunks ("FUN" = still unnamed). **Mechanical** =
named from TIRO/NOITE; the agent verifies, signs (`ghidra-fix-signature`) and types `this`.
**SAUNA** = needs real reading.

| # | Range | Fns (FUN) | Content | Kind / effort |
|---|---|---|---|---|
| 1 | `1098:0000–0a09` | 37 (0) | CRT startup, strings (far), `rand`, long math, `_cinit`, exit, `_setargv`, `_setenvp` | mechanical, low |
| 2 | `1098:0a0a–206b` | 61 (0) | CRT `_flsbuf`, `_output`, far heap, `_NMSG_*`, I/O, flush, close | mechanical, low |
| 3 | `1000`, `1008`, `1010`, `1018` | 21 (4) | 32-bit blitters (two new), DIB copy (+`0960`, `0c49`), DIB load/palette/remap | mixed, medium |
| 4 | `1068`, `1088` | 11 (11) | RLE: the RLE-aware DIB copies and `transrle.cpp` encode/decode (`_assert` "pOutputBuffer!= NULL"); compare NOITE's RLE path | SAUNA, high |
| 5 | `1020:0000–1695` | 24 (1) | SceneObject/Mover blit, restore, draw, enable_rle, attach, overlap, can_step | mechanical, medium |
| 6 | `1020:1696–2e98` | 29 (1) | Mover step/move/edge, Animation (AVI stubs), Player2D, object list | mechanical, medium |
| 7 | `1028`, `1038`, `1050`, `1060` | 27 (0) | Occupancy grid, Backdrop/WinG, perspective backdrop, Conditions, Scene | mechanical, low |
| 8 | `1030:0000–1deb` | 37 (0) | Object3D/Moveable attach, project, draw bounds, getters, drop, elevation, move | mechanical, medium |
| 9 | `1030:1dec–35c9` | 16 (3) | Moveable tick, Player/Exit (dead), Portable ctors, pick up/drop/icon | mechanical, medium |
| 10 | `1040` | 2 (0, 6.9 KB) | `game_handle_message` (5.9 KB) and `game_take_exit`, from TIRO `1040` | mechanical, high (alone) |
| 11 | `1048`, `1058`, `1070`, `1090` | 38 (0) | SaunaGame overrides, app shell, draw lists, WaveMix | mechanical, low |
| 12 | `1078` | 18 (3) | StatusBar (dead) and ControlPanel; the duplicate inventory pair `0a0f`/`0a68` | mixed, medium |
| 13 | `10a0:0000–2c5d` | 61 (17) | Scalar dtors `0000–00cc`, frame, SceneObject accessors `1f10–211c`, Animation/Mover/Actor2D/Player2D slots | by slot, medium |
| 14 | `10a0:2c5e–3437` | 49 (19) | Object3D/Animated3D/Moveable overrides, helpers `2f5c–3252`, Portable/ControlPanel type tests | by slot, medium |
| 15 | `10a0:3438–3fbd` | 82 (0) | SceneObjectVtbl defaults (trivial) | by slot, low |
| 16 | `10a0:3fbe–5327` | 21 (17) | Occupancy helpers, SceneObject/Object3D/Moveable/Mover ctors (the 3 + 3 ambiguous ones), strip init/alloc, frame init | mixed, medium |
| 17 | `10a0:5328–6c3f` | 28 (24) | Backdrop/draw helpers `5a7e–5c38` (one 1.2 KB), update list `629c–634e`, the DirectionalPlayer overrides `6436–68be` (dead), ControlPanel ctor and slots | mixed, high |
| 18 | `10a0:6c40–8a55` | 38 (12) | Game ctor/dtor/init and defaults, Pacman/Animation/Actor2D/Mover ctors, Conditions, scalar dtors `86be–8970` | mixed, medium |
| 19 | `10a0:8a56–9ca4` | 57 (14) | Backdrop/GridBackdrop/Scene defaults, scene/occupancy helpers, Ghost and SaunaBackdrop ctors | mixed, medium |
| 20 | `1080:0000–13bd` | 15 (0) | **Pacman**: occupy/vacate, move (`move_to`, edges, `move_tick` 1.7 KB, `restore_background` 1.7 KB), `can_step`, stop, tick | SAUNA, high |
| 21 | `1080:13be–238f` | 9 (0) | **Ghost**: occupy/vacate, `restore_background`, `can_step`, `move_tick`, the two extra slots (`ghost_choose_direction`, `ghost_is_next_step_free`) | SAUNA, high |
| 22 | `1080:2390–437a` | 14 (0) | **SaunaScene**: backdrop create, ctor/dtor, create/create_screen, the handler `32f7` (3.5 KB: keys, timers, 0x40a), `sauna_scene_send_ghosts_home`, score and wave helpers `4082–426e` | SAUNA, high |

Order of work: groups 1–3 and 11 first (they anchor the CRT, DIB and app names), then 5–10 and
12, then the `10a0` groups 13–19 (they need the vtable structs of phase 3), group 4, and the game
groups 20–22 last.

## Phase 4 results

Groups 1–22 are done (group 4 and the four new routines of group 3 in §RLE path). The game is described in
`GAME.md`, its bugs in `BUGS.md` (section SAUNA, P1–P9). What phase 4 corrected in the earlier
picture:
- **The mouse is live:** the scene handler returns 0 for mouse messages, so `game_handle_message`
  runs them: a left click walks Pacman to the point (`pacman_move_to`), a mouse move below y 440
  starts the (off-screen) panel's slide, a right click on Pacman or a ghost runs its `playOnce`.
- **The override names:** `PacmanVtbl.slot1` is `pacman_refresh_power_strip`, `GhostVtbl.slot1`
  `ghost_choose_direction` (the ghost AI), `GhostVtbl.slot2` `ghost_is_next_step_free`,
  `SaunaSceneVtbl` slot 16 `sauna_scene_send_ghosts_home` (the struct field `sendGhostsHome`).
- **The type tests:** SceneObjectVtbl `0x100`/`0x104` are `isScrollTarget`/`slot43` (Player2D
  overrides them: `player2d_is_scroll_target`, `player2d_as_scroll_target`), then `isPlayer`,
  `asPlayer`, `isDirectionalPlayer`, `asDirectionalPlayer` at `0x108–0x114`.
- **The four ghosts share timer 0x11 by design:** the handler tests `ghosts[0]`'s id and steps all
  four in turn on it.
- **The power mode starts one message late:** the cork sets `g_powerStartPending`; the next
  message of any kind swaps the pictures and starts timer 10 (5 s).
- **Keys:** key-up clears the four latches but does not stop Pacman; he runs until blocked.
- **`Scene.unk60`** is `handlerEnabled`; `Backdrop` +0x16 is `hwnd`, +0x18 `hdcWindow`;
  `g_unk0190` is `g_transparentColor`.

Cleanup:
- **Virtual calls:** `FarSlotSignatures.java 10a0 defs large` (223 slot definitions; no target for
  `SceneVtbl.handleMessage`, slot 0 is `_purecall`) and `calls large`: 450 of the 469 `CALLF [BX+k]`
  sites; the other 19 read by hand and typed with `site large` (Mover, Animation, Object3D, Ghost,
  ControlPanel and Condition calls through the class's own vptr, two SceneObject calls on an
  untyped local, `asAnimation()->playOnce` in `game_handle_message`): 469 overrides, none left.
  The 12 calls through `g_setSystemTimer` (8) and `g_killSystemTimer` (4) have
  `/SetSystemTimerFn` and `/KillSystemTimerFn` (copied from TIRO; the two globals typed as far
  pointers to them). The CRT function-pointer calls and the calls into the 32-bit segments stay
  untyped.
- **Names:** `frame_vector_deleting_dtor` `10a0:0000` and `_huge` `00cc` (INFERNO's names),
  `mover_dtor` `9548`, the nine DirectionalPlayer overrides `6436–68be` (NOITE's
  `directional_player_*`, same bodies in the same order).
- **Tags:** 19 `review` notes: 12 resolved by the names above and `scene_object_unk18` (ENCAIXE's
  slot: `drawDirtyTo` into the backdrop's second bitmap); 7 left with a one-line note (above).
- **CRT data:** 34 globals named after NOITE's by the instruction that reads them (`DATA.md`).
- `NearAdjustorThunks.java` rerun on the four blocks: 387 thunks, every name matching its target.
- `game_handle_message`'s plate no longer carries the note on the old slot names.

## Scripts

| Script | Use here |
|---|---|
| `NearAdjustorThunks.java` (`far`) | `10a0 0000 1e84 far`, `59ca 5a80`, `61d0 62a0`, `68d0 6ab0`; rerun after renaming |
| `FarSlotSignatures.java` (`large`) | `10a0 defs large`, `10a0 calls large`, `10a0 site large <addr>=<Vtbl>\|/SetSystemTimerFn …` |
| `CodeGapSweep.java` | every code segment, `create` |
| `FarVtSlots.java` (new `large` mode) | `10a0 41f8 4384 large`, `5326 59ca`, `79ea 8482`, `869a 86be`, `8f9c 9038`, `99ec 9ca4` |
| `DeadJumps.java` | `1010 … 10a0` |
| `SaunaDeadBlock.java` (new) | `1068:0167-1068:01a5 1068:162b-1068:167e 1080:402f-1080:4034` |
| `SaunaSpecInstall.java` (new) | `ghidra/cspec 1098:00f8`: the spec extensions and the chkstk fixup |
| `CopyTypesFromProgram.java` | `/NOITE.EXE`, `/TIRO.EXE`, `/ENCAIXE.EXE`; `/TIRO.EXE SetSystemTimerFn KillSystemTimerFn`, `/NOITE.EXE CrtFILE` |
| `RenameFunctions.java` | `zig-out/sauna/rn_p2*.tsv` |
| `ExportFunctionOps.java` | op dumps of SAUNA, TIRO, NOITE, ENCAIXE for the matchers |

Scratch (not committed, `zig-out/sauna/`): `SaunaSurvey`, `SaunaRelocs`, `SaunaDump`, `SaunaRawOps`,
`SaunaFnList`, `SaunaVtDump`, `SaunaCrtFix`, `SaunaMk`, `SaunaLst` (Java), and `ne.py`,
`crtmatch.py`, `feat.py`, `align.py`, `crt.py`, `crt2.py`, `vtm.py`, `vtslot.py`, `slotmap.py`,
`names.py`, `ctors.py`, `gamecls.py`, `sofields.py`, `groups.py`.

## RLE path (group 4 and the new routines of group 3)

Everything here is JARDIM.EXE's code: each function has the same size as its JARDIM twin and the
same bytes, apart from relocated call targets and DGROUP offsets (compared per function with the NE
relocation masks); names, signatures and plates are copied from JARDIM's (`docs/jardim/FUNCTIONS.md`)
and adapted. The 32-bit routines were not retyped (read with `objdump -mi386`). Nothing in SAUNA calls
`1068:0000`, `1068:1336` or the encoder, and nothing calls `enableRle`, so none of it runs (`rle_blit_transparent`
is reachable only on the RLE branch of `scene_object_draw_clip_to`/`draw_dirty_to`). In JARDIM the
labyrinth wall and sprite drawers use the scaled blits; SAUNA has no such caller.

| Address | Name | Twin | Score |
|---|---|---|---|
| `1000:0024` | `blit_scaled_column` (32-bit, shaded 4-px column) | JARDIM `1000:0024`, byte-identical | 9 |
| `1008:0024` | `blit_scaled_sprite_transparent` (32-bit) | JARDIM `1018:0024`, byte-identical | 9 |
| `1068:0000` | `dib_blit_scaled_column` | JARDIM `1068:0000` | 9 |
| `1068:01f5` | `dead_dib_blit_scaled_column_huge16` | JARDIM `1068:01f5` | 8 |
| `1068:0583` | `dead_dib_blit_scaled_column_byte` (`sig?`: signature inferred, no caller) | JARDIM `1068:0583` | 8 |
| `1068:0702` | `dead_dib_blit_scaled_column_byte_huge16` | JARDIM `1068:0702` | 8 |
| `1068:09fc` | `dead_dib_stretch_copy_rect` (`sig?`) | JARDIM `1068:09fc` | 8 |
| `1068:0c8e` | `dead_dib_stretch_copy_rect_huge16` | JARDIM `1068:0c8e` | 8 |
| `1068:1336` | `dib_stretch_copy_transparent` | JARDIM `1068:1336` | 9 |
| `1068:16ec` | `dead_dib_stretch_copy_transparent_huge16` | JARDIM `1068:16ec` | 8 |
| `1088:0000` | `rle_blit_transparent` | JARDIM `1088:0000` (replaces NOITE `1018:b78a`) | 9 |
| `1088:0389` | `dead_rle_blit_transparent_whole` (`sig?`) | JARDIM `1088:0389` | 8 |
| `1088:06ce` | `dead_rle_encode_dib` (`sig?`; asserts on `d:\c&p\pacman\transrle.cpp`) | JARDIM `1088:06ce` | 8 |
| `1010:0960` | `FUN_1010_0960` (`review`: row-table stepped clipped copy, role guessed) | JARDIM `1060:0960` (also unnamed) | 4 |
| `1010:0c49` | `FUN_1010_0c49` (`review`: its inner loop) | JARDIM `1060:0c49` | 4 |

`1000:0148`/`0234` are NOITE's row copies (JARDIM's `dib_rows_copy_transparent32`/`dib_rows_copy32`).
