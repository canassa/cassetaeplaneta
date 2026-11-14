# ENCAIXE.EXE: function inventory (phase 2)

The Ghidra program `/ENCAIXE.EXE` after function discovery. Addresses are Ghidra
`seg:off`. ENCAIXE is a small-model build (near code, near data, `this` at `[BP+4]`);
see `QUALITY.md` §0.

## Counts

Before: 453 functions (277 code, 88 import thunks, 88 externals).
After: **988** (812 code, 88 import thunks, 88 externals).

| Kind | Fns | Named | `sig?` | Where |
|---|---|---|---|---|
| Import thunk | 88 | 88 | – | `1030`, typed |
| Adjustor thunk | 286 | 286 (`*_thunk*`) | – | `1008:402e–51f5` (244), `1008:a13e–a496` (42) |
| CRT | 92 | 72 | 48 | `1008:0012–1bdd` |
| Blitter | 2 | 2 | – | `1000:0024`, `1000:0114` |
| Vtable slot (only) | 187 | 0 | 0 | engine and game; no direct caller |
| Called directly | 198 | 22 | 0 | DIB, app shell, wave, engine, game |
| Unreferenced | 47 | 4 | 4 | no call or slot reference; see below |

By segment: `1000` 2, `1008` 808, `1010` 2 (`APPABOUT`, the stub at `002e`).
"Named" means a real name. The adjustor thunks are named mechanically after their target
(`FUN_1008_5794_thunk_ca`), so they rename themselves when the script is rerun after the
targets get names.

Unreferenced (47): `dib_remap8/4`, `dib_remap_rle8`, `hmemmove_backward`, `3a5c–3b8a` (5),
`51f6`, `5e7c–6c18` (35, including the PerspectiveBackdrop-like `6756/6774/67ca`), `bc72`
(a 1655-byte function with a 6-way switch) and `1010:002e`. No word in DGROUP or in the code
holds their addresses, so most of them are library code linked with an object but never
called. The exception is `1010:002e`: it is `CALLF 1008:b064; RETF`, a static
initializer that is presumably reached through a CRT init table.

## Imports and types

- The 17 SDK structs come from NOITE: `RECT`, `POINT`, `MSG`, `PAINTSTRUCT`, `WNDCLASS`,
  `BITMAPINFO`, `BITMAPINFOHEADER`, `BITMAPCOREHEADER`, `BITMAPFILEHEADER`, `RGBQUAD`,
  `LOGPALETTE`, `LOGPALETTE256`, `PALETTEENTRY`, `OFSTRUCT`, `MIXCONFIG`, `MIXPLAYPARAMS` and
  `WAVEMIXINFO`. `CrtFILE` was not copied, because it has far pointers in NOITE.
- 81 import signatures are copied from NOITE (5 of them untyped there as well: `INITTASK`,
  `DOS3CALL`, `__AHSHIFT`, `__AHINCR`, `__WINFLAGS`). The WinG ordinals are renamed
  `WinGCreateDC`, `WinGRecommendDIBFormat`, `WinGCreateBitmap` and `WinGBitBlt`.
- 7 are typed from the SDK as `__stdcall16far`: `LOCALALLOC`, `LOCALREALLOC`, `LOCALFREE`,
  `LOCALSIZE`, `UNLOCKSEGMENT`, `ADDFONTRESOURCE` and `BITBLT`.
- `1018:5272` is `g_setSystemTimer` and `1018:5276` is `g_killSystemTimer`. They are 4-byte
  pointers to the function types `SetSystemTimerFn` (USER.11) and `KillSystemTimerFn` (USER.182),
  which WinMain fills through `GetProcAddress`.
- The cspec extensions are not needed. The stock `__cdecl16near` and `__stdcall16near` already
  return 3–4 bytes in `DX:AX`.

## Function discovery

- **Vtable slots.** Each slot is a word in `1018:0300–108f` that points to a method start and
  is either in a run of at least 3 or at a vptr store. That gives 1393 slot words, with 474
  distinct targets. 409 functions were created. Each slot is typed `word`, with a DATA
  reference to its code target; each vptr store has a DATA reference to its table.
  - Negative vbase offsets in vbtable rows `{0xfffe, 0xfb92}` point into code. One of them
    created a bogus `fb92` that split `wave_mix_activate`. It was removed, and the script now
    skips the second word of such a row and any target inside another function.
- **Adjustor thunks.** There are 286: 45 fixed (`SUB SS:[BX+2],imm; JMPF`) and 241 vtordisp
  (`MOV BX,SS:[BX+2]; MOV AX,[BX-2]; [ADD AX,k]; SUB SS:[BX+2],AX; JMP`). They are named
  NOITE's way:
  - `<target>_thunk` when there is no constant;
  - `<target>_thunk_<k>` (`484`, `486`, `14`, `22`, `6`, `d4`, `e`, `c4`, `ca`, `d8`);
  - `_thunk_m<k>` when the thunk subtracts (`m6`, `mca`).
- **Prologue and gap sweep.** 43 functions came from `PUSH BP; MOV BP,SP` / `ENTER` hits.
  18 more are frameless entries created by hand after reading them:
  - CRT entries `0740`, `0f4e`, `1496`, `14e6`, `1b7e`;
  - `RET n` / `MOV AX,1; RET 2` stubs `6312`, `6318`, `632c`, `6330`, `635a`, `69e0`, `69e4`, `6a5c`;
  - `XOR AL,AL; RET n` stubs `a856`, `a85c`;
  - `a7d4`, `b064`, and `1010:002e`.

  Ghidra's auto-analysis added about 66 more, at the call targets in the newly disassembled
  code. So the total is 409 + 43 + 18 + 66 − 1 (`fb92`) = 535 new code functions.
- **`game_handle_message`** at `1008:8eca` (3469 bytes) is a function now. It is slot 0 of
  `0x7fe`/`0xf62`.
- **Jump tables.**
  - `_output`'s switch at `08c7` had 8 bogus cases: Ghidra read 16 words starting at `0866`,
    so the extra 8 came from its own code, and one of them decoded `5606`, the middle of a
    `RET 2`. These were removed, the table is 8 words with a jump-table override, and `5602`
    is whole again.
  - The switch at `bc83` (`bc72`, 6 cases, table `bc88`) is now resolved, and `bc72` covers
    `bc72–c303`.
  - The other 7 tables were correct.

### What is left uncovered in 1008

- `0000–0011`: segment prefix, 16 zero bytes plus the word `0x00a4`. It is data.
- The jump tables: `0866–0875`, `b8cc`, `bb44`, `bc88`, `c442`, `ceb4`, `d986`, `e3b6`,
  `eefa`.
- `24e3–24e5`: `00 C3 00`, a stray unreachable `RET` between `dib_remap_rle8` and
  `hmemmove_backward`. NOITE has an 8-byte `FUN_1010_09c8` at the same spot.
- 673 alignment gaps of 1 byte (`00`/`90`), 674 bytes in all. `1010:0017` is padding too.

## Names from NOITE (97)

Each named function has a plate comment `Name from NOITE <name> at <addr> (opcode match x)`
saying how its name was decided.

- **Method.** Each pair was matched by a `difflib` ratio over Ghidra's normalised
  instruction lists, with far and near forms merged. A name was taken when:
  - the score was at least 0.75 with a margin of at least 0.1 over the next candidate and at
    least 8 instructions;
  - or the score was at least 0.6 with a margin of at least 0.25 and at least 12 instructions.

  Every pair was then checked by mnemonic similarity (≥ 0.75) and call count, and the order
  of the CRT, DIB and app code had to follow NOITE's link order.
- **Read by hand.** Tiny or ambiguous ones were named only after reading the listing:
  - `exit`, `_exit`, `_cexit`, `_c_exit` (the CX = 0 / 1 / 0x100 / 0x101 entries into `crt_doexit`);
  - `operator_new`, `operator_delete`, `srand`, `crt_call_winmain`, `crt_null_hook`;
  - `crt_dosret_*`, `crt_endstdio`, `_stackavail`, `_flushall`, `_close`, `crt_write_raw`;
  - `atoi`, `strcat`, `strcpy`;
  - `app_exit`, `app_idle`, `app_paint`, `app_command`, `message_box_printf`;
  - the 6 wave helpers.
- **Near-model names** replace NOITE's far ones:
  - `strncpy`, `_stricmp`, `strlen`, `strncmp`, `strcpy`, `strcat` (NOITE: `_fstr*`);
  - `_aNldiv`, `_aNlmul`, `_aNlrem` (NOITE: `_aF*`).
- **Groups:**
  - CRT 72: `0012–1bdd`.
  - DIB 9: `dib_copy_transparent`, `dib_copy`, `clear_system_palette`, `load_dib`,
    `read_dib_info`, `dib_remap8`, `dib_remap4`, `dib_remap_rle8`, `hmemmove_backward`.
  - App 9: `app_init`, `app_exit`, `app_message_loop`, `WinMain`, `app_idle`, `app_paint`,
    `app_command`, `message_box_printf`, plus the existing `APPWNDPROC` and `APPABOUT`.
  - Wave 7: `wave_mix_init`, `wave_mix_activate`, `wave_mix_deactivate`, `wave_play`,
    `wave_stop_all`, `wave_free_all`, `wave_mix_close`.
  - Blitters 2.

Candidates that were not applied (engine code, left for phase 4):
- `261c` ≈ `perspective_unproject_point` (0.71);
- `6756`/`6774`/`67ca` ≈ `perspective_backdrop_set_vanish_point`/`_set_view`/`_set_axis`
  (0.92/0.97/0.84);
- `5558` ≈ `scene_object_set_position` (0.95);
- `7f56` ≈ `object_list_is_full`;
- `a62a` ≈ `control_panel_get_visible_height` (0.88);
- `aa0c` ≈ `grid_backdrop_is_rect_free`;
- `b136` ≈ `status_bar_set_text`;
- `b08a/b090/b096/b0a6/b0b8` ≈ `condition_set/clear_default` and `flag_condition_set/clear/evaluate`,
  with `b064` + `1010:002e` ≈ NOITE's `init_static_conditions` pair;
- `8e6a–8eb2` ≈ `game_create_*_default`, `8caa` ≈ the Game dtor;
- the 1–2 instruction stubs at `5240–5624`, `a846–a8b4` (`condition_*_default`,
  `backdrop_*_default` shapes; ambiguous by content).

## Signatures

`NearSignatures` (mechanical, source ANALYSIS, `undefined2` parameters):

| Convention | Fns |
|---|---|
| `__stdcall16near` (from `RET n`) | 404 (145 with 1 word, i.e. `this` only) |
| `__cdecl16near` (from callers' `ADD SP`/`POP`, or no stack access) | 62 |
| `__cdecl16far` | 2 |
| typed by hand | 3: `APPWNDPROC`, `APPABOUT` (far pascal, as NOITE's), `WinMain` (near pascal, 5 words) |
| tag `sig?` + plate line | 52 |

The 52 `sig?` functions:
- 44 CRT functions with register arguments, shared epilogues or tail jumps;
- `sprintf` (varargs: callers pop 3 and 7 words);
- `dib_remap8/4`, `dib_remap_rle8`, `hmemmove_backward` and `atol`, which have no caller cleanup;
- `entry`.

The adjustor thunks and segment `1000` are not typed.

## Vtables (vptr stores into `1018:0300–108f`)

Classes are named by slot behaviour. They are tentative until phase 3.

| Table(s) | Slots | Corresponds to |
|---|---|---|
| `0304 03ce 048a 0620 097a 0a50 0b20 0c20 0ce6 0dc2 0e8e 0f92` | 93 each | the scene-object interface (NOITE `SceneObjectVtbl`, 102) |
| `0548` (no store; after vbtable `0544`) | 102 words | likely another scene-object table |
| `03be 06da 0a34 0bda 0f48` | 8 each | NOITE `Object3DVtbl` (8) |
| `07fe` | 6 | base Game (`GameVtbl`): slot 0 `8eca` handle_message, slots 1–4 the "Faltou redefinir" defaults |
| `0f62` | 7 | derived Game (Tetris): overrides `9e74 a08c 9f64 9fb2 a0f4` |
| `0daa` (store `0da8`, slot 0 = 0) | 12 | base Scene (NOITE `SceneVtbl`, 16) |
| `0f70` | 13 | the Tetris scene: slot 0 = `f2a2` (key handling) |
| `0952` | 19 | Backdrop (NOITE 23): `a856/a85c` query-rect stubs |
| `0bf4 1054` | 20 each | GridBackdrop (NOITE 24): `aa0c` ≈ `grid_backdrop_is_rect_free` |
| `0b0e` | 9 | ControlPanel-like (`a62a` ≈ `control_panel_get_visible_height`) |
| `0e7c` | 7 | StatusBar-like (`adaa` in place of `a62a`) |
| `107c` | 6 | FlagCondition (`b096/b0a6/b0b8`) |
| `1088` (slot 0 = 0) | 2 | Condition base (`b08a/b090`); `107c` and `1088` are stored by `b064` |
| `0f8a` | 3 | a small interface with `719c`, `f186` (rotate), `f1fe`: the Tetris piece |
| `0302` (`522c`), `061e` (`304a`), `0488 0c1c 0ce2` (`719c`), `0978 0a4e 0c1e 0ce4 0f90` (`7d0e`) | 1 each | Mover/DirectionalPlayer-sized tables (NOITE `MoverVtbl` 1) |
| `0544 06ea 06f0 0a44 0a4a 0b0a 0bea 0bf0 0cda 0cde 0da0 0da4 0f58 0f5e 104c 1050` | – | vbtables, `{0xfffe, offset}` rows |

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

The matcher and the name list are scratch files in `zig-out/encaixe/`: `match2.py`,
`cand.py`, `names.py`/`names.tsv`, `groups.py` and the `gaps_p2*.txt` reports.

## Phase-4 groups

These are the 526 functions other than the import and adjustor thunks. The adjustor
thunks follow their targets and need no group. The `sig?` column counts the functions
that carry the tag.

| # | Range | Fns | Bytes | Named | `sig?` | Content |
|---|---|---|---|---|---|---|
| – | `1000:0024–01c7` | 2 | 421 | 2 | – | blitters; nothing to do |
| 1 | `1008:0018–0864` | 30 | 2122 | 26 | 14 | CRT startup/exit, `sprintf`, `time`, string, long math, `_setargv`, `_flsbuf` |
| 2 | `1008:0876–1009` | 22 | 1929 | 14 | 14 | CRT `_output` and helpers, `malloc`/`free` (`0da4`/`0d50`), `__loctotime_t`, chkstk, `_NMSG_*` |
| 3 | `1008:100a–18d7` | 28 | 2239 | 23 | 14 | CRT I/O (`_lseek`, `_write`, `_tzset`?/`_isindst`? `12c0/13b0`), dosret, heap, `atol`/`atoi` |
| 4 | `1008:18d8–1bdd` + `1bde–27bd` | 26 | 3782 | 18 | 10 | CRT `fclose`…`crt_xtoa`, DIB/WinG helpers, `254a–2702` (`261c` ≈ `perspective_unproject_point`) |
| 5 | `1008:27be–301b` | 22 | 2125 | 0 | 0 | engine: first class block (getters at `2b32…`) |
| 6 | `1008:301c–402d` | 23 | 4084 | 0 | 0 | engine (the 8-slot Object3D methods `3192 32a2 332c 33ce`) |
| 7 | `1008:51f6–543d` | 28 | 564 | 0 | 0 | default stubs and getters |
| 8 | `1008:543e–557d` | 28 | 297 | 0 | 0 | default stubs and getters |
| 9 | `1008:557e–5625` | 28 | 142 | 0 | 0 | default stubs (`condition_*_default` shapes) |
| 10 | `1008:5626–5b61` | 28 | 1319 | 0 | 0 | small methods (vtordisp targets `5626…5cfc`) |
| 11 | `1008:5b62–5f1d` | 28 | 937 | 0 | 0 | small methods, `5e7c` (dead) |
| 12 | `1008:5f1e–63fb` | 28 | 1224 | 0 | 0 | small methods and stubs, mostly unreferenced (`604a–637c`) |
| 13 | `1008:63fc–6e25` | 28 | 2580 | 0 | 0 | engine: perspective backdrop (`6756/6774/67ca`, dead), draw/WinGBitBlt (`6a22–6c18`) |
| 14 | `1008:6e26–7db7` | 28 | 3951 | 0 | 0 | engine: UpdateList/DrawList (`71ee`, `72e0`), movement (`7a8a`, `7b66`, `7c50`) |
| 15 | `1008:7db8–8885` | 17 | 2744 | 0 | 0 | engine: `7dec`, `7f56` ≈ `object_list_is_full`, `805c`, `8124–8634` |
| 16 | `1008:8886–8ec9` + `1010:0000` | 16 | 1643 | 10 | 0 | app shell: WinMain, AppWndProc, the Game dtor `8caa`, `8d32`, the `create*` defaults |
| 17 | `1008:8eca–9c56` | 1 | 3469 | 0 | 0 | `game_handle_message`, high effort, alone |
| 18 | `1008:9c66–a85b` | 28 | 2182 | 0 | 0 | Game: `9c66`, ctor `9e28`, derived overrides; scene classes `a4a0–a85b` |
| 19 | `1008:a85c–b062` | 28 | 2035 | 0 | 0 | Backdrop/GridBackdrop stubs, board/occupancy matrix (`a962`), `ade4`, `ae7a` |
| 20 | `1008:b064–b897` + `1010:002e` | 25 | 2083 | 0 | 0 | the Condition static init, FlagCondition, font/text/score (`b136`, `b1dc`), `b5dc`, `b812` |
| 21 | `1008:b898–c419` | 8 | 2880 | 0 | 0 | Tetris core: `b898`, `ba20` (drop/land), `bb2e`, `bbd8`, `bc72` (dead 6-way switch), `c304` |
| 22 | `1008:c41a–f041` | 6 | 11194 | 0 | 0 | the four rotation giants `c41a/ce8c/d960/e392`, `eed8`, `f016` |
| 23 | `1008:f042–fcd1` | 20 | 3178 | 7 | 0 | Tetris scene: paint, `f186`, `f1fe`, keys `f2a2`, MCI, WaveMix, IPC `0x40a` |

Groups 17, 21 and 22 fall below 10 functions because their functions are large.

Phase 3 (`DATA.md`) did not change the groups. It gives them classes and types: 119 methods
now have a typed `this` (Game, Scene, Backdrop/GridBackdrop, SceneObject base slots,
Object3D, Mover, Animation, Piece, ControlPanel, Frame, OccupancyGrid, DrawList, the
Conditions), and every vtable slot is a typed near function pointer. By group:
- 5–6: Object3D methods and SceneObject-subobject helpers; 7–9: the SceneObjectVtbl and
  Frame defaults (slot names in `DATA.md`); 10–13: small methods that the adjustor thunks
  reach (type tests `5cf6/5cfc`, Moveable `5e7c/5f1e`, Mover ctors `6418/661c`);
- 14: SceneObject render slots, UpdateList/DrawList, Mover movement `7a8a–7d0e`;
  15: ObjectList `805c`, OccupancyGrid `8124–8302`, Backdrop create `8414`;
- 18: TetrisGame overrides, the Scene methods, the Player2D and TetrisPanel ctors; 19:
  Backdrop/GridBackdrop/TetrisBackdrop slots, the Actor2D/ControlPanel/Animated3D/Animation
  ctors, ControlPanel `ad9c/adaa/adc8`; 20: Conditions, the other ControlPanel/TetrisPanel slots, Scene
  `b5dc–b6f6`;
- 21–22: the Tetris board in `Piece.board` (`char[11][14]`, column-major), driven through
  `g_piece`; 23: TetrisScene handler `f2a2`, PieceVtbl `f186/f1fe`, DrawList ctor `f87a`.
