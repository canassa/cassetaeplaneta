---
name: zig-developer
description: Use when writing, reviewing or debugging the Zig port of Noite Animal (NOITE.EXE rewritten natively). Provides an offline Zig 0.17 language reference, a 0.16-to-0.17 change summary, and the port's house rules (origin tags, faithful-first translation, original bugs behind flags, flattening the C++ classes, 16-bit arithmetic). Check the installed Zig 0.17 standard library for exact APIs rather than relying on memory.
---

# Zig developer for the Noite Animal port

The port rewrites `NOITE.EXE` (16-bit Win16 C++, see `CLAUDE.md`) as a native
Zig program. Ghidra is the specification; the original game running under an
emulator is the oracle. Zig breaks API between releases, so **never answer Zig
questions from memory** — look it up:

- **Installed std library — the gold standard.** It is the reference for how to
  write Zig (naming, error handling, allocator threading, doc comments, test
  placement) and for exact signatures. Before writing a non-trivial module, find
  an analogous std module and mirror its conventions. Locate it with
  `zig env` (prints **ZON, not JSON** — don't pipe it to `jq`):

  ```sh
  STD=$(zig env | sed -n 's/.*\.std_dir = "\(.*\)".*/\1/p')
  grep -rn "pub fn readInt" "$STD/Io/Reader.zig"
  ```

- **Language reference (offline, split by section):** `zig-langref/` — one
  Markdown file per section of the 0.17.0 reference. Pick the section from its
  `README.md` index; never load the whole thing.
- **What changed in 0.17:** [Zig 0.16 → 0.17](zig-0.17-changes.md) — read it
  before trusting anything remembered from older Zig.

## Port house rules

These are invariants, not style preferences. Flag violations in review.

- **Every Zig function cites its origin.** Put `// @orig <seg:off> <ghidra_name>`
  on the line above each function or `switch` case translated from the
  original, one tag per original function (thunks/stubs it absorbs get their own
  `(absorbed)` tag). The port tracker checks these tags against its database;
  untagged code is either platform code or a bug. Struct fields cite their
  origin too — `// @orig SceneObject+0x456` or `// @orig g_lives` (free-form,
  not checked). Replaced CRT/API functions get a plain comment, not a tag
  (`noite check` warns on tagging them).
- **Faithful first.** Translate behaviour as the original does it, original
  bugs included. Don't "improve" logic while porting. Every known original bug
  (`BUGS.md`) is reproduced by default and its fix sits behind a named flag in
  one `Fixes` options struct; never fix silently.
- **Flatten the C++.** The original's virtual inheritance, vbtables,
  `this`-adjusting thunks, `is_x`/`as_x` type tests and default virtual stubs
  have no counterpart. One `Object` struct with a `kind` tag replaces the
  classes (`obj.is(.mover)` / `obj.as(.portable)` replace type tests); a
  virtual slot becomes one dispatcher (`pub fn moveTick`, named after the
  vtable field) that switches on `kind` and calls one function per original
  override, each tagged `@orig`; default stubs become the `else` branch.
- **One port unit per file.** A unit (an engine module, one virtual behaviour
  across all kinds, or one scene handler) owns its file; don't edit another
  unit's file — record what you need in the tracker instead.
- **Keep the original's integer widths and arithmetic.** The original is 16-bit:
  `int` is `i16`, `long` is `i32`, coordinates and counters wrap. Use the same
  widths and wrapping operators (`+%`, `-%`, `*%`) where the original can
  overflow; use `@divTrunc` for C division. Signed/unsigned mismatches in the
  original are behaviour — reproduce them.
- **Determinism.** Same inputs, same events. Reproduce the original's random
  number generator (the C runtime's LCG: `seed * 0x343fd + 0x269ec3`, result
  `(seed >> 16) & 0x7fff`) and its timer periods, and emit the game's private
  events (scene started, exit finished, animation done, movement done, player
  stepped, object created, minigame result) in the same order, so the event log
  can be diffed against the original's.
- **Platform code is isolated.** Windows, WinG, GDI, WaveMix, MCI and timers
  are replaced by one platform layer (window, 8-bit palettized framebuffer,
  sound mixing, video playback, timers, input). Game code never calls the OS or
  SDL directly.
- **No global mutable singletons.** The original keeps state in DGROUP globals;
  the port keeps it in one `Game` state struct passed down explicitly, so units
  are testable. Field names follow the original globals' names
  (`g_lives` → `lives`) and cite them.
- **Allocation is simple.** A long-lived allocator for game-lifetime data and an
  arena per scene, reset on scene change. No per-frame allocation in the main
  loop. Test with `std.testing.allocator` to catch leaks.
- **Panics mean bugs.** Malformed asset or INI data returns an error; it never
  panics.
- **Tests are optional for now** — convert first, verify later. When you do
  write one, its expected values must not come from your own reading of the
  decompile: use the real `assets/`, facts documented in Ghidra (constants, RNG
  sequence, grid sizes), or `tools/oracle` (runs the original function) when
  cheap. Tag each test `// @orig <seg:off> <name> oracle=<kind>` (kind:
  `emulated`, `asset`, `documented` or `trace`); `noite check` reads it.
  Tests run with the repo root as cwd (`@embedFile` can't reach `assets/`):
  `const text = try std.Io.Dir.cwd().readFileAlloc(std.testing.io,
  "assets/CASSETA.INI", gpa, .limited(1 << 20));`

## Port design (binding)

`docs/DESIGN.md` is the architecture: read it before porting. In short:
shared types live in `src/core/` (`Game`, `Object`, `Scene`, …) and the OS
in `src/platform/` — units add functions, not architecture. Engine,
behaviour and handler code take `g: *Game`; leaf modules take the narrowest
struct. Messages go through `g.post` / `g.send` / `g.setTimer` /
`g.setSystemTimer` exactly where the original posts, sends or sets them.
`hwnd`/`hdc` parameters are dropped; `Backdrop *` stays explicit. A unit's
public names are the Ghidra name in camelCase minus its class prefix
(`wave_play` → `sound.play`); handler globals go in the handler's `State`
(`g.sceneState(State)`). C strings stay `[N]u8` (`core/cstr.zig`); pointer
NULL → `?*T`, integer sentinels stay; original fatal errors →
`error.Fatal`; unchecked original limits → `error.LimitExceeded`. A unit
calling a virtual slot needs the slot's owning unit done first (slot table
in the design; `noite next` can't see virtual calls).

## Naming

Follow Zig's conventions (the std library): `camelCase` functions and
variables, `PascalCase` types, `snake_case` files. The original's names live in
the `@orig` tags, not in Zig identifiers — translate `scene_object_get_x` to
`getX` on `Object`.

## Toolchain

Zig **0.17.0**, pinned in `flake.nix` (`github:mitchellh/zig-overlay`; direnv
`use flake` or `nix develop`). Work goes through the `noite` tracker
(`CLAUDE.md` → Port tracker): claim a unit, port it in its worktree, `noite
finish`. `zig fmt` before committing; `zig build test` must pass.

**Always build Debug with the self-hosted backend.** Never pass `-Doptimize=Release*`,
`-fllvm` or set `use_llvm = true` — the LLVM backend is far too slow to iterate with.
