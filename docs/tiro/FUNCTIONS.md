# TIRO.EXE: function inventory (phase 2)

The Ghidra program `/TIRO.EXE` after phase 2: every function mapped, the names that transfer
mechanically from ENCAIXE and NOITE applied, the calling conventions set. Addresses are Ghidra
`seg:off`. TIRO is a medium-model `/Od` build (far code, near data, `this` at `[BP+6]`, 4-byte
far vtable slots); see `QUALITY.md` §0. ENCAIXE (`docs/encaixe/`) is the reference for the
names.

## Counts

Before phase 2: 503 code functions (1 named, `entry`), 94 untyped import thunks, 18,457
uncovered bytes in `1008–1088`.

After: **991 code functions** plus 94 import thunks (1,085 in all). 824 code functions are
named; 167 stay `FUN_` for phase 4, and 15 of the 368 adjustor thunks are still named after a
`FUN_` target.

| Kind | Fns | Named | Where / names |
|---|---|---|---|
| Import thunk | 94 | 94 | `10a8`, all typed |
| Adjustor thunk | 368 | 368 | `1088:0000–1331` (241), `1088:42c2–4d7d` (127); `<target>_thunk[_k]` |
| CRT | 81 | 81 | `1080` |
| Blitter | 2 | 2 | `1000:0024`, `1000:0114` (32-bit code, not typed) |
| DIB | 15 | 8 | `1008`, `1010` |
| App shell | 10 | 8 | `1038` |
| WaveMix | 11 | 11 | `1078` (NOITE's whole module) |
| Engine | 468 | 346 | `1018–1060`, `1070`, `1088` |
| TIRO game | 36 | 0 | `1048` (6), `1068` (30) |

By segment (code functions other than the adjustor thunks):

| Seg | Fns | Named | Unnamed |
|---|---|---|---|
| `1000` | 2 | 2 | – |
| `1008` | 4 | 1 | `0273`, `04b4`, `06f1` |
| `1010` | 11 | 7 | `05de`, `0783`, `0bf1`, `0c90` |
| `1018` | 51 | 49 | `1cea`, `1dec` |
| `1020` | 7 | 4 | `0118`, `016e`, `0229` |
| `1028` | 49 | 42 | `0000`, `02ba`, `02d3`, `0e71`, `1ad8`, `1b1b`, `1cb7` |
| `1030` | 9 | 6 | `01c8`, `050c`, `05da` |
| `1038` | 10 | 8 | `02e3`, `0577` |
| `1040` | 2 | 2 | – |
| `1048` | 6 | 0 | all |
| `1050` | 4 | 2 | `0021`, `0062` |
| `1058` | 15 | 11 | `002f`, `007d`, `0291`, `02ae` |
| `1060` | 4 | 4 | – |
| `1068` | 30 | 0 | all |
| `1070` | 11 | 5 | `0037`, `00ff`, `01f5`, `0319`, `0608`, `063a` |
| `1078` | 11 | 11 | – |
| `1080` | 81 | 81 | – |
| `1088` | 316 | 221 | 95 (below) |

## Function discovery

- **Vtable slots** (`FarVtSlots.java 1090 05d2 22a4`): a slot is a DGROUP dword whose segment
  word carries an NE relocation and points into a code block. That test is exact: 1,665 slots,
  560 distinct targets, 419 new functions. Each slot is typed as a 4-byte pointer (its reference
  to the code is the pointer's own) and each of the 70 vptr stores (`MOV word ptr [r+k],imm`)
  got a DATA reference to its table. The new functions include `game_handle_message`
  (`1040:0000`, 3,691 bytes) and `_purecall` (`1080:02ae`).
- **Adjustor thunks** (`NearAdjustorThunks.java 1088 0000 1332 far`, then `42c2 4d7e far`): the
  368 thunks (37 + 20 fixed, 204 + 107 vtordisp), named NOITE's way. In 6 of them Ghidra had
  absorbed the `JMPF` target as a tail; the script cuts each one back to its `JMPF` and makes the
  target a function.
- **Gap sweep** (`CodeGapSweep.java`, with the `/GA` prologue `8C D0 55 8B EC` added): 29 more:
  `1038:0000` (APPABOUT), `1020:0000`, 10 CRT entries and 17 in `1088`.
- **CRT by hand:**
  - `FATALEXIT` is set no-return; `_amsg_exit` had run on into `_flsbuf` (`082a`).
  - The `INC BP` far prologues start one byte before where Ghidra put them: `0e8a`, `0ef8`,
    `14da`, `1558`, `1596`. Their callers call the `INC BP`.
  - The frameless entries are made by hand: `_aNchkstk` `00c4`, `_cintDIV` `07e2`,
    `crt_dosret_maperr` `12a3`, the heap helpers `12fa`/`1386`/`13ec`, `crt_ltoa_body` `1802`
    and `crt_xtoa` `180e`. `_itoa` `179e` jumps to `crt_xtoa`. Their sizes are ENCAIXE's to the
    byte.
  - The 7 near helpers of `_output` (`0d42–0dd7`), at their CALL targets.
- **Dead jumps** (`DeadJumps.java`): `/Od` leaves an unreachable `JMP rel16` after each
  `case`/`return` jump to the epilogue. There are 61 of them, 3 bytes each, between two pieces
  of the same function (one chain of 5 in `1028:0d31`). They are disassembled and added to their
  function's body; the decompiler drops them.
- **Jump tables:** `_output`'s switch (`1080:0985`, `JMP CS:[BX+0x91c]`) has 8 words at
  `1080:091c`. They are typed `word[8]`, with COMPUTED_JUMP references, and the body is fixed
  up. This is the only computed jump in the program: `/Od` compiles every other `switch` as a
  compare chain. The other three indirect jumps are returns (`JMP BX` in `_aNchkstk`) and
  CRT hooks.

What is left uncovered, all proven data or padding:
- `1080:0000–0011`, the segment prefix;
- `1080:091c–092b`, the `_output` jump table;
- 362 one-byte alignment fillers (`00`/`90`): 38 in `1080` and 324 in `1088`.

Every `est_starts.json` start is a function, except the 5 `INC BP` entries, which moved one byte
back.

## Vtables

Each table is matched to its ENCAIXE class by the override pattern of the 91-slot SceneObject
tables against ENCAIXE's 93-slot ones. The match is Jaccard 1.0 for every base class.

**TIRO's SceneObjectVtbl has 91 slots: ENCAIXE's 93 without ENCAIXE `0x11` (`unk11`) and
`0x18` (`unk18`).** TIRO slot *i* is ENCAIXE slot *i* for *i* < 0x11, *i*+1 for 0x11–0x16, and
*i*+2 from 0x17 on. The virtual calls in every aligned function pair confirm this. Other
tables map 1:1.

| TIRO `1090:` | Class | ENCAIXE `1018:` | Ctor / vptr store |
|---|---|---|---|
| `0692` | Frame (`frame_get_cell`) | `0302` | `frame_ctor` `1088:33f6` |
| `0696` S | SceneObject | `0304` | `1088:16a2`, `3b3c`, `50ea` |
| `0802` O, `0822` S | Object3D | `03be`, `03ce` | `1088:253a` |
| `0992` M, `0996` S | Mover | `0488`, `048a` | `1088:30e4`, `31b8`, `5cf2` |
| `0b06` M, `0b0a` S, `0c76` O | Portable (**live** in TIRO, dead in ENCAIXE) | `0548`, `054a`, `0604` | `1018:1cea`, `1018:1dec` |
| `0ca0` M, `0ca4` S, `0e10` O | Moveable | `061e`, `0620`, `06da` | `1088:26ea`, `27c4` |
| `0eee` | Game (7, slot 6 `_purecall`) | `07fe` | `game_ctor` `4ef6`, `game_dtor` `3d06` |
| `1004` | TIRO scene (SceneVtbl: slot 0 `1068:1790`, 5 `1088:503e`, 7 `1068:008d`) | role of TetrisScene `0f70` | `1088:5004` |
| `1038`, `105c` S, `11c8` O | TIRO panel (ControlPanelVtbl) | role of TetrisPanel `0b0e` | `1088:4d7e` |
| `11f2` | TIRO game (GameVtbl: slots 1–4, 6 in `1048`) | role of TetrisGame `0f62` | `1048:0000` |
| `120e` | Backdrop (19) | `0952` | `backdrop_ctor` `5abe`, `backdrop_dtor` `5fa2` |
| `125a` A, `125e` S | Animation | `0a4e`, `0a50` | `1088:5bea`, `5c3e` |
| `13ce` M, `13d2` A, `13d6` S | Actor2D | `0c1c`, `0c1e`, `0c20` | `actor2d_ctor_strips` `587c` |
| `154a` M, `154e` A, `1552` S | Player2D | `0ce2`, `0ce4`, `0ce6` | `player2d_ctor` `51b0` |
| `16c6` M, `16ca` A, `16ce` S | TIRO class derived from Player2D (43 overrides) | – | `1088:4f50` |
| `1842` | Scene (13, slot 0 `_purecall`) | `0da8` | `scene_ctor` `5390`, `scene_dtor` `1060:003b` |
| `1876` | GridBackdrop (20) | `0bf4` | `grid_backdrop_ctor` `5698` |
| `18c6` S | StatusBar | `0dc2` | `status_bar_ctor` `4e3e` |
| `1a32`, `1a56` S, `1bc2` O | ControlPanel (slots 7–8 `_purecall`) | `0e7c`, `0e8e`, `0f48` | `control_panel_ctor` `5276` |
| `1bec` | TIRO backdrop (GridBackdropVtbl, slot 0 `1068:0000`) | role of TetrisBackdrop `1054` | `1088:554e` |
| `1c3c` A, `1c40` S, `1dac` O | Animated3D | `0978`, `097a`, `0a34` | `animated3d_ctor_strips_no_hitbox` `5946` |
| `1dd6` | FlagCondition | `107c` | `flag_condition_ctor` `5dd6` |
| `1de2` | CompoundCondition | `1082` | `compound_condition_ctor` `5e62` |
| `1dee` | Condition (slot 0 `_purecall`) | `1088` | `condition_ctor` `5f18` |
| `1dfa` (3), `1e06` A, `1e0a` S | TIRO class derived from Actor2D; its own table is PieceVtbl-shaped (slot 0 `mover_place_at`) | role of Piece `0f8a` | `1088:603a` |
| `1f7e` (4), `1f8e` A, `1f92` S | TIRO class derived from Actor2D | – | `1088:6170` |
| `2106` (4), `2116` A, `211a` S | TIRO class derived from `6170`'s | – | `1088:60d8` |

Other far pointers in DGROUP:
- `05d2–05ed`: 7 CRT hooks, pointing to `_fptrap`.
- `228e`: the static-init entry, pointing to `init_static_conditions_entry`.
- `22a0`: the exit entry, pointing to `crt_endstdio`.

The vbtables (`0990`, `0b04`, `0c98`, …) are the zero-slot rows between the tables. Pure
virtual slots point to `_purecall` (`1080:02ae`, R6025); ENCAIXE stores 0 in them instead.

## Names and how they were applied

Every applied name has a plate: `Name from ENCAIXE|NOITE <name> at <addr> (<method>; <evidence>)`.
`RenameFunctions.java` applies TSVs (`zig-out/tiro/rn_crt.tsv`, `rn_engine.tsv`), and
`NearAdjustorThunks` was rerun afterwards to rename the thunks after their targets.

| Method | Names |
|---|---|
| Import signatures copied from NOITE (83, incl. the 4 WinG ordinals renamed), then ENCAIXE (6 more); 5 typed from the SDK (`GETNEARESTPALETTEINDEX`, `GETOBJECT`, `GETPALETTEENTRIES`, `GETTICKCOUNT`, `HMEMCPY`) | 94 |
| CRT: ENCAIXE by opcode match and link order (76; 11 of them by order plus a body check, e.g. `exit`…`_c_exit` by their `CX` flag). NOITE's far-call `_aFldiv`/`_aFlmul` (TIRO calls them far, so the far-call names, as for `_aFchkstk`). `abs` and `_purecall` by body | 80 + `entry` |
| Blitters: byte-identical segment | 2 |
| Module segments, in-order alignment against ENCAIXE (`align.py`), each pair checked by `verify.py`: same API sequence, same virtual slots (TIRO slots mapped as above), callees agreeing, similar size; 81 of them also confirmed by a vtable slot | 139 |
| Vtable slot: slot *i* of a TIRO table gets the name of the function in the same slot of the same class's ENCAIXE table (thunks resolved to their targets on both sides). 285 functions get a candidate, none get two, and the 81 that alignment also named agree (alignment's one disagreement, `1028:001b`, was a rejected pair) | 204 more |
| By role, with the ENCAIXE or NOITE name: ctors and dtors that are the only vptr store of their class, the WaveMix and Conditions modules, `object_list_attach_to_scene`, `backdrop_*`, `draw_list_node_*`, `update_list_add`, APPABOUT | 30 |
| Adjustor thunks after their targets | 368 |

The prototypes cross-check the names: for 395 of the 404 named functions that ENCAIXE also has,
the mechanical parameter byte count equals ENCAIXE's. Of the 9 that differ:
- `crt_array_construct`/`crt_array_destruct` take a far function pointer here (+2 bytes);
- `sprintf` is varargs;
- the other 6 carry `sig?`.

Corrections to `QUALITY.md`:
- `1050` is not the SceneObject draw helpers. It is the Conditions module:
  `init_static_conditions`, `init_static_conditions_entry`, and two factories `0021`/`0062`
  that `new` an 8-byte CompoundCondition with isOr 0/1.
- The CRT long helpers are the far-call `_aF*` forms.
- `1018:0839` (`portable_can_step`) and `1028:063d` (`mover_draw_dirty_to`) are engine methods;
  their slots name them.
- The Backdrop/PerspectiveBackdrop fields sit **8 bytes lower** than in ENCAIXE (`0x448` vs
  `0x450` in `backdrop_create`, `0x450` vs `0x458` in the perspective setters), so the
  Backdrop layout does not transfer byte for byte. Check it in phase 3.

Pairs that share a body keep distinct names by slot, as in ENCAIXE:
`scene_object_blit_to_dc`/`scene_object_slot24` (`1028:0041`/`00a8`) and
`mover_blit_to_dc`/`mover_slot24` (`0152`/`0206`).

## Signatures

`NearSignatures.java` was run on `1008–1088`, with `regargs=1080:0000-1860`. It now also
accepts a frame behind the Windows far prologues (`MOV AX,DS; NOP; INC BP`, `INC BP`,
`MOV AX,SS`):
- `RETF n` gives `__stdcall16far` with n/2 words (500 functions);
- `RETF` gives `__cdecl16far`, counted from the callers' `ADD SP` (63);
- 6 CRT near helpers get `__cdecl16near` and 1 gets `__stdcall16near`.

Parameters are `undefined2`. `this` is the first parameter at `[BP+6]`, and it is a 2-byte near
pointer, which is what the decompiler wants for medium model: struct accesses come out as
`*(int *)(param_1 + 0x470)`. Adjustor thunks keep no signature.

**57 functions carry `sig?`:**
- 51 from the script:
  - CRT entries with no return or register arguments;
  - `sprintf` (varargs);
  - 7 functions with no caller cleanup to count (`1008:0273`, `1010:05de/0783/0c90`,
    `1028:1cb7`, `wave_play_loop`, `wave_stop`).
- 6 whose count differs from ENCAIXE's: `perspective_project_point`,
  `perspective_unproject_point`, `message_box_printf`, `crt_output_pad`, `crt_null_hook` and
  `_getbuf`.

`__cdecl16far_dx_ax` and `__cdecl16far_dxax_ptr` are installed (spec extensions) but not yet
applied. `g_setSystemTimer`/`g_killSystemTimer` (`1090:6312`/`6316`) are typed as far pointers
to ENCAIXE's `SetSystemTimerFn`/`KillSystemTimerFn`.

## Remaining unknowns

The 167 `FUN_` functions, by kind:
- **The TIRO game, 36:**
  - `1048`: the TiroGame ctor `0000` and its GameVtbl overrides: createPlayer `0029`,
    createInitScene `01ca`, createControlPanel `0110`, createStatusBar `016e`, onCreate `021a`.
  - All of `1068`: the scene handler `1790` (TIRO scene slot 0), scene create `008d`
    (slot 7), backdrop create `0000` (TIRO backdrop slot 0), and the methods of the 4 TIRO
    classes.
- **TIRO class ctors and overrides in `1088`:**
  - ctors `4d7e` (panel), `4f50`, `5004` (scene), `554e` (backdrop), `603a`, `60d8`, `6170`;
  - `503e` (TIRO scene createScreen) and `4e16` (TIRO panel slot 2).
- **Out-of-line accessors that ENCAIXE inlines** (`/Od` keeps every inline function as a call):
  - `13b8`, `13dc`, `1400`, `1424`, `1448`: hitbox getters, called by `moveable_can_step`,
    `scene_object_hitbox_overlaps` and the occupancy grid;
  - `2efe`, `2f1e`, `2f42`: position getters;
  - `146c`, `2fda`, `3a72`, `3aec`, `3b14`, `3acc`, `41dc`, `5d9e`, `6002`, `50c0`, `5256`;
  - `3a3e`, the view blit (`WinGBitBlt`), out of line in `app_paint` and `backdrop_autoscroll`.
    It matches ENCAIXE's `dead_blit_view_to_dc` at 0.81.
- **Ctors with several variants per class** (alloc_strips / strips_no_hitbox / …):
  - SceneObject `16a2`, `50ea` and the dtor-like `3b3c`;
  - Object3D `253a`;
  - Mover `30e4`, `31b8`, `5cf2`, with helpers `3278`, `3348`, `33b4`;
  - Moveable `26ea`, `27c4`;
  - Animation `5bea`, `5c3e`;
  - Portable `1018:1cea`, `1018:1dec`.

  Each needs its ENCAIXE/NOITE ctor read to say which is which.
- **Deleting dtors and dtor chains:** `3cd4` (Game; `app_exit` calls it), `3a9a`, `3f58`,
  `3f8a`, `3fbc`, `3fee`, `4022`, `4042`, `4062`, `412c`, `414c`, `5f70`.
- **Unreferenced methods** (no slot and no caller, like ENCAIXE's dead Portable/Exit code):
  `2974–2bf4` (17), `35c6–365c` (7), `4fe8`, `5088`, `50a4`, `4166`, `4192`, `41fe`, `39de`,
  `367e` (864 bytes), `3502`, `3556`, `3c50`, `3c80`, `3b5a`, `3b76`, `3b96`/`3bf4` (occupancy
  cell increment and decrement), `5a08`.
- **DIB:** four copy variants, where ENCAIXE has two (`1008:0000` = `dib_copy_transparent` from
  its caller; `0273`, `04b4`, `06f1` open). The newer DIB module code is `1010:05de`, `0783` and
  `0c90` (remap to the system palette with `GetNearestPaletteIndex`); `0bf1` is the
  BI_RLE4 case of `0c90`'s remap switch, which ENCAIXE lacks.
- **Engine extras:**
  - `1020:0118/016e/0229` (perspective backdrop);
  - `1028:0000`, `02ba`, `02d3`, `0e71`, `1ad8`, `1b1b`, `1cb7`;
  - `1030:01c8`, and `050c`/`05da` (one of them is `backdrop_set_dib_colors`);
  - `1038:02e3`, `0577`;
  - `1058:002f`, `007d` (status bar text draw), `0291`, `02ae`.
- **Lists:** `1050:0021`/`0062` (the CompoundCondition factories), and in `1070` a dead second
  copy of the draw-list ctor/insert/remove (`0037`, `00ff`, `01f5`) plus `0319`, `0608` and
  `063a`.

Decompiler artifacts:
- Far return addresses of untyped calls still leak into fake locals.
- A constant equal to a DGROUP slot address now prints as `&PTR_<target>_1090_xxxx`, because
  the vtable slots are typed pointers. Typing the callees (phase 3/4) removes most of it.

## Scripts

`ghidra/scripts/`:

| Script | Use here |
|---|---|
| `CopyTypesFromProgram.java` | `/NOITE.EXE`, then `/ENCAIXE.EXE`: SDK structs and 89 import signatures |
| `FarVtSlots.java` (new) | Far vtable slots → functions, slot typing, vptr-store references. Args: `1090 05d2 22a4 [dry]` |
| `NearAdjustorThunks.java` (`far` mode added) | `1088 0000 1332 far`, `1088 42c2 4d7e far`; rerun after renaming |
| `CodeGapSweep.java` (`/GA` prologue added) | per code segment, `create` |
| `DeadJumps.java` (new) | `/Od` unreachable epilogue jumps → their function's body. Args: segments `[dry]` |
| `NearSignatures.java` (far prologues added) | conventions and `sig?` |
| `ExportFunctionOps.java` | op dumps for the matchers |
| `RenameFunctions.java` | applies the name TSVs |

Done inline, not committed (in `zig-out/tiro/gs/`):
- installing `ghidra/cspec/*.xml` (`SpecExtension`);
- the timer globals;
- the CRT fixes (FATALEXIT no-return, the `INC BP` entries, the `_output` table);
- the `sig?` tags for the 6 count mismatches.

The matchers are `zig-out/tiro/*.py` (scratch, not committed):
- `fuzzy.py`, `feat.py` and `align.py` from phase 1;
- `verify.py` (pair checks), `side.py`/`vts.py` (side-by-side features);
- `vtmap.py`/`vtcls.py`/`vtname.py` (class and slot mapping), `mkrn.py` (the rename TSV).

## Phase-4 groups (refreshed)

The counts exclude the adjustor and import thunks. "verify only" means every function in the
group was named mechanically; its agent checks, signs and types. Order of work:
- first the CRT, DIB and app groups (1–4, 10);
- then the engine (5–9, 11–13);
- then `1088` (14–25), after phase 3's vtable typing;
- then the TIRO game (26–27).

| # | Range | Fns | Unnamed | Content | Kind |
|---|---|---|---|---|---|
| 1 | `1080:0000–07e6` | 31 | 0 | CRT startup, strings, `rand`, long math, `_cinit`, exit, `_setargv`, `_setenvp` | verify only |
| 2 | `1080:07e7–1003` | 21 | 0 | `_amsg_exit`, `_flsbuf`, `_output` and helpers, heap, `_NMSG_*` | verify only |
| 3 | `1080:1004–1860` | 29 | 0 | CRT I/O, dosret, heap growth, flush, close, `_itoa` | verify only |
| 4 | `1000`, `1008`, `1010` | 17 | 7 | blitters, DIB copy (4 variants), DIB load/palette/remap, the new remap code | mixed |
| 5 | `1018:0000–0f2a` | 31 | 0 | Object3D/Moveable/Portable attach, project, draw bounds, getters, drop, elevation, move | verify only |
| 6 | `1018:0f2b–21c7` | 20 | 2 | below/support/front, Moveable tick, Player/Exit, Portable pick up/drop/icon, Portable ctors `1cea`/`1dec` | mixed |
| 7 | `1020`, `1030`, `1050` | 20 | 8 | perspective backdrop, occupancy grid, Backdrop/WinG, Conditions | mixed |
| 8 | `1028:0000–0d30` | 21 | 3 | SceneObject/Mover blit, restore, draw, attach, overlap | mixed |
| 9 | `1028:0d31–1d52` | 28 | 4 | Mover step/move/edge, Animation, Player2D, object list | mixed |
| 10 | `1038`, `1040:0e6b`, `1048` | 17 | 8 | app shell, `game_take_exit`, TiroGame | mixed (1048 TIRO) |
| 11 | `1040:0000` | 1 | 0 | `game_handle_message` (3.7 KB), against ENCAIXE `8eca` (high effort, alone) | verify only |
| 12 | `1058`, `1060` | 19 | 4 | StatusBar, ControlPanel, Scene | mixed |
| 13 | `1070`, `1078` | 22 | 6 | draw lists (one dead copy), WaveMix | mixed |
| 14 | `1088:1332–17ff` | 28 | 7 | Frame, SceneObject defaults and getters, hitbox accessors, SceneObject ctor | mixed |
| 15 | `1088:1800–1bff` | 36 | 0 | SceneObjectVtbl defaults | verify only |
| 16 | `1088:1c00–1fff` | 24 | 0 | Animation/Mover getters and overrides | verify only |
| 17 | `1088:2000–23ff` | 21 | 0 | defaults, Animated3D overrides | verify only |
| 18 | `1088:2400–27ff` | 20 | 3 | defaults, `update_list_add`, Object3D and Moveable ctors | mixed |
| 19 | `1088:2800–2bff` | 23 | 17 | Actor2D slots; 17 unreferenced methods | mixed |
| 20 | `1088:2c00–2fff` | 31 | 4 | SceneObject getters, Portable, Game defaults, position accessors | mixed |
| 21 | `1088:3000–37ff` | 17 | 14 | Mover ctors and helpers, Frame, `367e` | mostly unnamed |
| 22 | `1088:3800–42c1` | 34 | 28 | Game defaults, `game_init`, dtor chains, occupancy cell, the view blit | mostly unnamed |
| 23 | `1088:4d7e–52ff` | 19 | 11 | TIRO panel, Game/StatusBar/Player2D/ControlPanel ctors, TIRO class `4f50` | mixed (TIRO) |
| 24 | `1088:5300–57ff` | 31 | 1 | Scene and Backdrop slots, Scene/GridBackdrop ctors, TIRO backdrop `554e` | mostly named |
| 25 | `1088:5800–622b` | 32 | 10 | Actor2D/Animated3D/Animation ctors, Backdrop ctor/dtor, Conditions, the TIRO class ctors | mixed (TIRO) |
| 26 | `1068:0000–178f` | 24 | 24 | TIRO scene create, music/waves, aim, the TIRO classes' methods, hit, respawn, arrow | TIRO |
| 27 | `1068:1790–2fcb` | 6 | 6 | TIRO handler `1790`, score helpers `2d89–2ed4` (high effort) | TIRO |
