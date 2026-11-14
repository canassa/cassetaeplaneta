# SERIAL.EXE: decompilation quality (phase 1)

This assesses the Ghidra program `/SERIAL.EXE` as auto-analysis left it (§1–§7), then lists the
program-wide fixes already applied (§8) and the plan (§10). Addresses are Ghidra `seg:off`.
Scratch tools live in `zig-out/serial/` (not committed): `ne.py` (NE segments and relocations),
`reloc.py` + `dis.py` (offline `objdump` listing with the far-call targets resolved from the
relocations), `cmp.py` / `fmap.py` / `newcode.py` (byte alignment against TIRO), `strscan.py`,
`thunks.py`, `stats.py`, `SerialSurvey.java`, `SerialExportFns.java`, `SerialDecomp.java`.

## 0. Headline: SERIAL is TIRO's sibling build

SERIAL is built from **the same engine sources, the same toolchain and the same options as
TIRO.EXE** (`docs/tiro/QUALITY.md` §0): MSVC 1.5x, **medium memory model** (far code, near data),
**`/Od`** (no optimisation), **stack probes** (`_aFchkstk`), `/GA` window callbacks.

- The NE header is TIRO's: flags 0x302, heap 512, stack 4096, 19 segments in the same order with
  the same flags. 18 of the 19 have the same role; 13 of them have **the same size to the byte**.
- Segment `1000` (the 32-bit blitters) and `1010` (DIB load/remap) are **byte-identical** to
  TIRO's. Every other engine segment differs only in DGROUP immediates (the data moved), so
  the functions sit at the **same offsets** (table in §1).
- `this` and data pointers are near (2 bytes, DS = SS = DGROUP); `this` is at `[BP+6]`. The vptr
  is a near DGROUP pointer and **vtable slots are 4-byte far code pointers** (NE-relocated). A
  virtual call is `MOV BX,[SI]; CALL dword ptr [BX+slot]`.
- Every function starts `PUSH BP; MOV BP,SP; MOV AX,frame; CALLF 1080:00e4` (`_aFchkstk`, 449
  callers), no `ENTER`, an unreachable `JMP` before each epilogue, long `0F 8x` jumps.
- Returns: `RETF n` 528×, `RETF` 114× (TIRO 531/102). The game code is far pascal
  (`__stdcall16far`, params reversed); the CRT helpers and game helpers with no `this` are
  far cdecl.
- The entry table is empty (nothing exported), as in TIRO.

**Consequence for phases 2–3:** names, prototypes, plates, vtable structs and class layouts
transfer **from TIRO** (already fully mapped) by address, not by fuzzy matching. ENCAIXE and
NOITE are needed only for what TIRO lacks (five new CRT routines, §4).

What differs from TIRO:
- `1068`, the game module: 0x49b6 bytes (TIRO 0x2fcc). It reuses TIRO's skeleton (scene create,
  music/waves, a player, a target class, a projectile class, a handler, score helpers) with new
  bodies; byte ratio against TIRO 0.37.
- `1088` (ctors/dtors/defaults + the adjustor-thunk blocks) is 0x6a32 (TIRO 0x622c): **462
  adjustor thunks** (TIRO 368), a frame vector-deleting dtor at `0000`, and the game classes'
  ctors.
- `1080` CRT is 0x1d73 (TIRO 0x1861): five more CRT routines, the `time`/`_tzset` family
  (`"PST"`/`"PDT"` in DGROUP; `srand(time(NULL))` in the target creator).
- `1028` (SceneObject/Mover/Animation) is **0x2a bytes shorter**: five engine functions differ
  in length (`scene_object_restore_background` +4, `mover_move_tick` −6,
  `scene_object_redraw_overlapping` −6, `animation_stop_and_redraw_dc` −6, `animation_tick`
  −28). TIRO's engine had local changes (the crossbow/target ticks); SERIAL is the plainer
  version. To check per function in phase 2.
- `1078` WaveMix is +9 bytes (`wave_play`), the same +9 that TIRO's QUALITY.md notes for LIXO.EXE,
  TIRO's earlier build. SERIAL's wave module is the older one.
- `1048` (the Game subclass) has the same size and the same six functions; only the immediates
  and one call differ.
- `GETTICKCOUNT` is not imported (93 imports, TIRO 94).

## 1. Segments

| Ghidra | NE | Size | vs TIRO | Holds |
|---|---|---|---|---|
| `1000` Code1 | 1 | 0x1a5 | identical | 32-bit `transrle.cpp` blitters (NE flag 0x2000): `0024` `dib_rows_copy_transparent32`, `0114` `dib_rows_copy32`. Ghidra decodes them as 16-bit garbage; don't type them |
| `1008` | 2 | 0x988 | same size, 13 one-byte diffs | DIB copy / transparent copy |
| `1010` | 3 | 0x1044 | **identical** | DIB load, palette, remap |
| `1018` | 4 | 0x21c8 | same size, ratio 0.975 | Object3D / Moveable / Portable / Player / Exit |
| `1020` | 5 | 0x297 | same size | Perspective backdrop, layers |
| `1028` | 6 | 0x1d29 | −0x2a | SceneObject / Mover / Animation / Player2D / object list |
| `1030` | 7 | 0x91d | same size | Occupancy grid, Backdrop (WinG) |
| `1038` | 8 | 0x5c7 | same size | App shell: APPABOUT `0000`, `app_init` `0055`, WinMain `0202`, APPWNDPROC `0335`, … |
| `1040` | 9 | 0x10aa | same size | `game_handle_message` `0000` (3,691 bytes, **not a function**), `game_take_exit` |
| `1048` | 10 | 0x260 | same size | the Game subclass: ctor, createPlayer (`trabu.bmp`), panel, status bar (font "Serial") |
| `1050` | 11 | 0xb5 | same size | Conditions module |
| `1058` | 12 | 0x743 | same size | StatusBar, ControlPanel |
| `1060` | 13 | 0x139 | same size | Scene create / add object / add exit |
| `1068` | 14 | **0x49b6** | new bodies | **The SERIAL game**: grid, scene create (music, 3 waves), 15 targets, bullet, player aim, target and bullet classes, **handler `1529` (12.9 KB)**, score helpers `478c–49b5` |
| `1070` | 15 | 0x67a | same size | Two draw-list classes |
| `1078` | 16 | 0x4a2 | +9 | WaveMix wrappers |
| `1080` | 17 | 0x1d73 | +0x512 | CRT (`entry` `001a`) |
| `1088` | 18 | 0x6a32 | +0x806 | Adjustor thunks `005a–1b37` and `4ac8–557f`; defaults, getters, ctors, dtors, Game/Frame init; the game classes' ctors (panel `5580`, player `5752`, scene `5806`/`5840`, backdrop `5d50`, target `683c`, bullet `68de`/`6976`) |
| `1090` Data19 | 19 | 0x25fb file, 0x6578 alloc | | DGROUP; BSS 0x3f7d bytes |
| `1098`, `10a0` | — | 0x20 / 0x2f0 | same | Resources: group icon + icon (`AppIcon`), no dialogs |
| `10a8` EXTERNAL | — | 0x174 | | 93 import thunks |

## 2. Entry and startup

Identical to TIRO (same offsets):
- `entry` `1080:001a` → `_cinit`, `_setargv`, `_setenvp`, WinMain `1038:0202`.
- WinMain: "O aplicativo já está aberto !!!" on a second instance;
  `GetProcAddress(GetModuleHandle("USER"), 11/182)` → SetSystemTimer / KillSystemTimer (far
  pointers in the BSS).
- `app_init` `1038:0055`: RegisterClass + CreateWindow **"Serial Killer"** (`1090:00aa`, the class,
  the title and NOITE's `FindWindow` target; the NE description is the same string).
- APPWNDPROC `1038:0335` is a function but unnamed and unreferenced (RegisterClass takes it
  as an immediate). APPABOUT `1038:0000` is not a function.
- `game_handle_message` `1040:0000` is vtable slot 0 of the Game tables; not a function.

## 3. Function boundaries

Raw counts: **700 functions**: 514 code functions + 93 import thunks + 93 externals. Only `entry`
and the imports are named. Conventions guessed: 410 `__stdcall16far`, 81 `__cdecl16far`, 10 near
(CRT), 13 unknown besides the 93 thunks.

Ghidra's function-start search found most bodies that have prologues, as for TIRO, but no vtable
is typed, so **no vtable slot makes a reference**.

Uncovered code: **20,301 bytes** in 182 ranges (TIRO 18 KB / 169):

| Seg | Ranges | Bytes | What |
|---|---|---|---|
| `1088` | 75 | 13,819 | the two thunk blocks, defaults/getters/ctors reached only through vtables |
| `1040` | 1 | 3,691 | `game_handle_message` |
| `1080` | 44 | 2,275 | `_output` body `0a1c–0e99`, the new CRT routines, `INC BP` far prologues, frameless entries |
| `1068` | 23 | 216 | `0000–008c` (the grid-backdrop create, a GridBackdrop slot) and 22 dead `JMP`s |
| `1038` | 3 | 91 | APPABOUT |
| `1020` | 1 | 63 | `1020:0000` |
| `1058` | 3 | 53 | `1058:0000` |
| others | 32 | 93 | dead `JMP`s (3 bytes each) and pads |

What is missing, measured with the dry runs of the far-model scripts:
- **Vtables:** `FarVtSlots.java 1090 0000 25fa dry` finds **1,666 far slots, 561 distinct targets,
  420 of them not functions**, 54 tables and 69 vptr stores (TIRO: 1,665 / 560 / 420 / 70). The
  tables are in `0626–233e` (TIRO `05d2–22a4`, shifted by the data).
- **Adjustor thunks: 462** (75 fixed + 387 vtordisp) in two blocks, `1088:005a–1b37` (335) and
  `4ac8–557f` (127). TIRO had 241 + 127. The fixed immediates are TIRO's (−0x484, −0x486, …). Same
  far shapes (`SS:[BX+4]`).
- **`1088:0000–0059`** is a vector-deleting dtor for Frame (`crt_array_destruct` over 0x16-byte
  elements, then `frame_dtor` `1088:1b38`), a vtable target that TIRO does not have.
- **Dead jumps:** the `/Od` epilogue `JMP`s (22 in `1068` alone); `DeadJumps.java` folds them.
- **CRT:** the TIRO set (frameless entries, `INC BP` prologues one byte early, `_output`'s near
  helpers, `FATALEXIT` no-return) plus the five new routines.
- **Jump tables:** two. `_output` (CRT, as in TIRO) and **one in the handler**:
  `1068:22a6 JMP CS:[BX+0x22ab]`, 6 words (a `switch (rand() % 6)` that picks a target index
  7–12). Ghidra already recovered this one (the table is data, the cases are in the body).

Bad splits: none seen. The handler `1068:1529` is one function of 12,899 bytes in 18 ranges
(the gaps are dead `JMP`s and the jump table). No data decoded as code.

Estimate after phase 2: ~520 + 420 slot targets + 462 thunks + the gap-sweep finds ≈ **1,100 code
functions**, of which ~1,000 have a TIRO twin at a known address.

## 4. Matching against TIRO

`fmap.py` aligns each TIRO segment with SERIAL's (`difflib`, byte level) and maps every TIRO
function entry and end. A function maps when its entry falls in an aligned block, its length is
unchanged and ≥ 70 % of its bytes are equal:

| Seg | TIRO fns | Map cleanly | Notes |
|---|---|---|---|
| `1000–1020`, `1030–1060`, `1070` | 141 | 141 | same offsets |
| `1028` | 49 | 44 | 5 differ in length (§0) |
| `1078` | 11 | 10 | `wave_play` +9 |
| `1080` | 81 | 78 | all mapped; 3 short ones below 0.7 (`crt_error_r6020`, `_fptrap`, `crt_endstdio`: equal shape, moved DGROUP words). Offsets shift after each of the 5 inserted routines |
| `1088` non-thunk | 316 | 315 | `target_ctor` differs (a different class) |
| `1088` thunks | 368 | — | remake with `NearAdjustorThunks` (immediates differ) |
| `1068` | 30 | 9 by shape | game code; map by role only |

The new CRT code (SERIAL offsets): `020c–029d` (146 bytes, before `_stricmp`), `0f9e–1099` (252,
after `_nmsize`), `1400–15eb` (492, after `crt_write_raw`), `1786–188f` (266, after
`crt_heap_find_end`), `19dc–1a69` (142, after `flsall`). `1080:020c` is called with 0 and its
result goes to `srand`: it is `time`. The rest are NOITE's `__loctotime_t`, `_tzset`/`__tzset`,
`_isindst` family (NOITE `1008:241c`, `2e6e–30ab`); confirm by opcode match in phase 2.

## 5. Imports

93 imports from WAVEMIX, KERNEL, GDI, USER, WING (4 ordinals) and MMSYSTEM (`mciSendString`),
TIRO's list without `GETTICKCOUNT`. All were **untyped** (`undefined X(void)`), so every API call
site leaked the far return address as fake arguments (`MESSAGEBOX(0x30,…,0x1090,…)` and
`local_x = 0x1080` stores). Two USER functions are reached dynamically (SetSystemTimer USER.11,
KillSystemTimer USER.182) through far pointers in the BSS.

All 93 have a typed twin in TIRO (`CopyTypesFromProgram.java /TIRO.EXE` matches them by library
and name; the WinG ordinals take TIRO's names). The type manager was empty (5 types).

## 6. Decompiler output quality (raw)

Sampled: the handler `1068:1529`, the creators `013f`/`03d5`, `0c42`, `47b2`, `48bc`.

| Issue | State |
|---|---|
| Stack probe | `_aFchkstk` lowers SP by the frame; untreated, outgoing pushes alias the locals. Fixed (§8) |
| Signatures | Parameter counts from `[BP+n]` are right; types are `int`/`undefined2`; `this` is `param_1` |
| API calls | Junk arguments until the imports are typed. Fixed (§8) |
| Virtual calls | `puVar1 = *(vbase(p)+2) + 0xd4; (*(code *)*puVar1)(junk, …)`: the far slot is read as two words, so no prototype applies; needs the vtable structs and `FarSlotSignatures.java` (phase 3) |
| Globals | Object pointers in the BSS: `DAT_1090_6536` (the player), `DAT_1090_6538…6554` (15 targets), `6556` (the bullet) |
| Constant pointers | Near constants print as DGROUP string symbols (`s_todo_CreateNewScene_1090_107f + 1` is a junk segment push) |
| Switches | `/Od` compare chains, plus one real jump table (§3) |
| Overall | Control flow is good; once typed, the `/Od` bodies read literally |

## 7. The data segment (`1090`)

0x25fb bytes initialised, 0x6578 allocated. Ghidra defined 219 items (63 strings), no globals named.

| Range | Contents |
|---|---|
| `0000–000f` | instance header |
| `0010–00a9` | `"(%03d,%03d)=>(%03d,%03d,%03d)"`, HDC/layer overflow errors |
| `00aa` | `"Serial Killer"` (class, title, NOITE's `FindWindow`) |
| `00b8` | g_noiteWnd (the 0x40a target) — **2 bytes lower than TIRO's `00ba`** (the title is 2 bytes shorter) |
| `00ba–00ff` | `AppIcon`, already-open message, `USER` ×2, the engine handler's latches |
| `0100` | `trabu.bmp` (the player's gun), its strip table |
| `0112–01b5` | **15 target bitmaps** `3sarab`, `3sbaba`, `3sbabt`, `3sclu`, `3sfada`, `3shitl`, `3slenn`, `3smafi`, `3snoel`, `3snoem`, `3svelh`, `3sesco`, `3spira`, `3skenn`, `3scoel` |
| `01b6–024b` | the target strip tables: names `01b6`, a **kind** per target `01d4`, frames `01f2`, widths `0210`, heights `022e` (15 each) |
| `024c–027b` | `bala.bmp` (the bullet) and its table; per-class parameter words (`025e–0276`: 200, 200, 200, 100, 5000, 5000, 10000, 10000) |
| `027c–02a5` | `panel.bmp` ×2, the font face `"Serial"`, `arialbd.fot` |
| **`02a6`** | **a word = 5: the lives** (decremented at `1068:0e9e`, reported to NOITE) |
| `02a8–0307` | MCI `open doom2.mid … alias musica`, waves `tiros1.WAV`, `morte2.wav`, `PRACAS01.WAV` |
| `030a–0313` | key latches (RIGHT `030a`, LEFT `030c`, SPACE `0312`) |
| `0314–04a9` | MCI / WaveMix messages, `"-%04d"`/`" %04d"`, overflow strings |
| `04aa–0625` | CRT data, `"PST"`/`"PDT"` (time zone) |
| `0626–233f` | **vtables and vbtables** (54 tables), with the Game strings and `Fundo.bmp` (`1094`) inside, as in TIRO |
| `2340–25fa` | `<<NMSG>>`, the R6xxx table |
| `25fb–6577` | BSS: the occupancy matrix (TIRO's sizes), the timer pointers, `g_game`, the player `6536`, the 15 targets `6538–6554`, the bullet `6556`, 3 far wave handles `6560–656b`, the score words |

Strings: the Latin-1 scan finds ~90 (as TIRO); Ghidra cut the accented ones (`número`, `já`,
`Não`, `método`, `possível`) and missed the short ones. `DefineStrings.java` in phase 3.

## 8. Program-wide fixes applied in phase 1

Stored in the program (saved):
1. **Spec extensions** installed from `ghidra/cspec/`: `__cdecl16far_dx_ax`, `__cdecl16far_dxax_ptr`
   and the call-fixup **`aFchkstk`** (`aFchkstk_fixup.xml`).
2. `1080:00e4` renamed **`_aFchkstk`** and given the call-fixup. The decompiler now prints
   "_aFchkstk replaced with injection" and allocates each frame.
3. **`CopyTypesFromProgram.java /TIRO.EXE`**: the 17 SDK structs (RECT … WAVEMIXINFO) and all **93
   import signatures** typed; the 4 WinG ordinals renamed (`WinGCreateDC`, `WinGRecommendDIBFormat`,
   `WinGCreateBitmap`, `WinGBitBlt`). No API is left untyped, so no SDK typing by hand.

## 9. What the game is (first look)

*Serial Killer*: a keyboard shooting gallery on TIRO's skeleton, launched by NOITE's
`handler_3farmcai` (the prison-escape cutscene, `serial\serial.exe`).
- **Player:** `trabu.bmp` (238×315, a *trabuco*, blunderbuss), aimed LEFT/RIGHT (`0x25`/`0x27`)
  in three directions (the bullet starts at x+0x2a / +0x61 / +0xa2), fired with SPACE.
  `ARMA.BMP`, the same size, is on the disc but not referenced.
- **Bullet:** `bala.bmp`, 47×93, 3 frames of 47×31.
- **15 targets**, one per bitmap, all built at start (`1068:013f`; 13 of one parameter set, 2
  of another), each with a *kind* from the table at `01d4`. Vertical strips of N frames:
  `3sarab` 6×80×177 … `3skenn` 2×200×67 (Kennedy in a car), `3scoel` 6×188×60 (a rabbit).
- **5 lives** (`02a6`); hitting the wrong kind costs one (to confirm).
- Waves: `tiros1.WAV` (shot), `morte2.wav` (death), `PRACAS01.WAV`. Music: `doom2.mid`
  (MCI alias `musica`, replayed on MM_MCINOTIFY). `CARREGA*.WAV`, `LPVITOR.WAV`, `METRAL.WAV`,
  `TIROS.WAV` and `VELHA.MID` are on the disc but not referenced by the EXE.

**The 0x40a result** (`1068:15ad`): `PostMessage(g_noiteWnd, 0x40a, hwnd, MAKELONG(lives,
lives > 0 ? 500 : <BSS word 63c4>))`. The wParam pushed is the handler's own `hwnd` argument,
which is never 0. **Candidate original bug:** NOITE reads `wParam != 0` as a win, so SERIAL
would always report a win, and NOITE adds the whole 32-bit lParam (≈ 500·65536 + lives) to the
score. To confirm with the typed decompile in phase 3.

## 10. Plan

### Phase 2 (functions)

1. Vtable slots: `FarVtSlots.java 1090 0626 2340` (420 new functions, slot typing, 69 store refs).
2. Thunks: `NearAdjustorThunks.java 1088 0000 1b38 far` and `1088 4ac8 5580 far` (462).
3. `CodeGapSweep.java` per code segment (`create`), then `DeadJumps.java`.
4. CRT by hand: TIRO's fixes at the mapped offsets (`INC BP` entries, frameless entries, `_output`
   helpers and jump table, `FATALEXIT` no-return), the 5 new routines against NOITE.
5. **Transfer from TIRO** (new `SerialFromTiro.java`): for every function `fmap.py` maps cleanly,
   copy the name, the prototype (types resolved into SERIAL's `/serial` category), the plate (with
   "Name from TIRO … at …") and the tags. Then rerun `NearAdjustorThunks` to rename the thunks,
   map the `1088` slot targets that fail the byte match by vtable slot (TIRO table ↔ SERIAL table),
   and read the five `1028` length changes and `wave_play`.
6. Game code (`1068`, game ctors in `1088`, `1048`): TIRO names by role where the role is the
   same (scene create, create targets, create bullet, aim, hit, score helpers), `FUN_` otherwise,
   grouped for phase 4.

### Phase 3 (data)

Strings (`DefineStrings.java`), the `/tiro` engine structs copied into `/serial` and checked
(near layouts), the 54 tables with `FarVtables.java`, `FarSlotSignatures.java` for the virtual
calls, globals with `NearGlobals.java`, `NearThisTypes.java`, `NearNullTests.java`; the game
classes from their ctors.

### Scripts that apply as they are

`FarVtSlots`, `NearAdjustorThunks` (`far`), `CodeGapSweep`, `DeadJumps`, `CopyTypesFromProgram`,
`FarVtables`, `FarSlotSignatures`, `NearStructs`, `NearGlobals`, `NearThisTypes`, `NearNullTests`,
`DefineStrings`, `RenameFunctions`, `NoiteStructs`/`NoiteFieldSet`, `UndefinedRanges`; the three
cspecs. New: a TIRO→SERIAL transfer script (names, prototypes, plates by mapped address).
