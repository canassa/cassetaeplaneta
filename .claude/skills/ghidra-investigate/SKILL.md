---
name: ghidra-investigate
description: Investigate, rename, type, and document a single function in NOITE.EXE (or a minigame) via the ghidra MCP server. Fix the signature first (mechanical work), then work out the role (semantic work). Score each phase independently and apply only at ≥8. Stops and reports if a new struct is needed. Use when the user names a function to look at, or when walking FUN_* functions one at a time.
---

# ghidra-investigate

For NOITE.EXE and the minigames (16-bit NE, Windows 3.1, MSVC 1.5x C++). Read
the "Binary facts" in `CLAUDE.md` first. Treat the disassembly as ground truth —
the C decompilation is interpretation. Tools are `mcp__ghidra__*`; pass
`program=<NAME>.EXE` whenever more than one program is open.

## Core rule

**Two phases, scored independently at ≥8:**

- **Phase 1 — Mechanical** (signature, parameter names + types). Evidence:
  prologue/epilogue, body access widths, caller push patterns.
- **Phase 2 — Semantic** (rename + plate). Only after Phase 1 leaves the
  decompilation reading cleanly. Evidence: callees, callers, strings, the INI
  data the engine interprets.

Stopping after Phase 1 is a normal outcome. Never rename a function whose
signature you couldn't pin down. **Triangulate:** at least two independent
pieces of evidence must agree. A wrong rename is harder to undo than a missing
one.

______________________________________________________________________

## Phase 1 — Fix the signature

### 1. Pull the function

`get_functions` with `function=<seg:off>` and
`fields=signature,decompiled_code,plate_comment,callers,callees,parameters,locals`;
add `include_disasm=true` (or call `disassemble_function`) for the listing.
**Read any existing plate first** — a prior analyst's notes are evidence.

#### Stop and report if…

- The address is in segment `1000`. It's 32-bit code decoded as 16-bit (`PUSH
  EBP`, `MOVZX BP,SP`, `66`-prefixed `RETF`); nothing there is trustworthy.
- The decompilation shows broken control flow: `Could not recover jumptable`,
  `Removing unreachable block`, `$$undef` symbols, `Could not follow disassembly
  flow into non-existing memory`, a body far longer or shorter than the
  instruction count suggests.
- The function isn't real: no callers, no xrefs, no prologue, starts mid-flow on
  a register the "caller" set. Likely an auto-analysis mis-carve; report it.

### 2. Make sure its callees are typed

Every untyped **import thunk** it calls (`1108:xxxx`, `undefined X(void)`)
corrupts the decompilation around that call — phantom leading arguments like
`MESSAGEBOX(0x1018,0x30,…)`, wrong `unaff_CS` flow. Type those thunks first with
`ghidra-fix-signature` ("Typing a Win16 API thunk"). They are cheap, certain
(the SDK gives the prototype) and fix every call site in the program.

### 3. Gather caller-side evidence

- `get_functions fields=callers include_call_context=true` gives each caller's
  decompiled call line.
- `get_xrefs_to` on the entry for data references (function-pointer tables,
  `CALLF [0x7bf4]`-style indirect calls through a global).
- Read at least one caller's disassembly for the pushes and the cleanup.
- **No callers is normal for Windows callbacks** — window procedures, dialog
  procedures, timer callbacks and exports (`AppWndProc`, `AppAbout`) are called
  by Windows. Their signature comes from the SDK. Look for where their address
  is taken (a `REGISTERCLASS` setup, `MakeProcInstance`, a `PUSH seg; PUSH off`
  of the entry).

### 4. Score mechanical confidence

| Score | Evidence                                                                                                     |
| ----- | ------------------------------------------------------------------------------------------------------------ |
| 10    | Known library function (MSVC CRT, a Win16 API thunk with its SDK prototype, a documented Windows callback). |
| 9     | Epilogue (`RETF n` / caller cleanup) + every caller's pushes + body widths agree.                            |
| 8     | Epilogue + body widths agree with at least one caller, or with a typed callee the args are forwarded to.     |
| ≤7    | **STOP.** Report findings; do not write.                                                                     |

Signs of a wrong signature: `in_stack_*`, `in_DX`, `unaff_SI`/`unaff_DI` that
flow into real expressions, `param_N` counts that disagree with `RETF n`. Ignore
`unaff_SS` and `unaff_CS` — they're segment registers read at entry and are
noise here.

### 5. Apply

If the current signature already matches the evidence, don't write. Otherwise
call `set_function_prototype`, following `ghidra-fix-signature` for:

- **far pascal (`RETF n`) → `__stdcall16far` with the parameter list reversed.**
- **32-bit parameters at non-4-aligned slots → split into two 16-bit halves.**
- far cdecl (plain `RETF`) → `__cdecl16far`, normal order.

Switch to `ghidra-fix-signature` entirely when callers disagree, when `DX:AX`
returns leak `in_DX`, or when the convention itself is in doubt.

### 6. Name and type parameters and meaningful locals

- `set_variable_type` only when **certain** of the type; otherwise keep
  `undefined1/2/4` matching the access width. A slot that is clearly a pointer
  but whose pointee is unknown gets `undefined1 *` (near) or `undefined1 *32`
  (far, when 4-aligned).
- `rename_variables` for locals whose role the call site or a literal names
  (`hdc = GETDC(hwnd)`, `n = lstrlen(...)`). Skip the ones you haven't pinned.
- **Split stack structs:** when the function fills adjacent `local_N` slots with
  constants and then passes `&local_N` (+ `SS`) to an API that takes a struct
  (`PAINTSTRUCT` for `BeginPaint`, `RECT`, the 0x14-byte `WAVEMIXINFO` for
  `WaveMixGetInfo`), those slots are one struct. Retype the lowest-addressed
  local to the struct with `set_variable_type` — if the struct exists.

#### 🛑 STOP and REPORT if a new struct is needed

Don't define structs here. Report the observed fields and offsets (pointer
dereferenced at `+0/+4/+0xa`, a vtable at `+0`, etc.) and hand off to
`memory-layout`.

### 7. Re-read the decompilation

Phase 1 succeeds when there's no `param_N` in the body, no `in_stack_*` /
`in_DX` leaks, no `[BP+N]` arithmetic, call sites show real arguments, and
coverage roughly matches the disassembly. A leak caused by an untyped **callee**
is that callee's problem — note it and type it, or move on.

______________________________________________________________________

## Phase 2 — Identify the role

### 8. Investigate

- **Callees** disclose the role: `BEGINPAINT`…`ENDPAINT` → paint handler;
  `WAVEMIXOPENWAVE` + `WAVEMIXPLAY` → sound cue; `GETPRIVATEPROFILESTRING` →
  reads `CASSETA.INI`/`JOGO*.INI`; `WINGBITBLT` → blits the offscreen WinG DC;
  `MCISENDSTRING` → MIDI/AVI playback; `OPENFILE`/`_LREAD`/`_HREAD` → loads a
  BMP/WAV/RLE asset.
- **Callers** disclose the role: which `WM_*` case of `AppWndProc` reaches it,
  which scene/object method calls it.
- **Strings.** `list_strings` / `search_strings`, and string pointers pushed as
  `PUSH 0x1018; PUSH 0x36d8` (code-segment strings) or DGROUP offsets. Many are
  Portuguese (`"número de linhas da matriz de ocupação"`). INI key names
  (`Portable`, `Animated`, `Exit`, `Limits`, `WAVE`, `Screen`, `Local`,
  `FirstScene`, `Player`, `Sprite`, `Control`, `StatusBar`) tie a function to the
  scene format in `assets/CASSETA.INI` — read that file to interpret the
  fields a parser extracts.
- **Window messages:** `msg` constants are `WM_*` (`0x1` CREATE, `0x2` DESTROY,
  `0x6` ACTIVATE, `0xf` PAINT, `0x1c` ACTIVATEAPP, `0x111` COMMAND, `0x113`
  TIMER, `0x200`+ mouse); `0x400`+ are app-private (`0x406` is used here).
- **C++ shape.** A far `this` pushed last, `LES BX,[this]; CALLF ES:[BX+k]` =
  virtual call through slot `k/4`. Functions that take the same `this` and touch
  the same offsets are members of one class.
- **Siblings in the same segment** often form a family (one source file per
  segment range in MSVC's output order).
- `read_memory` / `inspect_memory_content` with `seg:off` addresses to confirm a
  constant, table or string.

### 9. Score semantic confidence

| Score | Evidence                                                                                          |
| ----- | ------------------------------------------------------------------------------------------------- |
| 10    | Known library function (MSVC CRT routine, WinG sample skeleton function).                         |
| 9     | All call sites consistent + the role is pinned by an API sequence or INI key + one more corroborating fact (string, global, callee). |
| 8     | Body structure + callers + one additional fact converge on a single interpretation.               |
| ≤7    | **STOP.** Leave it `FUN_*`.                                                                       |

A clean function with zero callers that isn't a Windows callback is
*unreachable via static analysis* (it may be called through a pointer table).
Phase 2 is still possible if the body alone reaches 8; say "no static callers" in
the plate.

### 10. Rename + plate

- `rename_function` with `function_address=<seg:off>` and a name that follows
  the naming conventions in `CLAUDE.md`. Keep mangled export names as they
  are.
- `set_comment` with `type=plate` (or `batch_set_comments` with
  `plate_comment`): **terse**, one or two sentences on what the function does.
  Never name other functions or globals (names change). No numbered
  procedures, no restating the body. Note "far pascal; params listed
  reversed" if the signature uses that mapping.
- Update an existing plate rather than replacing useful detail.

______________________________________________________________________

## Pattern shortcuts

| Signal | Conclusion |
| ------ | ---------- |
| `ENTER n,0; PUSH DS; MOV AX,0x1050; MOV DS,AX` … `POP DS; LEAVE; RETF n` | Normal far pascal function. |
| Same, ending in plain `RETF` | far cdecl — callers clean the stack. |
| `INITTASK` call, `DOS3CALL`/`INT 21h AH=30h`, in `1008` | MSVC Win16 C runtime startup (`entry` → `_astart` → `WinMain`). |
| `R6000`–`R6021` strings referenced | MSVC CRT runtime-error path (`_amsg_exit` family). |
| `CALLF [0x7bf4]` / `CALLF [global]` | Indirect call through a function pointer stored in DGROUP — find who writes the global (`GetProcAddress` result, callback table). |
| `LES BX,[g]; LES BX,ES:[BX]; CALLF ES:[BX+k]` with `PUSH dword [g]` before | C++ virtual call on the object at `g`, slot `k/4`. |
| `MOV ES,word ptr [0x11xx]` | Loads the DGROUP selector (value `0x1050`); `ES:[x]` is DGROUP `x`. |
| `PUSH 0x1018; PUSH imm` before an API taking `LPCSTR` | Code-segment string at `1018:imm`. |
| Calls `Ordinal_100x` | WinG (names in `CLAUDE.md`). |

## Out of scope

- Globals and structs → `memory-layout`.
- Segment `1000` (32-bit code).
- Cross-cutting refactors — one function at a time.
