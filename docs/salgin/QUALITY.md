# SALGIN.EXE: decompilation quality (phase 1)

This is the assessment of the Ghidra program `/SALGIN.EXE` as auto-analysis left it, before
anything was named or typed by hand, plus the program-wide decompiler fixes applied right after
it (§6). Addresses are Ghidra `seg:off`. The scratch tooling is in `zig-out/salgin/` and is not
committed: `segs.py`, `bmap.py` (byte alignment against TIRO), `vt.py`/`vtpair.py` (vtable
pairing), `thunks.py`, `cmp1.py`, `bodychk.py`, and the inline Ghidra scripts in `gs/`
(`SalginSurvey`, `SalginDump`, `SalginFnExport`, `SalginCrtFix`, `SalginMk`, `SalginSpec`,
`SalginAdjThunks`).

## 0. Headline: SALGIN is TIRO's build, with a different game

SALGIN ("Sala de Ginástica", the gym) is built **exactly like TIRO** (`docs/tiro/QUALITY.md`):
the same engine sources, the same compiler and options, the same link order.

- **Medium memory model** (far code, near data), **unoptimised (`/Od`)**, **with stack probes**.
  19 NE segments, the same 19 as TIRO, in the same order and nearly the same sizes (§1).
- Calls are far (`CALLF` 1,424 direct + 274 indirect; near `CALL` 35×, all in the CRT).
  Returns: `RETF n` 410×, `RETF` 85×, `RET` 9×, `RET n` 1×. `ENTER` occurs only twice.
  `this` is at **`[BP+6]`**.
- Data pointers are near (2 bytes, DS = SS = DGROUP). The vptr is a near pointer into DGROUP,
  and each **vtable slot is a 4-byte far code pointer** (NE-relocated). A virtual call is
  `MOV BX,[SI]; CALL dword ptr [BX+slot]`.
- Every function starts `PUSH BP; MOV BP,SP; MOV AX,<frame>; CALLF 1080:00e4`, the far stack
  probe `_aFchkstk` (453 callers, byte-identical to TIRO's). `/Od` leaves a `JMP` to the
  epilogue after each `case`/`return` and long `0F 8x` jumps. The two window callbacks use the
  `/GA` prologue `MOV AX,SS; PUSH BP; MOV BP,SP; PUSH DS; MOV DS,AX`.
- The CRT is the medium-model Windows library, TIRO's plus the `time()`/`_tzset` family
  (`time`, `__loctotime_t`, `_tzset`, `_isindst`, `getenv`, `strncmp`, `atol`/`atoi`,
  `_aFlrem`), linked for the game's random seed.
- The entry table is empty: SALGIN exports nothing. The NE description is
  "Sala de Ginastica".

What this means for the phases:
- **Everything shared with TIRO transfers byte for byte**: names, prototypes, struct layouts,
  vtable structs (4-byte slots) and slot meanings. TIRO is already fully mapped, so it is the
  twin, not ENCAIXE: segment by segment the bytes are 91–100 % identical (§1), and a plain
  byte alignment maps every TIRO function of the engine segments onto a SALGIN function.
- Only the game itself is new: segment `1068`, the game subclass in `1048`, and the game's
  classes in `1088` (their ctors, overrides and thunks).
- Game code is far pascal (`__stdcall16far`, parameters reversed, `this` first at `[BP+6]`,
  2-byte data pointers), as in TIRO.

## 1. Segments

| Ghidra | NE | Size | vs TIRO (bytes, relocations unapplied) | Holds |
|---|---|---|---|---|
| `1000` Code1 | 1 | 0x1a5 | 0.999 | The WinG sample's 32-bit blitters (`FAST32.ASM`, not `transrle.cpp`) (`0024`, `0114`), as in NOITE/ENCAIXE/TIRO. Not typed. |
| `1008` | 2 | 0x988 | 0.995 | DIB copy and transparent copy |
| `1010` | 3 | 0x1044 | **identical** | DIB load, palette, remap |
| `1018` | 4 | 0x21c8 | 0.975 | Object3D / Moveable / Portable / Player / Exit |
| `1020` | 5 | 0x297 | 0.983 | Perspective backdrop, layers |
| `1028` | 6 | 0x1d25 | 0.958 | SceneObject / Mover / Animation / Player2D / object list |
| `1030` | 7 | 0x8f3 | 0.973 | Occupancy grid, Backdrop (WinG). `backdrop_autoscroll` is cut short (§3) |
| `1038` | 8 | 0x5b5 | 0.908 | App shell: APPABOUT, app_init, WinMain, APPWNDPROC… |
| `1040` | 9 | 0x10aa | 0.980 | `game_handle_message` (3,688 bytes), `game_take_exit` |
| `1048` | 10 | 0x2ab | 0.786 | The SALGIN Game subclass: ctor, createPlayer, panel, status bar, init scene, onCreate |
| `1050` | 11 | 0xb5 | 0.934 | Conditions module |
| `1058` | 12 | 0x743 | 0.980 | StatusBar, ControlPanel |
| `1060` | 13 | 0x139 | 0.957 | Scene create / add object / add exit |
| `1068` | 14 | 0x2d7a | 0.168 | **The SALGIN game**: the fighters, the energy bar, the round clock, waves, the scene handler `0d73` (7,227 bytes) |
| `1070` | 15 | 0x67a | 0.971 | The two draw lists |
| `1078` | 16 | 0x4a2 | 0.835 | WaveMix wrappers (`wave_play` is 9 bytes longer) |
| `1080` | 17 | 0x1d73 | 0.835 | CRT (TIRO's + the time family, +0x512 bytes). `entry` at `001a` |
| `1088` | 18 | 0x6980 | 0.761 | Adjustor thunks (`005a–1b39`, `4ade–547d`), SceneObjectVtbl defaults and getters, ctors/dtors, Game/Frame init, and the game classes' ctors and overrides |
| `1090` Data19 | 19 | 0x6658 | — | DGROUP. Initialised data ends at `26e2`; the file carries the BSS as zeros up to `6657` (TIRO's NE segment stops at its initialised part). Heap 512, stack 4096 |
| `1098`, `10a0` | — | 32 / 752 | — | Resources: one group icon and one icon (`AppIcon`) |
| `10a8` EXTERNAL | — | 0x178 | — | 94 import thunks, the same 94 as TIRO |

## 2. Entry and startup

As TIRO (`docs/tiro/QUALITY.md` §2), at the same addresses: `entry` `1080:001a`, WinMain
`1038:0202` ("O aplicativo já está aberto !!!", SetSystemTimer/KillSystemTimer through
`GetProcAddress(GetModuleHandle("USER"), 11/182)`), app_init `1038:0055` (class and title
"Sala de Ginástica", `1090:00aa`, NOITE's `FindWindow` target), APPWNDPROC `1038:0335`
(unnamed, no references), APPABOUT `1038:0000` (not a function). The game ctor is
`1088:55fa` (`game_ctor`, the base) and `1048:0000` (the derived one, which stores
`1090:661a`). The Game vtable slot 0 is `game_handle_message` `1040:0000`, which Ghidra had
not made a function.

## 3. Function boundaries

Counts before any fix:
- 706 functions: **518 code functions**, 94 import thunks and 94 externals.
- One name: `entry`; the imports have their module names. Conventions guessed: 409
  `__stdcall16far`, 86 `__cdecl16far` (one of them a thunk), 9 `__cdecl16near`, 1
  `__stdcall16near`, 13 unknown.

Ghidra's function-start search did as well as on TIRO, but as there nothing typed the vtables,
so no vtable slot made a reference. **20,842 bytes** of `1008–1088` were uncovered, in 175
ranges: 13.9 KB in `1088`, 3.7 KB in `1040` (the missing `game_handle_message`), 2.3 KB in
`1080`, 585 bytes in `1030`.

What was missing, and what finds it (all of it the TIRO procedure, `docs/tiro/FUNCTIONS.md`):
- **Vtable slots.** `1090:0722–242b` holds **1,660 far slots** (every one with an NE
  relocation) in 55 tables, with 547 distinct targets; **409 targets were not functions**.
  69 vptr stores (`MOV word ptr [r+k],imm`) point at the tables. `FarVtSlots.java 1090 0722 242c`.
- **Adjustor thunks: 451** (TIRO 368): 75 fixed (`SUB SS:[BX+4],imm`: −0x484 ×17, −0x486 ×14,
  6/8/10/12/20) and 376 vtordisp, in two blocks of `1088`: `005a–1b39` (335) and `4ade–547d`
  (116). Their targets: `1088` 292, `1018` 82, `1028` 62, `1068` 12, `1058` 3. The extra ones
  over TIRO belong to the game's three Actor2D-derived classes. `NearAdjustorThunks.java … far`.
  The script needs one guard here (a vtordisp thunk's second `MOV BX,SP` made into a function
  by mistake crashes it); the run used a local copy with it (`gs/SalginAdjThunks.java`).
- **Gap sweep** (`CodeGapSweep.java`): `1038:0000` APPABOUT, `1020:0000`, 4 CRT entries, 7 in
  `1088`.
- **The CRT by hand**, TIRO's list at SALGIN's addresses (`gs/SalginCrtFix.java`): FATALEXIT
  no-return (so `_amsg_exit` `0879` stops before `_flsbuf` `08bc`), the `INC BP` prologues
  `_nrealloc` `0f1c` and `_nmsize` `0f8a` (Ghidra had them one byte late), the `_output` jump
  table (`1080:09ae`, 8 words, `JMP CS:[BX+0x9ae]` at `0a17`), and the frameless entries
  `_aNchkstk` `00c4`, `_cintDIV` `0874`, `crt_dosret_maperr` `161d`, the heap helpers
  `1674`/`1700`/`1766`, `crt_ltoa_body` `1d14`. `_output`'s epilogue `0e9a` had been split off
  as its own function (a `JMP` flagged `CALL_RETURN`); it is merged back.
- **Dead jumps** (`DeadJumps.java`): 52 unreachable `JMP rel16` after `case`/`return` jumps.

Bad splits and merges: none beyond the CRT ones above. No data decoded as code.

One real difference from TIRO: **`backdrop_autoscroll` (`1030:0691`) returns 0 right after its
prologue** (`MOV AX,0; JMP epilogue`), so its 576-byte body `06ad–08ec` is unreachable. TIRO's
version does the scroll. It is left undefined, as dead code inside the function's range.

Large functions: `1068:0d73` (7,227 bytes, the scene handler), `1040:0000` (3,688),
`1018:0290` (914, `object3d_draw_bounds`), `1010:0c90` (942).

## 4. Shared code: matching against TIRO

TIRO is the twin. A byte alignment per segment (`bmap.py`: difflib matching blocks on the raw NE
segments, each TIRO function entry mapped through the block it falls in) gives:

| Segments | TIRO functions mapped onto an existing SALGIN function |
|---|---|
| `1000`–`1060`, `1070`, `1078` | **all** (2+4+11+51+7+49+9+10+2+6+4+15+4+11+11) |
| `1080` | 64 of 81 before the CRT fixes, 81 of 81 after |
| `1088` | 547; 137 TIRO functions (its game classes) have no counterpart, and 224 SALGIN ones are new (the extra thunks and the game classes) |
| `1068` | meaningless (0.17): a different game |

Checks on the byte mapping:
- It is only trusted outside `1068`, and the 1048 matches are taken as roles (the
  `tiro_game_*` names become `salgin_game_*`).
- Every mapped function in a vtable slot is cross-checked against the TIRO table of the same
  class (`vtpair.py`): 171 agree and 2 disagree. Both are in the run of Backdrop default stubs
  `1088:5cd6–5dd0`, which is longer in SALGIN, so the alignment slid by one stub there. The slot
  wins. `grid_backdrop_ctor` is `1088:5dec` (its only vptr store), not `5d98`.
- Bodies compared on the relocated bytes (`bodychk.py`): 78 of 569 pairs differ by more than 7 %,
  nearly all through DGROUP offsets (vptr and string immediates) and the probe call in tiny
  stubs. The real code differences are few: `backdrop_blit_to_dc` (`1088:4244`, 73 vs 52 bytes,
  selects and realizes the palette first), `animation_tick` (165 vs 193), `APPWNDPROC` (560 vs
  578), `wave_play` (182 vs 173), `mover_move_tick`, `scene_object_redraw_overlapping`,
  `animation_stop_and_redraw_dc` (−6 bytes each), `backdrop_autoscroll` (§3).

## 5. Imports

The same 94 imports as TIRO (WAVEMIX, KERNEL, GDI, USER, WING, MMSYSTEM), all untyped. Seven
are unreferenced (`LOCALREALLOC`, `LOCALSIZE`, `GLOBALSIZE`, `__AHSHIFT`, `__AHINCR`,
`__WINFLAGS`, `ENDDIALOG`, the last called from APPABOUT). `CopyTypesFromProgram.java /TIRO.EXE`
types all 94 in one run (TIRO has them all typed, including the 5 that NOITE lacks) and renames
the 4 WinG ordinals. The 17 SDK structs come with it.

## 6. Decompiler setup (applied in phase 1)

- `CopyTypesFromProgram.java /TIRO.EXE`: 17 SDK structs, 94 import signatures, 4 WinG names.
- Spec extensions installed (`gs/SalginSpec.java`, `SpecExtension.addReplaceCompilerSpecExtension`):
  `ghidra/cspec/cdecl16far_dx_ax.xml`, `cdecl16far_dxax_ptr.xml` and the call-fixup
  `aFchkstk_fixup.xml`.
- `1080:00e4` named `_aFchkstk` and given the call-fixup `aFchkstk`: every frame is
  allocated, and outgoing pushes no longer alias locals. As in TIRO, the probe's far return
  address stays in the two words below `BP`.

Still to do (phase 2/3): virtual-call overrides (`FarSlotSignatures.java`, after the vtable
structs exist), `this` types, the `__stdcall16far_pop<n>` models it installs.

## 7. Decompiler output before typing

| Issue | State |
|---|---|
| Signatures | Parameter counts from `[BP+n]` are right; types `int`/`undefined2`. |
| Junk at call sites | Every untyped API call (`MCISENDSTRING(0x1080,…)`) until the imports were typed. |
| C++ virtual calls | `(*(code *)*(vbase(p)+2 + slot))(junk CS, …)` with the vbase lookup `p + *(int *)(*(int *)(p+2)+2) + 2`, as in TIRO. Readable once the vtable structs and overrides exist. |
| Globals | The game objects are BSS words `1090:661a–6622`; strip tables and per-strip tables are indexed DGROUP arrays (`*(int *)(strip * 2 + 0x192)`). |
| Strings | All in DGROUP, none in code segments. Ghidra defined 73; several are cut at `ã`/`á`/`í`/`ú` (`DefineStrings.java` in phase 3). |
| Overall | Good control flow; `/Od` bodies are long and literal. The scene handler is a WM switch with an inner key switch. |

## 8. The scripts

Applies as is: `CopyTypesFromProgram`, `FarVtSlots`, `NearAdjustorThunks` (`far`),
`CodeGapSweep`, `DeadJumps`, `FarVtables`, `FarSlotSignatures`, `NearStructs`, `NearGlobals`,
`NearThisTypes`, `NearNullTests`, `DefineStrings`, `NoiteStructs`/`NoiteFieldSet`,
`RenameFunctions`, `UndefinedRanges`; the three `ghidra/cspec` files.

New: **`SalginCopyFromTwin.java`**: copies a twin program's category of types (`/tiro` →
`/salgin`) and, from a TSV of `own TAB twin TAB method` rows, the names, prototypes (types
mapped into the own category), no-return/call-fixup flags, tags and plates of the twin's
functions. It is generic: any minigame built from TIRO's sources can use it.

## 9. What the game is (first look)

A **one-on-one fight** ("porrada") at the gym, played with the keyboard against a computer
opponent, against a round clock. NOITE's `handler_4fsalgin` (`src/handlers/4fsalgin.zig`)
starts `salgin\salgin.exe` after the gym scene's animation, hands it the main window (0x40b)
and gets 0x40c back, as for every minigame. On WM_DESTROY the scene handler posts
**`0x40a(won, score)`**: `won` = the player's energy is not below the opponent's,
`score` = player energy × 100 on a win and −1000 on a loss. The rules are in `DATA.md`.
