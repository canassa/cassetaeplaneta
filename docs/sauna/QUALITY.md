# SAUNA.EXE: decompilation quality (phase 1)

This is the assessment of the Ghidra program `/SAUNA.EXE` as auto-analysis left it, plus the
program-wide decompiler fixes applied before the mapping (§7). Addresses are Ghidra `seg:off`.
The scratch matchers and dumps are in `zig-out/sauna/` and are not committed (`ne.py` NE segments
with relocation masks, `feat.py`/`align.py` model-independent features and in-order alignment,
`crt*.py`, `vtm.py`/`slotmap.py` vtable matching, `gs/Sauna*.java` dumps).

## 0. Headline: SAUNA is a large-model, unoptimised build

TIRO is medium model, ENCAIXE small model. SAUNA runs the same minigame engine sources (the
"Faltou redefinir o método Create…" strings, `MAX_OBJECT_QTY`, the occupancy grid, the WinG shell)
but it is built in the **large memory model** (far code **and far data**), **without optimisation
(`/Od`)** and **with stack probes**, like TIRO, and with **its engine at a NOITE-like revision**:

- One code segment per module, 19 of them plus two 32-bit blitter segments. Calls are far
  (`CALLF` ≈ 2,000 sites; near `CALL` only inside the CRT). `this` is a **far pointer at
  `[BP+6]`** (4 bytes), loaded with `LES BX,[BP+6]` and used as `ES:[BX+k]`. There are about
  6,300 `LES` in the game code.
- Every function starts `PUSH BP; MOV BP,SP; MOV AX,<frame>; CALLF 1098:00f8` (`_aFchkstk`,
  455 callers), then `PUSH DI; PUSH SI`, and ends `POP SI; POP DI; LEAVE; RETF [n]`. There is a
  `JMP` to the epilogue before each return, the long `0F 8x` jumps, and no `PUSH DS; MOV DS`
  prologue: DS is DGROUP (`10b0`) everywhere. The exported callbacks (`APPWNDPROC`, `APPABOUT`,
  `WinMain`) use the `/GA` prologue `MOV AX,SS; …`.
- **Data pointers are far** (4 bytes). Object layouts therefore follow **NOITE's** far layouts
  (`SceneObject.x` at +0x12, as NOITE), not TIRO's/ENCAIXE's near ones.
- **Vtables live in a code segment** (`10a0`), as in NOITE, not in DGROUP. A vptr is a far
  pointer stored as two words (`MOV ES:[BX],off; MOV ES:[BX+2],0x10a0`), and each slot is a
  4-byte far code pointer carrying an NE relocation. A virtual call is
  `LES BX,[obj]; LES BX,ES:[BX]; CALLF ES:[BX+slot]`.
- The compiler is the same MSVC 1.5x C++ as the other minigames; the CRT is the large-model
  Windows library, byte for byte NOITE's (§4).
- Strings live in DGROUP. A file name leaked into the asserts: `d:\c&p\pacman\transrle.cpp`
  (DGROUP `0946`), so the project folder was `pacman`.
- The NE entry table exports only `___EXPORTEDSTUB` (ordinal 1). The module description is
  "Sauna Mista", the window class and title too.

Engine revision. The SceneObject interface has **98 slots**: TIRO's 91 plus the five NOITE
slots before `getWorldX` (`slot00`, `slot01`, `enableRle`, `isRle`, `getSceneName`), ENCAIXE's
`unk18` after `draw`, and NOITE's `isScrollTarget`/`slot43` pair before `isPlayer`; TIRO's `unk4E`
is absent. The Backdrop (23), GridBackdrop (24) and Scene (16) tables have NOITE's slot counts, the
Animation table has 6 slots (NOITE 8, TIRO 1), the ControlPanel table 14 (NOITE 17, TIRO 9), the
Game table TIRO's 7. RLE sprites are in: `scene_object_enable_rle`, a `transrle.cpp` module
(`1088`) and an RLE-aware copy module (`1068`) that calls the 32-bit segments. Code bodies,
though, match TIRO best (same `/Od`): the module segments align to TIRO's in order (§4).

What this means for the phases:
- **Names and slot meanings come from TIRO** (and NOITE for the slots TIRO lacks); code matches
  TIRO by module order with model-independent features (APIs, small immediates, mnemonics with
  `LES` dropped).
- **Struct layouts do not transfer byte for byte from TIRO or ENCAIXE** (pointers double) and
  must be re-derived; NOITE's far layouts are the closest start (`SceneObject` agrees on the
  offsets checked so far).
- Game code is **far pascal** (`__stdcall16far`, parameters listed reversed, `RETF n`) with
  4-byte `this` and data pointers; the `ghidra-fix-signature` skill applies as written for NOITE.

## 1. Segments

The NE header: 23 segments, heap 512, stack 8192, auto-data segment 23.

| Ghidra | NE | Size | Holds |
|---|---|---|---|
| `1000` | 1 | 0x2a1 | **32-bit code** (NE flag 0x2000): NOITE's row blitters (the WinG sample's `FAST32.ASM`) (`0148` ≈ NOITE `dib_rows_copy_transparent32`, `0234` ≈ `dib_rows_copy32`, 0.93 byte ratio) after a new routine `0024` (called by `1068:0000`). Garbage as 16-bit code past the DPMI prologue; don't type |
| `1008` | 2 | 0x3c5 | **32-bit code**: one more blitter `0024`, called by `1068:1336`. Not in NOITE |
| `1010` | 3 | 0xcbc | DIB copy (TIRO `1008`, 4 functions at the same offsets) plus `0960`, `0c49` |
| `1018` | 4 | 0x1044 | DIB load/palette/remap: **TIRO's `1010` at identical offsets** (11 functions, same size) |
| `1020` | 5 | 0x2e98 | SceneObject/Mover/Animation/Player2D/object list (TIRO `1028`) |
| `1028` | 6 | 0xbb0 | Occupancy grid, Backdrop/WinG (TIRO `1030`) |
| `1030` | 7 | 0x35c9 | Object3D/Moveable/Portable/Player/Exit (TIRO `1018`) |
| `1038` | 8 | 0x372 | Perspective backdrop and layers (TIRO `1020`) |
| `1040` | 9 | 0x1b1f | `game_handle_message` (5,905 bytes, **not a function**) and `game_take_exit` |
| `1048` | 10 | 0x1d9 | SaunaGame: ctor and the createPlayer/Scene/ControlPanel/StatusBar/onCreate overrides (TIRO `1048`) |
| `1050` | 11 | 0xd5 | Conditions module (TIRO `1050`) |
| `1058` | 12 | 0x603 | App shell: APPABOUT, app_init, WinMain, APPWNDPROC… (TIRO `1038`) |
| `1060` | 13 | 0x314 | Scene: create, dtor, add object, the four add-exit variants (NOITE's set) |
| `1068` | 14 | 0x1f2f | RLE-aware DIB copies (8 functions; 4 shaped like TIRO's `dib_copy*`, 4 helpers), the callers of `1000`/`1008` |
| `1070` | 15 | 0xb82 | The two draw lists (TIRO `1070`) |
| `1078` | 16 | 0xc11 | StatusBar and ControlPanel methods (TIRO `1058`) |
| `1080` | 17 | 0x437a | **The SAUNA game**: Pacman and Ghost classes, SaunaScene and its handler, score |
| `1088` | 18 | 0x915 | `transrle.cpp`: RLE encode/decode (3 functions, `_assert` "pOutputBuffer!= NULL") |
| `1090` | 19 | 0x49b | WaveMix wrappers (TIRO `1078`, 11 functions) |
| `1098` | 20 | 0x206b | CRT (large model). `entry` at `001a`; `0000–0011` is the segment prefix |
| `10a0` | 21 | 0x9ca4 | **Adjustor thunks, the vtables and all the out-of-line accessors, defaults, ctors and dtors** (TIRO's `1088` plus the tables). The thunks are in four blocks (`0170–1e78`, `59ce–5a72`, `61d6–6290`, `68de–6aa0`); the tables in six ranges (`41f8–4384`, `5326–59ca`, `79ea–8482`, `869a–86be`, `8f9c–9038`, `99ec–9ca4`) |
| `10a8` | 22 | 0 file, 0xc alloc | A far BSS segment: the two static `FlagCondition`s (6 bytes each: far vptr + flag) that `init_static_conditions` builds |
| `10b0` | 23 | 0x7cda | DGROUP |
| `10b8`, `10c0` | — | 32 / 752 | Resources: one group icon and one icon (`AppIcon`) |
| `10c8` EXTERNAL | — | 0x164 | 89 import thunks |

## 2. Entry and startup

| What | Where | Notes |
|---|---|---|
| `entry` | `1098:001a` | INITTASK, `_cinit`, `_setargv`, `_setenvp`, `crt_call_winmain`; matches TIRO's at 0.95 |
| WinMain | `1058:021a` | "O aplicativo já está aberto !!!" on a second instance; USER.11/182 → SetSystemTimer/KillSystemTimer far pointers (`10b0:7b26`/`7b2a`) |
| app_init | `1058:0055` | RegisterClass/CreateWindow "Sauna Mista" 640×480 centred; `new(0x560)` → `sauna_game_ctor` (`1048:0000`), which sets `g_game` (`10b0:7b1a`) and `7b1e` |
| APPWNDPROC | `1058:0353` | Forwards to `g_game->vtbl[0]`; WM_CREATE → `vtbl[6]` + SetSystemTimer(hwnd, 1, 50); 0x40b stores `g_noiteWnd` (`10b0:01a2`); posts 0x40c once (flag `01d8`); WM_PAINT plays a wave every time |
| game_handle_message | `1040:0000` | Game slot 0. Not a function in the auto-analysis |

## 3. Function boundaries (auto-analysis)

Counts as auto-analysis left them:
- 711 functions in Ghidra's count: **533 code functions**, 89 import thunks and 89 externals.
- Named: `entry`, `___EXPORTEDSTUB` and the imports.
- Conventions guessed: 405 `__stdcall16far`, 94 `__cdecl16far`, 20 near (CRT), 14 unknown (the
  32-bit segments and CRT entries).
- 254 functions have no reference at all: Ghidra's function-start search found them.

What was missing:
- **Uncovered code: about 32 KB**, mostly in `10a0` (21.6 KB in 118 ranges, 63 of them ≥16 bytes),
  `1040` (5.9 KB: `game_handle_message`), `1098` (1.9 KB: `_output` and the CRT entries without a
  prologue), `1068` (0.6 KB), `1080` (0.45 KB at `0000`), and APPABOUT (`1058:0000`).
- **Vtables:** none typed, so no slot creates a reference. The 1,404 far slots carry NE
  relocations (`10a0` holds 2,016 relocations outside instructions); 42 tables are reached by 69
  vptr-store pairs. Almost every slot target is a function already (the start search found the
  defaults); what the tables lack is the references.
- **387 adjustor thunks** in `10a0`, missing as functions: 59 fixed (`SUB SS:[BX+4],imm; JMPF`,
  immediates 6…0x4bc; 0x4ba/0x4bc are the SceneObject vbase adjustments, NOITE 0x4be) and 328
  vtordisp (`MOV BX,SP; LES BX,SS:[BX+4]; MOV AX,ES:[BX-2]; …; SUB SS:[BX+4],AX; JMPF` — the
  large-model form, `this` far).
- **`/Od` dead jumps:** 51 unreachable `JMP rel16` after an unconditional jump, plus two dead
  `else` blocks in `1068` (`0167–01a5`, `162b–167e`, constant-folded conditions) and a 6-byte
  chain in `1080`.
- CRT: `_output` (`1098:0b14`) stopped at its jump table (`JMP CS:[BX+0xb04]`, 8 words at
  `1098:0b04`); its near helpers (`0f2f…0fce`) and the frameless entries (`_aNchkstk` `00d8`,
  `_cintDIV` `09ae`, `crt_dosret_maperr` `1941`, `crt_ltoa_body` `2008`) were undisassembled; two
  `INC BP` far prologues (`1b26`, `1ba6`) were split into a 1-byte function plus the rest.

Bad splits and merges: none besides the `INC BP` pair. No data was decoded as code.

Large functions: `1040:0000` game_handle_message (5,905), `1080:32f7` the SAUNA scene handler
(3,461), `1068:16ec`/`0c8e` (2,115/1,704, RLE copy helpers), `1080:2404` (1,734), `1080:0d05`
(1,721), `1030:032b` object3d_draw_bounds (1,363).

## 4. Matching against the twins

| Method | Result |
|---|---|
| CRT bytes vs NOITE (relocations masked, `ne.py`) | 45 functions equal byte for byte over their first 48 bytes; NOITE's large-model names (`_fstrcpy`, `_fmalloc`, `crt_heap_*`) |
| CRT link-order alignment vs NOITE `1008` and TIRO `1080` (`crt.py`, `crt2.py`) | 87 of 97 at ≥0.85, the rest by bytes and position |
| Module segments, in-order Smith-Waterman alignment vs TIRO (`align.py`; pair score = max of a feature ratio — APIs, small immediates, calls, slots — and a mnemonic ratio with `LES` and the chkstk pair dropped) | Every module segment finds its TIRO segment by a wide margin (e.g. `1020`→`1028` 23.7 vs 6.6 next, `1030`→`1018` 22.9 vs 6.1). `1018`, `1010` align at 1.00 throughout |
| Same vs NOITE | Weak (everything lands in NOITE's big `1010`): NOITE is optimised, so only the CRT matches it |
| Vtables: per-slot override pattern across 10 class pairs + default-body similarity, Needleman-Wunsch (`slotmap.py`) | SAUNA's 98 SceneObject slots ↔ TIRO's 91 with scores 0.81–0.98 per slot; the inserted slots are exactly NOITE's first five, ENCAIXE's `unk18` and one is/as pair |

Cross-check: of the 82 functions that both alignment and a vtable slot name, 79 agree; the 3 that
differ sit next to functions SAUNA inserted (`enableRle` before `drawDirtyTo`, the Animation AVI
stubs before `play`), where the alignment slipped by one. Slot names win.

## 5. Imports

89 imports from WAVEMIX, KERNEL, GDI, USER, WING and MMSYSTEM, in the usual order. All were
untyped; three are unreferenced (`__AHSHIFT`, `__AHINCR`, `__WINFLAGS`).
- 83 are in NOITE and were copied with `CopyTypesFromProgram.java /NOITE.EXE` (the 4 WinG
  ordinals renamed). The 6 others come from TIRO (`HMEMCPY`, `GETOBJECT`, `GETPALETTEENTRIES`,
  `GETNEARESTPALETTEINDEX`, `GETTICKCOUNT`) and ENCAIXE (`BITBLT`).
- The API pointer parameters are NOITE's (far `T *32`, or split `T *` + `_seg` where Ghidra's
  4-byte alignment needed it); their sizes were checked against NOITE's (`SaunaApiSizes.java`).
- There is no `WINEXEC`, `FINDWINDOW`, `SETTIMER` or MCI command interface: the game plays MIDI
  through `MCISENDSTRING` only.

## 6. Decompiler output quality

| Issue | State |
|---|---|
| chkstk | Every body starts with the `_aFchkstk` call (its AX frame size invisible); the call-fixup (§7) removes it and allocates the frame |
| Signatures | Parameter counts from `[BP+n]` are right; `this` shows as `undefined4 param_1` or `undefined2 *param_1` + `param_1._2_2_` (the segment) |
| Far pointers | Every field access is `*(int *)((int)param_1 + 0x14)`: the offset half only, the segment dropped. Typing `this` as a far struct pointer fixes it |
| Virtual calls | `puVar1 = (undefined2 *)((int)*param_1 + 4); (*(code *)*puVar1)(0x1098, …)`: the slot load is two words, so the decompiler falls back to the default model and passes the pushed `CS` as a first argument. Fixed by call-site overrides on all 469 sites (`FarSlotSignatures.java … large`, `FUNCTIONS.md` Cleanup) |
| Globals | DS = `10b0` is set everywhere, but the BSS globals were undefined, so many read `*(int *)0x1d6`; all typed in phase 3 and the cleanup (`DATA.md`) |
| API calls | Correct once typed (`POSTMESSAGE(0,hwnd,0x40c,g_noiteWnd)`), except where the far string pointer is split |
| Overall | The control flow is good; `/Od` bodies are long but literal |

## 7. Program-wide fixes applied

- **Types:** `CopyTypesFromProgram.java` from `/NOITE.EXE` (17 SDK structs, 83 signatures), then
  `/TIRO.EXE` and `/ENCAIXE.EXE` for the other 6.
- **Spec extensions** (`ghidra/cspec/`): `cdecl16far_dx_ax.xml`, `cdecl16far_dxax_ptr.xml` and
  the **`aFchkstk` call-fixup** (`aFchkstk_fixup.xml`), installed with `SaunaSpecInstall.java`,
  which also names `1098:00f8` `_aFchkstk` and sets the fixup on it. SAUNA's probe is the same
  routine as TIRO's (`SUB AX,SP` … `PUSH DX; PUSH BX; RETF`), so the same `SP = SP + 4 - ((AX+1)
  & 0xfffe)` model is right: frames are allocated and outgoing pushes no longer alias locals.

## 8. What the game is (first look)

*Sauna Mista* ("mixed sauna") is a **Pac-Man** in a sauna: the source folder is `pacman`, the
files are `LABIRIN*.BMP`, `PAC*.BMP`, `GHOST*.BMP`, `pac.mid`, `pacman*.wav`, and DGROUP holds the
maze as 30 text rows of 40 characters (`1` wall, 96 `2`, four `3` near the corners;
`031a–07e7`). The
`1080` segment has a player class (derives Player2D, whose `isScrollTarget`/`slot43` it keeps; built by
createPlayer) and a ghost class (derives Actor2D; four of them built by the SaunaScene ctor),
plus two bitmap objects `3o1amend.bmp`/`3o1rolha.bmp`. `DATA.md` has the details.

NOITE's side (`src/handlers/3fsauna.zig`, `handler_3fsauna`): WinExec `sauna\sauna.exe`, poll
`FindWindow("Sauna Mista")` on timer 0x14, post 0x40b with the main window; SAUNA's 0x40c hides
NOITE; its 0x40a result sets `minigameWon[4]`, adds the score and takes a life on a loss.

## 9. Plan

Phase 2 (functions):
1. `NearAdjustorThunks.java 10a0 <block> far` over the four thunk blocks (the large-model
   `LES BX,SS:[BX+4]` form is accepted by the script).
2. `CodeGapSweep.java` on every code segment, then `FarVtSlots.java 10a0 <lo> <hi> large` over the
   six table ranges (the new `large` mode pairs each offset store with its segment store and
   ignores relocations inside instructions).
3. `DeadJumps.java` on all code segments; the dead blocks and the CRT entries by hand.
4. Names: CRT (NOITE bytes, then alignment), module segments (TIRO in-order alignment), `10a0`
   by vtable slot (TIRO, NOITE for the extra slots), ctors/dtors by their vptr stores, then the
   thunks renamed after their targets.

Phase 3 (data): strings (`DefineStrings.java`), the vtable structs with far slots
(`FarVtables.java`), the class structs re-derived for far pointers (`NoiteStructs.java`, from
NOITE's layouts), the globals, the maze and the asset tables.

Risks:
- The engine is a hybrid: TIRO's code, NOITE's slot set and far layouts. Check every copied name
  against the slot it fills and every copied layout against SAUNA's own offsets.
- Several engine functions exist twice in SAUNA (`1078:0a0f/0b10`, `0a68/0b69`; three Moveable
  and four Mover ctors where TIRO has two and three), so similarity alone cannot pick one.
