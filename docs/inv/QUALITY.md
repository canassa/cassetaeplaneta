# INV.EXE: decompilation quality (phase 1)

This is an assessment of the Ghidra program `/INV.EXE` as auto-analysis left it, before anything
was named or typed by hand. Addresses are Ghidra `seg:off`. Scratch matchers live in `zig-out/inv/`
and are not committed: `segs.py` and `cmp.py` (NE header and segment diff), `relocs.py` (NE
relocations), `thk.py` (adjustor thunk shapes), `strscan.py` and `strcmp.py` (Latin-1 strings
against Ghidra's), and `fz.py` (normalised-opcode match against TIRO).

## 0. Headline: INV is TIRO's build, one engine revision later

*Invasores* (Space Invaders; NOITE's `FindWindow` target and the window title) is built by the
same toolchain **with the same options as TIRO**: the **medium memory model** (far code, near
data), **`/Od`** (no optimisation), and **stack probes**. Its NE header matches TIRO's field for
field: LINK 5.60, flags 0x302, auto data segment 19, heap 512, stack 4096, entry `1080:001a`,
expected Windows 3.10. It has the same 19 segments in the same order. Six of them have exactly
TIRO's length, and the 32-bit blitter `1000` and the DIB module `1010` are byte-identical. The
file is dated 22 January 1997; TIRO's is December 1995.

- One code segment per module. Calls are **far** (1,838 `CALLF`, 338 of them indirect through a
  vtable; near `CALL` only in the CRT, 35). Returns are `RETF n` 429× and `RETF` 81×. `this` is at
  **`[BP+6]`**.
- Data pointers are **near** (DS = SS = DGROUP). The vptr is a near pointer into DGROUP, and each
  **vtable slot is a 4-byte far code pointer** with an NE relocation. A virtual call is
  `MOV BX,[SI]; CALL dword ptr [BX+slot]`.
- Every function starts `PUSH BP; MOV BP,SP; MOV AX,<frame>; CALLF 1080:00e4` (`_aFchkstk`,
  **479 callers**; its bytes equal TIRO's apart from its DGROUP hook address). `/Od` shows the
  usual way: only 2 `ENTER`, a `JMP` to the epilogue before each return, and long `0F 8x` jumps.
  The window callbacks use the `/GA` prologue `MOV AX,SS; PUSH BP; MOV BP,SP`.
- The CRT is TIRO's medium-model Windows library (`_aFchkstk`, far string functions over near
  data, `_nmalloc` over `LocalAlloc`). It is 0x4c bytes shorter than TIRO's.
- The entry table is empty, as in TIRO: the program exports nothing and Ghidra named only `entry`.

What this means for the phases:
- **TIRO is the twin, not ENCAIXE.** Everything that TIRO's phases 2–3 produced (names, plates,
  prototypes, the `/tiro` structs, the far vtable structs, the slot signatures) applies to INV's
  engine. Code matches TIRO's far better than ENCAIXE's ever matched TIRO's (§4): **nearly all of the
  engine functions and every thunk should transfer from TIRO with a body check, not by reading.**
- The struct layouts transfer from TIRO byte for byte. Watch for one changed module: `1028`
  (SceneObject / Mover / Animation) is 0x2c bytes shorter and `1030` (occupancy, backdrop) 0xb
  shorter, so some of their bodies changed.
- Game code is far pascal (`__stdcall16far`, parameters reversed, `RETF n`, `this` at `[BP+6]`,
  near `this`). `ghidra-fix-signature` applies as it does for TIRO.

## 1. Segments

Δ is INV's length minus TIRO's. "Same" is the byte-level similarity of the two segments, with
relocated words not masked, so DGROUP offsets that moved count as differences.

| Ghidra | NE | Size | Δ TIRO | Same | Holds |
|---|---|---|---|---|---|
| `1000` Code1 | 1 | 0x1a4 | 0 | identical | The 32-bit `transrle.cpp` blitters `0024`/`0114` (NE flag 0x2000). Byte-identical to TIRO, ENCAIXE and NOITE. Copy the names; don't type them |
| `1008` | 2 | 0x988 | 0 | 0.995 | DIB copy and transparent copy |
| `1010` | 3 | 0x1044 | 0 | identical | DIB load, palette, remap (TIRO's newer DIB module, with `FindResource`/`GetObject`/`GetNearestPaletteIndex`) |
| `1018` | 4 | 0x21c7 | 0 | 0.977 | Object3D / Moveable / Portable / Player / Exit |
| `1020` | 5 | 0x296 | 0 | 0.986 | PerspectiveBackdrop and layers |
| `1028` | 6 | 0x1d27 | **−0x2c** | 0.912 | SceneObject / Mover / Animation / Player2D / object list |
| `1030` | 7 | 0x911 | **−0xb** | 0.975 | Occupancy grid, Backdrop (WinG) |
| `1038` | 8 | 0x5b5 | **−0x12** | 0.921 | App shell: APPABOUT, app_init, WinMain, APPWNDPROC… |
| `1040` | 9 | 0x10a9 | 0 | 0.979 | `game_handle_message` `0000` (3,691 bytes, **not a function**), `game_take_exit` `0e6b` |
| `1048` | 10 | 0x288 | +0x29 | 0.805 | INV's Game subclass (TIRO's `1048`: ctor, createPlayer, panel, status bar) |
| `1050` | 11 | 0xb5 | 0 | 0.934 | Conditions module |
| `1058` | 12 | 0x742 | 0 | 0.980 | StatusBar, ControlPanel |
| `1060` | 13 | 0x138 | 0 | 0.958 | Scene |
| `1068` | 14 | 0x3617 | +0x64b | 0.244 | **The Invaders game**: scene handler `1c9c` (5,736 bytes), the game classes, music, waves, score |
| `1070` | 15 | 0x679 | 0 | 0.994 | The two draw lists |
| `1078` | 16 | 0x4a2 | +9 | 0.895 | WaveMix wrappers (+9 bytes, the same delta as TIRO's earlier build `LIXO.EXE`) |
| `1080` | 17 | 0x1815 | −0x4c | 0.940 | CRT. `entry` at `001a`; `0000–0011` is the segment prefix |
| `1088` | 18 | 0x6b79 | +0x94e | 0.730 | Both adjustor-thunk blocks, the SceneObjectVtbl defaults and getters, ctors and dtors, Game/Frame init, **and the Invaders classes' ctors** at the end (`61e4–6b79`) |
| `1090` Data19 | 19 | 0x29a5 file, 0x6926 alloc | +0x448 / +0x45c | – | DGROUP. Heap 512, stack 4096 |
| `1098`, `10a0` | — | 32 / 752 | – | – | One group icon and one icon (`AppIcon`); no dialogs |
| `10a8` EXTERNAL | — | 0x174 | – | – | 93 import thunks |

Ghidra misreads:
- segment `1000` (32-bit code decoded as 16-bit), as everywhere;
- about **20 KB of code** (20,081 bytes, **24 %** of the 84.8 KB in `1008–1088`) in 207 uncovered
  ranges. 66 of them are 16 bytes or more: `1088` 13.7 KB (two thunk blocks of 5.3 and 4.4 KB plus
  the missing slot methods), `1040` 3.7 KB (the engine handler), `1080` 2.2 KB (CRT entries without
  a prologue), and one each in `1020`, `1038`, `1058` and `1068`.

## 2. Entry and startup

| What | Where | Notes |
|---|---|---|
| `entry` | `1080:001a` | `INITTASK`, `_cinit`, `_setargv`, `_setenvp`, WinMain, as in TIRO |
| WinMain, app_init, APPWNDPROC | `1038` | Same shell as TIRO. app_init registers the class whose `lpfnWndProc` is `1038:0335` (APPWNDPROC; `RegisterClass` gets it as an immediate, so it has no reference) and creates the window "Invasores" (`1090:00aa`) |
| APPABOUT | `1038:0000` | `/GA` prologue; **not a function** (the 85-byte gap) |
| game_handle_message | `1040:0000` | Game vtable slot 0; **not a function** (3,691 bytes, TIRO's size) |

## 3. Function boundaries

Ghidra's counts now:
- **718 functions**: 625 code functions plus 93 import thunks (and the 93 externals).
- Named: `entry` and the 93 imports. Conventions: 428 `__stdcall16far`, 81 `__cdecl16far`, 10
  near (CRT), 106 unknown.

As in TIRO, the function-start search found most bodies that have a prologue. What it misses:
- **Vtable slots.** The vtables are untyped, so no slot makes a reference. DGROUP `0594–26ee`
  holds **1,949 far code slots** (TIRO 1,665) with **643 distinct targets**, of which **500 are not
  functions** (`FarVtSlots.java 1090 0594 26ee dry`). There are 79 vptr stores. One store the
  script reports, `1038:00b8` → "table `1038`", is a false positive: it is `WNDCLASS.lpfnWndProc`'s
  segment word, `0x1038`.
- **449 adjustor thunks** (TIRO 368), none of them functions, in two blocks of `1088`:

  | Block | Thunks | Fixed | vtordisp | TIRO |
  |---|---|---|---|---|
  | `0000–14a5` | 256 | 72 in all | 377 in all | `0000–1331` (241) |
  | `4408–545b` | 193 | | | `42c2–4d7d` (127) |

  The shapes are TIRO's far forms (`MOV BX,SP; SUB SS:[BX+4],imm; JMPF` and the vtordisp form
  through `[BX-2]`). The fixed `SUB` immediates are TIRO's −0x484 (17) and −0x486 (14), the small
  6/0xa/0x10, and **0xc, 0x30 and 0x36**, which TIRO lacks: new classes with deeper bases. TIRO's
  `0x8` does not occur.
- **The prologue-less CRT pieces** in `1080` (2.2 KB in 12 ranges): `_output`, the frameless
  helpers, the `INC BP` far entries, as TIRO's `FUNCTIONS.md` lists them.
- **APPABOUT** `1038:0000` and **`game_handle_message`** `1040:0000`, as in TIRO.
- **Dead jumps.** The `/Od` unreachable `JMP rel16` after each `case`/`return` (3-byte gaps, 33 in
  `1068` alone).

Bad splits and merges: none seen. The gaps are undefined bytes, never instructions or data typed
over code.

Large functions:
- `1068:1c9c` (5,736 bytes): the Invaders scene handler.
- `1040:0000` (3,691 bytes, missing): the engine handler.
- `1010:0c90` (942), `1018:0290` (914, `object3d_draw_bounds`), `1010:02e0` (763).

**Estimate after phase 2:** about 700 non-thunk code functions (625 + the 500 slot targets, less
the thunks and overlaps among them) plus 449 thunks, so about **1,150 code functions**.

## 4. Matching against TIRO

`fz.py`: normalised opcodes (numbers → `N`, the chkstk pair and the in-function `JMP`s dropped),
`difflib` ratio, best TIRO function of any segment. On the 532 non-thunk functions Ghidra found:

| Seg | Fns | ≥ 0.95 | ≥ 0.75 | < 0.5 |
|---|---|---|---|---|
| `1008` | 4 | 4 | 4 | 0 |
| `1010` | 11 | 10 | 11 | 0 |
| `1018` | 51 | 49 | 51 | 0 |
| `1020` | 6 | 6 | 6 | 0 |
| `1028` | 49 | 13 | 47 | 1 |
| `1030` | 9 | 4 | 9 | 0 |
| `1038` | 9 | 5 | 9 | 0 |
| `1040` | 1 | 1 | 1 | 0 |
| `1048` | 6 | 0 | 5 | 1 |
| `1050` | 4 | 3 | 4 | 0 |
| `1058` | 14 | 13 | 14 | 0 |
| `1060` | 4 | 4 | 4 | 0 |
| `1068` | 53 | 0 | 24 | 13 |
| `1070` | 11 | 11 | 11 | 0 |
| `1078` | 11 | 5 | 11 | 0 |
| `1080` | 51 | 11 | 40 | 2 |
| `1088` | 236 | 32 | 233 | 1 |

The engine (`1008–1060`, `1070`, `1078`, the `1088` stubs) matches at 0.75 or better almost
everywhere. Ratios below 0.95 in an identical-length segment come from TIRO's bodies, which were
extended in its phase 2 (folded dead jumps, fixed tails), and from moved DGROUP offsets (masked)
whose instruction forms differ (`MOV AX,[k]` vs `MOV AX,[k+...]`). Phase 2 matches after the
discovery passes, segment by segment and **in address order**, and checks each pair.

INV-specific code to read:
- all of `1068` (about 55 functions): the scene handler, the cannon, the invader rows, the saucer,
  shots and bombs, explosions, music and waves, score;
- `1048` (6): the Game subclass;
- the new classes' ctors and slot overrides in `1088` (`61e4–6b79`, and the overrides the
  new vtables point to);
- whatever changed in `1028`, `1030` and `1038` (to compare with TIRO's body).

## 5. Imports

93 imports from WAVEMIX, KERNEL, GDI, USER, WING and MMSYSTEM, in TIRO's order. TIRO's
`GETTICKCOUNT` is not imported. All were **untyped**; seven are unreferenced (`LOCALREALLOC`,
`LOCALSIZE`, `GLOBALSIZE`, `__AHSHIFT`, `__AHINCR`, `__WINFLAGS`, and `ENDDIALOG`, called only from
the missing APPABOUT).

**Fixed in phase 1:** `CopyTypesFromProgram.java /TIRO.EXE` copied the 17 SDK structs and typed all
93 (TIRO's are all typed, with the 4 WinG ordinals renamed and `CREATEWINDOW`'s 4-byte `lpvParam`
fix). `SetSystemTimer`/`KillSystemTimer` are reached through two far pointers that WinMain fills
from `GetProcAddress(USER, 11/182)`, as in TIRO; they are typed in phase 3.

## 6. Decompiler output

Sampled: the handler `1068:1c9c`.

| Issue | State before the fixes |
|---|---|
| Signatures | Parameter counts right from `[BP+n]`; `int`/`undefined2`; `this` is `param_1` |
| chkstk | `FUN_1080_00e4();` first in every body; the outgoing pushes alias the locals |
| Junk at call sites | Every API call: `POSTMESSAGE(0x10a8,DAT_1090_6876,DAT_1090_6876 >> 0xf,param_4,0x40a)`, `MESSAGEBOX(0x1078,0x30,0x2c6,0x1090,…)`. The far return segment of untyped calls leaks as a first argument |
| Virtual calls | `(*(code *)*(vbase(p)+2 + 0xd4))(0x1068, vbase(p))`, with the SceneObject reached through the vbtable: `p + *(int *)(*(int *)(p + 2) + 2) + 2`. The pushed `CS` shows as a first argument |
| Globals | The game objects are `DAT_1090_68e0…68f2`; the 4 invader rows are an array at `68ea` |
| Strings in code segments | None: all strings are in DGROUP |
| Overall | Control flow is good. `/Od` bodies are long but literal |

**Fixed in phase 1** (stored in the program):
- the spec extensions `aFchkstk` (call-fixup, `ghidra/cspec/aFchkstk_fixup.xml`),
  `__cdecl16far_dx_ax` and `__cdecl16far_dxax_ptr` are installed; `1080:00e4` is named `_aFchkstk`
  and carries the call-fixup, so frames are allocated and pushes no longer alias the locals;
- the imports are typed (§5).

Fixed later: `FarSlotSignatures.java` typed the virtual and timer-pointer calls once the vtable
structs existed (phases 3–4); every indirect call but the 11 CRT function-pointer calls has an
override.

## 7. The data segment (`1090`)

0x29a5 bytes initialised, 0x6926 allocated; the BSS is 0x3f81 bytes. Ghidra defines 208 data items,
70 of them strings.

| Range | Contents |
|---|---|
| `0000–000f` | Windows instance header |
| `0010–00a9` | The coordinate format and the HDC/layer overflow strings (TIRO's) |
| `00aa` | `"Invasores"`: class, title, NOITE's `FindWindow` target |
| `00b6–00e7` | `AppIcon`, "O aplicativo já está aberto !!!", `USER` ×2 |
| `00fc–01b3` | The bitmap names and their strip tables: `Canhao`, `Brocha`, `Disco`, `Explod`, `Tiro`, `Bomba`, `Bomtir`, `Movein`, `Naboom1` `.bmp` |
| `01b4–01df` | `panel.bmp` ×2, `Mech`, `arialbd.fot` |
| `01e0–0279` | MCI (`doom1.mid`, alias `musica`) and the 8 waves `tiroes2`, `explos`, `nave`, `explo1`, `brocha3`, `explo5`, `marcha`, `desceniv` |
| `027a–028a` | The key latches (`027a` right, `027c` left, `0282` space) and game counters (`0286`, `0288`, `028a`) |
| `028c–039f` | MCI/WaveMix strings, `-%04d` / ` %04d`, the visible-objects overflow strings |
| `03a0–04b3` | WaveMix module data and strings |
| `04b4–0593` | CRT data (`_C_FILE_INFO=`…) |
| `0594–05b0` | 7 far CRT hooks |
| `05d4–0653` | `MAX_OBJECT_QTY` overflow |
| **`0654–26ee`** | **Vtables and vbtables**: 1,942 far slots in 64 tables (18 of them have the 91 slots of the SceneObject interface), with the Game strings ("Faltou redefinir…", `Espaco.bmp` at `0fb8`) inside, as in TIRO |
| `2836–29a4` | `<<NMSG>>` and the R6xxx table |
| `29a5–6925` | BSS: the occupancy matrix, then the app globals, `6876` (the score posted with 0x40a), `68e0–68f2` the game objects, the timer far pointers (`675a` is the SetSystemTimer pointer) |

Strings: a Latin-1 scan finds 82; Ghidra has 45 of them exactly, 6 with a wrong length (`012c`,
`0164`, `0180`, `048a`, `05d4`, `0fb8`), and is missing 31 (most of them carry an accent).
All 82 go through `DefineStrings.java` in phase 3.

## 8. What the game is (first look)

*Invasores* is **Space Invaders**, played from the keyboard, launched by NOITE's flying-saucer
scene `4fsacaet` (`src/handlers/4fsacaet.zig`) as `<cd>Inv\Inv.exe`.

Files (`assets/INV/`):
- `Espaco.bmp` (the background), `Canhao.bmp` (the cannon), `Movein.bmp` (the invader rows),
  `Disco.bmp` (the saucer), `Tiro.bmp` (the cannon's shot), `Bomba.bmp`/`Bomtir.bmp` (bombs),
  `Explod.bmp`, `Naboom.bmp`/`Naboom1.bmp` (explosions), `Brocha.bmp`, `panel.bmp`;
- `DOOM1.MID` through MCI;
- 8 waves through WaveMix; `EXPLO2–4.WAV`, `EXPLOS`, `QUEDANAV.WAV` and `TIROESP.WAV` are on the
  disc but not all of them are named in DGROUP.

From the handler `1068:1c9c` (`GAME.md` has the rules in full):
- LEFT/RIGHT (WM_KEYDOWN 0x25/0x27, latched in `027c`/`027a`) move the cannon (`68e0`) through
  SceneObject slots 0xc0/0xd0; WM_KEYUP stops it (`0xcc`) or reverses to the other held key.
- SPACE (0x20) fires the shot (`68e4`) from the cannon's x + 0x1b, y − 0x1e, if no shot is in
  flight; its latch `0282` is never set.
- WM_SYSTIMER (0x118) dispatches on the timer id of each object: the cannon, the saucer (`68e2`),
  the two bombs (`68e6`/`68e8`), the shot, the four invader columns (`68ea[4]`), the explosion
  (`68f2`).
- A shot that hits an invader: **`g_score` +100** (`6876`); the invader counter `0286` drops by
  one; with 15, 10 and 5 left the columns' period (`01de`) drops by 100 ms, with one left it becomes
  0x37 ms. A shot that hits the saucer: **+500**. The cannon's `+0x42` (the Player2D score, a dword)
  also gets +10 / +50 and is never reported.
- A bomb within the cannon's x..x+0x41 below y 0x19a hits the cannon: **−500** and a life.
- On WM_DESTROY it stops the waves and MCI and posts **0x40a** with WM_DESTROY's own wParam
  (0xffff win, 0 loss) and `(long)g_score`.

## 9. How it talks to NOITE

As TIRO and ENCAIXE. NOITE (`handler_4fsacaet`) runs `WinExec("<cd>Inv\Inv.exe")`, polls
`FindWindow("Invasores")` on timer 0x14 and posts **0x40b** with its window; INV answers **0x40c**
once (NOITE hides itself) and reports **0x40a** on exit. NOITE adds lParam to its score and goes to
`4fmarte2` on a win (wParam ≠ 0), `4fmarte` otherwise, which takes a life. While INV runs, NOITE's
system timer posts its own 0x40a if the "Invasores" window disappears.

## 10. Plan

### Phase 2: map all functions

1. **Discovery**, TIRO's scripts as they are:
   - `FarVtSlots.java 1090 0594 26ee` (500 new functions);
   - `NearAdjustorThunks.java 1088 0000 14a6 far` and `1088 4408 545c far` (449 thunks);
   - `CodeGapSweep.java` per code segment with `create` (APPABOUT, `1040:0000`, CRT entries);
   - the CRT's frameless pieces by hand, at TIRO's addresses shifted by the `1080` diff;
   - `DeadJumps.java` on every code segment.
2. **Names from TIRO.** Export both programs' ops and align each INV segment against the same TIRO
   segment in address order. Copy name, plate (`Name from TIRO <name> at <addr> (…)`), calling
   convention and prototype of every pair that checks out (same API sequence, same virtual slots,
   callees agreeing). A new script copies the prototypes, since TIRO's types live in `/tiro`: it
   needs the structs first, so phase 3's struct copy runs before the prototype copy.
3. **`1088` by vtable slot**: slot *i* of an INV table gets the TIRO name for slot *i* of the same
   class.
4. Re-run `NearAdjustorThunks` to name the thunks after their targets.

### Phase 3: map all data

1. Strings: `DefineStrings.java` on the 82.
2. Classes: copy TIRO's `/tiro` category into `/inv` and check each struct against INV's accesses
   (`1028`/`1030` changed).
3. Vtables: `FarVtables.java` with TIRO's slot structs, then `FarSlotSignatures.java` (defs, calls).
4. Globals: `NearGlobals.java` (key latches, counters, game objects, waves, score, timers) and the
   CRT and occupancy globals from TIRO.
5. The game classes (cannon, rows, saucer, shot, bombs, explosion): new structs.

Risks:
- An identical name is not proof: `/Od` code of two similar methods can be identical, so pairs are
  taken in address order inside a module, not by best score alone.
- `1028`, `1030` and `1038` changed; their pairs need a body check.
- The new thunk adjustments (0xc, 0x30, 0x36) belong to new classes; their layouts are new.

## 11. Final state

After phase 4 and the cleanup: 1,193 functions (93 imports, 449 adjustor thunks, 651 code
functions, 646 named, 5 dead `FUN_`), 0 `review`/`sig?` tags, 431 call-site overrides (every
indirect call but the 11 CRT function-pointer calls), uncovered code only data and padding
(`FUNCTIONS.md`). The game is in `GAME.md`, its bugs in `BUGS.md` (section INV).
