# ENCAIXE.EXE: decompilation quality (phase 1)

This is a read-only assessment of the Ghidra program `/ENCAIXE.EXE` in its
current state: auto-analysis only, nothing named or typed by hand.
Addresses are Ghidra `seg:off`. The scratch matchers are in `zig-out/encaixe/`
and are not committed: `ne.py`, `opmatch.py`, `fuzzy.py`, `prolog.py`, `vt.py`.

## 0. Headline: ENCAIXE is a small-model build

NOITE is built with far code and far data. ENCAIXE is built in the **small
memory model**. It runs the same engine sources ("Faltou redefinir o método
CreatePlayer/CreateInitScene/…", `MAX_OBJECT_QTY`, the occupancy matrix), but:

- All game and CRT code is in one segment (`1008`). Calls are **near** (`E8`), returns are
  **near** (`RET n` 436×, `RET` 104×, `RETF` 5×), and `this` is at `[BP+4]`.
- Data pointers are **near**, 2 bytes, with DS = SS = DGROUP. Vtables hold near code
  offsets, and a virtual call is `MOV BX,[SI]; CALL word ptr [BX+slot]` (298 sites).
- The functions have no `PUSH DS; MOV AX,DGROUP; MOV DS,AX` prologue. NOITE's
  `MOV ES,[0x11xx]` DGROUP idiom does not occur (only 2 `MOV ES,[0x10a]`, the CRT's PSP).
- The CRT is the small-model Windows library: near `_nmalloc` over `LocalAlloc`, and
  near cdecl.

What this means for the phases:
- NOITE's struct layouts do **not** transfer byte for byte. Every embedded far
  pointer shrinks to 2 bytes. Example: the virtual-base adjustment in the adjustor
  thunks is 0x484 here and 0x4be in NOITE.
- NOITE's names, field order and slot meanings do transfer.
- `ghidra-fix-signature` assumes far pascal. Here game code is **near pascal**:
  `__stdcall16near`, parameters reversed, `RET n` = total argument bytes, first
  parameter at `[BP+4]`.

## 1. Segments

| Ghidra | NE | Size | Holds |
|---|---|---|---|
| `1000` Code1 | 1 | 0x1a5 | The 32-bit `transrle.cpp` blitters. The segment has NE flag 0x2000 (32-bit) and is **byte-identical to NOITE's 1000**. It has 2 functions, `1000:0024` = `dib_rows_copy_transparent32` and `1000:0114` = `dib_rows_copy32`. Ghidra decodes them as 16-bit, so the listing is garbage past the prologue. Copy the names from NOITE and don't type them. |
| `1008` Code2 | 2 | 0xfcd2 | All other code: the CRT (`0012–1bde`), the WinG/DIB helpers, the engine, the app shell, the game. `entry` is at `1008:0018`, with its body starting at `0012`. |
| `1010` Code3 | 3 | 0x34 | `?APPABOUT@@…` (far, `RETF 0xa`). `1010:002e` holds a 6-byte stub, `CALLF 1008:b064; RETF`. It is not a function and has no references yet. |
| `1018` Data4 | 4 | 0x14bd file, 0x5410 alloc | DGROUP. The NE header gives a heap of 512 and a stack of 10240. |
| `1020` Rsrc0, `1028` Rsrc1 | — | 32 / 752 | Resources: one group icon and one icon (`AppIcon`). There are no dialogs, although `ENDDIALOG` is imported for `APPABOUT`. |
| `1030` EXTERNAL | — | 0x160 | 88 import thunks of 4 bytes each. This is NOITE's `1108`. |

Ghidra misreads two things:
- Segment 1000, as described above.
- About **41 % of 1008**: 26,272 bytes in 90 gaps are left undefined and never disassembled. See §3.

## 2. Entry and startup

| What | Where | Notes |
|---|---|---|
| `entry` | `1008:0018` | `INITTASK`, version, `_cinit` (`038e`), `_setargv` (`0540`), then `crt_call_winmain`. Its fuzzy match to NOITE's `entry` is 0.78: NOITE has an extra `LockSegment(-1)`. |
| crt_call_winmain | `1008:0372` | Calls WinMain. |
| WinMain | `1008:89cc` | If `hPrevInstance` is set, shows `MessageBox("O aplicativo já está aberto !!!")`. Otherwise it reads `GetModuleFileName` into `1018:528a`, and resolves `GetProcAddress(GetModuleHandle("USER"), 11)` → `1018:5272` (SetSystemTimer) and `…182` → `1018:5276` (KillSystemTimer). Then it runs `app_init` → `app_message_loop` → `8970`. |
| app_init | `1008:8886` | RegisterClass, CreateWindow, then the game ctor `9e28`. Matches NOITE `app_init` at 0.78. |
| app_message_loop | `1008:8988` | PeekMessage, Translate, Dispatch, WaitMessage, and an idle hook at `8a96`. Matches NOITE at 0.75. |
| `?APPWNDPROC@@…` | `1008:8ae4` | Far, exported. It first forwards every message to `g_game->vtbl[0]`. It also handles WM_CREATE (`vtbl[6]`, then SetSystemTimer(hwnd, 1, 50)), WM_DESTROY (KillSystemTimer, PostQuitMessage), WM_PAINT, WM_ACTIVATEAPP (`1018:5280`), WM_QUERYNEWPALETTE/WM_PALETTECHANGED, WM_COMMAND (`8c84`) and **0x40b** (`g_noiteWnd 1018:0026 = LOWORD(lParam)`). It posts **0x40c** once (flag `1018:002c`). |
| game ctor | `1008:9e28` | Stores vptr 0x7fe and then 0xf62 (derived), sets `g_game = 1018:53f2` and `1018:53f4`. |
| game handle_message | `1008:8eca` | Vtable `0x7fe/0xf62` slot 0. About 3.5 KB. It is **not a function in Ghidra** (gap `8eca–9c65`). |

## 3. Function boundaries

These are the counts now:
- 453 functions in total: 277 code functions plus 88 import thunks in `1030`
  plus 88 external entries.
- 11 code functions have names: entry, APPWNDPROC, APPABOUT, and the
  CRT/import ones Ghidra named.
- By region (rough; the split between engine and game is not settled): CRT
  82, DIB 11, engine 106, app 10, game 65, `1000` 2, `1010` 1.

**Missed functions are the main defect.** Vtables are never defined as data, so
Ghidra never follows them:
- The vtable region `1018:0302–108c` holds 1733 words, and 1667 of them point
  into code. That is 598 distinct targets, of which **535 are not functions**.
  None of the targets has a reference (`get_xrefs_to 1008:5240` returns nothing, even
  though 0x5240 is used in about 6 vtables).
- **251 are this-adjustor thunks**, packed into `1008:402d–51f5`. There are
  two forms:
  - `MOV BX,SP; SUB SS:[BX+2],imm; JMPF 1008:target`, 14 bytes with padding;
  - `MOV BX,SP; MOV BX,SS:[BX+2]; MOV AX,[BX-2]; …; JMP near`, a vtordisp-style thunk.

  These are the same family as NOITE's 310 `*_thunk_<adj>` functions.
- About 60 are default stubs at `1008:5240–52a8` and elsewhere: `XOR AX,AX; RET 2`,
  getters, and `RET n`-only bodies.
- About 220 are real methods. There are about 97 more `ENTER`/`PUSH BP; MOV BP,SP` starts in the gaps that no
  vtable points to.
- Estimate after phase 2: **about 850–900 functions**, including about 250 thunks and about 60 stubs.

Bad splits and merges:
- None found among the existing functions.
- Some bodies are bounded short because their tails sit in undefined
  gaps. Example: instructions at `1008:5606–560c` belong to no function. These get fixed as
  phase 2 fills the gaps.
- `entry`'s body begins at `0012`, before the entry point (CRT pre-entry code, as in NOITE).

Data and code confusion:
- No data was decoded as code: the gaps have no orphaned instructions.
- Code is left as *undefined* rather than typed as data.
- The 32-bit segment 1000 is the only place where code is decoded wrongly.

**Jump tables:** there are 9 (`2E FF A7` at `08c7` in `_output`, `b8c7`, `bb3e`, `bc83`,
`c43d`, `ceaf`, `d980`, `e3b0`, `eef5`). All of them are resolved, with `switchdataD_*`
tables defined in code. The one at `bc83` sits in the unanalysed gap
`bc37–c303`, so it will need checking once that function exists.

**Thunks:**
- `1008:15f8` is `thunk_FUN_1008_1884`, i.e. `atoi` → `atol`.
- The import thunks in `1030` are all marked as thunks.
- The adjustor thunks don't exist yet (see above).

**Large single functions (not mis-merged):** each is called once.
- `c41a` (2655 bytes), `ce8c` (2747), `d960` (2586) and `e392` (2858) are
  called from `f186`, which switches on the piece direction (1/2/4/8).
- `b898` and `eed8` are called from `ba20`.

## 4. The C runtime

The CRT occupies `1008:0012–1bde`: 82 functions plus a few gap fragments
(`14e6–15f7`, `0f4e–0f7a`). Its link order matches NOITE's segment `1008`.

How well matching against NOITE's 130 named CRT functions works:

| Method | Yield |
|---|---|
| `get_function_hash` (Ghidra's normalised opcode hash) | 8/277. The hash keeps operands, and near and far CRT differ. |
| Relocation-masked byte regex (`relmatch.py`) | 3 |
| Exact sequence of normalised mnemonic and operand shapes (`opmatch.py`) | 9 |
| `difflib` ratio over normalised objdump opcodes, against every NOITE function (`fuzzy.py`) | CRT region: **50 at ≥0.75**, 59 at ≥0.6, 23 at ≥0.9 (`_output` 0.96, `_aFldiv`/`_aFlrem` 0.99, `_lseek` 0.95) |

The expected yield is **about 60 of the 82 CRT functions named by matching**. Confirm
each one with `diff_functions` or by reading the code. The other ~20 need
reading, because they are small-model-only: `LocalAlloc` heap, `_nmalloc`,
`_nfree`, `_stackavail`, `_aNchkstk`, `sprintf` (`0108`). Since `sprintf` is `cdecl16near` and
varargs, its call sites show junk.

Names carry over from NOITE. Signatures do not: every pointer argument is near and
the convention is `__cdecl16near`.

The fuzzy method also picks up non-CRT code shared with NOITE:
- `1bde` = `dib_copy_transparent` (0.84), `1dbe` = `dib_copy` (0.87), `1f64` =
  `clear_system_palette` (0.65), `2138` = `read_dib_info` (0.87), `236e`/`23c0`
  ≈ `dib_remap8`;
- `8886` = `app_init`, `8988` = `app_message_loop`, `1010:0000` = APPABOUT;
- `fc46`/`fc5c`/`fca8` ≈ `wave_stop_all`/`wave_free_all`/`wave_mix_close`.

The engine methods match poorly (<0.7) because their near layouts differ.

## 5. Imports

There are 88 imports from 6 modules (WAVEMIX, KERNEL, GDI, USER, WING, MMSYSTEM),
in the same module order as NOITE. All of them are **untyped**
(`undefined X(void)`), so every call site carries junk: `MESSAGEBOX(0x1030,0x30,…)`,
`POSTMESSAGE(0x1030,…)` with missing arguments, and `unaff_CS`.

- **81 of 88 exist in NOITE with hand-typed signatures.** The 7 that are new are
  `LOCALALLOC`, `LOCALREALLOC`, `LOCALFREE`, `LOCALSIZE`, `UNLOCKSEGMENT`,
  `ADDFONTRESOURCE` and `BITBLT`.
- WinG is imported by ordinal: `Ordinal_1001` (WinGCreateDC, 0 xrefs now),
  `1002` (RecommendDIBFormat), `1003` (CreateBitmap, 0 xrefs) and `1010` (BitBlt). The 0-xref
  callers are inside undiscovered functions.
- Two USER functions are reached dynamically: ordinals **11 SetSystemTimer** and
  **182 KillSystemTimer**, through the far pointers `1018:5272` and `1018:5276`. Each is now split into
  two `undefined2`, so `(*DAT_1018_5272)()` loses its arguments.

Types:
- ENCAIXE's data type manager is **empty**: it has 5 primitives and no categories.
- NOITE has 69 structs in root `/`, among them `RECT`, `POINT`, `MSG`, `PAINTSTRUCT`,
  `WNDCLASS`, `BITMAPINFO(HEADER)`, `BITMAPFILEHEADER`, `RGBQUAD`, `LOGPALETTE(256)`,
  `PALETTEENTRY`, `OFSTRUCT`, `MIXCONFIG`, `MIXPLAYPARAMS`, `WAVEMIXINFO` and `CrtFILE`.
  NOITE has no data type archive.
- **The SDK structs and API signatures are independent of the memory model** (the
  API is always far). They can be copied as they are.
- **The engine structs cannot be copied**: they have near pointers and different
  offsets.

How to copy them:
- One `run_script_inline` script, opened from ENCAIXE, gets NOITE's
  `Program` from the project (`state.getProject()…getDomainFile("/NOITE.EXE")`, read-only).
  It does `dtm.addDataType(dt, DataTypeConflictHandler.KEEP_HANDLER)` for the SDK structs. For each
  ENCAIXE thunk in `1030` it copies the `FunctionSignature` of the NOITE thunk with the same
  name (`ApplyFunctionSignatureCmd`).
- The alternative is `import_data_types` with C text for the structs, plus
  `set_function_prototype` 81 times.
- After either, type the 7 new imports by hand.

`ghidra/cspec` extensions: **not installed in ENCAIXE**. Its CCs are only the 6
stock ones; NOITE has 8. Near functions don't need the far DX:AX variants. It is unverified
whether stock `__cdecl16near` returns `DX:AX` (`_aNlmul`/`_aNldiv`, `atol`,
`time`). If it doesn't, add a `__cdecl16near_dx_ax`: a copy of `cdecl16far_dx_ax.xml`
with `extrapop="2" stackshift="2"` and the first stack slot at offset 2.

## 6. Decompiler output quality

I sampled `89cc` (WinMain), `8ae4` (AppWndProc), `9e28`, `9c66`, `f186`, `f2a2`,
`7c50`, `7a8a`, `2cac`, `8c88` and `0108`.

| Issue | State |
|---|---|
| Signatures | All `undefined X(void)`. The CC was guessed per function: `__stdcall16near` for `RET n`, `__cdecl16near` for `RET`, `__stdcall16far` for APPWNDPROC. The decompiler infers parameter counts reasonably from `[BP+n]` (no `in_stack_*` was seen in the samples), but the parameters are all `int`/`undefined2`. |
| Junk at call sites | Every API call: `MESSAGEBOX(0x1030,0x30,…)`, `GETPROCADDRESS(0x1030,0xb)`, `POSTMESSAGE(0x1030,0,0x4010000)`, `unaff_CS`. These are fixed by typing the 88 thunks. Calls to near functions that Ghidra hasn't typed lose or shift arguments, e.g. `FUN_1008_7dec()` and `FUN_1008_f1fe()` with none. |
| Far pointers | These are rare: API string and struct arguments appear as `offset, 0x1018` pairs (e.g. `(char *)s_play_musica_notify_1018_10c6, 0x1018`). There are 39 `LES` (DIB and WinG bits, plus `__AHINCR` huge-pointer arithmetic in the DIB code) and the 2 far function pointers above. |
| C++ virtual calls | Readable but untyped: `(*(code *)*(undefined2 *)(*piVar + 0x6e))(piVar)`. Virtual-base lookups read as `p + *(int *)(*(int *)(p + 2) + 2) + 2` (vbtable at `this+2` or `this-0x32`). Fields are read at negative offsets from the vbase subobject (`[this-0x1a]`, `[this+0x426]`). Arguments to virtual calls Ghidra hasn't typed are often dropped: `(*(code *)…+0x46)()`. |
| Vtables | None are defined. There are about 55 tables or sub-tables at `1018:0302–108c` (vptr stores: `0x302/0x304`, `0x3be`, `0x3ce`, `0x488/0x48a`, `0x544`, `0x61e/0x620`, `0x6da`, `0x6ea/0x6f0`, `0x7fe`, `0x952`, `0x978/0x97a`, `0xa34–0xa50`, `0xb0a–0xb20`, `0xbda–0xc20`, `0xcda–0xce6`, `0xda0–0xdc2`, `0xe7c/0xe8e`, `0xf48–0xf92`, `0x1054`). Eleven of them are **93-slot** tables (the shared scene-object interface). Game vtables: `0x7fe` (base Game, 170 words up to the next store) and `0xf62` (derived). |
| Strings in the code segment | None. All strings are in DGROUP (small model), passed as `PUSH 0x1018; PUSH off`. |
| `MOV ES,[0x11xx]` | Not present (see §0). |
| Overall | The control flow is good: switches and loops are recovered. The CRT is clean. The game code needs types before it can be read. |

## 7. The data segment (`1018`)

Size: 0x14bd initialised and 0x5410 allocated, so the BSS is 0x3f53 bytes.

Ghidra defines 206 data items:
- 153 in DGROUP, of which 51 are strings and the rest `undefined1/2/4` placeholders;
- 53 in code: 8 switch tables.

`list_globals` returns 0, because nothing is named.

| Range | Contents |
|---|---|
| `0000–0010` | Windows instance header |
| `0014` | `"Encaixe Perfeito"`: the window class and title (NOITE's `FindWindow` target) and the NE description |
| `0026–0084` | App globals: `0026` g_noiteWnd, `0028` g_score (5 xrefs), `002a` g_started, `002c` g_ack0x40cPending, `006e–0074` arrow-key-held flags, `0078–0084` |
| `00ce–0236` | CRT data: `_psp` at `010a`, environment, `_iob`, `_C_FILE_INFO`, DOS version |
| `023c–02f4` | Engine error strings |
| **`0302–108c`** | **Vtables and vbtables**: 1733 words of near code offsets interleaved with vbtable words (`0xfffe/0xffce`, small offsets). Ghidra mis-cuts the strings here (e.g. `"@RFRLR…"`). |
| `06f4–094a` | Engine and app strings, file names |
| `108e–1202` | Font, MCI, WaveMix strings, `%06d` |
| `121e–14bd` | CRT tables, `<<NMSG>>`, and the R6xxx messages |
| `14be–5271` | BSS, 15.8 KB, mostly one byte array at `0x14be` addressed as `[bx+di+0x14be]`, probably the occupancy matrix ("matriz de ocupação" overflow strings at `081a`/`084c`). The other structures inside it are unknown. |
| `5272–5410` | App and engine globals: `5272/5276` far SetSystemTimer/KillSystemTimer, `5280` activate flag, `5286/528a` module path (0x104), `538e` sprintf buffer, **`53f2` g_game (43 operand refs)**, `53f4`, **`53f6` (80 operand refs, 52 xrefs): the active piece or board object driven by the keys**, `5406–540e` the sprintf FILE |

Strings:
- Ghidra found 51.
- A Latin-1 scan finds about 70 real ones. Ghidra truncates the ones that contain `ã`/`é`/`í`/`ú`.
  For example `"Não foi posível inserir…"` starts at `024c`, but Ghidra's string starts at `0284`.
  Others are cut the same way: `02da`, `0700`, `071c`, `074e`, `0778`, `07a6`, `07d8`, `081a`, `084c`, `0880`, `08a6`, `08ce`, `111c`, `113e`, `115c`, `11a0`, `11be` and `11da`.
- About 20 strings need redefining at the right start, with a Latin-1 charset.

## 8. What the game is

*Encaixe Perfeito* ("perfect fit") is a **Tetris** clone (`"Tetris"` at `094a`;
`tetris2.wav`). It is the pharaoh's minigame (`handler_3ffarao`).

Files it reads, relative to the current directory (`assets/ENCAIXE/`):
- `tetrfun.bmp`, the 640×460 8-bpp playfield background. `TETRFUNN.BMP` and
  `TETRFUNO.BMP` are on the disc but are not named anywhere in the EXE.
- `peca.bmp` and `pecaa–e.bmp`: 128×512 8-bpp piece strips, one per piece type.
- `panel.bmp`, 21×30.
- `doom2.mid`, played by MCI (`open doom2.mid type sequencer alias musica`,
  looped on MM_MCINOTIFY 0x3b9).
- `tetris2.wav` through WaveMix (`WAVEMIX.DLL` ships in the folder).
- `arialbd.fot` through `AddFontResource`, followed by a `SendMessage` broadcast. It is **not on
  the disc**, so the call must fail on a clean system. The score is drawn with `TextOut "%06d"`.
- It reads them with `OpenFile`, `_hread` and `GlobalAlloc` (`1fe4`/`2138`, the DIB loader).

Input and timing:
- The arrow keys `VK_LEFT/UP/RIGHT/DOWN` (0x25–0x28) arrive as WM_KEYDOWN/WM_KEYUP in `f2a2`.
- UP rotates, through `f186` and its direction switch.
- LEFT and RIGHT shift the piece by ±0x20 px.
- DOWN drops it, using SetSystemTimer.
- The tick is WM_SYSTIMER (0x118), from SetSystemTimer(hwnd, 1, 50 ms).

How it talks to NOITE:
- NOITE runs `WinExec`, then `FindWindow("Encaixe Perfeito","Encaixe Perfeito")`, then
  `PostMessage(minigame, 0x40b, 0, hwndNoite)`.
- ENCAIXE stores `LOWORD(lParam)` in `1018:0026`.
- On the next message it posts **0x40c** to NOITE once (the handshake, after which NOITE hides itself).
- In `f2a2` it handles msg 2 (WM_DESTROY). It closes the music and WaveMix, sets `g_score += wParam ? 500 :
  -500`, and posts **`PostMessage(noite, 0x40a, wParam, g_score)`**, meaning won/lost and the score.
- Unverified: how `wParam` becomes non-zero for a win. `DestroyWindow` is not imported, so the game must send itself msg 2.

The engine is NOITE's engine in a smaller build. The derived Game class defines
`CreateScreen`/`CreateNewScene`/`CreatePlayer`/`CreateInitScene`/`CreateControlPanel`/`CreateStatusBar`,
with the base versions printing "Faltou redefinir o método …".

## 9. Plan

### Phase 2: map all functions (about 600 new)

1. **Prerequisites** (minutes; they make the decompiler output usable for every later step):
   - Install the cspec extensions (only if the near DX:AX check fails, §5).
   - Copy NOITE's SDK structs and the 81 import signatures with one script (§5), then type the 7 new imports.
   - Split `5272`/`5276` into far function pointers.
2. **Vtables → functions.** Write a near version of `NoiteVtStores.java`: collect
   `MOV word ptr [r+k], imm` with `imm` in `0x300–0x1090`. For each table, walk the
   words while they land on code, `disassemble` + `createFunction` at each target,
   and add a **memory reference** from the slot to `1008:target`.
   **Risk:** a 2-byte pointer type in DGROUP resolves to `1018:xxxx`, not to code.
   So type the slots as `ushort` (or a 2-byte code pointer, after checking how it resolves)
   and add the references explicitly. Expect about 535 functions.
3. **Prologue sweep** of the remaining gaps: `ENTER n,0` and `PUSH BP; MOV BP,SP`
   after `RET`/padding. This gives about 97 functions. Then `find_code_gaps` again; the
   target is under 300 bytes, i.e. padding and switch tables.
4. **Adjustor thunks** (251): mark them as thunks of their `JMPF` or `JMP`
   target, and name them `<target>_thunk_<adj>` (NOITE's convention) once the targets are named.
   Do it with a script, not with agents.
5. **Default stubs:** name them the way NOITE does (`*_default`), once their slot meaning is known.
6. **CRT:** apply names for fuzzy matches ≥0.75 after a `diff_functions` check
   (about 50), then hand-read the rest (about 30). The signatures are near.
7. **Shared non-CRT code:** DIB/WinG (`1bde–27be`, NOITE `1010:0000–0900`), app shell
   (`8886–8eca`) and wave (`fc46–fcd2`), from NOITE with near signatures.
   `1000:0024/0114` take NOITE's names as they are.

Size: 2 scripts (one adapted from `NoiteVtStores`, one new for signatures), about
600 functions created, and about 90 CRT/shared names. One agent can do it in a few hours.

### Phase 3: map all data (boundaries and types)

1. Fix the about 20 truncated strings (Latin-1).
2. Vtables: for each of the ~55 tables, set the boundaries from the vptr stores, split vbtables from
   vftables, and build `XxxVtbl` structs with near function-pointer slots. This needs a
   2-byte version of `NoiteSlotTypes.java`. Map the 93-slot interface onto NOITE's
   `SceneObjectVtbl` by slot behaviour; it has fewer slots, and the mapping is not by index.
3. Classes: re-derive the near layouts of the Game, SceneObject family,
   ControlPanel, StatusBar, UpdateList, DrawList and the Tetris board/piece, using
   `memory-layout` and NOITE's field names. `NoiteStructs.java`/`NoiteFieldSet.java`
   already take `T *` (2-byte) vs `T *32`.
4. BSS: the `0x14be` matrix (dimensions from the overflow checks), then the
   `5272–5410` globals.
5. The CRT data in `00ce–0236` and `121e–14bd`, copying NOITE's `CrtFILE` with near
   pointers.

Size: about 55 vtables, about 12 classes, about 100 globals.

Risks:
- Near code pointers in DGROUP (see phase 2, step 2).
- `ghidra-fix-signature` and `ghidra-investigate` are written for far pascal. Agents need
  a minigame note: near pascal, `[BP+4]`, `RET n`, `this` at `[BP+4]`, pointers are 2 bytes.
- Rerunning auto-analysis after mass function creation may re-split or retype things. Keep
  the result lists from steps 2–4 so they can be reapplied.
- Some vtable words between tables are vbtable entries or data. The run boundaries in `vt.py` are heuristic.

### Phase 4: function groups (one Sonnet `ghidra-investigate` agent each)

The counts are estimated starts after phase 2: existing functions, vtable
targets and prologue hits (`zig-out/encaixe/est_starts.json`), excluding the 251
adjustor thunks. The total is 655. The CRT groups (1–3) are mostly named by
matching already, so their agents only verify the names and fix the signatures.

| # | Range (1008:) | ~Fns | Content |
|---|---|---|---|
| 1 | `0012–0800` | 27 | CRT startup/exit, `_cinit`, `_setargv`, heap, `sprintf`, `time`, string functions |
| 2 | `0800–1000` | 21 | CRT `_output`, `_flsbuf`, `__loctotime_t`, chkstk |
| 3 | `1000–1bde` | 34 | CRT I/O (`_lseek`, `_write`, `_close`, `fclose`, `_commit`), long math, `_dosmaperr`, `atol`/`atoi`, `_itoa` |
| 4 | `1bde–27be` | 25 | DIB/WinG helpers (copy, transparent copy, palette, read_dib_info, remap) |
| 5 | `27be–3000` | 29 | Engine: first class block (getters at `2b32…`) |
| 6 | `3000–402d` | 23 | Engine |
| 7 | `51f6–53e8` | 27 | Default stubs and getters (`5240…`); trivial, so this group is fast |
| 8 | `53e8–554c` | 27 | Small methods and stubs |
| 9 | `554c–5600` | 28 | Small methods and stubs |
| 10 | `5600–5794` | 18 | Engine methods |
| 11 | `5794–5c00` | 19 | Engine methods |
| 12 | `5c00–602e` | 28 | Engine methods (`5fe0` → mover) |
| 13 | `602e–6400` | 29 | Engine methods |
| 14 | `6400–6a00` | 29 | Engine (`661c`, `6816`) |
| 15 | `6a00–6e49` | 20 | Engine draw / WinGBitBlt (`6a22`, `6c58` fatal path, `6ca4–6e26`) |
| 16 | `6e49–7000` | 20 | Engine (`6ea8`, `6f08`) |
| 17 | `7000–7365` | 22 | UpdateList / DrawList (`71ee`, `72e0`, WinGRecommendDIBFormat) |
| 18 | `7365–7800` | 22 | Engine (`73c8`, `74b6`, `76f0`) |
| 19 | `7800–8886` | 29 | Mover/movement (`7a8a`, `7b66`, `7c50`), `7dec`, `805c`, `8124–8634` |
| 20 | `8886–8eca` + `1010` | 16 | App shell: WinMain, AppWndProc, msg loop, paint, fatal error, APPABOUT, the `1010:002e` stub |
| 21 | `8eca–9c66` | 1 (3.5 KB) | `game_handle_message` (high effort, alone) |
| 22 | `9c66–a244` | 21 | Game: new_scene `9c66`, ctor `9e28`, derived-Game overrides (vtbls `0x7fe`/`0xf62`) |
| 23 | `a244–a400` | 22 | Game/derived classes (vtbl `0xf92`, `a13e–a3e4`) |
| 24 | `a400–a706` | 21 | Scene/object classes (vtbls `0xdc2`, `0xda8`) |
| 25 | `a706–a900` | 21 | Scene/object classes (vtbls `0xf70`, `0x952`) |
| 26 | `a900–b100` | 20 | Board/occupancy matrix (`a962` clears `0x14be`), `ade4`, `ae7a` |
| 27 | `b100–b898` | 17 | Font/text/score (`b1dc` AddFontResource), `b5dc`, `b812` matrix |
| 28 | `b898–c41a` | 8 | Tetris core: `b898`, `ba20` (drop and land), `bb2e`, `bbd8`, `c304` (BitBlt) |
| 29 | `c41a–f042` | 10 (4 × ~2.7 KB) | The four rotation/shape giants `c41a`/`ce8c`/`d960`/`e392`, plus `eed8` and `f016`. Do them together: they are near-clones. |
| 30 | `f042–fcd2` | 22 | Tetris scene: paint `f042`, `f186` direction switch, `f1fe`, key handling `f2a2`, MCI/WaveMix (`f8e0–fca8`), IPC 0x40a |

That is 30 groups. Order of work:
1. Run 1–4 and 20 first; they anchor the CRT, DIB and app names.
2. Then 22–23 (Game).
3. Then the engine blocks 5–19, which are best done once the vtable slot meanings from phase 3 exist.
4. Then the Tetris groups 26–30.
5. Group 21 last.

Groups 21 and 29 have few functions but a lot of code each.
