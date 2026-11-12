# Casseta & Planeta — Noite Animal

Reverse-engineering the 1995 ATR Multimedia point-and-click adventure
`NOITE.EXE` (plus its minigames). The disc is extracted in `assets/`.

## Layout

- `assets/` — the extracted disc (one data track). Never edit; it's the
  reference. The `.iso` itself is not in git.
- `ghidra/noite.gpr` — Ghidra 12.2 project (`noite.rep` is not in git).
  Programs: `NOITE.EXE` (main game) and the minigames `ENCAIXE`, `INFERNO`,
  `INV`, `JARDIM`, `SALGIN`, `SAUNA`, `SERIAL`, `TIRO`, `XILINDRO` (`.EXE`).
  Ghidra is the source of truth.
- `ghidra/scripts/` — Ghidra scripts run through `run_script_inline`;
  `ghidra/cspec/` — calling-convention spec extensions installed in the program.
- `toolchain/ghidra-mcp` — submodule, bethington/ghidra-mcp (`dev` branch; v7.0.0
  doesn't build on Ghidra 12.2). Plugin built with JDK 25 and installed in
  `~/.config/ghidra/ghidra_12.2_NIX/Extensions/GhidraMCP`.
- `./ghidra-mcp.sh` — starts the bridge on `:8000` (the `ghidra` server in
  `.mcp.json`). It relays to the plugin's HTTP server on `:8089` inside the
  Ghidra GUI (Tools → GhidraMCP → Start MCP Server).

- `flake.nix` — dev shell (`use flake` via direnv, or `nix develop`): Zig
  0.17.0, uv, sqlite. Python is uv-managed (`.python-version`).
- `build.zig`, `src/` — the Zig port. `src/units.zig` is generated.
- `tools/cli/` — the `noite` port tracker (uv workspace member);
  `db/port.sqlite` — its database (committed).

The game logic lives in `CASSETA.INI` (scenes, exits, hotspots, portable items,
WAVE cues) and `JOGO*.INI` (save slots); the EXE is the engine that interprets it.

## Port tracker (`uv run noite …`)

`db/port.sqlite` holds every NOITE.EXE function (Ghidra snapshot: signature,
plate, decompile, disassembly, callees) plus tracking: `kind`, `status`
(`pending`, `in_progress`, `ported`, `failed`; `absorbed` = thunk/default
stub/type test, `replaced` = CRT/API, `dead`), `unit`, `tested`. A **unit** is
one Zig file (module, behaviour or scene handler) owning a set of functions.

```
noite import                 # refresh from Ghidra (needs the MCP bridge; keeps tracking)
noite status [--segments]    # counts by status / kind / segment, units
noite show <addr|name>       # row, callers/callees, decompile (--asm) — no Ghidra needed
noite mark <fn…> -s dead     # fix a status by hand (--by <addr> for absorbed)
noite unit new <name> -k module|behaviour|handler [--path src/x.zig] [--notes …]
noite unit add <unit> <fn…> [--match 'backdrop_*'] [--move];  unit rm <fn…>
noite unit show <unit> / unit list / unit sync   # sync: stubs + src/units.zig (main only)
noite check [-w <unit>] [--fix-status]           # @orig tags vs the DB
noite build|test [-w <unit>] [zig args]          # zig build [test]; Debug, self-hosted only
```

Workflow (one agent per unit, any number in parallel):

1. `noite next` — units whose callees outside the unit are all done
   (`--blocked` says what blocks the rest).
2. `noite start <unit>` — atomic claim; makes worktree `work/<unit>/` on
   branch `port/<unit>`, with each function's snapshot in `work/<unit>/.ref/`.
3. In the worktree, write the unit's file only: one
   `// @orig <seg:off> <name>` per function (`(absorbed)` for stubs it
   absorbs); tests optional for now — tag them with
   `// @orig <seg:off> <name> oracle=emulated|asset|documented|trace`.
   `noite test`, commit (commit skill).
4. `noite finish <unit>` (run it from the main checkout) — rebases on main,
   gates (`zig fmt --check`, `zig build`, `zig build test`, `noite check`,
   every unit function tagged, no files of other units / `db/` /
   `src/units.zig`), fast-forwards main, marks the functions `ported`,
   removes the worktree, commits the DB snapshot and pushes.
   `noite failed <unit> "why"` / `noite release <unit>` give the claim up
   (`-k` keeps the worktree).

Units are created on main during the design pass (`unit new` + `unit add`,
then `unit sync` and commit); import seeds one unit per `handler_*`. The DB
is committed so a clone can resume without Ghidra; only the main checkout's
copy is ever opened, and `noite snapshot` commits it safely while agents run.

## Binary facts (NOITE.EXE — the minigames share the toolchain)

- **Format:** 16-bit NE, Windows 3.1, Ghidra language `x86:LE:16:Protected Mode`.
- **Compiler:** Microsoft Visual C++ 1.5x (LINK 5.60), C++ without MFC, built
  on Microsoft's WinG sample skeleton (`AppWndProc`, `AppAbout`). Code uses
  386 instructions (`ENTER`/`LEAVE`, `66`-prefixed `PUSH imm32`, `dword` moves).
- **Segments:** Ghidra maps NE segment *n* to `0x1000 + (n-1)*8`.
  - `1000` — **USE32 segment** (32-bit code, the `transrle.cpp` RLE blitter).
    Ghidra decodes it as 16-bit, so its listing is garbage (`PUSH EBP`,
    `MOVZX BP,SP`, stray `ADD byte ptr [BX+SI],AL`). Do not type or rename
    anything there from the 16-bit view.
  - `1008` — MSVC C runtime + startup (`entry` at `1008:001a`).
  - `1010`–`1028` — game code. `1030`–`1048` — tiny BSS segments.
  - `1050` — DGROUP (DS). `1108` — import thunks (one 4-byte stub per API).
- **Addresses:** the MCP tools accept `seg:off` (`1018:32d6`) directly.
- **Prologue:** `ENTER n,0; PUSH DS; MOV AX,0x1050; MOV DS,AX` → epilogue
  `POP DS; LEAVE; RETF [n]`. Tiny functions skip `ENTER` but keep the DS load.
- **`MOV ES,word ptr [0x11xx]`** loads a relocated segment slot whose value is
  `0x1050` — so `ES:[x]` after it is just DGROUP `x` (Ghidra already shows it
  as `DAT_1050_x`).
- **Calling conventions:** most functions are `far pascal` (`RETF n`, callee
  pops, args pushed **left to right**); some are `far cdecl` (plain `RETF`,
  caller pops). Ghidra's x86-16 has no `__pascal` — see the
  `ghidra-fix-signature` skill for the mapping and the 4-byte alignment trap.
- **C++:** objects are reached through far pointers; a virtual call is
  `LES BX,[obj]; LES BX,ES:[BX]; CALLF [BX+slot]` with `this` pushed **last**.
- **Imports:** Ghidra names the KERNEL/USER/GDI/MMSYSTEM/WAVEMIX imports but
  types none of them (`undefined X(void)`), and there are no Win16 types
  (`HWND`, …) in the program. Untyped thunks make every call site decompile
  wrong (`MESSAGEBOX(0x1018,0x30,…)`). WinG imports show as ordinals:
  `Ordinal_1001` WinGCreateDC, `1002` WinGRecommendDIBFormat, `1003`
  WinGCreateBitmap, `1004` WinGGetDIBPointer, `1005` WinGGetDIBColorTable,
  `1006` WinGSetDIBColorTable, `1007` WinGCreateHalftonePalette, `1008`
  WinGCreateHalftoneBrush, `1009` WinGStretchBlt, `1010` WinGBitBlt.
- **Strings** used by code often live in the code segment (`1018:36d8`), passed
  as `PUSH 0x1018; PUSH 0x36d8`.

## Architecture (NOITE.EXE)

Verified:
- WinG sample-style shell: one 640×480 window whose procedure forwards
  messages to a single global game object.
- C++ engine: a short class chain for the game object; scenes are classes
  with virtual inheritance sharing one large base interface.
- Scenes are data-driven (`CASSETA.INI`) plus a table of hand-written
  per-scene handlers, filled at startup and indexed by the current scene.
  A handler sees every window message first; if it declines, the engine
  default runs.
- Minigames are separate EXEs started with `WinExec` from scene handlers.
  They talk to the main game through private window messages: the main game
  sends its window handle, the minigame hides the main window and, on exit,
  reports won/lost and a score. The main game adds the score and takes a
  life on a loss.

Inferred (not traced): the handler index is the scene number; the EXE path
prefix comes from `CASSETUP.INI`.

## ghidra-mcp 7.0 notes

- The MCP server is `ghidra`, so tools are `mcp__ghidra__<name>`.
- `get_functions` replaces the old decompile/callers/signature/variables tools;
  pass `fields=` to keep the payload small (`include_disasm=true` for the
  listing, or use `disassemble_function`).
- `set_function_prototype` applies the name in the prototype string to the
  function (thunks and normal functions alike) — always write the intended
  name (or the current `FUN_` name) there, never a placeholder.
- The tool's own naming enforcement is **off**: the Tool Option *GhidraMCP
  HTTP Server ▸ Strict Naming Enforcement* is unticked, and
  `ghidra/noite.rep/.ghidra-mcp/conventions.json` disables its global-name,
  plate-comment and struct-field rules (read only when the plugin's server
  starts). Follow the naming conventions below.
- `create_struct` misplaces fields: with explicit offsets it drops the ones
  at 0/2 and appends others at wrong offsets. Create structs with
  `ghidra/scripts/NoiteStructs.java` (and set fields at an offset with
  `NoiteFieldSet.java`) via `run_script_inline`. `modify_struct_field`
  (rename/retype by name) works.
- Far cdecl functions returning 32 bits use the spec extensions in
  `ghidra/cspec/` (`__cdecl16far_dxax_ptr`, `__cdecl16far_dx_ax`).
- Win16 API thunks and the SDK structs they take (`RECT`, `MSG`,
  `PAINTSTRUCT`, `BITMAPINFO`, …) are typed; WinG ordinals are renamed.

## Naming conventions

| Kind | Convention | Example |
|---|---|---|
| Trivial variable | one letter (if unclear, make it a local) | `i`, `n`, `c` |
| Local variable | `camelCase` | `count`, `curSlot` |
| Global variable | `g_` + `camelCase` (always, even pointers) | `g_trackPoints`, `g_videoDriver` |
| Const / macro | `SCREAMING_SNAKE_CASE` | `MAX_RACERS` |
| Struct / enum | bare `PascalCase`, no module prefix | `Car`, `Bitmap` |
| Struct member | `camelCase` | `kind`, `lodCount` |
| Enum value | `SCREAMING_SNAKE_CASE` | `GEAR_REVERSE` |
| Public function | `xx_snake_case`, using the module's two-letter prefix, declared in its `.H` | `ga_buy_part` |
| Private function | `static`, `snake_case` | `static build_list` |
| Source file | DOS 8.3, upper case, named for what the module is; its header has the same base name | `GARAGE.C`, `GARAGE.H` |

A *module* is one original source file (one object). Named public functions
use `xx_snake_case`, where `xx` is the module's unique two-letter prefix
(`GARAGE.C` → `ga_...`). Private functions remain `static snake_case`.
Address placeholders (`FUN_xxxx_xxxx`, `DAT_xxxx_xxxx`) stay until evidence
supports a name; functions the C runtime owns keep their runtime names.
- `run_script_inline` writes the script to `~/ghidra_scripts/<Class>.java`;
  delete it afterwards.
