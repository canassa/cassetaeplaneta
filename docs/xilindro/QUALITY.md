# XILINDRO.EXE: decompilation quality (phase 1)

This assesses the Ghidra program `/XILINDRO.EXE` as auto-analysis left it, before any naming or
typing, and lists the program-wide fixes applied right after. Addresses are Ghidra `seg:off`.
The scratch survey and matchers are in `zig-out/xilindro/` (not committed): `init/` holds the
untouched survey (`funcs.tsv`, `uncovered.tsv`, `data.tsv`, `blocks.tsv`), `gs/` the scratch
Ghidra scripts (`XilindroSurvey`, `XilindroRawOps`, `XilindroVtDump`, `XilindroDataRefs`,
`XilindroDataDump`, `XilindroDecAll`), and `xalign.py`, `exact3.py`, `vtcmp.py`, `dgmap*.py` the
offline matchers against TIRO.

## 0. Headline: XILINDRO is TIRO's build, with another game

XILINDRO is built exactly like TIRO.EXE (`docs/tiro/QUALITY.md` §0): **medium memory model, `/Od`,
stack probes**, MSVC 1.5x (LINK 5.60), the WinG skeleton, the same engine library. The NE header
is TIRO's (flags 0x302, heap 512, stack 4096, CS:IP `1080:001a`, 19 segments, 6 import modules,
empty entry table), and the 19 segments have TIRO's roles in TIRO's order. Most module segments
differ from TIRO's by a few bytes.

- Far code, near data: one code segment per module, calls `CALLF` (near `CALL` only in the CRT),
  `this` at `[BP+6]`, data pointers 2 bytes (DS = SS = DGROUP).
- The vptr is a near pointer into DGROUP; every **vtable slot is a 4-byte far pointer** with an NE
  relocation. A virtual call is `MOV BX,[SI]; CALLF [BX+slot]`.
- Every function starts `PUSH BP; MOV BP,SP; MOV AX,<frame>; CALLF 1080:00e4` (`_aFchkstk`,
  **453 callers**); `/Od` leaves a dead `JMP` to the epilogue after each `return`/`case`.
- The two window callbacks use the `/GA` prologue (`MOV AX,SS; PUSH BP; MOV BP,SP; PUSH DS`).
- Game code is far pascal (`__stdcall16far`, `RETF n`); some helpers are far cdecl.

So everything TIRO's phases 2-3 learnt transfers: the same scripts, the same cspecs, and **the
names, prototypes and struct layouts of TIRO itself**. With identical compiler settings the code
of the shared modules matches TIRO's instruction for instruction (pair ratio 0.8-1.0 on
normalised opcodes, struct offsets equal); ENCAIXE and NOITE are only needed through TIRO.

What differs from TIRO:
- **The game**: `1048` (the Game subclass) and `1068` (the scene: a street fight against a jail
  inmate, see `DATA.md`) are new; `1088` holds four new game classes instead of TIRO's four.
- **The CRT** (`1080`) is 0x512 bytes larger: it links `time` and its helpers (`__loctotime_t`,
  `__tzset`, `_tzset`, `_isindst`, `getenv`, `strncmp`, `atoi`/`atol`, `_aFlrem`), because the
  game calls `srand(time(0))`. The time-zone data (`TZ`, `PST`/`PDT`, `_timezone`, `_days`) is in
  DGROUP.
- **DGROUP is stored whole in the file**: file length = allocation = 0x669c. TIRO's file stops at
  the end of the initialised data (0x255d of 0x64ca); here the 0x3f74 bytes of BSS from `2728`
  are written out as zeros. Harmless.
- **A few engine bodies changed**, all small (`exact3.py` found no struct-offset difference):
  - `backdrop_autoscroll` (`1030:0691`) starts with `return 0`: the 576 bytes of TIRO's body are
    still there, unreachable (`/Od` keeps them). Autoscroll is disabled.
  - `mover_move_tick`, `scene_object_redraw_overlapping`, `animation_stop_and_redraw_dc` and
    `animation_tick` call SceneObject slot 0x1e (`invalidate`, `this` only) where TIRO calls slot
    0x1d (`blitToDc`, `this`, backdrop, hdc).
  - `wave_play` (`1078:01e6`) computes its WaveMix flags: `5 | (hWndNotify == 0 ? 2 : 0)`, i.e.
    `CLEARQUEUE|HIGHPRIORITY` (5) with a notify window and `CLEARQUEUE|USELRUCHANNEL|HIGHPRIORITY`
    (7) without one; every call in XILINDRO passes `hWndNotify` 0, so every wave gets 7. TIRO always
    passes 5.
  - `mover_step` takes the same Bresenham step as TIRO's with a shorter body; `WinMain` resolves the
    timer ordinals before `GetModuleFileName` (TIRO the other way round); `APPWNDPROC` plays no wave
    on WM_PAINT; `game_take_exit` differs by a few instructions.
- **Three switch jump tables** in `1068` (`2d0c` in a sound helper, `208a` and `22ac` in the scene
  handler, for the dense key-code switches `0x21-0x2d`). Ghidra resolved them by itself. TIRO had
  none besides the CRT's `_output` (its switches compiled as compare chains).

## 1. Segments

| Ghidra | NE | Size | Holds |
|---|---|---|---|
| `1000` Code1 | 1 | 0x1a5 | The WinG sample's 32-bit blitters (`FAST32.ASM`, not `transrle.cpp`) (flag 0x2c50), TIRO's two routines `0024`, `0114`. Not typed |
| `1008` | 2 | 0x988 | DIB copy / transparent copy (TIRO `1008`, same size) |
| `1010` | 3 | 0x1044 | DIB load, palette, remap (TIRO `1010`, same size) |
| `1018` | 4 | 0x21c8 | Object3D / Moveable / Portable / Player / Exit (TIRO 51 functions, same order) |
| `1020` | 5 | 0x297 | Perspective backdrop and layers |
| `1028` | 6 | 0x1d0b | SceneObject / Mover / Animation / Player2D / object list (TIRO 49, −0x48 bytes) |
| `1030` | 7 | 0x8f3 | Occupancy grid, Backdrop; `backdrop_autoscroll` disabled (above) |
| `1038` | 8 | 0x5b5 | App shell: APPABOUT, `app_init`, `WinMain`, `APPWNDPROC`, `message_box_printf` |
| `1040` | 9 | 0x10aa | `game_handle_message` (`0000`, 3,691 bytes), `game_take_exit` |
| `1048` | 10 | 0x2ab | XILINDRO's Game subclass: ctor, createPlayer (the Fighter), panel, status bar (font "Virtual"), init scene, onCreate |
| `1050` | 11 | 0xb5 | Conditions module (static FlagConditions) |
| `1058` | 12 | 0x743 | StatusBar and ControlPanel |
| `1060` | 13 | 0x139 | Scene create, add object, add exit |
| `1068` | 14 | 0x2e95 | **The fight**: Fighter / Opponent / EnergyBar methods, the scene handler `0d79` (7,482 bytes), MCI + 8 waves, the clock |
| `1070` | 15 | 0x67a | The two draw-list copies |
| `1078` | 16 | 0x4a2 | WaveMix wrappers |
| `1080` | 17 | 0x1d73 | CRT (`entry` `001a`; `0000-0011` segment prefix) |
| `1088` | 18 | 0x617a | Adjustor-thunk blocks `0000-1334`, `42d8-4c7d`; SceneObjectVtbl defaults, getters, ctors/dtors, Game/Frame init; the game-class ctors and type tests |
| `1090` Data19 | 19 | 0x669c (file = alloc) | DGROUP; BSS from `2728` |
| `1098`, `10a0` | — | 32 / 752 | Resources: group icon and `AppIcon`. No dialogs |
| `10a8` EXTERNAL | — | 0x178 | 94 import thunks |

## 2. Entry and startup

The same as TIRO's (`docs/tiro/QUALITY.md` §2): `entry` `1080:001a` → `_cinit`, `_setargv`,
`_setenvp` → `WinMain` `1038:0202`, which gets USER.11/USER.182 (SetSystemTimer/KillSystemTimer)
into `1090:64dc`/`64e0` and refuses a second instance ("O aplicativo já está aberto !!!").
`app_init` (`1038:0055`) registers and creates the 640×480 window **"Xilindro"** (`1090:00aa`,
NOITE's `FindWindow` target) and builds the game (`xilindro_game_ctor` → `g_game` `665c`,
`g_xilindroGame` `665e`). Ghidra had found `entry` and nothing else by name; APPABOUT
(`1038:0000`) and `game_handle_message` (`1040:0000`) were not functions.

## 3. Ghidra's auto-analysis (before any fix)

- **612 functions**: 518 code functions + 94 import thunks. Named: `entry` and the imports.
  Conventions guessed: 409 `__stdcall16far`, 86 `__cdecl16far`, 10 near, 13 unknown.
- **Uncovered code: 18,788 bytes of 81,666 (23 %)** in 176 ranges, the same picture as TIRO:
  `1088` 11,848, `1040` 3,691 (`game_handle_message`), `1080` 2,275, `1030` 585 (the dead tail of
  `backdrop_autoscroll`), `1068` 98 (dead jumps and the three jump tables), `1038` 91 (APPABOUT),
  `1020` 63, `1058` 53, `1070` 33, `1010` 21, `1028` 18, `1018` 12.
- **Vtables never typed**: `1090:0766-2458` holds **1,660 relocated far slots, 547 distinct
  targets, 409 of them not functions**, and 68 vptr stores. No slot made a reference.
- **357 adjustor thunks missing** (TIRO 368): `1088:0000-1334` 241 (37 fixed, 204 vtordisp, same
  as TIRO) and `1088:42d8-4c7d` 116 (21 fixed, 95 vtordisp; TIRO 127).
- **CRT fragments without prologue**: `_output` (`09be`, 1,150 bytes, its 8-word jump table at
  `09ae` untyped and its 7 near helpers), `_amsg_exit` ran on into `_flsbuf` (no-return
  `FATALEXIT`), the `INC BP` far prologues one byte early (`0f1c`, `0f8a`), and the frameless
  entries `_aNchkstk` `00c4`, `_cintDIV` `0874`, `crt_dosret_maperr` `161d`, the heap helpers
  `1674/1700/1766`, `crt_ltoa_body` `1d14`. All are TIRO's, moved by a constant per region
  (`crtmap.py` checks the bytes).
- No bad splits or merges; no data decoded as code. Ghidra found 250+ unreferenced functions by
  prologue, as in TIRO.
- **Imports**: 94, the same modules, names and order as TIRO; all untyped. `MESSAGEBOX(0x1078,…)`-
  style junk at every call site.
- **Types**: the data type manager was empty (5 built-ins); the 6 stock conventions only.
- **Strings**: Ghidra defined 84 in DGROUP; a Latin-1 scan finds 87 real ones plus the 11 NMSG
  texts. Many are cut at `ã`/`é`/`í` (`"mero de HDCs"`, `"o consegue ativar"`, `" aberto !!!"`) or
  start mid-way (`"es de tela\nAumente…"`), as in TIRO.
- **Decompiler**: the same as TIRO before its fixes: `FUN_1080_00e4()` at the top of every body,
  outgoing pushes aliased with locals, far virtual calls decoded with the pushed `CS` as an extra
  first argument (`(*(code *)*puVar1)(0x1080, this, …)`), vbase arithmetic
  `p + *(int *)(*(int *)(p + 2) + 2) + 2` everywhere. Control flow is good.

## 4. Program-wide fixes applied (phase 1)

| Fix | How | Result |
|---|---|---|
| Spec extensions | `ghidra/cspec/cdecl16far_dx_ax.xml`, `cdecl16far_dxax_ptr.xml`, `aFchkstk_fixup.xml` installed with `SpecExtension` | far 32-bit returns; the `_aFchkstk` call-fixup |
| Stack probe | `1080:00e4` named `_aFchkstk`, call-fixup `aFchkstk` set | frames allocated; no more aliasing |
| SDK types and imports | `CopyTypesFromProgram.java /TIRO.EXE` | the 17 SDK structs; **all 94 imports typed and the 4 WinG ordinals renamed**, nothing left untyped |
| Timer pointers | `CopyTypesFromProgram.java /TIRO.EXE SetSystemTimerFn KillSystemTimerFn` | `g_setSystemTimer`/`g_killSystemTimer` typed, their 13 call sites overridden (phase 3) |

## 5. Scripts

All existing far-model scripts apply as they are (TIRO's arguments, other ranges):

| Script | Here |
|---|---|
| `FarVtSlots.java` | `1090 0600 2700`: 1,660 slots, 408 functions created |
| `NearAdjustorThunks.java` (`far`) | `1088 0000 1335 far`, `1088 42c0 4c7e far`: 357 thunks |
| `CodeGapSweep.java` | per segment: 14 in `1088`, 4 in `1080`, `1020:0000`, `1038:0000` |
| `DeadJumps.java` | all code segments: 52 dead jumps |
| `NearSignatures.java` | conventions of what TIRO could not provide (`regargs=1080:0000-1d73`) |
| `FarVtables.java`, `FarSlotSignatures.java`, `NearStructs.java`, `NearGlobals.java`, `DefineStrings.java`, `NearNullTests.java`, `RenameFunctions.java`, `ExportFunctionOps.java` | phases 2-3 |

New, because the twin is a *typed* program (TIRO), not just a name source:
- **`XilindroCopyCategory.java`**: copies a data type category of another program into this one
  under another name (`/tiro` → `/xilindro`), with an exclusion regex for the twin's own game
  classes. 212 types + their pointers (engine structs, 13 vtable structs, 180 slot definitions).
- **`XilindroCopyPrototypes.java`**: copies calling convention, return type, parameter names and
  types (remapped into `/xilindro`), varargs, no-return and the `sig?` tag from matched twin
  functions. 584 prototypes.

Scratch only (inline, deleted after use, kept as notes in `zig-out/xilindro/`): the CRT boundary
fix (TIRO's `TiroCrtFix` with XILINDRO offsets), the body extension of `backdrop_autoscroll` over
its dead tail, the rename-with-plate pass for the game names.

## 6. Verdict

Ghidra's raw analysis is as weak as on TIRO (a quarter of the code uncovered, no vtable, no type),
but nothing is new: the TIRO tooling repairs it completely. Because XILINDRO is a same-settings
build of the same engine, **the shared code maps 1:1 to TIRO's fully typed program**: 578 names
and 584 prototypes copied by in-order alignment, the engine structs copied unchanged. The only
real reading is the game (`1048`, `1068`, 13 functions in `1088`): about 53 functions, one of them
the 7.5 KB scene handler.

Final state (after phase 4 and the cleanup): 1,090 functions (94 imports, 357 adjustor thunks, 639
code functions, 634 named, 5 dead `FUN_`), 0 `sig?`/`review` tags, 382 call-site overrides (every
indirect call but the 11 CRT function-pointer calls), uncovered code only data and padding
(`FUNCTIONS.md`). `_output` (`1080:09be`) still fails to decompile.
