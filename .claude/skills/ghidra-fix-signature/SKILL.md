---
name: ghidra-fix-signature
description: Recover the correct prototype (calling convention, parameter list, parameter types, return type) for a function in NOITE.EXE or a minigame whose signature Ghidra got wrong — including Win16 API import thunks. Maps MSVC far pascal / far cdecl onto Ghidra's x86-16 conventions (reversed parameter order, split 32-bit args to dodge Ghidra's 4-byte alignment), drives off the prologue/body, decompiler `in_stack_*` / `in_REG` leaks and every caller's push pattern, and refuses to apply unless the evidence converges. Use when a decompilation reads `func()` but the body reads `[BP+N]`, when `in_stack_*` appears, when call sites show junk args like `MESSAGEBOX(0x1018,0x30,…)`, or when caller pushes / `RETF n` don't match the declared args.
---

# ghidra-fix-signature

For NOITE.EXE and the minigames (16-bit NE, Windows 3.1, MSVC 1.5x). Read the
"Binary facts" in `CLAUDE.md` first. Companion to `ghidra-investigate` — that
skill names and documents a function; this one fixes the **shape** of its
prototype. Tools are `mcp__ghidra__*`.

## Why it matters

A function declared `undefined f(void)` that really reads `[BP+6]` detaches the
argument at every call site, and the body papers over it with `in_stack_NNNN`.
In this binary the problem is everywhere at once: **none of the ~90 Win16 API
import thunks are typed**, so every `MessageBox`, `BeginPaint`, `SelectPalette`
call decompiles to nonsense until its thunk is fixed.

## The three Ghidra traps in this binary

### 1. There is no `__pascal` — use `__stdcall16far` with the parameters reversed

`list_calling_conventions` offers only `__stdcall16near`, `__cdecl16near`,
`__stdcall16far`, `__cdecl16far`, `__regcall`, `__thiscall`. MSVC Win16 code is
mostly `far pascal`: arguments pushed **left to right**, callee pops (`RETF n`).
Ghidra's stdcall pushes right to left, so the source's **last** parameter sits at
the lowest stack address — Ghidra's first slot.

> Write the prototype with the source parameter list **reversed** and
> `calling_convention=__stdcall16far`.

`WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)` becomes
`long f(long lParam, uint wParam, uint msg, uint hwnd)`. Name the parameters
after the source order so the reversal stays readable, and say so in the plate
("pascal; params listed reversed").

`far cdecl` functions (plain `RETF`, caller `ADD SP,N`) map directly to
`__cdecl16far` in normal order.

### 2. Ghidra aligns 4-byte stack parameters to 4 — split them

Ghidra's x86-16 conventions place a 4-byte parameter (`long`, `T *32`,
`unsigned long`) at the next **4-byte-aligned** entry-SP offset. MSVC packs
arguments on 2-byte boundaries. Any 32-bit parameter that lands at offset 6, 10,
14, … is read 2 bytes too high, and its value comes out half-swapped
(`(char *)0x36e61018` instead of `1018:36d8`).

Entry-SP offsets for a far function: `+0` return IP, `+2` return CS, first
Ghidra parameter at `+4`. Walk the (already reversed, for pascal) list adding
2 or 4 per parameter. Then:

- A 4-byte parameter at an offset that's a multiple of 4 → keep it whole
  (`long lParam`, `Obj *32 pThis`).
- A 4-byte parameter at an offset ≡ 2 (mod 4) → **split it into two 2-byte
  parameters**, low word first: a far pointer becomes `char *lpText,
  uint lpText_seg`; a long becomes `uint dwX_lo, uint dwX_hi`.

Verified on `MessageBox(hwnd, lpText, lpCaption, uType)`:
`int f(uint uType, char *32 lpCaption, char *32 lpText, uint hwnd)` renders
`f(0x30,(char *)0x36e61018,(char *)0x1018,…)` (wrong), while
`int f(uint uType, char *lpCaption, uint lpCaption_seg, char *lpText,
uint lpText_seg, uint hwnd)` renders `f(0x30,(char *)0x36d8,0x1018,
(char *)0x36e6,0x1018,0)` — exactly the pushed bytes.

### 3. Thunks take the prototype's name

`set_function_prototype` on an import thunk (`1108:xxxx`) **renames it** to the
name in the prototype string, unlike on normal functions. Always put the
thunk's real name in the string (`int MESSAGEBOX(...)`). If you clobber it,
restore it with `rename_function`.

## Stack layout cheat sheet

After `ENTER n,0` (or `PUSH BP; MOV BP,SP`):

| `[BP+N]` | far function (`RETF`)   | near function (`RET`) |
| -------- | ----------------------- | --------------------- |
| `[BP+0]` | saved BP                | saved BP              |
| `[BP+2]` | return IP               | return IP             |
| `[BP+4]` | return CS               | **lowest arg word**   |
| `[BP+6]` | **lowest arg word**     | next arg word         |

`in_stack_NNNN` is named from **entry SP**, so for a far function
`in_stack_00000004` is `[BP+6]` — the lowest argument, not the return CS.

"Lowest arg word" is the **last** source argument for pascal and the **first**
for cdecl.

The `PUSH DS` in the prologue sits below BP; it never shows up as an argument.

## Procedure

### 1. Snapshot

`get_functions` with `fields=signature,parameters,locals,decompiled_code,callers`
and `include_disasm=true` (or `disassemble_function`). Record the current
prototype — you will need it to revert — plus the return instruction and every
`[BP+N]` the body reads, with its width.

### 2. Pin the convention from the return instruction

| Epilogue           | Convention                                                 |
| ------------------ | ---------------------------------------------------------- |
| `RETF n`           | far pascal → `__stdcall16far`, params reversed. `n` = total arg bytes. |
| `RETF`             | far cdecl → `__cdecl16far`. Callers clean with `ADD SP,N`. |
| `RET n` / `RET`    | near pascal / near cdecl (rare; mostly CRT in `1008`).     |
| `66 CA ..` (`RETF` with a `66` prefix) | 32-bit code — you are in segment `1000`. **Stop.** |

`n` in `RETF n` is a free, exact check on the total argument size.

### 3. Enumerate argument reads in the body

For every `[BP+N]` with `N ≥ 6` (far): offset, width (`byte`/`word`/`dword`,
`LES BX,[BP+N]` = 4-byte far pointer), and signedness (`MOVSX`/`CBW` vs
`MOVZX`/`MOV AH,0`). Adjacent words used together (`LES`, `DX:AX` built from
`[BP+N]`/`[BP+N+2]`, `PUSH dword ptr [BP+N]`) are **one** 32-bit argument.

**Pass-through trap:** two adjacent words that are only pushed straight to a
callee (`PUSH [BP+0xa]; PUSH [BP+8]; CALLF x`) are one or two arguments
depending on **the callee's** parameter list, not on the push shape. Check the
callee before merging them.

### 4. Walk every caller

`get_functions fields=callers` (or `get_xrefs_to` on the entry). Callers of
exported/callback functions (window procedures, `AppAbout`) are Windows itself
— there are none; rely on the body and on the documented Win16 signature.

At each call site record the pushes before `CALLF` and the cleanup after:

- far pascal: no cleanup; total pushed bytes must equal `RETF n`.
- far cdecl: `ADD SP,N` must equal total pushed bytes.

Push widths come from the bytes, not the mnemonic: `66 6A xx`, `66 68 …`,
`66 FF 76 xx` and `PUSH dword ptr` push **4** bytes. MSVC here is compiled for
386 and uses them freely (`PUSH 0x10032` = two words `0x0032, 0x0001`).

C++ calls: `PUSH dword ptr [obj]` right before `LES BX,[obj]; LES BX,ES:[BX];
CALLF [BX+k]` is `this`, pushed **last** → the first Ghidra parameter of the
reversed pascal list (a 4-byte `*32` at offset 4, which is aligned).

If callers disagree on the byte count and the `66`-prefix check doesn't close
the gap, stop and report.

### 5. Type each parameter

- **Pointer slots get pointers.** A 4-byte slot used with `LES` or passed to an
  API that wants a far pointer is a far pointer: `T *32` when it lands
  4-aligned (trap 2), otherwise split `(T *p, uint p_seg)`. A 2-byte slot used as
  a DS-relative base is a near pointer `T *`. Never `int`/`long` for a pointer.
- **Win16 handles** (`HWND`, `HDC`, `HPALETTE`, `HGLOBAL`, …) are 16-bit. The
  program has no Win16 types; use `uint` and a descriptive name (`hwnd`, `hdc`)
  unless someone has created the typedefs.
- Byte zero-extended into a word (`MOV AH,0; PUSH AX`) → declare `int`/`uint`.
- Unknown → `undefined2` / `undefined4` to lock the width without lying.

### 6. Return type

- `MOV AX,…` only → 16-bit (`int`, `uint`, handle, `BOOL`).
- `DX:AX` set before the return → 32-bit (`long`, far pointer).
  - far pascal (`RETF n`): `__stdcall16far` already returns `DX:AX`.
  - far cdecl (plain `RETF`): plain `__cdecl16far` has no `DX:AX` output and
    turns a 4-byte return into a hidden `__return_storage_ptr__` (which then
    sticks). Use the installed spec extensions (`ghidra/cspec/*.xml`):
    `__cdecl16far_dxax_ptr` with a `T *32` return for far pointers,
    `__cdecl16far_dx_ax` with `long`/`ulong` for 32-bit scalars.
  - Decompiling right after changing a prototype can show a half-updated body
    (stores missing); decompile again before judging.
- Callers never read AX → `void`.

### 7. Apply

```
set_function_prototype
    function_address=<seg:off>
    prototype="<ret> <name>(<reversed-for-pascal, split-where-misaligned params>)"
    calling_convention=__stdcall16far | __cdecl16far | __stdcall16near | __cdecl16near
```

The calling convention goes in its own argument, never in the string. For a
thunk the name in the string is applied (trap 3).

### 8. Verify

Re-read the function and at least two callers (`get_functions` with
`include_call_context=true`). Pass when:

- No `in_stack_*` and no `[BP+N]` arithmetic in the body.
- Call sites show the real values: string pointers as `0x36d8` + `0x1018`,
  constants where the disassembly pushes constants, no leading `0x1018`/`0x1108`
  junk argument.
- No new `in_DX` leaks at callers.

If the body reads worse, re-apply the snapshot from step 1.

### 9. Plate (signature facts only)

Only when non-obvious, one bullet each: "far pascal; params listed reversed",
"lpText split into offset/segment (Ghidra 4-byte alignment)", "no callers —
Windows callback". Naming and behaviour belong to `ghidra-investigate`.

## Typing a Win16 API thunk

Import thunks are 4-byte stubs at `1108:xxxx`. Typing one fixes every call site
in the program at once, so do the APIs a function calls **before** judging that
function. All Win16 APIs are `far pascal`. Take the prototype from the Windows
3.1 SDK and apply traps 1–3:

```
MessageBox(HWND, LPCSTR lpText, LPCSTR lpCaption, UINT uType)
→ int MESSAGEBOX(uint uType, char *lpCaption, uint lpCaption_seg,
                 char *lpText, uint lpText_seg, uint hwnd)      __stdcall16far
```

Name parameters after the SDK. WinG imports are `Ordinal_100x` (names in
`CLAUDE.md`); rename the thunk too.

## Stop conditions

- The function is in segment `1000` (32-bit code decoded as 16-bit).
- Callers disagree on argument bytes and `RETF n` / `ADD SP,N` doesn't settle it.
- The body reads `[BP+N]` at an offset that isn't a valid argument slot (`[BP+3]`,
  `[BP+5]`) — mis-disassembly.
- A 32-bit return keeps leaking `in_DX` after typing.

A clear "what's blocking" report beats a half-applied prototype.
