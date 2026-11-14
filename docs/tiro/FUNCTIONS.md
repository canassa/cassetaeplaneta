# TIRO.EXE: function inventory

The Ghidra program `/TIRO.EXE`: every function mapped, named, typed and documented with a plate.
Addresses are Ghidra `seg:off`. TIRO is a medium-model `/Od` build (far code, near data, `this` at
`[BP+6]`, 4-byte far vtable slots); see `QUALITY.md` §0. ENCAIXE (`docs/encaixe/`) is the
reference for the names. The game itself is described in `GAME.md`, the data in `DATA.md`.

## Counts

**1,085 functions:** 94 import thunks, 368 adjustor thunks and 623 code functions. 618 of the 623
are named; 5 stay `FUN_` (below). Every code function has a plate. 5 functions carry the tag
`review`, 8 the tag `sig?`.

| Kind | Fns | Where / names |
|---|---|---|
| Import thunk | 94 | `10a8`, all typed |
| Adjustor thunk | 368 | `1088:0000–1331` (241), `1088:42c2–4d7d` (127); `<target>_thunk[_k]`, all after named targets |
| CRT | 81 | `1080` |
| Blitter | 2 | `1000:0024`, `1000:0114` (32-bit code, not typed) |
| DIB | 15 | `1008`, `1010` |
| App shell | 10 | `1038` |
| WaveMix | 11 | `1078` (NOITE's whole module) |
| Engine | 468 | `1018–1060`, `1070`, `1088` |
| TIRO game | 36 | `1048` (6), `1068` (30) |

By segment (code functions other than the adjustor thunks):

| Seg | Fns | Named | Seg | Fns | Named |
|---|---|---|---|---|---|
| `1000` | 2 | 2 | `1048` | 6 | 6 |
| `1008` | 4 | 4 | `1050` | 4 | 4 |
| `1010` | 11 | 11 | `1058` | 15 | 15 |
| `1018` | 51 | 51 | `1060` | 4 | 4 |
| `1020` | 7 | 7 | `1068` | 30 | 30 |
| `1028` | 49 | 47 | `1070` | 11 | 11 |
| `1030` | 9 | 9 | `1078` | 11 | 11 |
| `1038` | 10 | 10 | `1080` | 81 | 81 |
| `1040` | 2 | 2 | `1088` | 316 | 313 |

Conventions: 500 `__stdcall16far` (far pascal, parameters listed reversed), 97 far cdecl
(`__cdecl16far`, `__cdecl16far_dx_ax`, `__cdecl16far_dxax_ptr`), the rest CRT near helpers and
register-argument entries.

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
| `16c6` M, `16ca` A, `16ce` S | Crossbow (derives Player2D; 43 overrides, `isCrossbow`) | – | `crossbow_ctor` `1088:4f50` |
| `1842` | Scene (13, slot 0 `_purecall`) | `0da8` | `scene_ctor` `5390`, `scene_dtor` `1060:003b` |
| `1876` | GridBackdrop (20) | `0bf4` | `grid_backdrop_ctor` `5698` |
| `18c6` S | StatusBar | `0dc2` | `status_bar_ctor` `4e3e` |
| `1a32`, `1a56` S, `1bc2` O | ControlPanel (slots 7–8 `_purecall`) | `0e7c`, `0e8e`, `0f48` | `control_panel_ctor` `5276` |
| `1bec` | TiroBackdrop (GridBackdropVtbl, slot 0 `tiro_backdrop_create`) | role of TetrisBackdrop `1054` | `tiro_backdrop_ctor` `1088:554e` |
| `1c3c` A, `1c40` S, `1dac` O | Animated3D | `0978`, `097a`, `0a34` | `animated3d_ctor_strips_no_hitbox` `5946` |
| `1dd6` | FlagCondition | `107c` | `flag_condition_ctor` `5dd6` |
| `1de2` | CompoundCondition | `1082` | `compound_condition_ctor` `5e62` |
| `1dee` | Condition (slot 0 `_purecall`) | `1088` | `condition_ctor` `5f18` |
| `1dfa` (3), `1e06` A, `1e0a` S | Target (derives Actor2D; TargetVtbl: `placeAt`, `moveTick`, `checkEdge`; `isTarget`) | role of Piece `0f8a` | `target_ctor` `1088:603a` |
| `1f7e` (4), `1f8e` A, `1f92` S | Projectile (derives Actor2D; ProjectileVtbl: `placeAt`, `moveTick`, `stepMove`, `tryStep`; `isProjectile`) | – | `projectile_ctor` `1088:6170` |
| `2106` (4), `2116` A, `211a` S | Arrow (derives Projectile, the same slots) | – | `arrow_ctor` `1088:60d8` |

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
| By hand, one function at a time (the TIRO game, the out-of-line accessors and ctors, the DIB code, dtor chains, the dead methods), with the ENCAIXE or NOITE name where a counterpart exists | 162 |
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
- Portable is live code here (ENCAIXE's is dead): its vtables, ctors and methods are linked and the
  tables are referenced, though nothing in TIRO constructs one (both ctors have no caller).
- `1018:0839` (`portable_can_step`) and `1028:063d` (`mover_draw_dirty_to`) are engine methods;
  their slots name them.
- The Backdrop/PerspectiveBackdrop fields sit **8 bytes lower** than in ENCAIXE (`0x448` vs
  `0x450` in `backdrop_create`, `0x450` vs `0x458` in the perspective setters), so the
  Backdrop layout does not transfer byte for byte (`DATA.md` has TIRO's).

Pairs that share a body keep distinct names by slot, as in ENCAIXE:
`scene_object_blit_to_dc`/`scene_object_slot24` (`1028:0041`/`00a8`) and
`mover_blit_to_dc`/`mover_slot24` (`0152`/`0206`).

## Signatures

`NearSignatures.java` set the conventions on `1008–1088`, with `regargs=1080:0000-1860`, and the
the functions were then typed one by one:
- `RETF n` → `__stdcall16far` with the parameters listed reversed (`this` first, at `[BP+6]`, a
  2-byte near pointer);
- `RETF` → `__cdecl16far`, counted from the callers' `ADD SP`; the 32-bit returns use the spec
  extensions `__cdecl16far_dx_ax` and `__cdecl16far_dxax_ptr`;
- the CRT near helpers are `__cdecl16near` / `__stdcall16near`.

Adjustor thunks keep no signature. `CREATEWINDOW`'s `lpvParam` is a 4-byte pointer (the thunk
copied from NOITE had 2 bytes, which shifted every argument of `app_init`'s call).

**8 functions carry `sig?`:** `dib_copy_transparent_whole` (`1008:0273`), `dib_set_usage`,
`dib_create`, `dib_map_to_palette` (no caller cleanup to count), `perspective_project_point`,
`perspective_unproject_point` (count differs from ENCAIXE's), `message_box_printf` (varargs) and
`FUN_1028_1cb7`.

## Decompiler setup

Three fixes make the `/Od` far-model code decompile cleanly. They are stored in the program.

- **`_aFchkstk`.** Every function starts with `MOV AX,frame; CALLF _aFchkstk`, which lowers SP by
  the frame size. The call-fixup `aFchkstk` (`ghidra/cspec/aFchkstk_fixup.xml`, installed as a spec
  extension and set on `1080:00e4`) replaces the call with `SP = SP + 4 - ((AX + 1) & 0xfffe)`
  (the `+4` undoes the `CALLF`'s own pushes), so each frame is allocated and outgoing pushes no
  longer alias the locals. The return address the `CALLF` leaves in the two words below `BP`
  remains: a local read before it is written shows as that constant (e.g. `text[6] = -0x21` in
  `tiro_draw_score`, the first values of `first`/`blocker` in `mover_can_step`).
- **Virtual calls.** A far slot is read as two 16-bit loads, so the decompiler never applies the
  slot's prototype ("Load size is inaccurate") and falls back to the near default model, which
  takes the pushed `CS` for an extra first argument. `FarSlotSignatures.java` writes the 180
  `<Vtbl>_<field>Fn` definitions from their targets' prototypes and puts a call-site signature
  override on 400 calls: 370 resolved from the decompiler's types (the slot field, the vptr type,
  or the vbtable entry that adjusts `this`: +2 SceneObject, +4 Object3D), 28 checked by hand, and the
  two calls through `g_setSystemTimer`/`g_killSystemTimer`. The 3 left are CRT function-pointer
  calls (`crt_array_construct`/`destruct`, `crt_call_fptr_table`).
- **Exact pops.** The decompiler rounds an unknown extrapop up to a multiple of 4
  (`FuncProto::resolveExtraPop`), so an override with an odd number of argument words would pop 2
  bytes too many. Those overrides use `__stdcall16far_pop6/10/14/18` (spec extensions identical to
  `__stdcall16far` with a fixed extrapop).

What the decompiler still shows:
- **The 14 sub-object NULL tests** read `this == (char *)s_coordFormat + 8` (or `s_hdcOverflow`,
  `s_userModule`): a pointer-typed constant is always printed as the DGROUP symbol that contains it.
  No data reference exists behind them; each compare carries a PRE comment (`NearNullTests.java`).
- **SceneObject virtual bases:** calls and fields reached through `vbptr->sceneObjectOffset` keep the
  `*(code *)*slotPtr` / `field + offset` shape (the override fixes the arguments, not the
  expression).

## Remaining unknowns

The 5 `FUN_` functions, all dead and tagged `review`:
- `1028:0e71`: an empty member function (`RETF 0xa`, this + 4 unused words) between
  `mover_can_step` and `mover_step`; no caller, no slot.
- `1028:1cb7`: far cdecl, two 32-bit arguments, DX:AX result, mask/shift arithmetic with
  0xfff/0xfff0/0xf000/0xf (huge-pointer glue?); no caller.
- `1088:35c6`, `1088:35e0`: empty (this, backdrop) methods (`RETF 4`), twins (ENCAIXE `69e0`/`69e4`
  are unnamed too).
- `1088:3642`: an empty (this) method (`RETF 2`; ENCAIXE `6a5c`, NOITE `1010:a908`).

Dead but named (no caller and no slot, or a slot nothing calls): the second draw-list copy
(`1070:0037`, `00ff`, `dead_draw_list_remove` `01f5`), `draw_list_invalidate_chain`/`_all`
(`1070:0608`/`063a`), `dead_scene_object_empty_dc_hook` (`1028:02d3`), `target_move_tick_or_stop`
(`TargetVtbl.moveTick`) and `projectile_move_tick` (`ProjectileVtbl.moveTick`; it tests y, not x),
`perspective_backdrop_set_layer` and the other PerspectiveBackdrop functions, the Portable ctors
(no Portable is built), `status_bar_draw_text`, `player_move_tick` and the 17 `2974–2bf4` methods.

`crossbow_is_crossbow` (`1088:4fe8`), `target_is_target` (`5088`) and `projectile_is_projectile`
(`50a4`) are SceneObject slots 0x59, 0x58 and 0x56 (ENCAIXE's `slot64`/`slot63`/`slot61`) reached
through adjustor thunks: type tests that answer 1 for their class (the base answers 0).
`projectile_try_step` calls `isTarget`; the other two have no call site.

## Scripts

`ghidra/scripts/`:

| Script | Use here |
|---|---|
| `CopyTypesFromProgram.java` | `/NOITE.EXE`, then `/ENCAIXE.EXE`: SDK structs and 89 import signatures |
| `FarVtSlots.java` | Far vtable slots → functions, slot typing, vptr-store references. Args: `1090 05d2 22a4 [dry]` |
| `FarSlotSignatures.java` | slot `FunctionDefinition`s and virtual-call overrides. Args: `1090 defs`, `1090 calls`, `1090 site <addr>=<Vtbl>…` |
| `NearAdjustorThunks.java` (`far` mode) | `1088 0000 1332 far`, `1088 42c2 4d7e far`; rerun after renaming |
| `NearNullTests.java` | the NULL-test comments, per segment |
| `CodeGapSweep.java` (`/GA` prologue) | per code segment, `create` |
| `DeadJumps.java` | `/Od` unreachable epilogue jumps → their function's body. Args: segments `[dry]` |
| `NearSignatures.java` (far prologues) | conventions and `sig?` |
| `ExportFunctionOps.java` | op dumps for the matchers |
| `RenameFunctions.java` | applies the name TSVs |

`ghidra/cspec/`: `aFchkstk_fixup.xml` (the call-fixup), `cdecl16far_dx_ax.xml`,
`cdecl16far_dxax_ptr.xml`; installed with `SpecExtension` (inline). The `__stdcall16far_pop<n>`
models are installed by `FarSlotSignatures.java` when it needs them.
