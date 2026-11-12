# Native port of NOITE.EXE — design

The plan every porting agent reads before claiming a unit. House rules are
in `.claude/skills/zig-developer/SKILL.md`; binary facts and the tracker
workflow in `CLAUDE.md`; original bugs in `BUGS.md`. Ghidra (via the tracker
snapshot, `noite show`) is the specification.

## Source layout

```
src/main.zig             entry, args, main loop (skeleton)
src/core/                shared types and Win16 replacements (skeleton, not units)
  game.zig               Game: the game object + every engine DGROUP global
  object.zig             Object, Kind, parts, Frame, Dib, ObjectList, Rect
  world.zig              Scene, Backdrop, Grid, DrawList, UpdateList, Condition, …
  modstate.zig           Ini (reader state + g_ini* record), Sound (wave table)
  msg.zig                Msg and the message numbers (wm.*, noite.*)
  queue.zig              the emulated Win16 message queue and timers
  handler.zig            Handler type, per-scene State storage
  fixes.zig              Fixes (BUGS.md fixes, all off)
  cstr.zig crt.zig       C strings in fixed buffers; the CRT rand()
src/platform/            the platform layer (not units)
  platform.zig           the Platform interface
  sim.zig                files over assets/, media timing, minigame stub
  headless.zig sdl.zig   backends
src/<unit>.zig           module units
src/behaviour/<unit>.zig behaviour units (one group of virtual slots)
src/handlers/<scene>.zig scene handler units
src/units.zig            generated index (`noite unit sync`)
```

`core/` and `platform/` hold **types and skeleton code only**. Ported
functions live in units. A unit that needs a new field adds it to the core
type in its own commit only if the field is missing from the original
layout (it should not be: every known field is already there).

## Object model

The C++ lattice (SceneObject ← Object3D, Animation, Mover; Animated3D,
Moveable, Actor, Player/DirectionalPlayer, Exit, Portable, ControlPanel,
StatusBar; virtual bases, vbtables, vtordisp and adjustor thunks) is
flattened into **one `Object` struct with a `kind` tag**
(`src/core/object.zig`):

| Kind | original class | INI key | parts live |
|---|---|---|---|
| `local` | Object3D | `Local=` | base, o3d |
| `animated` | Animated3D | `Animated=`, `Static=` | base, o3d, anim |
| `moveable` | Moveable | `Moveable=` | base, o3d, mover |
| `actor` | Actor | `C_Actor=` (none shipped) | base, o3d, anim, mover, actor |
| `player` | DirectionalPlayer | `Player=` | base, o3d, anim, mover, actor (+lives/score) |
| `exit` | Exit | `Exit=`, `2Exit=`, 1Animation | base, o3d, anim, exit |
| `portable` | Portable | `Portable=`, `ZoomPort=` | base, o3d, mover, portable |
| `control_panel` | ControlPanel | `Control=` | base, o3d, anim, panel |
| `status_bar` | StatusBar | `StatusBar=` | base, status |

Every object carries every part (memory is irrelevant); `kind` says which
are meaningful. Field names are the Ghidra member names with
`// @orig Struct+0xNN` origins. Not ported: Actor2D, Player2D, the
standalone Mover/Animation/Player classes (never instantiated), the unused
mover/backdrop subclass remains, CompoundCondition (marked `dead`).

**Type tests** (SceneObject slots 42–57, 5D/5E) are `obj.is(.class)` /
`obj.as(.class)` (null like the original's NULL); `asX` pointer
adjustment disappears — the part is just a field. Thunks, vtordisp
adjustors and default stubs are `absorbed` in the tracker.

**Virtual slots → dispatchers.** Each slot becomes one `pub fn` named after
the `SceneObjectVtbl` field (`draw`, `moveTick`, …) in the behaviour unit
that owns the slot. It switches on `obj.kind` and calls one Zig function per
original implementation; **each implementation function carries the
`@orig` tag** of the function it ports (`moverMoveTick` for
`mover_move_tick`). Derived implementations that call a base one directly
(Actor's moveTick → Moveable's) call that implementation function, not the
dispatcher. The default stub (`scene_object_*_default`, absorbed) is the
`else` branch.

```zig
// behaviour/movement.zig — SceneObject slot 3C
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .moveable, .portable => moveableMoveTick(g, obj, bd),
        .actor => actorMoveTick(g, obj, bd),
        .player => playerMoveTick(g, obj, bd),
        else => {}, // scene_object_move_tick_default
    }
}
// @orig 1010:6612 player_move_tick
fn playerMoveTick(g: *Game, obj: *Object, bd: *Backdrop) void { … }
```

Signatures: `(g: *Game, obj: *Object, <args in source order>)`. `hwnd`
and `hdc` parameters are dropped (one window; the DC is the platform
screen); the `…Dc` and plain variants both stay (two functions, two tags).
`Backdrop *` arguments stay explicit (`bd: *Backdrop`). Flags-only
returns are `bool`; other returns keep the original type (`i16`, `?*Object`).

### SceneObject slots (kinds: L local, A animated, M moveable, Ac actor, P player, E exit, Po portable, C control_panel, S status_bar)

Generated from the 14 vtables (thunks resolved). "dead" = never called.
Type-test slots 43–57 and 5D/5E are `Object.is/as`.

| slot | behaviour | unit | default | overrides (impl: kinds) |
|---|---|---|---|---|
| 00 | slot00 | misc | FUN_1010_12e6 |  |
| 01 | slot01 | misc | FUN_1010_12fe |  |
| 02 | enableRle | misc | so_enable_rle |  |
| 03 | isRle | misc | so_is_rle |  |
| 04 | getSceneName | misc | so_get_scene_name |  |
| 05 | getWorldX | space3d | so_get_world_x_default (stub) | object3d_get_world_x: L A M Ac P E Po C |
| 06 | getWorldDepth | space3d | so_get_world_depth_default (stub) | object3d_get_world_depth: L A M Ac P E Po C |
| 07 | getWorldElev | space3d | so_get_world_elev_default (stub) | object3d_get_world_elev: L A M Ac P E Po C |
| 08 | getSizeW | space3d | so_get_size_w_default (stub) | object3d_get_size_w: L A M Ac P E Po C |
| 09 | getSizeH | space3d | so_get_size_h_default (stub) | object3d_get_size_h: L A M Ac P E Po C |
| 0A | getSizeD | space3d | so_get_size_d_default (stub) | object3d_get_size_d: L A M Ac P E Po C |
| 0B | getAnchorX | space3d | so_get_anchor_x_default (stub) | object3d_get_anchor_x: L A M Ac P E Po C |
| 0C | getAnchorY | space3d | so_get_anchor_y_default (stub) | object3d_get_anchor_y: L A M Ac P E Po C |
| 0D | getX | position | so_get_x | mover_get_x: M Ac P Po |
| 0E | getY | position | so_get_y | mover_get_y: M Ac P Po |
| 0F | getStepX | position | so_get_step_x_default (stub) | mover_get_step_x: M Ac P Po |
| 10 | getStepY | position | so_get_step_y_default (stub) | mover_get_step_y: M Ac P Po |
| 11 | slot11 | dead | FUN_1010_13e6 |  |
| 12 | setElevation | space3d | so_set_elevation_default (stub) | object3d_set_elevation: L A E C; moveable_set_elevation: M Ac P; portable_set_elevation: Po |
| 13 | setAnchor | space3d | so_set_anchor_default (stub) | object3d_set_anchor: L A M Ac P E Po C |
| 14 | setSize | space3d | so_set_size_default (stub) | object3d_set_size: L A M Ac P E Po C |
| 15 | setWorldElev | space3d | so_set_world_elev_default (stub) | portable_set_world_elev: Po |
| 16 | drawBounds | visibility | so_draw_bounds_default (stub) | object3d_draw_bounds: L A M Ac P E Po C |
| 17 | addDirtyRect | render | so_add_dirty_rect |  |
| 18 | computeOverlap | render | so_compute_overlap |  |
| 19 | restoreBackground | render | so_restore_background | mover_restore_background: M Ac P Po |
| 1A | drawDirtyTo | render | so_draw_dirty_to | mover_draw_dirty_to: M Ac P Po |
| 1B | draw | render | so_draw | animation_draw: A Ac; player_draw: P; exit_draw: E; control_panel_draw: C |
| 1C | drawClipTo | render | so_draw_clip_to |  |
| 1D | drawClip | render | so_draw_clip |  |
| 1E | erase | render | so_erase | animation_erase: A Ac P E C |
| 1F | slot1F | misc | FUN_1010_1720 | FUN_1010_8b24: A; FUN_1010_85ce: Ac; FUN_1010_81c8: P; FUN_1010_7c6a: E; FUN_1010_7ee2: C |
| 20 | redraw | visibility | so_redraw | animated3d_redraw: A Ac P E C |
| 21 | hideAndInvalidate | visibility | so_hide_and_invalidate |  |
| 22 | blitToDc | visibility | so_blit_to_dc | moveable_blit_to_dc: M Ac P Po |
| 23 | invalidate | visibility | so_invalidate | moveable_invalidate: M Ac P Po |
| 24 | slot24 | dead | FUN_1010_b10c | FUN_1010_8956: M; FUN_1010_8616: Ac; FUN_1010_8210: P; FUN_1010_793c: Po |
| 25 | hide | visibility | so_hide | mover_hide: M Ac P Po |
| 26 | show | visibility | so_show | animated3d_show: A E C; mover_show: M Po; actor_show: Ac P |
| 27 | occupy | occupancy | so_occupy | player_occupy: P; control_panel_occupy: C; status_bar_occupy: S |
| 28 | vacate | occupancy | so_vacate | player_vacate: P; control_panel_vacate: C; status_bar_vacate: S |
| 29 | reoccupy | occupancy | so_reoccupy |  |
| 2A | attach | occupancy | so_attach | object3d_attach: L A E; moveable_attach: M Ac P Po; control_panel_attach: C; status_bar_attach: S |
| 2B | canStep | occupancy | so_can_step_default (stub) | moveable_can_step: M Ac P; portable_can_step: Po |
| 2C | isStepBlocked | occupancy | so_is_step_blocked |  |
| 2D | isAvi | animation | so_is_avi_default (stub) | animation_is_avi: A Ac P E C |
| 2E | nextFrame | animation | so_next_frame_default (stub) | animated3d_next_frame: A Ac P E C; portable_next_frame: Po |
| 2F | prevFrame | animation | so_prev_frame_default (stub) | animated3d_prev_frame: A Ac P E C; portable_prev_frame: Po |
| 30 | play | tick | so_play_default (stub) | animated3d_play: A Ac P C; exit_play: E |
| 31 | playIdle | animation | so_play_idle_default (stub) | directional_player_play_idle: P |
| 32 | stopAndRedrawDc | animation | so_stop_and_redraw_dc_default (stub) | animated3d_stop_and_redraw_dc: A E C; actor_stop_and_redraw_dc: Ac; directional_player_stop_and_redraw_dc: P |
| 33 | stopAndRedraw | animation | so_stop_and_redraw_default (stub) | animated3d_stop_and_redraw: A E C; actor_stop_and_redraw: Ac; directional_player_stop_and_redraw: P |
| 34 | tick | tick | so_tick_default (stub) | animated3d_tick: A Ac; player_tick: P; exit_tick: E; control_panel_tick: C |
| 35 | stop | animation | so_stop_default (stub) | animated3d_stop: A Ac P E C |
| 36 | advanceFrames | animation | so_advance_frames_default (stub) | animation_advance_frames: A Ac P E C |
| 37 | moveTo | movement | so_move_to_default (stub) | moveable_move_to: M Ac Po; directional_player_move_to: P |
| 38 | moveToEdgeH | movement | so_move_to_edge_h_default (stub) | moveable_move_to_edge_h: M Ac Po; directional_player_move_to_edge_h: P |
| 39 | moveToEdgeV | movement | so_move_to_edge_v_default (stub) | moveable_move_to_edge_v: M Ac Po; directional_player_move_to_edge_v: P |
| 3A | stopMovingDc | movement | so_stop_moving_dc_default (stub) | moveable_stop_moving_dc: M Po; actor_stop_moving_dc: Ac; directional_player_stop_moving_dc: P |
| 3B | stopMoving | movement | so_stop_moving_default (stub) | moveable_stop_moving: M Po; actor_stop_moving: Ac P |
| 3C | moveTick | movement | so_move_tick_default (stub) | moveable_move_tick: M Po; actor_move_tick: Ac; player_move_tick: P |
| 3D | getTimerId | animation | so_get_timer_id_default (stub) | animated3d_get_timer_id: A E C; moveable_get_timer_id: M Po; actor_get_timer_id: Ac P |
| 3E | isMoving | movement | so_is_moving_default (stub) | moveable_is_moving: M Ac P Po |
| 3F | isRunning | animation | so_is_running_default (stub) | animation_is_running: A Ac P E C |
| 40 | moveToAndDrop | space3d | so_move_to_and_drop_default (stub) | object3d_move_to_and_drop: L A E C; moveable_move_to_and_drop: M Ac P; portable_move_to_and_drop: Po |
| 41 | setPosition | position | so_set_position | moveable_set_position: M Ac P Po |
| 42 | isScrollTarget | position | so_is_scroll_target | player_is_scroll_target: P |
| 58 | redrawOverlapping | visibility | so_redraw_overlapping_default (stub) | object3d_redraw_overlapping: L A M Ac P E Po C |
| 59 | hitboxOverlaps | position | so_hitbox_overlaps |  |
| 5A | boundsOverlap | position | so_bounds_overlap |  |
| 5B | slot5B | dead | FUN_1010_1cd2 |  |
| 5C | slot5C | dead | FUN_1010_1cc6 |  |
| 5F | isEnabled | exit | so_is_enabled_default (stub) | exit_is_enabled: E |
| 60 | getExitIndex | exit | so_get_exit_index_default (stub) | exit_get_exit_index: E |
| 61 | slot61 | dead | FUN_1010_1d12 |  |
| 62 | slot62 | dead | FUN_1010_1d1e |  |
| 63 | slot63 | dead | FUN_1010_1d2a |  |
| 64 | slot64 | dead | FUN_1010_1d36 |  |
| 65 | slot65 | dead | FUN_1010_1d42 |  |

### Other vtables

| vtable | slots → where |
|---|---|
| Object3DVtbl (8) | `space3d`: 00 slot00 (ret 0), findSupport, isBelow (Po override), isAboveOnScreen, isInFrontOf, overlaps3d, moveToAtElev (M/Ac/P, Po), dropToSupport (M/Ac/P, Po) |
| AnimationVtbl (8) | `avi`: setAvi, setAviName, getAviName, openAvi, playAvi, closeAvi, stopAvi; `animation`: 07 playOnce |
| MoverVtbl (1) | `movement.placeAt`: mover_place_at (no kind uses it alone) / moveable_place_at (M Ac P Po) |
| DirectionalPlayerVtbl (2) | 00 placeAt as above; 01 `animation.playWalkH` (no callers) |
| ControlPanelVtbl (17) | 00–07 Animation; 08–10 plain functions in `panels` (one kind) |
| Backdrop/Grid/PerspectiveBackdrop | flattened: only PerspectiveBackdrop exists; base stubs absorbed; `backdrop` (+ `grid` queries, `projection` math) |
| SceneVtbl (16) | flattened to the INI scene class: `scene` (+ `scene_loader` for slot 07 create) |
| GameVtbl (14) | flattened to NoiteGame: `game` (00 dispatch, 02/04/05/06 creators, 08 onCreate), `game_hook` (01), `game_scenes` (07 init, 0C/0D), `save` (09–0B) |
| ConditionVtbl (3) | `condition`: `switch (cond.kind)` (base / flag) |

## State

`Game` (`src/core/game.zig`) is the original Game object (classes
Game/IniGame/NoiteGame flattened) **plus every engine DGROUP global**
(`g_lives` → `g.lives`, `g_newObject` → `g.newObject` …), one heap
instance with a stable address. It holds: the current/old scene (which
owns its backdrop, object list and exits), player / control panel / status
bar objects, global objects, used objects, the update list and draw list,
the INI reader state (`g.ini`, incl. the section table and the `g_ini*`
record), the wave table (`g.sound`), lives/score, minigame results,
picked items, saved position, the handler table, the CRT `rand` state,
the message queue and timers, `fixes`, the platform, and every handler's
`State` (`g.scenes`).

Access: engine, behaviour and handler code take `*Game`. **Leaf modules
take the narrowest thing**: `grid` takes `*Grid`, `draw_list` `*DrawList`
(+ a comparison callback where it needs the virtual isInFrontOf),
`update_list` `*UpdateList`, `object_list` `*ObjectList`, `projection`
`*const Backdrop` + plain numbers, `ini` `*Ini` + `Platform`, `sound` `*Sound` + `Platform`, `dib`
bytes/`Dib`. That keeps them testable with no `Game`.

Allocation: objects, DIBs and scenes are `g.gpa.create`/`destroy`d where
the original calls `new`/`delete` (units `object_create`, `object_init`,
`scene`); per-scene scratch (backdrop pixels, loader temporaries) goes in
`g.scene_arena`, reset by the scene switch. No allocation in the per-message
path. Pointers (`?*Object`) mirror the original's far pointers, dangling
exactly where it dangles — don't add guards beyond what it does.

## Events and timing

The original is message-driven: `AppWndProc` → `game_handle_message`
(scene → its handler, then the hook, then the engine default) →
DefWindowProc. The port keeps the Win16 model so the event order (and so a
message trace) can match the original's:

- `core/queue.zig` emulates the application queue: **posted messages
  (FIFO, 8 slots — PostMessage fails when full), then input (mouse moves
  coalesced), then WM_PAINT, then timers**. `g.post` = PostMessage;
  `g.send` = SendMessage (nested, immediate dispatch); `g.setTimer`/
  `killTimer` = SetTimer (WM_TIMER); `g.setSystemTimer`/`killSystemTimer`
  = USER ordinals 11/182 (WM_SYSTIMER: the 50 ms engine tick id 1,
  animation/movement timers 5–10). A due timer yields one message when
  nothing else is pending and is rearmed from delivery time.
- The main loop (`src/main.zig`): drain platform events (input → queue,
  OS notifications → posted), dispatch one due message, repeat; when the
  queue is empty, present the screen and wait for the next timer/event.
- OS notifications come from the platform at the time they would happen:
  MM_WOM_DONE (0x3bd) when a wave's duration has elapsed (wParam =
  channel), MM_MCINOTIFY (0x3b9, wParam 1, lParam = device) when an AVI
  ends, the minigame's 0x40c/0x40a.
- Private messages: 0x401 scene started · 0x402 exit finished (exit index)
  · 0x403 animation finished (id) · 0x404 movement finished (id) · 0x405
  player stepped (id) · 0x406 object created (id, `g.newObject`; sent) ·
  0x40a minigame result (won, score) · 0x40b/0x40c minigame handshake ·
  0x40d unlock input. Keep every `PostMessage`/`SendMessage` of the
  original as `g.post`/`g.send` at the same point — never call the target
  code directly instead.
- Determinism: the headless backend has a virtual clock (jumps to the next
  deadline) and scripted input; `random_below` reseeds the CRT LCG from
  `plat.unixTime()` on every call, so the clock fully decides it.
- Trace: `--trace FILE` logs every dispatched message
  (`ticks S|Q id wparam lparam`), for diffing against the original run
  under an emulator. Unverified (fix in `queue.zig` when traces disagree):
  queue capacity, order of simultaneous timers, timer rearm base.

## Scene handlers

```zig
// src/handlers/2fpontoc.zig
pub const State = struct { bus: ?*Object = null, boarding: i16 = 0, … }; // its g_s2fpontoc* globals
// @orig 1018:f182 handler_2fpontoc
pub fn handle(g: *Game, m: Msg) i16 { const s = g.sceneState(State); … }
```

- Signature: the original far cdecl `(hwnd, msg, wParam, lParam)` minus
  hwnd; returns non-zero = handled (engine default skipped).
- Registration: `register_scene_handlers` (unit `game`) stores each
  `units.handler_<scene>.handle` at its Screen= Number in `g.handlers`.
  Dispatch: `ini_scene_handle_message` (unit `scene`) calls
  `g.handlers[scene.sceneNumber]` for 0x406 always, otherwise when
  `handlerEnabled`.
- Globals: a handler's `g_s<scene>*` globals become fields of its `State`
  (default-initialised like the original's DGROUP data); shared ones
  (`g_slotScreenSaves`) are `Game` fields.
- Handlers talk to the engine through the units' public functions
  (`ini_game_switch_scene` → `game_scenes.switchScene`, `wave_play` →
  `sound.play`, slots → `animation.stopAndRedraw(g, obj, bd)` …) and to the
  OS through `g.plat` (WinExec, FindWindow, postTo, showMain, mciString).

## Naming across units

Agents port in parallel, so names must be predictable: a unit's public
function is the Ghidra name in camelCase **minus the unit's class prefix**
(`scene_object_reset_rects` in `frames` → `frames.resetRects`;
`ini_game_switch_scene` in `game_scenes` → `game_scenes.switchScene`;
`wave_play` → `sound.play`); a dispatcher is the vtable field name
(`render.draw`, `movement.moveTo`, `space3d.findSupport`). Implementation
functions of a slot are `<class><Slot>` (`moverMoveTo`, `exitTick`). Keep
`pub` whatever another unit calls.

## Platform layer

`src/platform/platform.zig` — a vtable interface (`Platform`, like
`std.mem.Allocator`): clock (`ticks`, `unixTime`), events (`poll`, `wait`),
screen (640×480 8-bit + 256-colour palette, `present`; GetDC + WinGBitBlt
become writes into `screen().pixels`), GDI text (`textOut`, `textExtent`),
DOS files (`open/read/write/seek/close` on `\FASE2\X.WAV`-style paths,
case-insensitive over `assets/`, writes to `save/` which is read first),
WaveMix (`waveOpen/Free/Play/Flush`, `mixActivate`), MCI (`mciString` for
the music/waveaudio commands, `aviOpen/Play/Stop/Close`), other programs
(`winExec`, `findWindow`, `postTo`, `showMain`) and `messageBox`.

Backends: **headless** (virtual clock, scripted input; tests, traces) and
**SDL3** (window, palette → XRGB texture, mouse/arrow keys as Win16
messages, real clock). Both share `sim.zig`: files, media durations from
the file headers and the minigame stub, so they emit the same events.

Verified: SDL3 3.4 (nixpkgs, via pkg-config) links and runs with Zig
0.17.0 Debug, **self-hosted x86_64 backend and Zig's own linker**
(`use_llvm = false, use_lld = false`, set in `build.zig`), ~1 s builds.
SDL is declared by hand (`@cImport` is gone in 0.17; no translate-c).

Not implemented yet (platform tasks, not tracker units):
- **Video**: the 79 game AVIs are 640×480 8-bit **Autodesk FLIC in AVI**
  (fourcc `AFLC`; each `00dc` chunk is a FLC frame chunk, magic `F1FA`,
  deltas type 7/SS2) with 8-bit mono 22 050 Hz PCM audio. `SAMPLE.AVI`
  (Cinepak) is a disc extra, unused. A pure-Zig FLC decoder is small.
- **Audio**: WAVs are 8-bit PCM; mixing via SDL audio streams (8 channels).
- **Music**: `VELHA.MID` through MCI `sequencer` ("musica" alias). SDL3 has
  no MIDI; needs a synth (open question). Until then music never notifies.
- **Text**: the control panel's score/lives use GDI TextOut with the system
  font; needs a bitmap font.
- **Minigames** (separate EXEs): stubbed by `sim.zig` — the handshake is
  answered and a configurable result is reported.

## Conventions

- **Strings**: original `char[N]` fields/locals stay `[N]u8`, NUL-terminated;
  functions take `[]const u8` and end at the first NUL (`cstr.slice`).
  strcpy/strcat/sprintf → `cstr.copy/cat/print` (truncate, always
  terminate). Code-segment string constants → Zig literals.
- **Sentinels vs optionals**: pointers → `?*T` (NULL = null). Integer
  sentinels the callers compare against (-1 section offset, -1 timer id,
  -1 exit index, 0 "not found" ids) stay as values — faithful, translates
  one-to-one. Optionals for "no handle" from the platform (`?File`).
- **Errors**: malformed data → a Zig error, never a panic. Original fatal
  paths (`ini_fatal_error`, FatalAppExit, the "Estouro …" checks) →
  `error.Fatal` after `plat.messageBox` with the original text; it
  propagates to `main`. Non-fatal MessageBoxes → `plat.messageBox` and go on.
  Platform failures behave like the API's failure value (OpenFile -1 →
  null, WinExec < 32).
- **Original limits** (150 INI sections, 25 exits, 100 draw nodes / update
  entries, 30 waves, 400 handlers, 65×81 grid, `char[N]`): fixed arrays of
  the original size. Where the original checks, port the check; where it
  would overflow unchecked, return `error.LimitExceeded` (it's memory
  corruption, not behaviour) and note it in the doc comment. An `asset`
  test should show the shipped data stays inside.
- **Integers**: `int` → `i16`, `unsigned` → `u16`, `long` → `i32`, `BYTE`
  → `u8`; wrapping ops where the original can overflow; `@divTrunc`/
  `@rem` for C `/` `%`.
- **Fixes**: `src/core/fixes.zig`, read as `g.fixes.<flag>` at the bug
  site. Add a flag (with its BUGS.md id) when you port a bug's site.
- **CRT/API**: replaced, not ported (`noite` statuses `replaced`); their
  behaviour is in `core/crt.zig`, `core/cstr.zig`, `Game.send/post/
  setTimer…` or the platform. Cite them with plain comments.
- **Out-pointers**: an original output parameter (`int *x`) becomes part of the
  return value (a small struct, e.g. `ScreenPoint {x, y}`), unless the
  callee only sometimes writes it — then keep `*T`.
- **Reading the original**: the decompile drops arguments of virtual calls
  and can show wrong operands around them; take formulas from the
  disassembly (`.ref/*.asm`). A trivial virtual getter is a field read.
- **Tests** optional; when written, oracle per the skill.

## Units and porting order

89 units: 26 modules, 9 behaviours, 53 handlers, `ini_sections` (done).
`noite next` orders by **direct** calls only. Virtual calls
(`CALLF [BX+off]`, slot = off/4) are invisible to it, so a unit is also
blocked until **every unit owning a slot it calls is done** (slot table
above). Before `noite start`, check the slots your functions call and pick
another unit if an owner is pending. The phases are the expected order:

1. **Leaves**: `dib`, `condition`, `projection`, `ini`, `sound` (ready
   now), then `frames`, `misc`, `grid`, `update_list`.
2. **Construction**: `object_init`, `object_list`, `object_create`,
   `backdrop`, `ini_readers`, `avi`.
3. **Behaviours**, in this expected order (verify the slots you call):
   `position`, `space3d`, `occupancy`, `render`, `visibility`,
   `animation`, `tick`, `movement`; `draw_list` after `space3d`
   (it calls isInFrontOf).
4. **Engine**: `exit`, `portable`, `panels`, `scene`, `scene_loader`,
   `game`, `game_scenes`, `save`, `game_hook`, `game_input`, `app`.
5. **Handlers** (53), once phase 4 is done.

A dispatcher can only be called once its unit is merged (a missing `pub fn`
does not compile). If two pending behaviour units need each other's slots,
don't work around it with a local copy: `noite failed <unit> "needs slot
<name> (<unit>)"` and take another unit.
