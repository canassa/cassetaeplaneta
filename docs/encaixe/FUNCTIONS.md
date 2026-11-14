# ENCAIXE.EXE: function inventory

The Ghidra program `/ENCAIXE.EXE`. Addresses are Ghidra `seg:off`. ENCAIXE is a small-model
build (near code, near data, `this` at `[BP+4]`); see `QUALITY.md` §0. Data, classes and
vtables are in `DATA.md`; the game logic is in `GAME.md`.

## Counts

988 functions: 812 code, 88 import thunks (`1030`), 88 externals.

| Kind | Fns | Where / names |
|---|---|---|
| Import thunk | 88 | `1030`, typed |
| Adjustor thunk | 286 | `1008:402e–51f5` (244), `1008:a13e–a496` (42); `<target>_thunk[_k]` |
| CRT | 92 | `1008:0012–1bdd` (incl. `atoi`, a 3-byte jump to `atol`) |
| DIB | 9 | `dib_*`, `load_dib`, `read_dib_info`, `clear_system_palette`, `hmemmove_backward` |
| App shell | 11 | `app_*`, `WinMain`, `APPWNDPROC`, `message_box_printf`; `1010`: `APPABOUT`, `init_static_conditions_entry` |
| WaveMix | 8 | `wave_*` (`fa60–fca8`) |
| Engine | 373 | SceneObject family, Mover/Moveable/Animation/Actor2D/Player2D, Object3D, Backdrop/GridBackdrop, Scene, Game, ControlPanel/StatusBar, lists, occupancy grid, Conditions; NOITE's names |
| Tetris | 31 | `te_*`: TetrisGame, TetrisScene, TetrisPanel, TetrisBackdrop, Piece, score |
| Blitter | 2 | `1000:0024`, `1000:0114` (32-bit code, not typed) |

Every code function has a real name except three (below). No function carries `sig?`.
Five carry `review` (below). Every adjustor thunk is named after its target's final name.

Duplicate names: none. Pairs that share a body keep distinct names by their slot:
`scene_object_blit_to_dc` / `scene_object_slot24` (`6ca4`/`6cf6`, blitToDc and slot24 of the
base table), `mover_blit_to_dc` / `mover_slot24` (`6da8`/`6e26`), `dead_blit_view_to_dc` /
`dead_slot24_blit_view_to_dc` (`69e8`/`6a22`). The NOITE pairs that ENCAIXE splits by class:
`mover_attach` (`5726`, table `048a`) vs `moveable_attach` (`257c`, tables `0620` and the dead
Portable `054a`); `mover_invalidate` (`6d48`) vs `moveable_invalidate` (`25bc`); `animation_draw`
(`56aa`, live) vs `player_draw` (`3a5c`, dead Player class) and `player2d_draw` (`7eae`).

Unreferenced (47): `dib_remap8/4`, `dib_remap_rle8`, `hmemmove_backward`, `3a5c–3b8a` (the dead
Player/Exit methods), `51f6`, `5e7c–6c18` (35, the dead Portable/Exit/PerspectiveBackdrop code),
`bc72` and `1010:002e`. No word in DGROUP or in the code holds their addresses. `1010:002e` is
`CALLF 1008:b064; RETF`, reached through the CRT init hook `g_crtInitHook`.

## Left unnamed or under review

| Address | Name | Tag | Why |
|---|---|---|---|
| `1008:69e0` | `FUN_1008_69e0` | `review` | dead empty `(this, backdrop)` method (`RET 4`); no table holds it, so its slot is unknown (NOITE `FUN_1010_a8c0`, also unnamed) |
| `1008:69e4` | `FUN_1008_69e4` | `review` | as `69e0` (NOITE `FUN_1010_a8ca`) |
| `1008:6a5c` | `FUN_1008_6a5c` | `review` | dead empty `(this)` method (`RET 2`) (NOITE `FUN_1010_a908`) |
| `1008:27be` | `object3d_unk11` | `review` | Object3D override of the ENCAIXE-only slot `unk11`: GetDC + ReleaseDC and nothing else; the slot's purpose is unknown |
| `1008:bc72` | `te_piece_calc_shape_rects` | `review` | dead; name by role only (fills `Piece+0xf2–0x108`, which nothing reads) |

`crt_ltoa_body` (`1b7e`) is an unreachable CRT fragment (the `_ltoa`/`_ultoa` body without its
entries). `crt_xtoa` (`1b8a`) takes register arguments and stays `__cdecl16near(void)`.

## Decompiler artifacts (no reference to remove)

- **Null tests of an adjusted `this`.** `CMP SI,0x34; JNZ; XOR DI,DI` (the sub-object offset of
  a NULL object) prints as `this == (word *)&g_keyDown`, `s_appName + 4` (0x18), `&g_nextId`
  (0x10), `g_pieceStripFiles + 2` (0x42), `g_pieceStripWidths` (0x56), `&g_crtHoldRand` (0xe4).
  The decompiler symbolises pointer-typed constants itself; there is no stored reference. The 16
  compares carry a PRE comment (`NearNullTests.java`). `read_dib_info`'s `== 0xc`
  (sizeof `BITMAPCOREHEADER`) prints as `&g_instStackMin` and is commented the same way.
- **CRT return addresses.** In `_write` / `crt_write_flush_text`, the near return addresses that
  `CALL` pushes (`0x11c7`, `0x11d3`, `0x11e2`, …) show as `s_<string> + n` stores to stack slots.
- Removed: the 6 stored references that were wrong (`mover_invalidate` `[DI+0x454/0x456]` and
  `draw_list_remove` `[SI+4]` on the NULL path, `_dosmaperr`'s `XLAT` into space `0000`).

## Function discovery

- **Vtable slots.** Each slot is a word in `1018:0300–108f` that points to a method start and
  is either in a run of at least 3 or at a vptr store: 1393 slot words, 474 distinct targets.
  Each slot is typed `word`, with a DATA reference to its code target; each vptr store has a
  DATA reference to its table. Negative vbase offsets in vbtable rows `{0xfffe, 0xfb92}` point
  into code; the script skips the second word of such a row and any target inside another
  function.
- **Adjustor thunks** (286): 45 fixed (`SUB SS:[BX+2],imm; JMPF`) and 241 vtordisp
  (`MOV BX,SS:[BX+2]; MOV AX,[BX-2]; [ADD AX,k]; SUB SS:[BX+2],AX; JMP`), named NOITE's way:
  `<target>_thunk`, `<target>_thunk_<k>`, `<target>_thunk_m<k>` when the thunk subtracts.
- **Prologue and gap sweep.** 43 functions from `PUSH BP; MOV BP,SP` / `ENTER` hits, 18
  frameless entries created by hand (CRT entries `0740`, `0f4e`, `1496`, `14e6`, `1b7e`;
  `RET n` stubs `6312`, `6318`, `632c`, `6330`, `635a`, `69e0`, `69e4`, `6a5c`; `a856`, `a85c`;
  `a7d4`, `b064`, `1010:002e`), and about 66 from auto-analysis at the new call targets.
- **Jump tables.** `_output`'s switch at `08c7` is 8 words with a jump-table override; the
  switch at `bc83` (`bc72`, 6 cases, table `bc88`) is resolved; the other 7 were correct.

### Bytes left uncovered in 1008

- `0000–0011`: segment prefix (16 zero bytes and `0x00a4`), data.
- The jump tables: `0866–0875`, `b8cc`, `bb44`, `bc88`, `c442`, `ceb4`, `d986`, `e3b6`, `eefa`.
- `24e3–24e5`: `00 C3 00`, a stray unreachable `RET` (NOITE has an 8-byte `FUN_1010_09c8` there).
- 673 one-byte alignment gaps (`00`/`90`), 674 bytes in all. `1010:0017` is padding too.

## Names and signatures

- 97 names come from NOITE by an opcode match (plate `Name from NOITE <name> at <addr>`); the
  rest were read and named by role, each plate saying what it is, the NOITE counterpart and the
  evidence. Near-model CRT names replace NOITE's far ones (`strncpy`, `_stricmp`, `strlen`,
  `strncmp`, `strcpy`, `strcat`, `_aNldiv`, `_aNlmul`, `_aNlrem`).
- Prefixes: NOITE's class prefixes for the engine (`scene_object_`, `mover_`, `moveable_`,
  `animation_`, `actor2d_`, `player2d_`, `object3d_`, `backdrop_`, `grid_backdrop_`, `scene_`,
  `game_`, `control_panel_`, `status_bar_`, `portable_`, `exit_`, …), `te_` for the Tetris
  classes, `dead_` for unreferenced methods whose class is unknown.
- Conventions: game code `__stdcall16near` (from `RET n`), `__cdecl16near` where callers pop;
  `APPWNDPROC`, `APPABOUT` far pascal; `WinMain` near pascal (5 words). The 17 SDK structs and 81
  import signatures come from NOITE; 7 more imports are typed from the SDK as `__stdcall16far`.
  `g_setSystemTimer` / `g_killSystemTimer` are far pointers to `SetSystemTimerFn` (USER.11) /
  `KillSystemTimerFn` (USER.182), filled by WinMain through `GetProcAddress`.

## Groups

The 526 functions other than the import and adjustor thunks, by range. All groups are done.

| # | Range | Fns | Content | Status |
|---|---|---|---|---|
| – | `1000:0024–01c7` | 2 | blitters | done |
| 1 | `1008:0018–0864` | 30 | CRT startup/exit, `sprintf`, `time`, string, long math, `_setargv`, `_flsbuf` | done |
| 2 | `1008:0876–1009` | 22 | CRT `_output`, `malloc`/`free`, `__loctotime_t`, chkstk, `_NMSG_*` | done |
| 3 | `1008:100a–18d7` | 28 | CRT I/O, `_tzset`, dosret, heap, `atol`/`atoi` | done |
| 4 | `1008:18d8–27bd` | 26 | CRT `fclose`…`crt_xtoa`, DIB helpers, Object3D attach/unproject | done |
| 5 | `1008:27be–301b` | 22 | Object3D getters, draw-bounds, support/drop; Moveable and Portable overrides | done |
| 6 | `1008:301c–402d` | 23 | Object3D size/anchor/depth order/overlap, Moveable movement, Animated3D tick, the dead Player/Exit/Portable methods | done |
| 7 | `1008:51f6–543d` | 28 | Frame dtor/getCell, SceneObjectVtbl defaults and getters | done |
| 8 | `1008:543e–557d` | 28 | SceneObjectVtbl defaults and getters | done |
| 9 | `1008:557e–5625` | 28 | SceneObjectVtbl defaults, type tests | done |
| 10 | `1008:5626–5b61` | 28 | Animation/Mover small overrides | done |
| 11 | `1008:5b62–5f1d` | 28 | Actor2D/Player2D/Object3D/Animated3D overrides, Moveable ctor | done |
| 12 | `1008:5f1e–63fb` | 28 | Moveable slots, the dead Actor/Player/Exit/Portable methods | done |
| 13 | `1008:63fc–6e25` | 28 | ControlPanel type tests, Mover ctors, Frame ctors, dead PerspectiveBackdrop and blits, SceneObject/Mover invalidate and blit | done |
| 14 | `1008:6e26–7db7` | 28 | SceneObject render slots, UpdateList/DrawList, Mover movement, Animation | done |
| 15 | `1008:7db8–8885` | 17 | Animation stop/tick, Player2D slots, ObjectList, OccupancyGrid, Backdrop create/autoscroll | done |
| 16 | `1008:8886–8ec9` + `1010:0000` | 16 | app shell, Game dtor, `game_init`, the `create*` defaults | done |
| 17 | `1008:8eca–9c56` | 1 | `game_handle_message` | done |
| 18 | `1008:9c66–a85b` | 28 | `game_take_exit`, TetrisGame, Scene methods, Player2D/TetrisPanel ctors, `te_scene_create_screen` | done |
| 19 | `1008:a85c–b062` | 28 | Backdrop/GridBackdrop slots, Actor2D/ControlPanel/Animated3D/Animation ctors | done |
| 20 | `1008:b064–b897` + `1010:002e` | 25 | Conditions, StatusBar/ControlPanel slots, Scene create/dtor/addObject, `te_scene_create`, `te_grid_backdrop_create_with_walls` | done |
| 21 | `1008:b898–c419` | 8 | Piece spawn, new game, landing, right column, stop, `bc72`, restore background | done |
| 22 | `1008:c41a–f041` | 6 | `te_piece_move_right/left/down`, `te_piece_rotate`, `te_piece_clear_full_lines`, `te_piece_draw` | done |
| 23 | `1008:f042–fcd1` | 20 | row clear, PieceVtbl, `te_scene_handle_message`, score, DrawList, WaveMix | done |

## Remaining unknowns

- The five functions in the table above.
- `Piece.unk48`, `Piece.unk4E` (written, never tested), `Piece+0xf2–0x108` (only the dead
  `bc72` writes them), `Piece+0x46`.
- `FrameCell` (8 bytes): allocated and constructed, read only by `frame_get_cell`.
- The ENCAIXE-only SceneObject slots `unk11` and `unk18`; `unk4E` returns a name (`""` by
  default, `prevSceneName` for Portable).

## Scripts (`ghidra/scripts/`)

| Script | Use |
|---|---|
| `CopyTypesFromProgram.java` | Copies SDK structs and import-thunk signatures (and thunk names) from another program in the project. Args: `[/NOITE.EXE] [types…]`. |
| `NearVtSlots.java` | Small-model vtable slots → functions plus slot and store references. Args: `1008 1018 0300 1090 2000 [dry]`. |
| `NearAdjustorThunks.java` | Finds and names this-adjustor thunks. Rerun it after renaming targets. Args: `1008 0000 fcd2 [dry]`. |
| `CodeGapSweep.java` | Reports gaps, and with `create` makes functions at prologues and referenced gap starts. Args: `1008 [report] [create]`. |
| `NearSignatures.java` | The mechanical conventions and `sig?` tags. Args: `1008 1010 regargs=1008:0000-1bdd [dry]`. |
| `ExportFunctionOps.java` | Dumps normalised instruction lists for the fuzzy matcher. Args: `<out.tsv>`. |
| `RenameFunctions.java` | Renames from a TSV (`addr name [plate]`). |
| `NearNullTests.java` | PRE comment on each `CMP reg,imm; JNZ; XOR r,r` (or `MOV [BP-n],0`) null test of an adjusted `this`. Args: `1008 [maxImm] [dry]`. |
