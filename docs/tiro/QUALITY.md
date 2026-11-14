# TIRO.EXE: decompilation quality (phase 1)

This is a read-only assessment of the Ghidra program `/TIRO.EXE` in its current state:
auto-analysis only, nothing named or typed by hand. Addresses are Ghidra `seg:off`. The
scratch matchers are in `zig-out/tiro/` and are not committed: `segs.py`, `ops.py`,
`fuzzy.py` (normalised opcodes), `feat.py` (field offsets, immediates, API calls, slots),
`align.py` (in-order alignment per segment), `thunks.py`, `TiroSurvey.java`, `TiroDump.java`,
`ExportRawOps.java`.

## 0. Headline: TIRO is a medium-model, unoptimised build

ENCAIXE is small model. TIRO runs the same engine sources ("Faltou redefinir o método
CreatePlayer/…", `MAX_OBJECT_QTY`, the occupancy matrix), but it is built in the **medium
memory model** (far code, near data), **without optimisation (`/Od`)** and **with stack
probes**:

- One code segment per module: 17 code segments plus the 32-bit blitter. Calls are **far**
  (`CALLF` about 1,600 sites, near `CALL` only inside the CRT). Returns are `RETF n` 492×,
  `RETF` 81×. `this` is at **`[BP+6]`**.
- Data pointers are **near** (2 bytes, DS = SS = DGROUP), as in ENCAIXE. The vptr is a near
  pointer to DGROUP, but the **vtable slots are 4-byte far code pointers** (`seg:off`, NE-relocated).
  A virtual call is `MOV BX,[SI]; CALL dword ptr [BX+slot]`, and slot offsets are twice ENCAIXE's.
- Every function starts `PUSH BP; MOV BP,SP; MOV AX,<frame>; CALLF 1080:00e4` (`_aFchkstk`,
  448 callers). Other `/Od` signs: no `ENTER` (only 2), a `JMP` to the epilogue before each
  `RET`, and long-form `0F 8x` jumps everywhere. There is no `PUSH DS; MOV DS` prologue. The two
  window callbacks use the `/GA` prologue `MOV AX,SS; PUSH BP; MOV BP,SP; PUSH DS; MOV DS,AX`.
- The CRT is the medium-model Windows library: far `_aFchkstk`, far string functions over near
  data, and `_nmalloc` over `LocalAlloc`.
- The entry table is **empty**: TIRO exports nothing, so Ghidra named only `entry`.

What this means for the phases:
- **Struct layouts transfer from ENCAIXE byte for byte** (both use near data). Example:
  `object3d_draw_bounds` reads the same `[SI-0xe]…[SI-0x14]`. The exceptions are vtable
  structs (4-byte slots, not 2) and anything that holds a code pointer. The adjustor thunks
  subtract both 0x484 (ENCAIXE's value) and 0x486, so at least one class grew by 2 bytes.
- Names and slot meanings transfer from ENCAIXE (and NOITE). The code does **not** match
  byte for byte, because of `/Od`; see §4.
- Game code is **far pascal**: `__stdcall16far`, parameters reversed, `RETF n` = total
  argument bytes, first parameter (`this`) at `[BP+6]`. NOITE's skills
  (`ghidra-fix-signature`) apply as written, except that `this` and data pointers are 2 bytes.

`LIXO.EXE` ("trash", in the same folder, Dec 1995) is an earlier build of TIRO. It has the
same 19 segments and sizes, except that the wave module is +9 bytes and DGROUP −4. NOITE
starts `tiro\tiro.exe`, so LIXO is out of scope.

## 1. Segments

| Ghidra | NE | Size | Holds |
|---|---|---|---|
| `1000` Code1 | 1 | 0x1a4 | The 32-bit `transrle.cpp` blitters (NE flag 0x2000). **Byte-identical to NOITE's and ENCAIXE's `1000`**. Two functions, `0024` = `dib_rows_copy_transparent32` and `0114` = `dib_rows_copy32`; copy the names and don't type them. |
| `1008` | 2 | 0x988 | DIB copy and transparent copy (`IntersectRect`; ENCAIXE `1bde–1f63`) |
| `1010` | 3 | 0x1044 | DIB load, palette, remap, `hmemmove_backward`. This is a **newer DIB module** with extra `FindResource`/`AccessResource`/`GetObject`/`GetPaletteEntries`/`GetNearestPaletteIndex` code (`05de`, `0783`, `0c90`) |
| `1018` | 4 | 0x21c7 | Object3D / Moveable / Portable / Player / Exit (ENCAIXE `254a–3fda`, in the same order) |
| `1020` | 5 | 0x296 | Perspective backdrop, layers ("Estouro no número de Layers") |
| `1028` | 6 | 0x1d53 | SceneObject / Mover draw and movement, Animation, Player2D, object list (ENCAIXE `6c18–8014`) |
| `1030` | 7 | 0x91c | Occupancy grid, Backdrop (`WinGCreateDC`/`CreateBitmap`/`RecommendDIBFormat`) |
| `1038` | 8 | 0x5c7 | App shell: `APPABOUT` `0000`, `app_init` `0055`, `app_exit` `016e`, `app_message_loop` `019f`, `WinMain` `0202`, `app_paint` `030c`, `APPWNDPROC` `0335`, `message_box_printf` `0591` |
| `1040` | 9 | 0x10a9 | Game base: **`game_handle_message` `0000` (3,691 bytes, not a function)**, `game_take_exit` `0e6b` |
| `1048` | 10 | 0x25f | TIRO's Game subclass: ctor `0000`, create player `0029` (16 arrows), control panel `0110`/`016e` (`panel.bmp`), status bar `021a` (font "Mech") |
| `1050` | 11 | 0xb4 | SceneObject draw helpers (ENCAIXE `53c8–543e`) |
| `1058` | 12 | 0x742 | StatusBar and ControlPanel (ENCAIXE `b116–b55a`; text with `arialbd.fot`) |
| `1060` | 13 | 0x138 | Scene create, add object, add exit (ENCAIXE `b5b0–b6ba`) |
| `1068` | 14 | 0x2fcc | **The TIRO game**: music and waves, crossbow, targets, arrow, hits, score, handler `1790` |
| `1070` | 15 | 0x679 | Two draw-list classes (ENCAIXE `f842–f9d4`, twice) |
| `1078` | 16 | 0x498 | WaveMix wrappers (ENCAIXE `fa60–fca8`) |
| `1080` | 17 | 0x1860 | CRT. `entry` is at `001a`; `0000–0011` is the segment prefix |
| `1088` | 18 | 0x622b | **Both adjustor-thunk blocks** (`0000–1331`, `42c2–4d7d`), and also the SceneObjectVtbl defaults and getters, ctors and dtors, and Game/Frame init (ENCAIXE `51f6–6c00` and `8caa–b6ba`). Its order does not follow ENCAIXE. |
| `1090` Data19 | 19 | 0x255d file, 0x64ca alloc | DGROUP. Heap 512, stack 4096 |
| `1098`, `10a0` | — | 32 / 752 | Resources: one group icon and one icon (`AppIcon`). There are no dialogs, although APPABOUT exists |
| `10a8` EXTERNAL | — | 0x178 | 94 import thunks |

Ghidra misreads:
- Segment `1000`, as described above.
- About **18 KB of code** (23 % of the 80.9 KB in `1008–1088`) in 169 uncovered ranges. 63 of the
  ranges are 16 bytes or more, and they sit mostly in `1088` (12.0 KB), `1040` (3.7 KB) and `1080`
  (2.3 KB). See §3.

## 2. Entry and startup

| What | Where | Notes |
|---|---|---|
| `entry` | `1080:001a` | `INITTASK`, `_cinit` (`03f2`), `_setargv` (`05d0`), `_setenvp` (`0752`), then WinMain. It matches ENCAIXE `entry` at 0.88 and NOITE at 0.86 |
| WinMain | `1038:0202` | `hPrevInstance` gives "O aplicativo já está aberto !!!". It calls `GetProcAddress(GetModuleHandle("USER"), 11/182)` and stores the results in `1090:6312`/`6316` (SetSystemTimer/KillSystemTimer, far) |
| app_init | `1038:0055` | RegisterClass and CreateWindow "Tiro ao Alvaro" (`1090:00aa`). The game is created by `1088:4ef6`, the base ctor, which sets `g_game` `1090:6494`; the derived ctor `1048:0000` sets `6496` |
| APPWNDPROC | `1038:0335` | Same as ENCAIXE (§9). It is a function in Ghidra, but it is **unnamed** and has no references (RegisterClass gets it as an immediate) |
| APPABOUT | `1038:0000` | WM_INITDIALOG/WM_COMMAND → EndDialog, `RETF 0xa`. It is **not a function** |
| game_handle_message | `1040:0000` | Vtable slot 0 of the Game tables. It is **not a function** (3,691 bytes) |

## 3. Function boundaries

These are the counts now:
- 691 functions in total: **503 code functions** plus 94 import thunks plus 94 externals.
- Named: `entry` and the 94 imports. The calling conventions Ghidra guessed are 408
  `__stdcall16far`, 72 `__cdecl16far`, 10 near (CRT) and 13 unknown.

Ghidra did much better than on ENCAIXE. Its function-start search found 254 functions that have
**no reference at all**. But the vtables are never typed, so **no vtable slot creates a
reference**, even though all 1,665 far pointers in DGROUP carry NE relocations.

What is still missing:
- **Vtables:** `1090:05d2–22a3` holds 1,663 far code slots in 16 runs, with 560 distinct
  targets. **420 of the targets are not functions.** Of these, 509 targets are in `1088`.
- **368 adjustor thunks are missing**, in two blocks in `1088`:

  | Block | Thunks | Fixed | vtordisp | NOITE/ENCAIXE counterpart |
  |---|---|---|---|---|
  | `0000–1331` | 241 | 37 | 204 | ENCAIXE `402e–51f5` (244) |
  | `42c2–4d6a` | 127 | 20 | 107 | ENCAIXE `a13e–a496` (42) |

  The shapes are the far forms of ENCAIXE's: `MOV BX,SP; SUB SS:[BX+4],imm; JMPF` and
  `MOV BX,SP; MOV BX,SS:[BX+4]; MOV AX,[BX-2]; [ADD AX,k]; MOV BX,SP; SUB SS:[BX+4],AX; JMPF`.
  Every slot is `[BX+4]`, not `[BX+2]`, because the return address is far.
  - The `SUB` immediates of the fixed thunks: −0x484 (17), −0x486 (14), and 6/8/10/16.
  - The thunks jump to `1088` (230), `1028` (63), `1018` (60), `1068` (12) and `1058` (3). 24 of
    the 137 distinct targets are not functions.
- **52 vtable targets that are not thunks**, among them `1040:0000`, `1058:0000`, `1068:0000`,
  `1080:02ae`, `1080:12d0`, and 47 in `1088` (default stubs, getters, ctors).
- **About 52 prologue hits** in the gaps beyond these: `1020:0000`, `1038:0000` (APPABOUT), 10
  CRT entries in `1080`, and about 38 in `1088`.
- CRT fragments that have no prologue: `_output` (`1080:098a–0e07`, 1,150 bytes), `1080:12fa`,
  `1557`, `175d` and `1802`.
- **Estimate after phase 2: about 975 code functions**: about 607 non-thunk functions
  (`zig-out/tiro/est_starts.json`) and 368 thunks.

Bad splits and merges:
- None seen. Some bodies stop short where the next bytes are uncovered.
- No data was decoded as code, and no code was typed as data. The gaps are undefined bytes,
  never instructions.

Large functions:
- `1068:1790` (5,583 bytes) is the TIRO scene handler.
- `1040:0000` (3,691 bytes, missing) is the engine handler.
- `1068:0991` (1,179 bytes) respawns a target.
- `1018:0290` (914 bytes) is `object3d_draw_bounds`.
- `1030:0691` (652 bytes) is backdrop autoscroll.

## 4. The C runtime and shared code: fuzzy matching

The CRT is in `1080`: 53 functions plus about 12 missing entries. Its link order matches
ENCAIXE's `1008:0018–1bdd`.

| Method | Yield (500 TIRO functions) |
|---|---|
| Normalised opcodes (`fuzzy.py`, chkstk pair and `JMP`s dropped), vs ENCAIXE | 68 at ≥0.75, 22 at ≥0.9, 284 at ≥0.6. At ≥0.75: CRT 40, `1088` stubs 23, others 5 |
| Same, vs NOITE | 49 at ≥0.75. Nearly all are CRT (48) |
| Feature sequence (`feat.py`: field displacements, immediates, API names, slot/2) | Strong on engine bodies: `object3d_draw_bounds` 0.97, `portable_is_below` 0.91, `draw_list_invalidate_nodes` 0.94, `object3d_is_in_front_of` 0.86 |
| **In-order alignment per segment** (`align.py`, the max of the two ratios, Smith-Waterman) | The module segments align to contiguous ENCAIXE ranges in the same order. `1018` aligns 51/51 to `254a–3fda` (44 at ≥0.4). `1028` aligns 44/49 to `6c18–8014`. `1038` 9/9 to `8886–8c88`. `1058` 14/14. `1078` 11/11. `1060` 4/4. `1050` 4/4 |

Expected yield, before confirming each with `diff_functions` or by reading:
- **CRT:** about 50 of 65 named: 40 by ENCAIXE at ≥0.75, plus NOITE's `crt_call_winmain` (`03c6`),
  `exit`/`_exit` (`04d1`/`04df`), `_FF_MSGBANNER` (`05ac`), `_stackavail` (`12e6`) and `_dos_commit`
  (`17de`), all at ≥0.94. `0118`/`0128` are `operator_new`/`operator_delete` (they are
  identical 7-instruction stubs, so check which is which). `024e` is `abs` by use (NOITE's
  `_toupper` at 0.83 is a false match). The rest are `_output`, the missing entries and
  `_nmalloc`/`_nfree`, which need reading. The names are ENCAIXE's near-data ones: `strcpy`,
  `_stricmp`, `_aNldiv`, `_aNlmul`. The chkstk is far, `_aFchkstk`.
- **Engine module segments** (`1008–1078`, without `1048` and `1068`; about 190 functions):
  about 150 map 1:1 to ENCAIXE by module order, about 130 of them with a pair score ≥0.4. Use
  the score with the order, not alone: `/Od` caps most ratios at 0.5–0.8.
- **`1088`** (about 316 starts): most are the SceneObjectVtbl defaults, getters, ctors and dtors.
  Their bodies are 2–10 instructions, so code similarity cannot tell them apart. **Name them by
  vtable slot**: slot *i* of a TIRO table maps to slot *i* of the ENCAIXE table for the same class.
- **Shared with NOITE beyond the CRT:** the blitters, and through ENCAIXE the DIB, app shell and
  wave modules.

**Same code as ENCAIXE** (names and types can be copied mechanically, after a per-function
check):
- the blitters;
- DIB copy (`1008`) and DIB load/remap (`1010:0000/0105/02e0/0a06/0a68/0ae7/0c05`);
- Object3D…Portable (`1018`, all but `0839`, `0d43`, `10cc`, `1ad3`, `1cea`, `1dec`);
- perspective backdrop (`1020:003f–00c4`);
- SceneObject/Mover/Animation/Player2D/object list (`1028`, all but `02ba`, `02d3`, `063d`, `0e71`);
- occupancy grid and backdrop (`1030:0000/00e4/0200/033c`);
- the app shell (`1038`);
- `game_take_exit` and `game_handle_message` (`1040`);
- the `1050` helpers;
- StatusBar and ControlPanel (`1058`, all but `007d`, `0291`, `02ae`);
- Scene (`1060`);
- the draw lists (`1070`);
- WaveMix (`1078`);
- the CRT (`1080`);
- the `1088` defaults and getters (by slot).

**TIRO-specific** (to read):
- all of `1068` (30) and `1048` (6);
- the TIRO classes' ctors and overrides in `1088`, e.g. `4d7e`, `50ea`, `587c`, `5a08`, `5c3e`,
  `5cf2` and `603a–6170`, which match ENCAIXE's `te_*`/`player2d_ctor` only by shape;
- the extra DIB functions `1010:05de`, `0783` and `0c90`;
- `1018:1ad3/1cea/1dec` and `1028:063d`.

That is about **70–90 functions**.

## 5. Imports

There are 94 imports from 6 modules (WAVEMIX, KERNEL, GDI, USER, WING, MMSYSTEM), in the same
order as NOITE and ENCAIXE. All are **untyped**. Seven are
unreferenced (`LOCALREALLOC`, `LOCALSIZE`, `GLOBALSIZE`, `__AHSHIFT`, `__AHINCR`, `__WINFLAGS`,
`ENDDIALOG`); the last is called from the missing APPABOUT.

What can be copied:
- **83 of 94 are in NOITE**, typed, including the 4 WinG ordinals `1001`/`1002`/`1003`/`1010`, which
  NOITE has renamed.
- Of the 11 others, `ADDFONTRESOURCE`, `LOCALALLOC`, `LOCALFREE`, `LOCALREALLOC`, `LOCALSIZE` and
  `UNLOCKSEGMENT` are typed in ENCAIXE.
- **5 are new**: `GETNEARESTPALETTEINDEX`, `GETOBJECT`, `GETPALETTEENTRIES`, `GETTICKCOUNT` and `HMEMCPY`.
- `BITBLT` (in ENCAIXE) is not imported.
- Two USER functions are reached dynamically: `SetSystemTimer` (USER.11) and `KillSystemTimer`
  (USER.182) through `1090:6312`/`6316`.

How to copy them:
- `CopyTypesFromProgram.java` from `/NOITE.EXE`: the 17 SDK structs and 83 signatures.
- Then from `/ENCAIXE.EXE`: 6 signatures; the script keeps what is already typed.
- Then type the 5 new ones from the SDK as `__stdcall16far`.

Types: the data type manager is **empty** (1 category, 4 types). Its CCs are the 6 stock ones.
- **The `ghidra/cspec` far extensions apply as they are** (code is far):
  `__cdecl16far_dx_ax` for the long-math helpers, `atol` and `rand`, and
  `__cdecl16far_dxax_ptr`. Install both.
- **The engine structs can be copied from ENCAIXE's `/encaixe` category**, because the data
  layouts are the same. The vtable structs need far (4-byte) slots instead.

## 6. Decompiler output quality

I sampled `1068:1790` (the scene handler), `08ab`, `0991`, `2daf`, `2e1c`, `2e89`,
`1038:0335` (AppWndProc) and `1018:0290`.

| Issue | State |
|---|---|
| Signatures | Ghidra infers the parameter counts from `[BP+n]` well (no `in_stack_*` seen). The parameters are `int`/`undefined2`. `this` is `param_1`. |
| chkstk | Every body starts `FUN_1080_00e4();`. Its AX argument (the frame size) is invisible, which is harmless. |
| Junk at call sites | Every API call: `MCISENDSTRING(0x1080,param_6,0)`, `MESSAGEBOX(0x1078,0x30,0x300,0x1090)`, `POSTMESSAGE(0x10a8,…)`. The far return address of untyped calls leaks into fake locals: `local_8 = 0x1080; local_a = 0x17e3; FUN_1078_03a6();`. Typing the thunks fixes most of it. |
| Far pointers | Rare: only string arguments (`DS:off`), wave handles and the two timer pointers. `LES` appears 111× in `1010`, for DIB huge pointers. |
| C++ virtual calls | `puVar1 = *(vbase(p)+2) + 0xd4; (*(code *)*puVar1)(0x1068, vbase(p))`, where the vbase lookup is `p + *(int *)(*(int *)(p + 2) + 2) + 2`. The first argument is a junk segment. These become readable once the vtable structs exist. |
| Globals | Object pointers live in BSS (`DAT_1090_6498`…`64a2`). Indexed access to the target array prints as `((undefined2 *)&DAT_1090_649a)[i] + 0x4e`. |
| Strings in code segments | None: all strings are in DGROUP. |
| Overall | The control flow is good (switches, loops). `/Od` makes the bodies longer but very literal, which makes them easy to read once typed. |

## 7. The data segment (`1090`)

Size: 0x255d initialised and 0x64ca allocated; the BSS is 0x3f6d bytes.

Ghidra defines 186 data items: 73 strings and 113 `undefined1/2` placeholders. `list_globals` returns 0.

| Range | Contents |
|---|---|
| `0000–000f` | Windows instance header |
| `0010` | `"(%03d,%03d)=>(%03d,%03d,%03d)"` (a debug format used in `1018`, `1038`, `1068`) |
| `002e–00a9` | Engine errors: HDC and layer overflow |
| `00aa` | `"Tiro ao Alvaro"`: the class and title (NOITE's `FindWindow` target) and the NE description |
| `00ba` | g_noiteWnd (set by 0x40b) |
| `00bc–00ed` | `AppIcon`, the already-open message, `USER` ×2 |
| `00ee` / `00f0` | g_started / g_handshakePending (= 1) |
| `0102–0193` | Bitmap names. `0118` → {`besta.bmp`, `bestse.bmp`}. **`0194`** → the 10 target names `girla/b/c.bmp`, `travea…traveg.bmp`, followed by tables of 10 (9 frames, width 0x4b, height 0x5f) |
| `01e4–0210` | `Tiresq`/`Tirofr`/`Tirdir.bmp` (the arrow, flying left/straight/right), table at `0206` |
| `021e–0243` | `panel.bmp` ×2, `Mech` (font face), `arialbd.fot` |
| `0244–02b9` | MCI (`pac.mid`), waves `ARCFLE02.WAV`, `uii.wav`, `nossa.wav`, `tirojogo.wav`, `PASARS01.WAV` |
| `02ba`/`02bc`/`02c2` | right / left / space held flags |
| `02c6–035f` | MCI and WaveMix messages, the score formats `-%04d` / ` %04d` |
| `0360–04f5` | Overflow and WaveMix error strings, then CRT data from `04f6` (`_C_FILE_INFO=`) |
| `05d2–05ed` | 7 far pointers to `1080:0f18` (CRT hooks) |
| `0612–0691` | `MAX_OBJECT_QTY` overflow |
| **`0692–22a3`** | **Vtables and vbtables**: 1,656 far slots in 15 runs of 3 or more (plus 2 single slots), and about 73 distinct vptr-store immediates. Three runs are exactly **93 slots** (`13ce`, `154a`, `16c6`): the shared SceneObject interface, as in ENCAIXE. The Game strings ("Faltou redefinir…", `Fundtiro.bmp` at `0ff6`) sit inside this region, as in ENCAIXE |
| `23ee–255c` | `<<NMSG>>` and the R6xxx table |
| `255d–6311` | BSS, 0x3db5 bytes: **the occupancy matrix**, the same size as ENCAIXE's `14be–5271` (`char[65][81]` + `SceneObject*[65][81]`) |
| `6312–64ca` | `6312`/`6316` the timer far pointers, `6324` activate, **`6326` g_score**, `6494` g_game, `6496` g_tiroGame, **`6498` the crossbow** (player), **`649a–64a0` the 4 targets**, **`64a2` the arrow**, `64ac–64bf` 5 far wave handles |

Strings:
- A Latin-1 scan finds 86. Ghidra defines 56 exactly.
- 17 are **truncated** at `ã`/`é`/`í`/`á`: `002e`, `0055`, `0089`, `00c4`, `030e`, `033d`, `0360`, `03a1`, `049d`,
  `0622`, `0e3a`, `0e6c`, `0e96`, `0ec4`, `0f7e`, `0fa4` and `0fcc`.
- 12 are **missing**: `00e4`, `00e9`, `0132`, `013c`, `0232`, `028d`, `0354`, `035a`, `0447`, `0473`, `0f18` and `0f4a`.
- About 29 need `DefineStrings.java`.

## 8. What the game is

*Tiro ao Álvaro* (a pun on *tiro ao alvo*, target shooting) is a **crossbow shooting
gallery**, controlled from the **keyboard**. It is the hall door minigame (`handler_3fhall`).

The files, read from the current directory (`assets/TIRO/`):
- `Fundtiro.bmp`, 640×480 8-bpp: the background.
- `besta.bmp` and `bestse.bmp`, 285×381: the crossbow, loaded and unloaded.
- `girla–c.bmp` and `travea–g.bmp`, 75×855 = **9 frames of 75×95** each: the targets.
- `Tiresq`/`Tirdir.bmp` (55×54) and `Tirofr.bmp` (55×108): the arrow.
- `panel.bmp`, 21×30.
- `pac.mid` through MCI, looped on MM_MCINOTIFY 0x3b9.
- 5 waves through WaveMix: `ARCFLE02` (the shot), `uii`, `nossa`, `tirojogo`, and `PASARS01` (277 KB).
  WM_PAINT plays wave `64bc` every time; that `64bc` is PASARS01 is inferred from the order.
- `arialbd.fot`, which is not on the disc.

The score is drawn as `TextOut "%04d"` into a box blitted at (400,448) with WinGBitBlt.

Play, from `1068:1790` and its callees:
- **Aim.** LEFT and RIGHT (WM_KEYDOWN 0x25/0x27, latched by the flags `02bc`/`02ba`) call
  `1068:0476` and a crossbow slot (0xa4); that this turns the crossbow is inferred.
  The direction is `crossbow+0x1c`, 0/1/2.
- **Fire.** SPACE (0x20, latched by `02c2`) decrements the arrows (`crossbow+0x40`, starting at
  **16**, `1048:00e2`) and plays the shot. It launches the arrow from crossbow x+0x48/+0x75/+0xa2
  with direction 0/1/2.
- **The mouse is ignored.** WM_MOUSEMOVE and the button messages return 1.
- **Targets.** Four Animation-derived targets (`649a–64a0`) run on their own timers, through
  WM_SYSTIMER 0x118, whose id is in slot 0xd4:
  - two enter from the left (x=0x18, y=0x55);
  - two enter from the right edge (y=0x82);
  - they keep 0x58/0xb0 px apart;
  - each picks an identity `rand() % 10` on (re)spawn. That is the index into the 10 target
    bitmaps, so 0–2 are the girls and 3–9 the *travecos* (inferred from the order of the table).
- **Hit.** The arrow box (x, 0x37 wide) overlaps a target box (x, 0x4b wide); `1068:08ab` checks it.
  - identity < 3 gives **+150** (`2e1c`, wave `64b0`);
  - otherwise **−150** (`2daf`, wave `64b4`);
  - both also play `64b8` and redraw the score.
  - A target that leaves the screen respawns (`0991`).
- **End.** In the target ticks, `arrows == 1` makes the game `SendMessage(hwnd, WM_DESTROY)`.
  It is not yet checked whether this is the last arrow or one before it.
- **Pause.** WM_ACTIVATE (6) pauses or resumes the MIDI and WaveMix.

## 9. How it talks to NOITE

The protocol is the same as ENCAIXE's:
- NOITE runs `WinExec("tiro\tiro.exe")`, then `FindWindow("Tiro ao Alvaro")` on timer 0x14, then
  `PostMessage(tiro, 0x40b, 0, hwndNoite)`.
- `APPWNDPROC` stores `LOWORD(lParam)` in `1090:00ba`.
- Once started, it posts **0x40c** (`PostMessage(noite, 0x40c, hwnd, 0)`) one time, cleared by flag `00f0`.
- It forwards every message to `g_game->vtbl[0]` (`1090:6494`).
- WM_CREATE calls `vtbl[6]` and then SetSystemTimer(hwnd, 1, 50).

Result, on WM_DESTROY (msg 2) in `1068:1790`:
- it stops the waves and closes WaveMix and MCI;
- then it calls **`PostMessage(noite, 0x40a, g_score > 0, MAKELONG(g_score, g_score >> 15))`**.

So **TIRO wins iff the final score is positive**. The score starts at 0 (BSS), each hit adds
±150, and there is no ±500 bonus (unlike ENCAIXE). NOITE adds lParam to its score, and on a win
it sends the player to `3fprisao`.

## 10. Plan

### Phase 2: map all functions (about 475 new)

1. **Prerequisites** (they make the decompiler output usable):
   - Install `ghidra/cspec/cdecl16far_dx_ax.xml` and `cdecl16far_dxax_ptr.xml`.
   - Run `CopyTypesFromProgram.java /NOITE.EXE`, then `/ENCAIXE.EXE` (§5), and type the 5 new imports.
   - Type `6312`/`6316` as far `SetSystemTimerFn`/`KillSystemTimerFn` (copy them from ENCAIXE).
2. **Vtable slots → functions.** `NearVtSlots.java` assumes 2-byte slots. Here a slot is a 4-byte
   relocated far pointer, so either add a `far` mode to it, or reuse NOITE's far-slot path
   (`NoiteVtStores.java` finds far stores; the vptr stores here are near, `MOV [r+k], imm`
   with `imm` in `05d2–22a4`). A far code pointer type resolves to `seg:off`, so typing
   the slots `pointer32` gives the references for free. Expect about 52 new methods.
3. **Adjustor thunks.** `NearAdjustorThunks.java` with `SS:[BX+4]` (a parameter, or a far
   copy), over `1088 0000 1332` and `1088 42c2 4d7e`. That gives 368 thunks; their 24 missing
   targets come with them.
4. **Gap sweep.** `CodeGapSweep.java` on each code segment, with the `/GA` callback prologue
   `8C D0 55 8B EC` added. That gives `1038:0000` APPABOUT, `1040:0000`, `1068:0000`,
   `1020:0000`, `1058:0000` and the 10 CRT entries. Make the frameless CRT fragments by hand
   (`_output` `1080:098a` and others). The target is under 300 uncovered bytes.
5. **Names by matching.** Rerun `fuzzy.py`, `feat.py` and `align.py` on the complete function list.
   Emit a TSV for `RenameFunctions.java`, with the plate "Name from ENCAIXE <name> at <addr>":
   - the CRT at ≥0.75;
   - the module segments by in-order alignment at ≥0.4, read when below 0.6;
   - `1088` by vtable slot against ENCAIXE's tables, mapped by class (the 93-slot tables and the
     Game/Frame/ControlPanel tables).

   Then rerun `NearAdjustorThunks` to refresh the thunk names.
6. **Signatures.** `NearSignatures.java` on all code segments (`RETF n` → `__stdcall16far`,
   `RETF` → `__cdecl16far` from the caller cleanup). Copy the ENCAIXE prototypes of the matched
   functions, with `this` at `[BP+6]` and pointers 2 bytes.

### Phase 3: map all data

1. Fix the 29 strings with `DefineStrings.java` (Latin-1).
2. Copy the `/encaixe` category's class and record structs (same near layouts) into `/tiro`
   with `CopyTypesFromProgram.java /ENCAIXE.EXE <names>`. Check each with `memory-layout`
   against TIRO's accesses (watch the 0x486 class).
3. Vtables: the tables and vbtables at `0692–22a3` (about 73 vptr-store targets), with slot structs of **far** function pointers. Use
   `NoiteSlotTypes.java` (its `T *32` slots) and `NearStructs.java` for the vbtables. Apply them
   with a far variant of `NearVtables.java`'s `A|` step; the relocations give the references.
4. Globals: run `NearGlobals.java` for `00ba–02c2` and `6312–64ca` (the crossbow, targets,
   arrow, waves, score), and copy the occupancy matrix and CRT globals (`CrtFILE` and the like)
   from ENCAIXE.
5. Run `NearThisTypes.java` per class, then `NearNullTests.java` (the `CMP SI,0x18/0x34` NULL
   tests).

Risks:
- `/Od` lowers every similarity score; never name by score alone below 0.6 without the module order.
- `1088` mixes several modules; its function order does not follow ENCAIXE.
- The vbase adjustments differ (0x484/0x486) for at least one class.

### Phase 4: function groups (one `ghidra-investigate` agent each)

The counts are estimated non-thunk starts after phase 2 (`est_starts.json`, 607 in total),
without the 368 thunks.
- **Mostly mechanical**: the groups that phase 2 names from ENCAIXE. Their agents verify,
  sign and type.
- **TIRO**: the groups that need real reading.

| # | Range | ~Fns | Content | Kind |
|---|---|---|---|---|
| 1 | `1080:0000–07e6` | 29 | CRT startup, strings, `rand`, long math, `_cinit`, exit, `_setargv`, `_setenvp` | mechanical |
| 2 | `1080:07e7–1003` | 13 | CRT `_flsbuf`, `_output`, heap, `_NMSG_*` | mechanical |
| 3 | `1080:1004–1860` | 23 | CRT I/O, dosret, flush, commit, close | mechanical |
| 4 | `1000`, `1008`, `1010` | 17 | Blitters, DIB copy, DIB load/palette/remap (3 new DIB functions) | mixed |
| 5 | `1018:0000–0f2a` | 31 | Object3D/Moveable/Portable attach, project, draw bounds, getters, overlap, drop, elevation, move | mechanical |
| 6 | `1018:0f2b–21c7` | 20 | Object3D below/support/front, Moveable tick, Player/Exit, Portable pick up/drop/icon | mechanical |
| 7 | `1020`, `1030`, `1050` | 20 | Perspective backdrop and layers, occupancy grid, Backdrop/WinG, SceneObject draw helpers | mechanical |
| 8 | `1028:0000–0d30` | 21 | SceneObject/Mover blit, restore, draw, attach, overlap | mechanical |
| 9 | `1028:0d31–1d52` | 28 | Mover step/move/edge, Animation, Player2D, object list | mechanical |
| 10 | `1038`, `1040:0e6b`, `1048` | 17 | App shell (APPABOUT, WinMain, APPWNDPROC, …), `game_take_exit`, TIRO Game subclass (ctor, CreatePlayer, panel, status bar) | mixed |
| 11 | `1040:0000` | 1 (3.7 KB) | `game_handle_message`, copied from ENCAIXE `8eca` and then verified (high effort, alone) | mechanical |
| 12 | `1058`, `1060` | 19 | StatusBar, ControlPanel, Scene | mechanical |
| 13 | `1070`, `1078` | 22 | The two draw lists, WaveMix | mechanical |
| 14 | `1088:1332–17ff` | 28 | Frame and defaults, getters | by slot |
| 15 | `1088:1800–1bff` | 36 | SceneObjectVtbl default stubs (trivial) | by slot |
| 16 | `1088:1c00–1fff` | 24 | Animation/Mover getters and overrides | by slot |
| 17 | `1088:2000–23ff` | 21 | Defaults, Animated3D overrides | by slot |
| 18 | `1088:2400–27ff` | 20 | Defaults, Moveable ctors | by slot |
| 19 | `1088:2800–2bff` | 23 | Defaults, Actor2D | by slot |
| 20 | `1088:2c00–2fff` | 31 | SceneObject getters, Portable, Game defaults | by slot |
| 21 | `1088:3000–37ff` | 17 | Mover ctors, `frame_init`, Scene background | mixed |
| 22 | `1088:3800–42c1` | 34 | Game defaults, `game_init` (`3dc6`), Scene create defaults | mixed |
| 23 | `1088:4d7e–52ff` | 19 | Game ctor (`4ef6`), TIRO panel and target ctors | TIRO |
| 24 | `1088:5300–57ff` | 31 | ControlPanel ctor, create init scene, Scene getters, grid backdrop | mixed |
| 25 | `1088:5800–622b` | 32 | TIRO object ctors (`587c`, `5946`, `5a08`, `5c3e`, `5cf2`, `603a–6170`), frame dtor | TIRO |
| 26 | `1068:0000–178f` | 24 | TIRO scene: create/music/waves (`008d`), aim (`0476`), Target class (`0586–0883`), hit `08ab`, respawn `0991`, arrow (`1037–1739`) | TIRO |
| 27 | `1068:1790–2fcb` | 6 (5.5 KB) | TIRO handler `1790` (keys, ticks, collisions, 0x40a), score helpers `2d89–2ed4` (high effort) | TIRO |

That is 27 groups. Order of work:
1. Groups 1–3, 4 and 10 first; they anchor the CRT, DIB and app names.
2. Then 5–9 and 11–13, the mechanical engine.
3. Then the `1088` groups 14–25. These need the vtable mapping from phase 3, step 3, so run
   phase 3's vtable step before them.
4. Groups 26–27 last.
