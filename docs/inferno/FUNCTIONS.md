# INFERNO.EXE: function inventory

The Ghidra program `/INFERNO.EXE` after phase 2: every function mapped, the twins named, every
named function carrying a plate that says where its name comes from. Addresses are Ghidra
`seg:off`. INFERNO is a large-model `/Od` build (far code and far data, `this` a far pointer at
`[BP+6]`, the vtables in the code segment `1080`); see `QUALITY.md` §0. TIRO (`docs/tiro/`) is the
reference for the engine names, NOITE for the CRT. The data is in `DATA.md`.

## Counts

**1,160 functions:** 86 import thunks, 464 adjustor thunks and **610 code functions**. 557 of the
610 are named and carry a plate; **53 stay `FUN_`** (38 of them the INFERNO game in `1068`).
Phase 2 named 544; phase 3 added the 13 that the class and data map made obvious (the game
classes' ctors and type tests, the score helpers, the two new Backdrop type-test slots renamed).

| Kind | Fns | Where / names |
|---|---|---|
| Import thunk | 86 | `10a8`, all typed |
| Adjustor thunk | 464 | `1080:0132–202f` (371), `1080:6876–705f` (93); `<target>_thunk[_k]`, renamed after their targets |
| CRT | 92 | `1078`, all named; 50 with NOITE's prototypes |
| Blitter | 2 | `1000:0024`, `1000:0114` (32-bit code, not typed) |
| DIB | 15 | `1008`, `1010` |
| App shell | 10 | `1038` |
| WaveMix | 11 | `1070` (TIRO's `1078` module) |
| Engine | 417 | `1018–1060`, `1080` (15 still `FUN_`) |
| INFERNO game | 63 | `1048` (4), `1068` (47), and 12 in `1080` (the game classes' ctors, type tests, scene/backdrop ctors) |

By segment (code functions, without the adjustor thunks):

| Seg | Fns | Named | No reference | Seg | Fns | Named | No reference |
|---|---|---|---|---|---|---|---|
| `1000` | 2 | 2 | 0 | `1048` | 4 | 4 | 0 |
| `1008` | 4 | 4 | 2 | `1050` | 4 | 4 | 3 |
| `1010` | 11 | 11 | 3 | `1058` | 6 | 6 | 6 |
| `1018` | 47 | 46 | 4 | `1060` | 2 | 2 | 0 |
| `1020` | 7 | 7 | 7 | `1068` | 47 | 9 | 1 |
| `1028` | 46 | 44 | 5 | `1070` | 11 | 11 | 2 |
| `1030` | 10 | 10 | 1 | `1078` | 92 | 92 | 8 |
| `1038` | 10 | 10 | 2 | `1080` | 305 | 293 | 39 |
| `1040` | 2 | 2 | 0 | | | | |

"No reference" (83) counts functions that nothing calls and no live slot or thunk reaches. Some
are reached by an immediate (APPWNDPROC and APPABOUT through RegisterClass/DialogBox,
`frame_cell_ctor` through `crt_array_construct`, `init_static_conditions_entry` and
`crt_endstdio` through the CRT tables); the rest is linked-in dead code (§Dead code).

Conventions (code functions): 473 `__stdcall16far`, 94 far cdecl (`__cdecl16far`, 9
`__cdecl16far_dxax_ptr`, 1 `__cdecl16far_dx_ax`), 22 near (CRT), 21 left unknown (CRT entries
without a frame). `NearSignatures.java` set the non-CRT ones mechanically (`RETF n` →
`__stdcall16far`, n/2 word parameters; `RETF` → `__cdecl16far` from the callers' cleanup), so a far
`this` shows as two words; 7 carry the tag `sig?` (no caller cleanup to count: the five unused DIB
functions, `FUN_1028_28f7`, `wave_stop`). The CRT prototypes come from NOITE
(`InfernoCrtSigs`, inline; 50 copied, the internal helpers have none in NOITE either).

## Function discovery

- **Vtable slots** (`FarVtSlots.java 1080 <lo> <hi>` on `4790–4f22`, `65fa–669a`,
  `7d50–8430`, `8648–866c`, `89c2–8e4a`): 1,248 far slots, 362 new functions, every slot typed
  as a 4-byte pointer with a DATA reference to its target, and a DATA reference from each vptr
  store. The script's store search matched the constants `0x8000`/`0x8080` in `dib_create`
  (`1010:0901/0913/0949/096d`) as if they were stores of the tables `1080:8000`/`8080`; those four
  references were dropped (`1080:7f74–80df` is one 91-slot table, not three).
- **Adjustor thunks** (`NearAdjustorThunks.java 1080 0132 2030 far`, `1080 6800 7060 far`): 464
  thunks (63 + 14 fixed, 308 + 79 vtordisp). 32 bodies had run on into their targets and were cut
  back to the `JMPF`. The large-model vtordisp shape (`LES BX,SS:[BX+4]`) needed a one-line
  addition to the script.
- **Gap sweep** (`CodeGapSweep.java <seg> … create` per segment): 23 more, among them
  `1038:0000` APPABOUT and `1020:0000`.
- **CRT by hand** (`gs/InfernoCrtFix.java`, scratch): the `INC BP` entries `_flushall` `1a0c` and
  `_fcloseall` `1a8c` (Ghidra had them one byte late); `_aNchkstk` `00d8`, `_cintDIV` `08b6`,
  `crt_dosret_maperr` `1827`, `crt_ltoa_body` `1eee`; the 7 `_output` helpers `0e37–0ed6`;
  `_output`'s jump table at `0a0c` (8 words, COMPUTED_JUMP references from `0a76`), after which
  `_output` has NOITE's 1,062 bytes. `FATALEXIT` is no-return.
- **Dead code**: 44 `/Od` dead `JMP rel16` (`DeadJumps.java`), and the unreachable block
  `1040:1388–13db` added to `game_take_exit`'s body.

What is left uncovered, all data or padding: `1078:0000–0011` (segment prefix), `1078:0a0c`
(jump table), the vtables and strings in `1080`, and one-byte `00`/`90` fillers.

## Names and how they were applied

Every name has a plate: `Name from TIRO|NOITE <name> at <addr> (<method>…)` or
`Name <name>: <evidence>`. `RenameFunctions.java <tsv> force` applied the TSVs
(`zig-out/inferno/rn_crt.tsv`, `rn_vt.tsv`, `rn_align.tsv`, `rn_fix.tsv`, `rn_fix2.tsv`);
`force` rewrites a plate this script wrote before, for names corrected after a vtable remap.

| Method | Names |
|---|---|
| Imports: NOITE's signatures (81, the 4 WinG ordinals renamed), TIRO's for the other 5 | 86 |
| CRT: NOITE's `1008` functions searched byte for byte in `1078` (81 at ≥ 0.72); 11 by order, size and body (`abs`, `_purecall`, `crt_doexit`, `crt_restore_vectors`, `_setargv`, `_dosmaperr`, `crt_endstdio`, `crt_error_r6020`, `_cintDIV`, `crt_ltoa_body`, `operator_delete_huge`) | 92 |
| Blitters: segment byte-identical to TIRO's | 2 |
| Vtable slot: slot *i* of an INFERNO table gets the name of the TIRO function in the mapped slot of the same class's table (thunks resolved on both sides; mapping below) | 255 |
| In-order alignment of each module segment against TIRO (`align.py`; features independent of the data model), FUN_ functions with score ≥ 0.4 and a consistent neighbour; in `1080` only `2030–6177`, where the order still follows TIRO | 158 |
| By role: ctors/dtors from their vptr stores, the INFERNO Game/Scene/Backdrop subclass slots, the score helpers | 29 |
| By hand (body read): `occupancy_grid_set_cell`, `occupancy_grid_clear`, `scene_object_reset_rects`, `animated3d_tick`, `exit_tick`, `portable_drop`, `scene_object_frame_src_x/y` (the alignment had them shifted by one), the Frame vector deleting dtors, the new Backdrop slots | 13 |
| Adjustor thunks after their targets | 464 |

**Class of each table** (override pattern against TIRO's, Jaccard 1.0 over the 91 SceneObject
slots for every engine class):

| INFERNO `1080:` | Class | TIRO `1090:` | Slot map |
|---|---|---|---|
| `4926` | Frame | `0692` | 1:1 |
| `492a` S | SceneObject | `0696` | 1:1 |
| `4a96` O, `4ab2` S | Object3D | `0802`, `0822` | O: TIRO's slot 4 (`isInFrontOf`) is gone |
| `4c22` M, `4c26` S | Mover | `0992`, `0996` | 1:1 |
| `4790` M, `4794` S, `4900` O | Moveable | `0ca0`, `0ca4`, `0e10` | O as Object3D |
| `4d96` M, `4d9a` S, `4f06` O | Portable | `0b06`, `0b0a`, `0c76` | O as Object3D |
| `65fa` | Game (7) | `0eee` | 1:1 |
| `6616` | Scene (13) | `1842` | 1:1 |
| `664a` | Backdrop (20) | `120e` (19) | 0–2 = 0–2, 3–17 = TIRO 4–18; 18, 19 new |
| `83dc` | GridBackdrop (21) | `1876` (20) | as Backdrop; 20 = TIRO 19 |
| `7d50` | INFERNO Game (GameVtbl) | role of `11f2` | slots 1, 2, 6 in `1048` |
| `7d6c` | INFERNO backdrop (GridBackdropVtbl) | role of `1bec` | slot 0 `inferno_backdrop_create` |
| `7f3c` | INFERNO scene (SceneVtbl) | role of `1004` | slots 0, 5, 7 |
| `7f70` A, `7f74` S | Animation | `125a`, `125e` | 1:1 |
| `80e4` M, `80e8` A, `80ec` S | Actor2D | `13ce`, `13d2`, `13d6` | 1:1 |
| `8260` M, `8264` A, `8268` S | Player2D | `154a`, `154e`, `1552` | 1:1 |
| `7dc0` M, `7dc4` A, `7dc8` S | **Hero** (derives Player2D; the player) | role of Crossbow | 7 overrides |
| `89c2` (2) M, `89ca` A, `89ce` S | **Platform** (derives Actor2D) | role of Target | 4 overrides |
| `8b42` (4) M, `8b52` A, `8b56` S | **Prop** (derives Actor2D; ProjectileVtbl shape) | role of Projectile | 5 overrides |
| `8cca` (4) M, `8cda` A, `8cde` S | **Hazard** (derives Prop) | role of Arrow | 3 overrides |
| `8648`, `8654`, `8660` | CompoundCondition, Condition, FlagCondition | `1de2`, `1dee`, `1dd6` | 1:1 (in a different order) |

The four game class names are provisional (from their bitmaps; `DATA.md` §5).

Cross-check: for 752 of the 775 names INFERNO shares with TIRO, the named callees and the return
kind agree. The 23 that differ are engine-version changes, not misnames: INFERNO's draw and tick
paths realise the palette and skip TIRO's `PostMessage` notifications, `frame_init` has no hitbox
arguments, the "Faltou redefinir" defaults call `MESSAGEBOX` directly.

## Remaining `FUN_` functions

- **`1068` (38)**: the INFERNO game (groups 23–27 below).
- **`1080` (12)**: `669a`, `66f8` (`game_handle_message` helper: returns `obj+0x78 == 0`), `671a`,
  `6802`, `736e`, `74a8` (in the Player2D/Scene ctor range), `3c74`, `3daa` (reached only by
  unreferenced thunks), `3e0a`, and `503a`, `5050`, `50ae` (empty members, TIRO's
  `FUN_1088_35c6/35e0/3642`).
- **`1018`/`1028` (3)**: `1018:216d` (690 bytes, no reference, between `exit_tick` and
  `portable_ctor`), `1028:1408` (empty member, TIRO's `FUN_1028_0e71`), `1028:28f7` (TIRO's
  `FUN_1028_1cb7`, huge-pointer arithmetic).

Named in phase 3 (`DATA.md` §4): `hero_ctor` `70fa`, `platform_ctor` `86c0`, `prop_ctor` `87c0`
(11 calls), `hazard_ctor` `88ca`; the SceneObject slot overrides `hero_slot56` `7244`,
`platform_is_platform` `7262`, `prop_is_prop` `727c`, `prop_slot5a` `7296`, `hazard_is_hazard`
`72b4`; `inferno_lose_life`, `inferno_score_add_150/300/100` (`1068:58b2–59f2`).

## Dead code

Linked but unreachable (no call, no live slot): the second half of the DIB module
(`dib_copy_transparent_whole`, `dib_copy_rect`, `dib_set_usage`, `dib_create`,
`dib_map_to_palette`), all of `1020` (the PerspectiveBackdrop setters and the layer functions: no
PerspectiveBackdrop is built), the whole ControlPanel module `1058` and its getters in `1080`,
Exit (`exit_play`, `exit_tick`, `exit_*` in `1080`), Player (`player_*`), Animated3D and Actor
(`animated3d_*`, `actor_*`; their slot functions are reached only through thunks that no table
holds), `portable_ctor` (nothing builds a Portable), `object_list_erase_all/draw_all`,
`compound_condition_new_and/or`, `wave_stop`, `wave_pump`, and 178 adjustor thunks.

## Phase 4: function groups

One `ghidra-investigate` agent per group. "Mechanical" groups have TIRO names already; their
agents verify, fix the signatures (far `this` = 4 bytes), type `this` and write plates.

| # | Range | Fns | Content | Kind / effort |
|---|---|---|---|---|
| 1 | `1078:0000–0911` | 33 | CRT startup, `_fstr*`, `rand`, long math, array ctor/dtor iterators, `_cinit`, exit, `_setargv`, `_setenvp` | mechanical (NOITE) |
| 2 | `1078:0912–1253` | 21 | CRT `_flsbuf`, `_output` and helpers, `_fmalloc`/`_halloc`, NMSG | mechanical (NOITE) |
| 3 | `1078:1254–1f51` | 38 | CRT I/O, write/flush, heap internals, dosret, `_itoa` | mechanical (NOITE) |
| 4 | `1000`, `1008`, `1010` | 17 | blitters (don't type), DIB copy, DIB load/palette/remap | mechanical |
| 5 | `1018:0000–0f50` | 21 | Object3D/Moveable/Portable attach, invalidate, perspective, draw bounds, getters, overlap, drop, elevation, move | mechanical |
| 6 | `1018:0f51–2947` | 26 | Object3D below/above/support, redraw overlapping, Moveable tick/stop, Animated3D tick, Exit, Portable (`FUN_1018_216d`) | mechanical, low |
| 7 | `1020`, `1030`, `1050` | 21 | perspective setters and layers (dead), occupancy grid (`occupancy_grid_clear` is new), Backdrop/WinG, conditions | mechanical |
| 8 | `1028:0000–1407` | 22 | SceneObject/Mover blit, restore, draw clip/dirty, place, attach, overlap | mechanical |
| 9 | `1028:1408–2993` | 24 | Mover step/move/edge, Animation play/stop/tick, object list | mechanical |
| 10 | `1038`, `1040:1335`, `1048` | 15 | app shell, `game_take_exit`, the INFERNO Game subclass | mixed |
| 11 | `1040:0000` | 1 (4.9 KB) | `game_handle_message`, from TIRO's, then verified | mechanical, high effort alone |
| 12 | `1058`, `1060`, `1070` | 19 | ControlPanel (dead), Scene create/add exit, WaveMix | mechanical |
| 13 | `1080:0000–2521` | 32 | Frame vector dtors, `frame_dtor`, SceneObjectVtbl defaults 1 | by slot |
| 14 | `1080:2522–284f` | 30 | SceneObjectVtbl default stubs 2 (trivial) | by slot |
| 15 | `1080:2850–2ff5` | 30 | Mover/Animation getters and overrides | by slot |
| 16 | `1080:2ff6–359f` | 30 | Actor2D overrides, `update_list_add`, Object3D ctor, Animated3D | by slot |
| 17 | `1080:35a0–3c39` | 30 | Moveable ctor, Actor/Player/Exit overrides (mostly dead) | by slot |
| 18 | `1080:3c3a–42ff` | 30 | ControlPanel getters, SceneObject getters, `animation_set_strip`, `FUN_3c74/3daa/3e0a` | by slot, mixed |
| 19 | `1080:4300–59b1` | 30 | Mover ctor, strips/state init, Frame, dead `*_blit_view`, SceneObject helpers, occupancy cells | mixed |
| 20 | `1080:59b2–627b` | 30 | backdrop clear/draw, Game/Scene/ControlPanel/StatusBar dtors, `game_init`, Game defaults, Backdrop defaults | by slot |
| 21 | `1080:627c–736d` | 30 | Backdrop and Scene defaults, `FUN_669a–6802`, `game_ctor`, **Hero ctor `70fa`, the type tests `7244–72b4`**, INFERNO scene ctor | mixed / game |
| 22 | `1080:736e–8e51` | 33 | Player2D, Scene, backdrop, Actor2D, occupancy, Animation, Mover and condition ctors, `exit_set_link`, **Platform/Prop/Hazard ctors `86c0/87c0/88ca`** | mixed / game |
| 23 | `1068:0000–0bf6` | 8 (3.1 KB) | scene create (music, waves, start tick), backdrop create (floor row), `0158`, `016c` (jump), **`0260` (1.9 KB, hero movement)**, `09be`, `0b01`, `0bc8` | INFERNO, high |
| 24 | `1068:0bf7–1a1d` | 7 (3.6 KB) | Hero SceneObject overrides (`0bf7`, `15c3`, `1649`, `16dd`, `1720`), **`0edc` (1.8 KB)**, `1936` | INFERNO, high |
| 25 | `1068:1a1e–2f92` | 11 (5.5 KB) | creators of the platforms and drinks (`1a1e`) and the rocks and cross (`272a`); Platform methods `1e5d–25e3`; Prop methods `2b5a–2e59` | INFERNO, high |
| 26 | `1068:2f93–4bdb` | 13 (7.2 KB) | `2f93` (1.6 KB, the `g_…726a` object), Prop slots `35c2–398d`, `3ac3`, the hazards' creator `3bf8`, **`3f86` (1.9 KB)**, Hazard methods `46f7–49fb` | INFERNO, high |
| 27 | `1068:4bdc–5baa` | 8 (4 KB) | **the scene handler** (keys, timers 0xc/0xe, the 3-minute limit, 0x40a), the wave and score helpers `589e–5a9f` | INFERNO, high |

Order of work: 1–4 and 10 first (anchors), then 5–9 and 11–12, then the `1080` groups 13–22
(after phase 3's vtable structs), the game groups 23–27 last.

## Scripts

`ghidra/scripts/`:

| Script | Use here |
|---|---|
| `CopyTypesFromProgram.java` | `/NOITE.EXE`, then `/TIRO.EXE`: SDK structs, all 86 import signatures |
| `FarVtSlots.java` | slots → functions on the five `1080` table ranges (data segment argument `1080`) |
| `NearAdjustorThunks.java` (`far`, now also the `LES` vtordisp form) | `1080 0132 2030 far`, `1080 6800 7060 far`; rerun after renaming |
| `CodeGapSweep.java` | per code segment, `create` (run one segment per call: a script that runs it through `runScript` blocks on a "script not found" dialog when the script is not in `~/ghidra_scripts`) |
| `DeadJumps.java` | all code segments |
| `NearSignatures.java` | conventions of `1008–1070`, `1080` |
| `RenameFunctions.java` (`force` added) | the name TSVs |

Scratch (`zig-out/inferno/`, not committed): `InfernoSurvey`, `InfernoDump`, `gs/InfernoSpec`
(installs the cspecs), `gs/InfernoChk` (`_aFchkstk` + call-fixup), `gs/InfernoCrtFix`,
`gs/InfernoVtDump`, `gs/InfernoFnList`, `gs/InfernoRawOps`, `gs/InfernoCallees`; the matchers
`feat.py`, `align.py`, `vt.py`, `vtname.py`, `runs.py`, `prop.py`.
