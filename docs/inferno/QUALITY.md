# INFERNO.EXE: decompilation quality (phase 1)

This is the assessment of the Ghidra program `/INFERNO.EXE` as auto-analysis left it, plus the
program-wide fixes that were applied first. Addresses are Ghidra `seg:off`. The scratch matchers
and dumps are in `zig-out/inferno/` (not committed): `InfernoSurvey.java`, `InfernoDump.java`,
`gs/*.java`, `segs.py`, `ops.py`, `feat.py`, `align.py`, `vt.py`, `vtname.py`, `runs.py`.
`funcs0.tsv` and `uncovered0.tsv` are the auto-analysis snapshot that the numbers below come from.

## 0. Headline: INFERNO is a large-model, unoptimised build

TIRO is medium model; INFERNO runs the same engine sources at nearly the same version (the same
91-slot SceneObject vtable, "Faltou redefinir o método Create…", `MAX_OBJECT_QTY`, the occupancy
matrix), but it is built in the **large memory model** (far code **and far data**),
**without optimisation (`/Od`)** and **with stack probes**. It is the only minigame so far whose
data model is NOITE's.

- One code segment per module: 16 code segments plus the 32-bit blitter. Calls are far
  (`CALLF` 1,615 sites; near `CALL` only inside the CRT). `this` is a **far pointer at
  `[BP+6]`** (4 bytes), so every method's first two parameter words are `this`.
- Data pointers are **far** (4 bytes, `LES BX,…` 3,800+ times). Objects are reached as
  `LES BX,[BP+6]; … ES:[BX+k]`. The vbptr is a far pointer too (`LES BX,ES:[BX-0x1a]`).
- **The vptr is a far pointer into the code segment `1080`**: the vtables are not in DGROUP but
  in `1080` (as in NOITE, whose tables live in its code segments). Each slot is a 4-byte far code
  pointer with an NE relocation on its segment word. A virtual call is
  `LES BX,[obj]; LES BX,ES:[BX]; CALLF ES:[BX+slot]`, with the slot offsets equal to TIRO's.
- Every function starts `PUSH BP; MOV BP,SP; MOV AX,<frame>; CALLF 1078:00f8` (`_aFchkstk`, 516
  callers). Other `/Od` signs as in TIRO: no `PUSH DS; MOV DS` prologue, a `JMP` to the epilogue
  before each return, long-form `0F 8x` jumps. The window procedure uses the `/GA` prologue
  `MOV AX,SS; PUSH BP; MOV BP,SP; PUSH DS; MOV DS,AX` (2 sites in `1038`).
- **String literals of the engine code live in its code segment `1080`** ("Faltou redefinir…",
  "Fundo.bmp", the `MAX_OBJECT_QTY` and occupancy overflow texts), like NOITE's. The game's own
  strings (bitmap and wave names, MCI commands, WaveMix errors, score formats) are in DGROUP.
- The CRT is the **large-model Windows library** (`LLIBCEW`): far `_aFchkstk`, `_fstr*`/`_fmem*`
  string functions, `_fmalloc`/`_halloc` heaps. It matches **NOITE's CRT byte for byte**
  (§4), not TIRO's or ENCAIXE's.
- The entry table is empty: INFERNO exports nothing; Ghidra named only `entry` and
  `___EXPORTEDSTUB`.

What this means for the next phases:
- **Code shape and names transfer from TIRO** (same `/Od` codegen, same engine version, same
  module order, same vtable slot offsets). Instruction sequences do not match byte for byte
  because every pointer is far.
- **Data layouts do not transfer from TIRO/ENCAIXE** (their pointers are 2 bytes). They are
  closer to NOITE's (far pointers, far vptr and vbptr), but NOITE is a later, bigger engine:
  check every offset. Example: `object3d_overlaps_3d` reads the scene object at
  `[this+vbase+0x470/0x472]` here, `[+0x45a/0x45c]` in TIRO.
- **Adjustor thunks subtract 0x49e/0x4a0** (TIRO 0x484/0x486, NOITE 0x4be): the classes with a
  SceneObject virtual base are 0x1a bytes bigger than TIRO's.
- Game code is far pascal: `__stdcall16far`, parameters reversed, `RETF n` = argument bytes.
  The `ghidra-fix-signature` skill applies with `this` and data pointers 4 bytes (Ghidra's
  4-byte alignment trap matters for every far pointer after an odd number of words).

## 1. Segments

| Ghidra | NE | Size | Holds | TIRO twin |
|---|---|---|---|---|
| `1000` Code1 | 1 | 0x1a4 | The 32-bit `transrle.cpp` blitters (NE flag 0x2000). **Byte-identical to TIRO's** (and NOITE's/ENCAIXE's) `1000` | `1000` |
| `1008` | 2 | 0x988 | DIB copy / transparent copy | `1008` (same size) |
| `1010` | 3 | 0x1044 | DIB load, palette, remap (the newer DIB module, as TIRO's) | `1010` (same size) |
| `1018` | 4 | 0x2947 | Object3D / Moveable / Portable / Exit | `1018` (0x21c7) |
| `1020` | 5 | 0x371 | Perspective backdrop setters and layers | `1020` |
| `1028` | 6 | 0x2993 | SceneObject / Mover draw and movement, Animation, object list | `1028` |
| `1030` | 7 | 0xc44 | Occupancy grid, Backdrop/WinG | `1030` |
| `1038` | 8 | 0x5d9 | App shell: APPABOUT, app_init, WinMain, APPWNDPROC | `1038` |
| `1040` | 9 | 0x177a | `game_handle_message` (4,917 bytes), `game_take_exit` | `1040` |
| `1048` | 10 | 0x218 | INFERNO's Game subclass (ctor, createPlayer, createInitScene, onCreate) | `1048` |
| `1050` | 11 | 0xd5 | Conditions (`init_static_conditions`, the two factories) | `1050` |
| `1058` | 12 | 0x548 | ControlPanel only (6 functions); **no StatusBar code** | `1058` (StatusBar + ControlPanel) |
| `1060` | 13 | 0xc9 | Scene create, add exit | `1060` |
| `1068` | 14 | 0x5bab | **The INFERNO game** (47 functions, 23 KB) | `1068` (12 KB) |
| `1070` | 15 | 0x4a4 | WaveMix wrappers | **`1078`** |
| `1078` | 16 | 0x1f51 | CRT (large model). `entry` at `001a`; `0000–0011` is the segment prefix | `1080` |
| `1080` | 17 | 0x8e51 | **Both adjustor-thunk blocks** (`0132–202f`, `6876–705f`), the SceneObjectVtbl defaults, getters, ctors/dtors, Game/Frame init, **all the vtables** (`4790–4f22`, `65fa–669a`, `7d50–8430`, `8648–866c`, `89c2–8e4a`) and the engine's string literals | `1088` |
| `1088` Data18 | 18 | 0 file, 0xc alloc | A far BSS segment: the two static `FlagCondition` objects (`1050` pushes `1088:0000` and `1088:0006`) | — (in DGROUP) |
| `1090` Data19 | 19 | 0x9c9 file, 0x72c0 alloc | DGROUP. Heap 512, stack 4096. BSS 0x68f7 bytes | `1090` |
| `1098`, `10a0` | — | 32 / 752 | Resources: one group icon and one icon | same |
| `10a8` EXTERNAL | — | 0x158 | 86 import thunks | 94 |

The draw-list module (TIRO `1070`) is **missing**: INFERNO has one module segment fewer, and its
`1070` is TIRO's WaveMix module.

## 2. Entry and startup

| What | Where | Notes |
|---|---|---|
| `entry` | `1078:001a` | `INITTASK`, `_cinit` (`0470`), `_setargv` (`0652`), `_setenvp` (`07fc`), WinMain |
| WinMain | `1038:021a` | Same as TIRO's (already-open check, SetSystemTimer/KillSystemTimer from `GetProcAddress(USER, 11/182)`) |
| app_init | `1038:0055` | RegisterClass + CreateWindow "Inferno" (`1090:0084`: class, title and NOITE's `FindWindow` target) |
| APPWNDPROC | `1038:0353` | Found by Ghidra, unnamed (RegisterClass takes it as an immediate) |
| APPABOUT | `1038:0000` | `/GA` prologue; **not a function** after auto-analysis |
| game_handle_message | `1040:0000` | GameVtbl slot 0; **not a function** (4,917 bytes uncovered) |

## 3. Function boundaries

Auto-analysis: **442 code functions** plus 86 import thunks. Named: `entry`,
`___EXPORTEDSTUB` and the imports. Conventions: 328 `__stdcall16far`, 81 `__cdecl16far`,
20 near (CRT), 13 unknown. 186 of the 442 have no reference at all (Ghidra's function-start
search found them).

Uncovered: **31,103 bytes** in 180 ranges, 23,059 of them in `1080`, 5,001 in `1040` and 1,925 in
the CRT. About 5 KB of the `1080` bytes are vtables and strings; the rest is code.

What was missing, and how phase 2 recovered it (`FUNCTIONS.md` has the details):
- **Vtable targets:** no slot was typed, so no slot made a reference. 1,248 far slots in 42
  tables; 362 targets were not functions (`FarVtSlots.java`, run on the `1080` table ranges).
- **Adjustor thunks:** 464 in two blocks, none of them functions. Their large-model vtordisp
  shape (`MOV BX,SP; LES BX,SS:[BX+4]; MOV AX,ES:[BX-2]; [ADD AX,k]; MOV BX,SP;
  SUB SS:[BX+4],AX; JMPF`) is new; `NearAdjustorThunks.java` now accepts it.
- **Missed prologues:** APPABOUT, `1020:0000`, 10 CRT entries, 7 in `1080`
  (`CodeGapSweep.java`).
- **CRT by hand:** two `INC BP` far entries (`_flushall` `1a0c`, `_fcloseall` `1a8c`) that Ghidra
  started one byte late; the frameless entries `_aNchkstk` `00d8`, `_cintDIV` `08b6`,
  `crt_dosret_maperr` `1827`, `crt_ltoa_body` `1eee`; the 7 near helpers of `_output`
  (`0e37–0ed6`); and `_output`'s switch table (8 words at `0a0c`, `JMP CS:[BX+0xa0c]` at `0a76`),
  without which `_output` stopped after 106 of its 1,062 bytes.
- **Dead code:** 44 unreachable `JMP rel16` after epilogue jumps (`DeadJumps.java`) and one
  unreachable 84-byte block inside `game_take_exit` (`1040:1388–13db`, no jump reaches it).

Bad splits/merges: none. No data was decoded as code. Large functions:
`game_handle_message` `1040:0000` (4,917), the scene handler `1068:4bdc` (3,266), `1068:3f86`
(1,905), `1068:0260` (1,886), `1068:0edc` (1,767), `1068:2f93` (1,583), `object3d_draw_bounds`
`1018:02da` (1,363).

## 4. Matching against the twins

| Method | Yield |
|---|---|
| **CRT, byte match against NOITE's `1008`** (same LLIBCEW library; NOITE's 130 CRT functions searched for in `1078`) | 81 functions at ≥ 0.72 (66 at ≥ 0.9, 30 at 1.00), plus 11 by order, size and body |
| **Vtable slots** (slot *i* of an INFERNO table = slot *i* of the same class's TIRO table, thunks resolved on both sides) | 255 names; class of each table by its override pattern (Jaccard 1.0 for every engine class) |
| **In-order alignment per module segment against TIRO** (Smith–Waterman over a data-model-independent feature sequence: API calls, vtable slot offsets, calls to already-named functions, branch kinds, small immediates) | every module segment aligns in order to its TIRO twin (`1070` to TIRO `1078`); 187 more names |

The opcode-level matchers that TIRO used against ENCAIXE (`fuzzy.py`) do not work here: every
`MOV r,[SI+k]` of TIRO is a `LES BX,…; MOV r,ES:[BX+k]` pair in INFERNO.

**The engine version differs from TIRO's in four vtables** (found from the slot calls of aligned
pairs and the argument sizes of the default stubs):
- **Object3DVtbl has 7 slots, not 8**: TIRO's slot 4 (`isInFrontOf`) is gone; INFERNO slot *i* =
  TIRO *i* for *i* < 4, *i*+1 after.
- **BackdropVtbl has 20 slots** (TIRO 19): TIRO slot 3 (`queryRectFirst`) is gone (INFERNO 3–17 =
  TIRO 4–18), and two slots are new: 18 (returns 0; GridBackdrop returns 1) and 19
  (`asGridBackdrop`: NULL, GridBackdrop returns `this`). **GridBackdropVtbl has 21** (its 20 =
  TIRO's 19, `createWithGrid`).
- The **SceneObjectVtbl (91), MoverVtbl, AnimationVtbl, FrameVtbl, GameVtbl (7), SceneVtbl (13)
  and ConditionVtbl (3)** map 1:1.

Other engine differences seen while matching: `Frame` has no hitbox fields (`frame_init` takes 5
arguments, TIRO 9); the SceneObject draw/tick paths realise the palette and skip TIRO's
`PostMessage` notifications; there is no StatusBar, no Animated3D and no draw-list class.

## 5. Imports

86 imports from WAVEMIX, KERNEL, GDI, USER, WING and MMSYSTEM, all untyped by auto-analysis.
Seven have no reference: `WAVEMIXOPENCHANNEL`, `WAVEMIXGETINFO`, `WAVEMIXCONFIGUREINIT`,
`__AHSHIFT`, `__AHINCR`, `__WINFLAGS` and `ENDDIALOG` (called from the then-missing APPABOUT).

**Applied:** `CopyTypesFromProgram.java /NOITE.EXE` (17 SDK structs, 81 signatures, the 4 WinG
ordinals renamed), then `/TIRO.EXE` (the 5 NOITE lacks: `HMEMCPY`, `GETOBJECT`,
`GETPALETTEENTRIES`, `GETNEARESTPALETTEINDEX`, `GETTICKCOUNT`). All 86 are typed. The Win16 API
is the same in every memory model, so NOITE's signatures (its `ptr` + `_seg` split for the 4-byte
alignment trap) apply unchanged.

## 6. Decompiler output

Sampled: the scene handler `1068:4bdc`, `object3d_*` slots in `1018`, the `1080` stubs, APPWNDPROC.

| Issue | State |
|---|---|
| chkstk | Every body started with `FUN_1078_00f8();` and its frame was not allocated. **Fixed:** the `aFchkstk` call-fixup (`ghidra/cspec/aFchkstk_fixup.xml`) is installed as a spec extension and set on `_aFchkstk` (`1078:00f8`); the stub is identical to TIRO's |
| Signatures | Parameter counts from `[BP+n]` are right; `this` shows as `undefined4 param_1` and is split into `(int)param_1` / `param_1._2_2_` |
| API call sites | Junk like `MESSAGEBOX(0x30,…)` with a leaked segment before typing; **fixed** by the import types |
| Virtual calls | `puVar1 = *(vbptr+2 + this + 4) + 0xd4; (*(code *)*puVar1)(0x10a8, this…)`: the first argument is the leaked CS (the near default model), as in TIRO. Needs the vtable structs and `FarSlotSignatures`-style overrides (phase 3/4) |
| Globals | Far object pointers in the BSS (`DAT_1090_722a`, the player); arrays of far pointers print as `((undefined4 *)&DAT_1090_7246)[i]` |
| Strings | DGROUP strings print as `s_…_1090_…`; the engine strings are in `1080` and pushed as `PUSH 0x1080; PUSH off` |
| Overall | Control flow good; `/Od` long but literal. Readable once `this` and the far globals are typed |

## 7. The data segment (`1090`)

0x9c9 bytes initialised, 0x72c0 allocated. Auto-analysis defined 67 strings and 139 undefined
placeholders. A Latin-1 scan finds 73 strings in DGROUP and 13 in `1080`; about 20 of Ghidra's
are cut at an accent (`ú`, `ã`, `ç`, `í`) and 14 are missing.

| Range | Contents |
|---|---|
| `0000–000f` | Windows instance header |
| `0010–0083` | `"(%03d,%03d)=>(%03d,%03d,%03d)"`, the HDC/layer overflow strings |
| `0084` | `"Inferno"`: class, title, NOITE's `FindWindow` target |
| `008c` | the NOITE window (set by 0x40b; the 0x40a target) |
| `0096–00c3` | `AppIcon`, the already-open message, `USER` ×2 |
| `00d4–02c9` | the bitmap names and their far-pointer strip tables (`015a`, `01de`, `020c`, `0252`, `0284`, `02ac`) |
| `02ca–03ff` | `"Mario"`, the MCI strings (`mario.mid`, alias `musica`), the 5 wave names, WaveMix messages |
| `0406`/`040c` | the score formats `-%04d` / ` %04d` |
| `046a–0509` | WaveMix error strings |
| `051e–09c8` | CRT data, `R6xxx` messages |
| `09ca–1e5b` | BSS: `g_occupancyCount` `char[65][81]` |
| `1e5c–7097` | `g_occupancyObject` `SceneObject far *[65][81]` (4-byte entries: twice TIRO's size) |
| `7098–72bf` | app and game globals: timer far pointers (`70a0`…), `g_score` (`70b0`), the game objects (`722a` the player, `7246[4]`, `726a`, `726e[…]`) |

## 8. What the game is (first look)

*Inferno* is the minigame of the pope's punishment (NOITE `handler_3fpapmal` runs
`inferno\inferno.exe` when the `3apapmal` video ends). The assets say what it is: a keyboard
**platformer in hell** — `mario.mid` as music, "Sonic" waves (`sonicmor`, `sonicpul`, `sonicmag`,
`sonicf`), the hero `mar*.bmp` (walk/jump/fall strips, left and right), platforms (`Plataf.bmp`,
`rocha01–03.bmp`), fire (`fogo.bmp`), a devil (`diabo.bmp`), a cross, coal, and drinks (`cerva`,
`chopp`, `copo`). `GAME.md` (phase 4) will describe it; `DATA.md` §6 has what the data shows.

From the scene handler `1068:4bdc`:
- LEFT/RIGHT (0x25/0x27) walk, UP (0x26) or numpad `+` (0x6b) jump, DOWN (0x28) or numpad `−`
  (0x6d) another action; each latched by a flag cleared on WM_KEYUP. The mouse is ignored.
- **A 3-minute limit** (180,000 ms of `GetTickCount` from the start): then the game reports and,
  a second later, posts itself WM_DESTROY.
- **Result:** `PostMessage(noite, 0x40a, won, won ? 500 : g_score − 1000)`, sent every 100 ms
  after the time is up, and also on WM_CLOSE / WM_QUERYENDSESSION.

## 9. Plan (as carried out in phases 2 and 3)

Phase 2 (`FUNCTIONS.md`):
1. Prerequisites: the chkstk fixup, the cspec extensions `cdecl16far_dx_ax` /
   `cdecl16far_dxax_ptr`, the import types (done in this phase).
2. `FarVtSlots.java` on the `1080` table ranges (the script takes the table segment, so the
   code-segment tables need no change); drop the bogus "stores" that are just the constants
   0x8000/0x8080 in `1010`.
3. `NearAdjustorThunks.java … far` with the new `LES` vtordisp form.
4. `CodeGapSweep.java` per segment, the CRT fixes, `DeadJumps.java`.
5. Names: CRT from NOITE by bytes, engine from TIRO by vtable slot (with the four remapped
   tables) and by in-order alignment, then the thunks renamed after their targets.

Phase 3 (`DATA.md`): strings with `DefineStrings.java`; the vtables typed with far slot structs
(`FarVtables.java` works on any segment); the class layouts measured from INFERNO's own accesses
(far pointers), with NOITE's large-model structs as the starting point instead of TIRO's.

Scripts that apply as they are: `CopyTypesFromProgram`, `FarVtSlots`, `CodeGapSweep`,
`DeadJumps`, `RenameFunctions`, `DefineStrings`, `NoiteStructs`, `NoiteFieldSet`, `FarVtables`.
Changed: `NearAdjustorThunks` (large-model vtordisp form). Not applicable as they are:
`NearSignatures`/`NearThisTypes`/`NearStructs` (near `this` and 2-byte pointers),
`FarSlotSignatures` (reads a near vptr), `NearNullTests` (the far NULL test is
`SUB AX,k; OR DX,AX; JNZ`, not `CMP SI,k`).
