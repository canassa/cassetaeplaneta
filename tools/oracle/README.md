# Oracle — run original NOITE.EXE functions

Runs functions of the original `assets/NOITE.EXE` on chosen inputs, to produce
expected values for the Zig port's unit tests. No Ghidra needed.

Unicorn in 16-bit protected mode plus our own NE loader (`noiteemu.py`):

- selectors match Ghidra (NE segment *n* → `0x1000 + (n-1)*8`, DGROUP `0x1050`);
- all NE relocations applied; `__AHSHIFT`/`__AHINCR`/`__WINFLAGS` as constants;
- the 93 imports are stubs; an unhandled one stops the run with its name;
- pascal and cdecl calls with a far-return sentinel; reports AX, DX, bytes
  popped, requested memory and imports hit;
- scratch selector `0x1118` (64 KiB) for strings, structs, fake objects;
- segment 1000 starts 16-bit and switches itself to 32-bit via DPMI
  (`INT 31h` 000B/000C emulated).

In the dev shell (`nix develop`, which provides Python with Unicorn):

```sh
python3 -I oracle.py 1008:35fa 's:  -123456' --cdecl          # atol → dxax
python3 -I poc_tests.py "$PWD"                                 # 37 checks
```

Options: `--stub DLL.ord:argbytes:ret`, `--read SEL:OFF:LEN`, `--mem SEL:OFF=HEX`.

Ghidra's MCP `emulate_function` does not work here: its p-code emulator lacks
the `segment` operation every 16-bit protected-mode access uses, and it assumes
flat 32-bit calls.

Limits: Win16/MMSYSTEM/WAVEMIX/WinG calls need a Python stub each (heap calls
need a small selector allocator); functions reading many globals need a seeded
DGROUP image; OS-driving code (painting, window procedure, sound) is a poor
target. Use it to generate golden vectors checked into the Zig tests — the
emulator does not run inside them.
