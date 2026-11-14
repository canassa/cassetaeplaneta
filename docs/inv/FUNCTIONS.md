# INV.EXE: function inventory

The Ghidra program `/INV.EXE` in its final state: every function mapped, named or noted, plated and
typed; the engine named from TIRO, the game read in phase 4. Addresses are Ghidra `seg:off`. INV is
TIRO's medium-model `/Od` build (`QUALITY.md` §0): far code, near data, `this` at `[BP+6]`, 4-byte
far vtable slots. **TIRO (`docs/tiro/`) is the reference for the engine names**; ENCAIXE's names
reach INV through TIRO's. The game is described in `GAME.md`, its bugs in `BUGS.md` (section INV).

## Counts

**1,193 functions:** 93 import thunks, 449 adjustor thunks and 651 code functions. **646 of the
651 are named**; 5 stay `FUN_` (dead unknowns that TIRO leaves unnamed too). Every code function
has a plate; no function carries a `review` or `sig?` tag.

| Kind | Fns | Where / names |
|---|---|---|
| Import thunk | 93 | `10a8`, all typed (from TIRO) |
| Adjustor thunk | 449 | `1088:0000–14a5` (256), `1088:4408–545b` (193); `<target>_thunk[_k]`, every one after its target's final name |
| CRT | 79 | `1080`: TIRO's 81 without `srand`/`rand` |
| Blitter | 2 | `1000:0024`, `1000:0114` (32-bit code, not typed) |
| DIB | 15 | `1008` (4), `1010` (11) |
| App shell | 10 | `1038` |
| WaveMix | 11 | `1078` |
| Engine | 458 | `1018–1060`, `1070`, `1088` |
| INV game | 76 | `1048` (6), `1068` (54), `1088` (16: the subclass ctors, the 7 game-class ctors, 5 type tests, `invader_column_set_cell`) |

By segment (code functions other than the adjustor thunks):

| Seg | Fns | Named | Seg | Fns | Named |
|---|---|---|---|---|---|
| `1000` | 2 | 2 | `1048` | 6 | 6 |
| `1008` | 4 | 4 | `1050` | 4 | 4 |
| `1010` | 11 | 11 | `1058` | 15 | 15 |
| `1018` | 51 | 51 | `1060` | 4 | 4 |
| `1020` | 7 | 7 | `1068` | 54 | 54 |
| `1028` | 49 | 47 | `1070` | 11 | 11 |
| `1030` | 9 | 9 | `1078` | 11 | 11 |
| `1038` | 10 | 10 | `1080` | 79 | 79 |
| `1040` | 2 | 2 | `1088` | 322 | 319 |

Conventions: 519 `__stdcall16far` (far pascal, parameters listed reversed), 106 far cdecl
(`__cdecl16far` 101, `__cdecl16far_dxax_ptr` 4, `__cdecl16far_dx_ax` 1), 24 near CRT helpers, the 2
untyped blitters.

## Function discovery

The TIRO procedure, with TIRO's scripts unchanged:

- **Vtable slots** (`FarVtSlots.java 1090 0594 26ee`): 1,949 slots, 643 distinct targets, **499
  new functions**, every slot typed as a 4-byte pointer, 79 vptr stores referenced. One reported
  store, `1038:00b8` → `1090:1038`, is `WNDCLASS.lpfnWndProc`'s segment word; its reference was
  deleted.
- **Adjustor thunks** (`NearAdjustorThunks.java 1088 0000 14a6 far`, then `4408 545c far`): 449
  thunks (72 fixed, 377 vtordisp). The slot pass had already made them functions. Rerun after the
  renaming to name them after their targets.
- **Gap sweep** (`CodeGapSweep.java <seg> <report> create`, one call per segment): 34 more,
  among them `1038:0000` (APPABOUT) and the CRT entries with a prologue. Don't call it through
  `runScript` from an inline script: the nested lookup pops a modal "Script does not exist"
  dialog and blocks the program's transaction.
- **CRT by hand, replayed from TIRO.** INV's `1080` is TIRO's minus `srand`/`rand` (`0262–02ad`,
  0x4c bytes), so every TIRO CRT address ≥ `0x2ae` is INV's + 0x4c. An inline script took each
  TIRO `1080` function, shifted its body, and made or fixed the INV function: `_aNchkstk` `00c4`,
  `_cintDIV` `0796`, `_flsbuf` `07de` (cut from `_amsg_exit` once `FATALEXIT` was set no-return),
  the 7 `_output` helpers `0cf6–0d8b`, the `INC BP` entries `_nrealloc` `0e3e` and `_nmsize`
  `0eac` (Ghidra had them one byte late), `crt_dosret_maperr` `1257`, the heap helpers
  `12ae`/`133a`/`13a0`, `crt_ltoa_body` `17b6`. `_output`'s jump table (`1080:08d0`, 8 words) is
  typed and its 8 COMPUTED_JUMP references are set; its epilogue `0dbc–0dc6`, which Ghidra had
  made a function, is folded back into `_output` (1,057 bytes, TIRO's size).
- **Dead jumps** (`DeadJumps.java`, all code segments): 72 unreachable `JMP rel16` folded into
  their functions.

What is left uncovered, all data or padding:
- `1080:0000–0011` (segment prefix) and `1080:08d0–08df` (`_output`'s jump table);
- one-byte alignment fillers: 37 in `1080`, 386 in `1088`.

## Names and how they were applied

`SalginCopyFromTwin.java /TIRO.EXE /tiro /inv …` (written for SALGIN, generic for a TIRO twin)
did the copying. The `types` mode copied TIRO's `/tiro` category (487 types: classes, vtable
structs, slot function definitions) into `/inv`. The `fns` mode took a TSV of `INV addr → TIRO
addr`. For each pair it copied the name, the calling convention and parameter types (mapped to
`/inv`), the no-return flag and the tags. It also wrote a plate `Name from TIRO <name> at <addr>
(<method>).` followed by TIRO's plate. **The TIRO text in those plates quotes TIRO's DGROUP
addresses and TIRO's game objects**: read it for the engine logic, not for INV's globals.

| Method | Names |
|---|---|
| Imports: `CopyTypesFromProgram.java /TIRO.EXE` | 93 |
| In-order alignment per segment (`zig-out/inv/align.py`: Needleman-Wunsch over INV and TIRO functions in address order, pair score = normalised-opcode ratio). Every engine segment pairs 1:1 (same count on both sides); 557 pairs score ≥ 0.6, and the 4 below (`1028:095b` 0.48, `1088:369c` 0.58, `1080:0262` 0.50, `1080:0fb8` 0.44) have exactly TIRO's size | 588 copied (586 renamed) |
| CRT: same alignment; the address shift (TIRO − 0x4c past `rand`) holds for every pair | (in the 588) |
| By role, with INV names: the Game subclass (`inv_game_*`, `1048`), `inv_scene_create`, `inv_scene_handle_message`, `inv_backdrop_create`, `inv_draw_score`, `inv_blit_score_box`, `inv_panel_ctor`, `inv_scene_ctor`, `inv_scene_create_screen`, `inv_backdrop_ctor`. TIRO's plates replaced by INV ones | 19 |
| By class (vtable stores, `operator new` sizes, bitmaps): the 7 game-class ctors, 5 type tests, `invader_column_set_cell` | 13 |
| Adjustor thunks after their targets (`NearAdjustorThunks.java`, rerun after phase 4) | 449 |

Corrections and caveats:
- The copy skips nothing by name: TIRO's 5 unnamed functions arrived as `FUN_<TIRO address>` and
  were reset to INV's default names. (A twin whose name is `FUN_` should be skipped.)
- TIRO's game-specific names were not copied: `crossbow_*`, `target_*`, `projectile_*`,
  `arrow_*`, `tiro_*` in `1068` and `1088`.
- TIRO's type tests in SceneObject slots 0x56/0x58/0x59 (`scene_object_is_projectile/target/
  crossbow`) are base defaults that return 0 here. They are renamed after ENCAIXE's numbering:
  `scene_object_slot61_default`, `slot63_default` and `slot64_default`, next to the existing
  `slot62_default` (0x57) and `slot65_default` (0x5a).

### Engine functions that differ from TIRO

The 11 pairs whose sizes differ (each plate says by how much):

| INV | Name | INV / TIRO bytes | Note |
|---|---|---|---|
| `1028:00a8` | `scene_object_slot24` | 79 / 103 | |
| `1028:01ee` | `mover_slot24` | 156 / 180 | together with `00a8`, most of `1028`'s −0x2c |
| `1028:02e1` | `scene_object_restore_background` | 124 / 120 | |
| `1030:033c` | `backdrop_create` | 245 / 256 | `1030`'s −0xb |
| `1038:0335` | APPWNDPROC | 560 / 578 | no wave on WM_PAINT (TIRO plays `PASARS01`) |
| `1048:0029` | `inv_game_create_player` | 204 / 231 | the Cannon, 4 lives |
| `1048:01ff` | `inv_game_on_create` | 138 / 70 | calls the six INV creators |
| `1078:01e6` | `wave_play` | 182 / 173 | `1078`'s +9 |
| `1080:001a` | `entry` | 171 / 177 | |
| `1088:17a4` | `scene_object_hide_and_invalidate` | 47 / 41 | |
| `1088:310c` | `animation_set_strip` | 285 / 265 | |

The 5 dead unknowns, TIRO's 5 to the byte (no caller, slot or data reference settles a role):
`1028:0e45` (empty member), `1028:1c8b` (`(ulong, ulong) -> DX:AX`, huge-pointer glue?),
`1088:370c`, `1088:3726` (empty `RETF 4` twins), `1088:3788` (empty `RETF 2`).

## Vtables → classes

Each INV table was compared slot by slot with every TIRO table of the same length
(`zig-out/inv/vtmap.py`). **Every engine table matches a TIRO table at 1.0**; the 91-slot
SceneObject tables reach 0.97, because the three base type-test slots were renamed. The engine
classes are TIRO's (Frame, SceneObject, Object3D, Mover, Portable, Moveable, Game, Backdrop,
Animation, Actor2D, Player2D, Scene, GridBackdrop, StatusBar, ControlPanel, Animated3D, the
Conditions), with INV's subclasses in TIRO's roles (Game `117e`, Scene `11e6`, ControlPanel
`0fc4`, GridBackdrop `1d46`). The 7 INV classes:

| Class | Tables (`1090:`) | Ctor | `new` | Built by | Object |
|---|---|---|---|---|---|
| **Cannon** (derives Player2D) | `1876` M, `187a` A, `187e` S | `cannon_ctor` `1088:562e` | 0x4b8 | `inv_game_create_player` | `68e0`, the player |
| **Saucer** (Actor2D; 4-slot Mover table) | `1dba`, `1dca`, `1dce` | `saucer_ctor` `6750` | 0x4be | `inv_create_saucer` | `68e2` |
| **Missile** (Actor2D; 3-slot Mover table; base of Bomb and Shot) | `1f42`, `1f4e`, `1f52` | `missile_ctor` `6abe` | – | – | – |
| **Bomb** (derives Missile) | `20c6`, `20d2`, `20d6` | `bomb_ctor` `67ee` | 0x4ba | `inv_create_bombs` | `68e6`, `68e8` |
| **Shot** (derives Missile) | `224a`, `2256`, `225a` | `shot_ctor` `6886` | 0x4ba | `inv_create_shot` | `68e4` |
| **InvaderExplosion** (Actor2D; 3-slot Mover table) | `23ce`, `23da`, `23de` | `invader_explosion_ctor` `6a26` | 0x4e4 | `inv_create_invader_explosion` | `68f2` |
| **InvaderColumn** (Actor2D; 3-slot Mover table) | `2552`, `255e`, `2562` | `invader_column_ctor` `691e` | 0x4de | `inv_create_invader_columns` (×4) | `68ea[4]` |

Type tests (SceneObject slots that answer 1 for the class, 0 in the base): `shot_is_shot` 0x56,
`invader_is_invader` 0x57 (column and explosion), `saucer_is_saucer` 0x58, `cannon_is_cannon` 0x59,
`bomb_is_bomb` 0x5a. `DATA.md` has the layouts.

## Phase 4: function groups

The engine needs only checking: names, prototypes and plates are TIRO's, and TIRO's were
verified. The game groups need reading. Counts exclude the adjustor thunks.

| # | Range | Fns | Content | Kind / effort |
|---|---|---|---|---|
| 1 | `1080` | 79 | CRT. Every pair is TIRO's at a fixed shift; spot-check `_lseek` `0fb8`, `_setargv` `0584`, `_output` `08e0`, `entry` | mechanical, low |
| 2 | `1000–1010`, `1038`, `1078` | 38 | Blitters, DIB, app shell, WaveMix; diff APPWNDPROC and `wave_play` against TIRO | mechanical, low |
| 3 | `1018–1030`, `1040–1060`, `1070` | 152 | The engine modules. Diff the 4 changed bodies in `1028`/`1030` against TIRO; the 2 `FUN_` in `1028` stay as TIRO left them | mechanical, low–medium |
| 4 | `1088:14a6–43ff` | 234 | SceneObjectVtbl defaults, getters, engine ctors/dtors, Game/Frame init; check by slot; `17a4`, `310c` and the 3 `FUN_` | mechanical, low |
| 5 | `1088:545c–6b79` | 88 | Engine ctors and Conditions, plus INV's subclass ctors and the 7 class ctors. Type every INV ctor's parameters (TIRO's `crossbow_ctor`/`target_ctor` shapes) | mixed, medium |
| 6 | `1048`, `1068:0000–07a6` | 19 | INV Game subclass, scene and backdrop create, the 6 creators (`0132` empty, `016e` columns, `028b` explosion, `0343` saucer, `0541` bombs, `03df` shot), the wrappers `0146`/`031b`, and the shared helpers `04bc`, `06d1`, `07a6` (each called from the handler) | INV, medium |
| 7 | `1068:0837–0d3d` | 10 | **Cannon** (`0837`, `087c`, `096a`, `0a19`: slots of `187e`) and **Saucer** (`0a84`, `0b20`, `0bc5`, `0ce6`, `0d3e`: slots of `1dba`/`1dce`); `0c16` (called on a saucer hit) | INV, medium |
| 8 | `1068:0e26–122f` | 7 | **Missile/Bomb/Shot** overrides (`0e26`, `0e77`, `0ede`, `0f2f`, `0fba`, `10f0`), `122f` | INV, medium |
| 9 | `1068:1272–1c30` | 13 | **InvaderColumn / InvaderExplosion** overrides (`1272`, `13a8`, `14e3`, `160a`, `178d`, `181f`; column-only `197e`, `1b03`; explosion-only `1bdb`, `1c03`), `1521`, `157b` (formation step), `1c30` | INV, medium–high |
| 10 | `1068:1c9c` | 1 (5,736 bytes) | `inv_scene_handle_message`: keys, every WM_SYSTIMER tick, hits, the invader count and speed-up, the end, 0x40a. Alone | INV, high |
| 11 | `1068:3304–351d` | 10 | Wave helpers (`3304`, `332a`, `3384`, `33aa`, `3405`, `3460`, `3486`, `34ac`) and the score box (`inv_blit_score_box`, `inv_draw_score`) | INV, low |

Order: groups 6–9 and 11 before 10 (the handler calls all of them); 1–5 at any time. Group 5's ctor
signatures matter to groups 6–9.

## The game functions

`1048`, the InvGame subclass (GameVtbl overrides, TIRO's roles): `inv_game_ctor` `0000`,
`inv_game_create_player` `0029` (the Cannon at (340, 380), 4 lives), `inv_game_create_control_panel`
`00f5`, `inv_game_create_status_bar` `0153`, `inv_game_create_init_scene` `01af`,
`inv_game_on_create` `01ff` (`game_init`, then the six `1068` creators).

`1068`:

| Addr | Name | Role |
|---|---|---|
| `0000` | `inv_backdrop_create` | GridBackdropVtbl.create: 32-px grid, no walls |
| `0026` | `inv_scene_create` | SceneVtbl.create: MCI `doom1.mid`, WaveMix, 8 waves, " 0000" |
| `0132` | `inv_on_create_hook` | empty far cdecl hook |
| `0146` | `invader_column_start_right` | heads a column right (arms timer 0xf) |
| `016e` | `inv_create_invader_columns` | the 4 columns at x 40 + 108·i, y 60 |
| `028b` | `inv_create_invader_explosion` | the explosion, parked at (640, 480) |
| `031b` | `invader_column_start_right_dup` | byte copy of `0146`, no caller |
| `0343` | `inv_create_saucer` | the saucer; launch timer 0xe, 10 s |
| `03df` | `inv_create_shot` | the shot (null-pointer write first, BUGS I1) |
| `04bc` | `shot_vanish` | blank frame, stop |
| `0541` | `inv_create_bombs` | the 2 bombs; drop timers 8/9 (null-pointer writes, BUGS I1) |
| `06d1` | `bomb_shot_down` | stop, one tick of `Bomtir.bmp` |
| `07a6` | `cannon_lose_life` | −1 life; 0 → `WM_DESTROY` (0), else the `Brocha.bmp` explosion |
| `0837` | `cannon_can_step` | Cannon SO canStep: always 1 |
| `087c` | `cannon_blit_to_dc` | Cannon SO blitToDc, one step wider each side |
| `096a` | `cannon_play` | Cannon SO play: TIRO's aim code, dead |
| `0a19` | `cannon_tick` | Cannon SO tick, dead |
| `0a84` | `saucer_arm_timer` | SaucerVtbl.armTimer |
| `0b20` | `saucer_stop_moving_dc` | Saucer SO stopMovingDc: hide, park at (50, 10) |
| `0bc5` | `saucer_stop_moving` | Saucer SO stopMoving |
| `0c16` | `saucer_explode` | `Explod.bmp` |
| `0ce6` | `saucer_move_tick_or_stop` | SaucerVtbl.moveTickOrStop, dead |
| `0d3e` | `saucer_check_edge` | SaucerVtbl.checkEdge: vanish at x ≥ 518, else step |
| `0e26` | `missile_arm_timer` | MissileVtbl.armTimer (kind 2 → `timer2Id` and `timer2IdB`, kind 5 → `timer2IdB`) |
| `0e77` | `missile_stop_moving_dc` | Missile SO stopMovingDc: stop, hide |
| `0ede` | `missile_stop_moving` | Missile SO stopMoving |
| `0f2f` | `missile_move_tick` | MissileVtbl.moveTick: stop off-screen, else step |
| `0fba` | `missile_can_step` | Missile SO canStep: `hitState` = the blocker's class |
| `10f0` | `missile_move_step` | Missile SO moveTick: one step |
| `122f` | `invader_column_init_cells` | 5 live cells (44·i twice, harmless) |
| `1272` | `invader_column_can_step` | Column SO canStep (its `hitState` is never read) |
| `13a8` | `invader_column_stop_moving_dc` | Column SO stopMovingDc: right-edge descent or landing |
| `14e3` | `invader_column_stop_moving` | Column SO stopMoving |
| `1521` | `invader_column_update_lowest_alive` | recomputes `lowestAlive` |
| `157b` | `invader_column_turn` | turns a column with the formation |
| `160a` | `invader_column_move_tick` | Column SO moveTick: 20 px, the cells follow |
| `178d` | `invader_column_move_tick_or_stop` | InvaderVtbl.moveTickOrStop, dead |
| `181f` | `invader_column_step` | InvaderVtbl.step: edge tests, then one step |
| `197e` | `invader_column_restore_background` | Column SO restoreBackground, live height only |
| `1b03` | `invader_column_draw` | Column SO draw, live height only |
| `1bdb` | `invader_explosion_restore_background` | the engine's version |
| `1c03` | `invader_explosion_draw` | the engine's version |
| `1c30` | `invader_explosion_start` | `Naboom1.bmp` on the killed cell |
| `1c9c` | `inv_scene_handle_message` | SceneVtbl.handleMessage (5,736 bytes) |
| `3304`–`34ac` | `inv_play_shot_wave`, `inv_score_invader_hit` (+100), `inv_play_explo5_wave`, `inv_score_saucer_hit` (+500), `inv_score_cannon_hit` (−500), `inv_play_march_wave`, `inv_play_descend_wave`, `inv_play_saucer_wave` | the sounds and the `g_score` changes |
| `34d2` | `inv_blit_score_box` | box (416, 437) to the window |
| `351d` | `inv_draw_score` | " %04d" / "-%04d" into the box |

`1088`: the subclass ctors (`inv_panel_ctor`, `inv_scene_ctor`, `inv_backdrop_ctor`), the class
ctors (`cannon_ctor` `562e`, `saucer_ctor` `6750`, `bomb_ctor` `67ee`, `shot_ctor` `6886`,
`invader_column_ctor` `691e`, `invader_explosion_ctor` `6a26`, `missile_ctor` `6abe`), the 5 type
tests and `invader_column_set_cell` `69d6` (`(this, alive, i, y, x)`, far pascal, `RETF 0xa`; adds
44·i to y).

## Phase 4 results

All 11 groups are done. What phase 4 corrected in the earlier picture:
- **Score:** `g_score` +100 per invader, +500 per saucer, −500 per bomb hit; the +10/+50 go to
  the cannon's `Player2D.score`, which nothing reports.
- **Result:** `0x40a` carries WM_DESTROY's own wParam (0xffff won, 0 lost), not `g_score > 0`.
- **The formation:** a right-edge turn descends 22 px, a left-edge turn does not; landing at
  y ≥ 390 loses; `g_unk01DC` is `g_invadersLanded`, `g_unk0278` is `g_formationMaxY` (the
  `desceniv.wav` trigger).
- **Timers:** bomb 0's drop id is `Missile.timer2Id` (+0x44), bomb 1's `timer2IdB` (+0x46); the
  saucer's launch id is `Saucer.timer2Id` (+0x4c).
- **`hitState`** is the class of the blocker ('1' shot … '5' bomb), not an outcome.
- **The handler** is 5,736 bytes; nothing reaches `game_handle_message`'s key, timer or mouse code.

Cleanup:
- **Tags:** the 4 dead game functions (`cannon_play`, `cannon_tick`, `saucer_move_tick_or_stop`,
  `invader_column_move_tick_or_stop`) are confirmed dead; the 5 `FUN_` plates end with a one-line
  note; `message_box_printf` is far cdecl `(caption, format, int arg)` (all 14 callers push 3 words,
  pop 6); `perspective_project_point`/`_unproject_point` keep 7 words (every caller pops 0xe); the 4
  unreferenced DIB functions keep TIRO's prototypes; `FUN_1028_1c8b` is `(ulong, ulong) -> DX:AX`.
- **Types:** `invader_column_set_cell`; the slot definitions of `InvaderVtbl` (`step`,
  `moveTickOrStop`), `SaucerVtbl` (`armTimer`, `moveTickOrStop`, `checkEdge`) and `MissileVtbl`
  (`armTimer`, `moveTick`) from their targets, the fields renamed after them;
  `SceneObjectVtbl_hideAndInvalidateFn` `(this, backdrop, hdc)`.
- **Overrides:** 14 untyped call sites retyped with `FarSlotSignatures.java 1090 site` (10
  `hideAndInvalidate` calls, 3 `InvaderVtbl.step`, 1 `SaucerVtbl.checkEdge`). 431 call-site
  overrides in all: every indirect call but the 11 CRT function-pointer calls.
- **Thunks:** `NearAdjustorThunks.java` rerun (`far`, both blocks): 449, 72 fixed, 377 vtordisp,
  every name matching its target.

**Final state:** 1,193 functions (93 imports, 449 adjustor thunks, 651 code functions, 646 named,
5 dead `FUN_`), 0 `review`/`sig?` tags, 431 call-site overrides.

## Scripts

`ghidra/scripts/` as used here:

| Script | Use |
|---|---|
| `CopyTypesFromProgram.java` | `/TIRO.EXE`: SDK structs and the 93 import signatures |
| `FarVtSlots.java` | `1090 0594 26ee` |
| `NearAdjustorThunks.java` (`far`) | `1088 0000 14a6 far`, `1088 4408 545c far`; rerun after naming |
| `CodeGapSweep.java` | per code segment, `create` |
| `DeadJumps.java` | all code segments |
| `ExportFunctionOps.java` | op dumps of INV and TIRO for the matchers |
| `SalginCopyFromTwin.java` | `types`, then `fns <tsv>` |
| `RenameFunctions.java` | the role names |
| `NearSignatures.java` | conventions of the unnamed `1068` functions |
| `FarSlotSignatures.java` | `1090 site …`: the 14 retyped call sites |

Not committed (scratch, `zig-out/inv/`): `align.py`, `mk.py` (the copy TSV), `vtmap.py`, the CRT
replay, the vtable/metadata dumps.
