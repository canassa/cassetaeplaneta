# JARDIM.EXE: decompilation quality (phase 1)

This is the assessment of the Ghidra program `/JARDIM.EXE` as auto-analysis left it, and of the
program-wide fixes applied before the mapping (phase 2, `FUNCTIONS.md`). Addresses are Ghidra
`seg:off`. The scratch tools are in `zig-out/jardim/` and are not committed: `ne.py` (NE
segments and relocations), `vtruns.py`/`vstores.py` (far pointer runs, vptr stores), `match.py`
and `align.py` (fuzzy and in-order matching against TIRO and NOITE), `vtlib.py`, `vtmap.py`,
`vtmapn.py`, `vtname.py` (vtable slot naming), `crtmatch.py`, `final.py`, and the inline Ghidra
scripts in `zig-out/jardim/gs/`.

JARDIM.EXE ("Noite Animal Jardim", 201,104 bytes, 22 Jan 1997) is the garden minigame. NOITE
starts it from two scenes (`handler_espquete`, `handler_4fjarvamp`).

## 0. Headline: JARDIM is a large-model, unoptimised build

ENCAIXE is small model and TIRO medium model. JARDIM runs the same engine sources ("Faltou
redefinir o método CreatePlayer/…", `MAX_OBJECT_QTY`, the occupancy matrix), but it is built in
the **large memory model** (far code, **far data**, like NOITE), **without optimisation (`/Od`)**
and **with stack probes** (like TIRO):

- One code segment per module: 21 16-bit code segments plus **four** 32-bit segments. Calls are
  far (`CALLF`). `this` is a **4-byte far pointer at `[BP+6]`**, reloaded with `LES BX,[BP+6]`
  before every access.
- Data pointers are far. The vptr is a **far pointer** (two word stores, the segment word
  NE-relocated) and the vtables and vbtables live in a **code segment** (`10c0`), as NOITE's live
  in `1010`/`1018`. Vtable slots are 4-byte far code pointers; a virtual call is
  `LES BX,[obj]; LES BX,ES:[BX]; CALLF ES:[BX+slot]`.
- Every function starts `PUSH BP; MOV BP,SP; MOV AX,<frame>; CALLF 10b8:02b6` (`_aFchkstk`,
  491 callers). Other `/Od` signs: a `JMP` to the epilogue before each return, long `0F 8x`
  jumps, `LEAVE; RETF n` epilogues, dead jumps and dead blocks (§3). There is no
  `PUSH DS; MOV DS` prologue: the CRT loads DS once and the code reaches DGROUP through DS.
- **Huge pointers** in a few modules: `__AHINCR` (KERNEL.114) and `__AHSHIFT` (KERNEL.113) are
  used 127 times, 74 of them in `1068` (scaled DIB copies), the others in `1040` (DIB load),
  `1060` (DIB copy), `1088` (RLE), `10c0` (the array-delete helpers) and the CRT.
- **Floating point is linked in** (the CRT has the MSVC math library and its emulator fixups:
  199 OSFIXUP relocations, all in `10b8`, and the `WIN87EM.__FPMATH` import), but no game code
  calls it; only `crt_restore_vectors` calls `__FPMATH`. The game itself uses integer and 32-bit
  fixed-point arithmetic (`_aFldiv`, `_aFlmul`).
- The compiler is MSVC 1.5x (LINK 5.60), the WinG sample skeleton (`APPABOUT`, `APPWNDPROC`).
  The source tree was `d:\c&p\doom\` (assert string of `transrle.cpp`), and the music is
  `doom.mid`: the garden is a **Doom-like raycaster**.

What this means for the phases:
- **Struct layouts transfer from NOITE** (far data), not from TIRO or ENCAIXE. The vbase
  displacements in the adjustor thunks are 0x4ba and 0x4bc (TIRO 0x484/0x486, NOITE 0x4be).
- **Class set and vtable shapes follow NOITE**: the 97-slot SceneObjectVtbl is NOITE's 102
  slots without five (§5), and there are NOITE's Player, Actor, Exit, Animated3D, Portable,
  Moveable classes. TIRO's Actor2D/Player2D/Crossbow do not exist.
- **Code shape follows TIRO** (`/Od` + stack probe), so the in-order alignment against TIRO
  names the module segments (§4), and the same three decompiler fixes apply (§6).
- Game code is **far pascal** (`__stdcall16far`, parameters reversed, `this` first). A far
  pointer is two `undefined2` parameters until typed (the `ghidra-fix-signature` 4-byte
  alignment trap applies as in NOITE).

## 1. Segments

27 NE segments; Ghidra maps NE segment *n* to `0x1000 + (n−1)·8`.

| Ghidra | NE | Size | Holds |
|---|---|---|---|
| `1000` | 1 | 0x2a0 | 32-bit (NE flag 0x2000) `transrle.cpp` blitters, **three** routines (`0024`, `0148`, `0234`); NOITE/TIRO have two (`0024`, `0114`). `0148` is called by `dib_copy_transparent*`, `0234` by `dib_copy*`, `0024` by the scaled copy `1068:0000` (new) |
| `1008` | 2 | 0x20c | 32-bit, one routine at `0024` (called by `1028:0951`, the raycaster), compares against 0x5a0 (1440) |
| `1010` | 3 | 0x20c | 32-bit, one routine at `0024` (called by `1028:0951`), compares against 0x2d0/0x870 |
| `1018` | 4 | 0x3c4 | 32-bit, one routine at `0024` (called by `1068:1336`, a scaled sprite copy) |
| `1020` | 5 | 0x67e | App shell: `APPABOUT`, `app_init`, `app_exit`, `app_message_loop`, `WinMain`, `app_idle`, `app_paint`, `APPWNDPROC`, `app_command`, `message_box_printf` (TIRO `1038`) |
| `1028` | 6 | 0x5fd6 | **The labyrinth**: the raycasting backdrop class (vtable `10c0:4842`), map placement, rendering, movement, the result (`PostMessage 0x40a`) |
| `1030` | 7 | 0xb5b | Occupancy grid, Backdrop/WinG (TIRO `1030`) |
| `1038` | 8 | 0x2e34 | SceneObject / Mover / Animation draw and movement, object list (TIRO `1028`) |
| `1040` | 9 | 0x102f | DIB load, palette, remap, `hmemmove_backward` (TIRO `1010`, the newer DIB module) |
| `1048` | 10 | 0x35c8 | Object3D / Moveable / Portable / Player / Exit (TIRO `1018`) |
| `1050` | 11 | 0xd5 | Conditions (TIRO `1050`) |
| `1058` | 12 | 0x1b0c | `game_handle_message` (5,887 bytes) and `game_take_exit` (TIRO `1040`) |
| `1060` | 13 | 0xcbb | DIB copy and transparent copy (`IntersectRect`; TIRO `1008`), plus two new functions `0960`, `0c49` |
| `1068` | 14 | 0x1f2f | **Scaled DIB copies** (huge pointers; 4 outer/inner pairs, two of them calling the 32-bit `1000:0024`/`1018:0024`) |
| `1070` | 15 | 0x313 | Scene create/dtor/add object/add exits (TIRO `1060`) |
| `1078` | 16 | 0xc10 | StatusBar and ControlPanel (TIRO `1058`) |
| `1080` | 17 | 0xb81 | The two draw-list classes (TIRO `1070`) |
| `1088` | 18 | 0x915 | `transrle.cpp`'s 16-bit side (3 functions, `GlobalAlloc`; called from the SceneObject draw code) |
| `1090` | 19 | 0x1d1 | The JARDIM Game subclass (TIRO `1048`) |
| `1098` | 20 | 0x33db | **Phase 1 scene** (`raymap1.dat`, `maos1.bmp`, …) |
| `10a0` | 21 | 0x4a4 | WaveMix wrappers (TIRO `1078`) |
| `10a8` | 22 | 0x3ee2 | **Phase 2 scene** (`raymap2.dat`) |
| `10b0` | 23 | 0x2c1a | **Phase 3 scene** (`raymap3.dat`) |
| `10b8` | 24 | 0x4b37 | CRT (large model, with the FP math library). `entry` is `10b8:001a` (NE CS:IP 24:001a); `0000–0011` is the segment prefix |
| `10c0` | 25 | 0x933a | Engine library: the **276 adjustor thunks** (`00e2–17a0`), SceneObjectVtbl defaults and getters, ctors and dtors, Game/Frame/Scene/Backdrop defaults, **all the vtables and vbtables** (`3f0e–933a`, 65 store targets, 1,460 far slots) and the engine strings |
| `10c8` | 26 | 0 file, 0xc alloc | A 12-byte uninitialised far data segment (NE flag 0x0c51). The Exit ctor (`10c0:8892`) stores the far pointer `10c8:0000` (an empty far string) |
| `10d0` | 27 | 0x1882 file, 0x8c98 alloc | DGROUP (NE auto-data). Heap 512, stack 4096; SS:SP = 27:0000 |
| `10d8`, `10e0` | — | 32 / 752 | Resources: one group icon and one icon (`AppIcon`) |
| `10e8` | — | 0x174 | 93 import thunks |

Ghidra misreads:
- The four 32-bit segments (`1000–1018`): each routine starts with the DPMI 16→32 switch and
  the rest decodes as garbage. Read them with `objdump -mi386` (`zig-out/jardim/seg_*.bin`).
- About **28 KB of 16-bit code** in `1058`, `10b0`, `10b8` and `10c0` was not disassembled (§3).

## 2. Entry and startup

| What | Where | Notes |
|---|---|---|
| `entry` | `10b8:001a` | NOITE's large-model startup (0.88 normalised-op ratio): `INITTASK`, `_cinit` (`00d8`), `_setargv` (`0aa6`), `_setenvp` (`0c50`), `crt_call_winmain` (`0a50`) |
| WinMain | `1020:021a` | TIRO's (1.00): the "O aplicativo já está aberto !!!" check, `GetProcAddress(GetModuleHandle("USER"), 11/182)` → SetSystemTimer/KillSystemTimer far pointers at `10d0:1882`/`1886` |
| app_init | `1020:0055` | RegisterClass and CreateWindow "Noite Animal Jardim" (`10d0:0016`); the game object is `g_game` far at `10d0:86e8` |
| APPWNDPROC | `1020:0353` | Was a function but unnamed. See §8 for the protocol; WM_CREATE calls `g_game->vtbl[6]` (onCreate), sets `10d0:005e` and `SetSystemTimer(hwnd, 10, 50)`; WM_DESTROY `KillSystemTimer(hwnd, 10)` |
| APPABOUT | `1020:0000` | Was a function (unlike TIRO), unnamed |
| game_handle_message | `1058:0000` | Slot 0 of the Game tables, **not a function** (5,887 bytes uncovered) |

## 3. Function boundaries

Before the fixes: **727 functions**: 634 code functions plus 93 import thunks. Only `entry` was
named (and the imports). The 16-bit segments had **33,827 uncovered bytes**, most in `10c0`
(18,167 including the tables), `1058` (5,887), `10b8` (4,863) and `10b0` (3,804). Ghidra's function-start
search found most of the module code; what it missed is what only a vtable points to.

| Fix | Script | Result |
|---|---|---|
| Vtable slots → functions | `JardimFarVtSlots.java` (new) | 65 vptr-store targets, 44 tables with slots, 1,460 slots, 500 distinct targets, **349 new functions** (`game_handle_message`, `_purecall`, all the SceneObjectVtbl defaults…). Every slot typed as a 4-byte pointer, every store given a DATA reference to its table |
| Adjustor thunks | `NearAdjustorThunks.java 10c0 00e2 17a0 far` (unchanged: it already handles `LES BX,SS:[BX+4]`) | **276 thunks** (53 fixed, 223 vtordisp); 275 already existed as slot targets, **16 bodies cut** back to their `JMPF` (Ghidra had run them on into the target) |
| Gap sweep | `CodeGapSweep.java` per segment | **43 more**: 15 CRT entries in `10b8`, 24 in `10c0`, 1 each in `1020`, `1028`, `1030`, `1078` |
| Dead jumps | `DeadJumps.java` | **70** unreachable `JMP rel16` after a jump to the epilogue, added to their functions |
| Dead blocks | `JardimDeadBlocks.java` (new) | **4** unreferenced arms after an unconditional `JMP` (no branch anywhere reaches them: a constant condition `/Od` kept): `1028:5982` and `59c9` (34 bytes each, in `1028:52a8`), `1068:0167` (63, in `1068:0000`), `1068:162b` (84, in `1068:1336`) |

After the fixes: **1,160 functions**: 93 import thunks, 276 adjustor thunks, 791 code
functions. What is still uncovered (4,806 bytes, not counting `1000–1018`):
- `10b8` (3,385): the **FP math library**: 8087 code with `FWAIT` prefixes and register-argument
  entries (`10b8:1cbe`, `255f`, `3239–38d9`, …) and its constant tables (`3ad6`, `3ff0`, `4020`,
  `456c`, `45a6`). It has no prologue for the sweep; nothing outside `10b8` calls it.
- `10c0` (681): engine strings, the vbtables, one-byte pads between functions.
- 3-byte gaps are gone; no data was decoded as code and no code was typed as data.

Large functions: `1028:2609` (6,170 bytes, the labyrinth backdrop's slot 23: movement, hits
and the result), `1058:0000` `game_handle_message` (5,887), `10a8:1103` (8,484), `1098:0f6e`
(6,325) and `10b0:10d0` (3,700): the three phase scenes' slot 18, the per-phase game tick.

Calling conventions as auto-analysis left them: 436 `__stdcall16far`, 134 `__cdecl16far`,
32 `__cdecl16near`, 6 `__stdcall16near`, 26 unknown. After `NearSignatures.java` (§6): 576
`__stdcall16far`, 137 `__cdecl16far`, 34/9 near (CRT), 98 tagged `sig?` (varargs `sprintf`,
the frameless CRT helpers, functions no caller cleans up after).

## 4. Shared code: what matches what

Normalised-op matching (`match.py`) and per-segment in-order alignment (`align.py`, the
max of the op-shape and feature ratios, Smith-Waterman, the same method as TIRO's) against
TIRO, and feature matching (field displacements, immediates, API names, far slot/4) against
NOITE:

| JARDIM | Twin | Aligned |
|---|---|---|
| `1020` app shell | TIRO `1038` | 10/10, all ≥ 0.78 |
| `1030` occupancy + backdrop | TIRO `1030` | 9/9 ≥ 0.69 |
| `1038` SceneObject/Mover/Animation/object list | TIRO `1028` | 48/53 ≥ 0.5 |
| `1040` DIB | TIRO `1010` | 11/11 ≥ 0.94 |
| `1048` Object3D/Moveable/Portable/Player/Exit | TIRO `1018` | 47/53 ≥ 0.5 |
| `1050` Conditions | TIRO `1050` | 4/4 |
| `1058` game handler | TIRO `1040` | 2/2 (0.61, 0.58) |
| `1060` DIB copy | TIRO `1008` | 4/6 (≥ 0.87) |
| `1070` Scene | TIRO `1060` | 4 of 7 |
| `1078` StatusBar/ControlPanel | TIRO `1058` | 17/18 |
| `1080` draw lists | TIRO `1070` | 11/11 |
| `1090` Game subclass | TIRO `1048` (role) | 6/6 |
| `10a0` WaveMix | TIRO `1078` | 11/11 ≥ 0.92 |
| `10b8` CRT | **NOITE `1008`** (large-model CRT) | 92 of 153 at ≥ 0.7 |
| `10c0` defaults, ctors | TIRO `1088` (order differs) | poor for tiny bodies: name by vtable slot |
| `1028`, `1068`, `1088`, `1098`, `10a8`, `10b0`, `1000–1018` | — | game-specific |

The CRT must be matched against NOITE, not TIRO: the names are the far-data ones (`_fmalloc`,
`_fstrcpy`, `_halloc`, `crt_huge_array_destruct`).

## 5. Vtables

The tables are in `10c0`, not in DGROUP. A slot is a dword whose segment word carries an NE
selector relocation into a code segment; a table starts at a vptr-store immediate. 16 runs of
3+ relocated dwords hold all 1,460 slots; DGROUP has 7 short runs more (CRT hooks and similar,
phase 3).

**SceneObjectVtbl has 97 slots: NOITE's 102 without `reoccupy` (0x29), `isAvi` (0x2d),
`advanceFrames` (0x36), `isAnimated3D`/`asAnimated3D` (0x4a/0x4b).** JARDIM slot *i* = NOITE
slot *i* for *i* ≤ 0x28, *i*+1 for 0x29–0x2b, *i*+2 for 0x2c–0x33, *i*+3 for 0x34–0x46,
*i*+5 from 0x47 on. It keeps NOITE's five leading slots (`slot00`, `slot01`, `enableRle`,
`isRle`, `getSceneName`) that TIRO and ENCAIXE do not have. The map is confirmed by the
override pattern of every class: Portable overrides 0x51/0x52 (`isPortable`/`asPortable`),
ControlPanel 0x4f/0x50, every Object3D 0x4b/0x4c, Mover 0x47/0x48, Animation 0x45/0x46, and
Player 0x3f, 0x41, 0x42 (`isScrollTarget`, `isPlayer`, `asPlayer`).

Other tables: Object3DVtbl 8 (NOITE 8), MoverVtbl 1, AnimationVtbl **6** (NOITE 8: two AVI
slots fewer), ControlPanelVtbl 14, BackdropVtbl 23 (NOITE 23), SceneVtbl 16 (NOITE 16), a
24-slot Scene subclass (`810a`, the labyrinth scene), GameVtbl 7 (TIRO 7), FrameVtbl 1,
ConditionVtbl 3 (×3). Pure virtual slots point to `_purecall` (`10b8:0816`).

## 6. Decompiler setup (applied)

The same three fixes as TIRO; they are stored in the program.
- **Spec extensions**: `cdecl16far_dx_ax.xml`, `cdecl16far_dxax_ptr.xml` and the call-fixup
  `aFchkstk_fixup.xml` are installed (`SpecExtension`). `10b8:02b6` is named `_aFchkstk` and
  carries the call-fixup `aFchkstk`. Before it, every frame aliased the outgoing pushes
  (`local_12 = &local_12; FUN_10b8_06a2(); local_12 = 0x158;` in `1028:2034`); after it the same
  body reads `sprintf(local_12); message_box_printf(0x158,…)`. The `_aFchkstk` return address
  still shows as a stray local (`uStack_6 = 0x203f`), as in TIRO.
- **Imports**: `CopyTypesFromProgram.java /NOITE.EXE` copied the 17 SDK structs and **83**
  import signatures (and renamed the 4 WinG ordinals). NOITE is large model too, so its
  signatures are right as they are; **do not** copy from TIRO or ENCAIXE afterwards (the script
  overwrites, and their pointers are near). 9 more typed by hand from the SDK, far pascal:
  `HMEMCPY`, `RECTANGLE`, `CREATESOLIDBRUSH`, `GETOBJECT`, `GETPALETTEENTRIES`,
  `GETNEARESTPALETTEINDEX`, `GETTICKCOUNT`, `FILLRECT`, `GETKEYSTATE`. `WIN87EM.__FPMATH` is
  register-based and stays untyped.
- **Mechanical conventions**: `NearSignatures.java` on all 16-bit segments
  (`regargs=10b8:0000-4b37`), see §3.
- **Still to do (phase 3)**: virtual calls still read `(*(code *)*puVar1)(0x10b8, this_lo,
  this_hi, …)`: a far slot is two 16-bit loads, so the slot prototype is never applied and the
  pushed `CS` leaks as a first argument. `FarSlotSignatures.java` fixes this once the vtable
  structs exist.

What the decompiler shows well already: the control flow (switches as compare chains, loops),
API calls with real arguments (`MCISENDSTRING(hwnd,0,0,"close musica")`,
`MESSAGEBOX(0x30,"Erro Wave Mix",…)`), the far `this` as `param_1`/`param_2` pairs. The
large-model NULL test of an adjusted `this` compares both words (`if (seg == 0 && off == 0)`),
so TIRO's `NearNullTests` problem (a constant printed as a DGROUP symbol) does not occur.

## 7. Strings and data (overview; `DATA.md` has the map)

- Ghidra defined 208 strings. The Portuguese ones are cut at the first accent ("todo
  CreatePlayer" starts in the middle of "Faltou redefinir o método CreatePlayer").
- DGROUP strings: the app name, the labyrinth errors ("Objeto posicionado fora do labirinto…",
  "…dentro de parede…"), the three phases' bitmaps, maps, MCI and wave names (each phase has its
  own copy), the CRT messages, the math library names (`sin`, `cos`, `tan`, `pow`, `log`,
  `exp`).
- Code-segment strings, in `10c0`: the engine's "Faltou redefinir o método …", "Não foi
  possível abrir o arquivo: %s", `MAX_OBJECT_QTY`, and `opcao1/2/3.bmp`.

## 8. How it talks to NOITE

NOITE (`handler_espquete`, `handler_4fjarvamp`) runs `<CD>jardim\jardim.exe`, polls
`FindWindow("Noite Animal Jardim")` on timer 0x14, then posts `0x40b` with **wParam = variant**
(1 from `espquete`, 0 from `4fjarvamp`) and lParam = its window.

JARDIM's `APPWNDPROC` differs from TIRO's and ENCAIXE's:
- At the top of **every** message: if `g_noiteWnd` (`10d0:002a`) is 0, it calls
  `FindWindow("Noite Animal", "Noite Animal")` and, if found, posts `0x40c` (wParam = its own
  window); otherwise, while `10d0:0060` is 0, it posts `0x40c` again. So 0x40c is re-posted on
  every message until NOITE answers. WM_SYSTIMER (0x118) repeats the FindWindow.
- **0x40a** from NOITE sets `10d0:0060` = 1 (stop re-posting).
- **0x40b** stores `g_noiteWnd = LOWORD(lParam)` and the **variant** `10d0:00b2 = wParam`, and
  posts 0x40c.
- Then every message goes to `g_game->vtbl[0]` (`game_handle_message`).

The result is posted from `1028:2609` (the labyrinth backdrop's slot 23):
- a loss: `score −= 1000; PostMessage(noite, 0x40a, 0, score)`;
- a win: `score += 1000000000 / (GetTickCount() − start)`, then
  `PostMessage(noite, 0x40a, 1, score)`;
  where the score is the word at backdrop+0x718 and `start` is the dword at `10d0:00ae`, the
  tick count of the first labyrinth created (§10, J1).

NOITE adds lParam to its score and goes to `6fsai1`/`6fsai2` on a win, `6fsaida` on a loss.

## 9. Scripts and specs

Applicable as they are: `CopyTypesFromProgram.java` (from NOITE only), `NearAdjustorThunks.java`
(`far`), `CodeGapSweep.java`, `DeadJumps.java`, `NearSignatures.java`, `ExportFunctionOps.java`,
`RenameFunctions.java`, `NoiteStructs.java`/`NoiteFieldSet.java` (far layouts, NOITE's syntax),
`FarSlotSignatures.java` (slot defs and call overrides; its vbtable fallback assumes TIRO's
+2/+4 vbtable rows and needs checking), `FarVtables.java` (its `dataseg` argument can be the
code segment `10c0`), `DefineStrings.java`, `UndefinedRanges.java`, `DumpListing.java`, and the
three `ghidra/cspec` files.

Not needed: `NearNullTests.java` (far NULL tests decompile cleanly), `NearVtSlots.java`/
`NearVtables.java` (near slots), `FarVtSlots.java` as it is (it scans a DGROUP range; JARDIM's
tables are interleaved with code in `10c0`, so a range scan would take every `CALLF` operand for
a slot).

New:
- `JardimFarVtSlots.java`: far vtables in a code segment, tables found from the far vptr
  stores (`MOV word ptr [r+k],off … MOV word ptr [r+k+2],seg` with a relocated `seg`).
- `JardimDeadBlocks.java`: folds the unreferenced `/Od` dead arms into their functions.

## 10. Candidate original bugs (for later)

- **J1, the time bonus.** The win bonus divides 10⁹ by `GetTickCount() − start`, but the code
  keeps only `AX` of the DX:AX tick count and sign-extends it (`CWD`) before the 32-bit
  subtraction (`1028:3d71–3d81`), while `start` (`10d0:00ae`) holds the full 32-bit tick
  (`1028:2191` stores DX:AX, once: flag `10d0:00b4`). So "elapsed" is
  `(long)(short)low16(now) − start`: once Windows has run for more than ~33 s it is usually a
  large negative number and the "bonus" a small negative one (about −10⁹/start); near a
  coincidence it is tiny or 0 (a huge bonus, or a divide error in `_aFldiv`).
- **J2, the 0x40c flood.** Until NOITE's 0x40a arrives, every window message (including every
  WM_MOUSEMOVE and timer tick) posts another 0x40c to NOITE (`APPWNDPROC`).
