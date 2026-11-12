---
name: memory-layout
description: Reverse a memory region in NOITE.EXE (or a minigame) into the correct type — struct, C++ object with vtable, array, parallel arrays, slot table — by enumerating every access width, stride and writer, then verifying by re-reading the decompilation. Use when a DGROUP global turns out to be part of a wider layout, when a far pointer to a heap object is dereferenced at many offsets, or when the decompilation reads like byte arithmetic (`*(int *)((int)uVar3 + 4)`, `*(int *)((char *)&g + slot * 4 + 2)`) that should be `p->field` / `g[slot].field`.
---

# memory-layout

For NOITE.EXE and the minigames (16-bit NE, Windows 3.1, MSVC 1.5x C++). Read
the "Binary facts" in `CLAUDE.md` first. Companion to `ghidra-investigate` — use
that for one function; use this when a global or a pointed-to object needs a
real type. Tools are `mcp__ghidra__*`.

## The trap this skill exists to avoid

Typing one global in isolation. A `DAT_1050_xxxx` is rarely just one word — it's
the offset half of a far pointer, an array element, a struct field, or the
head of a heap object reached through a far pointer. **Before typing one
global, prove what its neighbours are.**

## Two kinds of memory in this binary

1. **DGROUP globals** at `1050:xxxx` (DS). Near pointers into DGROUP are 2
   bytes. Accesses look like `[0x7c06]` or, via a far segment slot,
   `MOV ES,[0x1190]; …ES:[0x7ae0]` — both are DGROUP (`[0x1190]` holds `0x1050`).
2. **Heap objects** reached through **far pointers** (4 bytes, offset low,
   selector high): `LES BX,[g]` then `ES:[BX+k]`. C++ objects come from MSVC's
   `operator new` — most likely `FUN_1008_038e` in the CRT segment, as in
   `FUN_1008_038e(0x6c8)` → DX:AX far pointer → NULL check → constructor call
   in `FUN_1018_3014` (confirm before naming it). There's no fixed address to type — you type the **pointer**
   (`Game *32`) and define the **struct** it points to.

## When to invoke this skill

- Byte arithmetic over a slot index or over a far pointer:
  `*(int *)((int)*(undefined4 *)&DAT_1050_7ae0 + 4)`.
- A `WARNING: Globals starting with '_' overlap smaller symbols` banner.
- Adjacent `DAT_1050_*` labels at `+2` / `+4` (far-pointer halves, struct fields).
- A constructor / init / loader writes a fixed set of offsets every time — those
  are one record's fields.
- An access width (`LES`, `CMP dword`) that doesn't match the declared type.

## Procedure

### 1. Enumerate every access

For a global: `get_xrefs_to address=1050:xxxx` (page through `total`), and for
the neighbours at `+2`, `+4`, … For a heap object: start from the global or
parameter holding the far pointer, and in each function that loads it follow
what `ES:[BX+k]` offsets are read and written. `analyze_struct_field_usage` and
`get_field_access_context` help once a struct exists;
`analyze_data_region` / `detect_array_bounds` help on a DGROUP range.

Record per access: site, width (byte / word / dword / `LES` = far pointer),
pattern (direct, `[base + slot*K]`, `ES:[BX+k]` off a far pointer).
**The widest coherent width wins.**

### 2. Decide the layout kind

| Evidence | Layout |
| -------- | ------ |
| One base, stride 1/2 | `byte[N]` / `word[N]` |
| Stride 4, used with `LES` and stored as two `MOV word` halves | array of far pointers `T *32 x[N]` |
| Stride N with mixed widths at fixed offsets | array of struct `T x[N]` |
| Several bases indexed by the **same** slot variable | parallel arrays — separate top-level globals, not a wrapper struct |
| Far pointer from `operator new(size)` → constructor writes `+0` = a code-segment address table | C++ object with **vtable** at `+0`; `size` is `sizeof` the class |

**C++ objects:** the constructor is the authoritative field list — it writes the
vtable pointer (a far pointer to a table of far function pointers, usually in a
code or data segment) and initializes members. Virtual calls are
`LES BX,[this]; LES BX,ES:[BX]; CALLF ES:[BX+k]` → slot `k/4`. Model the vtable
as its own struct of far function pointers (`code *32`), and the object as a
struct whose field `+0` is a far pointer to it.

### 3. Find the creator / destroyer

`get_xrefs_to` on the head with `WRITE` references → the creator (`*Init`,
`*Load`, constructor) and destroyer. The creator writes every field once; its
body is the field list. `get_xrefs_from` on the creator lists every data target
it touches.

### 4. Derive counts and sizes

- Array bounds: the loop constant in the creator's free-slot search, a validity
  check (`slot < N`), and a scan loop. Three independent sites agreeing ⇒ solid.
  `search_instructions` with `mnemonic=CMP` and an operand pattern finds the
  constant users.
- Heap object size: the argument to `operator new` (`0x6c8` for the object at
  `1050:7ae0`) or to `GLOBALALLOC`.

### 5. Define the type

- `create_struct` with explicit fields (name, type, offset). Leave the struct
  **unpacked** (field offsets exactly as observed): MSVC 16-bit packs to 2 bytes,
  while Ghidra gives `*32` and `long` an alignment of 4 — an aligned struct
  would insert padding. Check the size with `get_struct_layout` afterwards.
- Far pointers are `T *32` (4 bytes). Plain `T *` is a 2-byte near pointer —
  correct only for DGROUP-relative pointers.
- Fill unknown gaps with `undefined1[n]` rather than guessing fields.
- Retype fields later with `modify_struct_field`; add with `add_struct_field`.
- Win16 structs (`RECT`, `PAINTSTRUCT`, `WNDCLASS`, `BITMAPINFOHEADER`, the
  WinG/WaveMix structs) aren't in the program yet. When one is needed, create it
  from the SDK layout once and reuse it.

Keep far pointers typed as `T *32`, even though init and NULL checks still
render as two half-word accesses (`_0_2_`, `_2_2_`) — that's the binary's
two-`MOV word` storage, and the dereference sites (which dominate) render
cleanly. Don't model a far pointer as `{offset; segment;}`.

### 6. Apply

- A global: `set_global` (name + type + plate + array length in one
  transaction; names follow the naming conventions in `CLAUDE.md`, e.g.
  `g_game`, `g_slotFlags`).
  It refuses to evict named neighbours unless `allow_evict=true` — when it
  refuses, look at what it would evict before overriding.
- A bare type change: `apply_data_type` (`clear_existing` defaults to true).
- A heap object: type the **pointer** (`set_global type_name=Game *32`, or
  `set_variable_type` on a parameter/local). Typing the pointee struct is what
  makes `ES:[BX+k]` render as `p->field`.
- Addresses are passed as `seg:off` (`1050:7ae0`). Preview with `dry_run=true`.

If the apply fails with a conflicting *instruction* in a data range, Ghidra
disassembled data after a broken jump. Stop and ask the user to clear the code
bytes in the UI (or use `clear_flow_and_repair` if the cause is clear).

### 7. Verify by re-reading the decompilation

**Don't claim done until you've read at least one writer and two readers.**

✅ Pass:
- `p->field`, `g[slot]`, `g[slot].field` where there was byte arithmetic.
- Overlap warnings gone (or moved to a named, still-unfixed neighbour).
- Virtual calls read `(*p->vtbl->Method)(p, …)`.

❌ Fail:
- `*(int *)((int)p + N)` still present → wrong offset, wrong width, or the
  pointer isn't typed at that site (a local copy needs `set_variable_type` too).
- A new overlap warning → wrong width or off by one.
- Different functions render differently → one of them has its own stale view
  (a local or parameter still typed `undefined4`).

📐 Expected residue: half-word stores/NULL checks of far pointers; arguments
passed as `(int)p + 0x14` integer expressions.

### 8. Check the size is right

- Every write target of the creator falls inside the struct.
- For heap objects, `sizeof` equals the `operator new` argument; no access in
  any function goes past it.
- Empty space after a DGROUP struct is usually unrelated globals — don't grow
  the struct without an access that demands it.

## Plate comment

On the head global or the struct's constructor: kind (struct / C++ class /
array / parallel arrays), count or size. Terse; never name other functions or
globals (names change). Field details live in the struct.

```
Main game object (0x6c8 bytes). Vtable at +0; the window procedure offers
each message to its first virtual method before its own handling.
```

## Done when

1. The type is defined and applied (global and/or the far pointers to it).
2. One writer and two readers decompile with field/array syntax.
3. The plate states kind and size/count.
4. The size check in step 8 holds.

If a step stalls, report what's blocking instead of half-applying — a
half-typed layout renders inconsistently across functions, which is worse than
untyped.
