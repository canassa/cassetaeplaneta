# Native port of SERIAL.EXE — design

SERIAL.EXE ("Serial Killer", the prison-escape shooting gallery that NOITE's
`3farmcai` starts after the escape video) in Zig, next to NOITE's, ENCAIXE's
and TIRO's ports. NOITE's `docs/DESIGN.md`, TIRO's `docs/tiro/DESIGN.md`
(and ENCAIXE's behind it) and the zig-developer skill hold for everything
this file does not override. Ghidra (program `SERIAL.EXE`, through the
tracker snapshot `noite -p serial show`) is the specification; `GAME.md`
(rules, protocol), `DATA.md` (classes, vtables, globals), `FUNCTIONS.md`
(names, dead code, what differs from TIRO), `QUALITY.md` (the build),
BUGS.md K1–K5.

## Decisions

- **Own tree, SERIAL's code; TIRO's Zig as the template.** SERIAL is TIRO's
  sibling build (QUALITY.md §0): the same engine sources, toolchain and
  options (medium model, `/Od`, far 4-byte vtable slots), the same NE
  layout, 590 of its 633 code functions byte-aligned with a TIRO function
  at the same offset (FUNCTIONS.md), every engine vtable TIRO's slot for
  slot, every engine struct TIRO's layout. It is closer to TIRO than TIRO
  is to ENCAIXE. But the two builds are still not one program:
  - four engine functions repaint differently (`mover_move_tick`,
    `scene_object_redraw_overlapping`, `animation_stop_and_redraw_dc`,
    `animation_tick` call SceneObject slot 1E `invalidate` where TIRO's
    call 1D `blitToDc`), `scene_object_restore_background` restores with
    the colour-key copy (`dib_copy_transparent`, key `g_unk00A8`), where
    TIRO's copies opaque (and so `dib_copy_rect` is dead in SERIAL), and
    `wave_play` passes flags 7, not 5;
  - the game module (`1068`) is SERIAL's own: 15 figures in three lanes,
    a Target class of 0x5c bytes with its own fields and a four-slot
    `TargetVtbl` (`startTimer` inserted at slot 1), no hit animation, no
    respawn, the lives, the clock, a 12.9 KB handler;
  - SERIAL's `Game` has other globals (`g_gun`, `g_targets[15]`,
    `g_lives`, `g_timerIds`/`g_timerPeriods`, three waves, `g_spawnToggle`),
    its `Object` other kinds (`gun`, `bullet`) and another Target part.

  So SERIAL gets its own units under `src/serial/`, ported from its own
  functions with its own `@orig` addresses, and does not call TIRO's
  units. **Sharing TIRO's units was weighed and rejected**, for TIRO's
  reasons against sharing ENCAIXE's (docs/tiro/DESIGN.md "Decisions"),
  which hold here unchanged:
  - every TIRO unit takes TIRO's `Game`/`Object`/`Backdrop`; sharing
    means making 20 finished, checked TIRO units generic over the program
    (comptime game and object types, kinds, Target parts) for SERIAL's
    sake, and the five more minigames being designed now on the same
    engine would each add their variant to that generic code;
  - an `@orig` tag maps to one program's address and `noite check` scans
    one tree per program; `noite finish` refuses a unit that edits another
    program's tree, so a SERIAL unit could not land a fix in a shared
    function, and a shared function would need two tags checked against
    two DBs;
  - where SERIAL does differ (above), a shared body needs `if (serial)`
    branches; a copy keeps each port a plain transcription of its binary.

  The copy is cheaper than for TIRO: the TIRO unit of the same name is the
  starting point for every unit (same slot names and numbers, same
  dispatcher signatures, same struct offsets, same function names but
  `tiro_`→`serial_`, `crossbow`→`gun`, `arrow`→`bullet`). Most functions
  are TIRO's bytes with other DGROUP immediates; every plate says so in
  its first line ("Name from TIRO … at …") and adds "SERIAL differs from
  TIRO" where it does. The skeleton already is TIRO's skeleton renamed.
- **Shared, because identical or not game code:** as TIRO: the platform
  layer (`src/platform/`, host included), `core/msg.zig`,
  `core/queue.zig`, `core/cstr.zig`, `core/crt.zig` (`srand`/`rand` are
  MSVC's), `core/stub.zig`, `core/errors.zig`, `core/fixes.zig` (one
  `Fixes`, K-flags prefixed `serial_`), the Win16 data types. Segment
  `1000` is byte-identical to TIRO's and NOITE's: SERIAL's
  `dib.rowsCopy32`/`rowsCopyTransparent32` (tagged 1000:0114 / 1000:0024)
  call NOITE's `src/dib.zig`, as TIRO's do. The state-free delegation rule
  is TIRO's: a SERIAL function may call a NOITE, ENCAIXE or TIRO function
  only when that function takes no program state (no `Game`, `Object`,
  `Backdrop`) and the two decompiles are shown identical in the unit's
  commit; the SERIAL wrapper carries SERIAL's `@orig` tag.
- **The CRT's `time()`** is the platform's `unixTime()` (as ENCAIXE's):
  `srand(time(NULL))` in `serial_create_targets` is
  `g.rand.srand(@truncate(@as(u32, @bitCast(g.plat.unixTime()))))`. The
  ten time-zone routines (`time`, `__loctotime_t`, `_tzset`, `_isindst`,
  `getenv`, `atoi`/`atol`, …) are `replaced`: what they compute is a
  number of seconds, and only its low word reaches `srand`. On the
  headless platform `unixTime()` is `800 000 000 + ms / 1000` of the
  virtual clock, so the figures follow from the second of SERIAL's
  WM_CREATE (Tests).
- **Faithful first, the owner's rule.** K1–K5 are reproduced as they are
  by default. Each fix exists only behind its own `Fixes` flag (off by
  default). Corrigida (`Fixes.all()`) takes K1–K4; K5 is a choice
  (`Fixes.choices`) until the owner decides (Owner questions).
- **K1/K2 are SERIAL's.** The result is wrong in what SERIAL posts, so its
  fixes live in SERIAL's `gallery` (WM_DESTROY). NOITE's
  `handler_3farmcai` (`src/handlers/3farmcai.zig`) stays as the original:
  `minigameWon[2] = wParam != 0`, `g_score += lParam` (32-bit).
- **Two programs in one process**, as TIRO (`src/platform/host.zig`,
  docs/encaixe/DESIGN.md "Running two programs"): SERIAL is a task with its
  own state, queue, timers, window and screen. The host needs nothing new
  for SERIAL: TIRO brought the keys and the key repeat (Platform).
- **The local heap**, as TIRO: `Game.local()` is the task's local heap (an
  arena freed by `Game.destroy`); what SERIAL never frees (the strips of
  the 15 figures, `scene_object_dtor` frees nothing) is not a leak of the
  port.

## Source layout

```
src/serial/root.zig        program root: core, units, `ready`, `program` (host.Program)
src/serial/core/           types only (not units)
  game.zig                 Game: SerialGame + every SERIAL DGROUP global; queue, send/post, timers, local heap
  object.zig               Object (kinds gun / target / bullet / control_panel / status_bar), parts, Frame, ObjectList
  world.zig                Scene, Backdrop (one bitmap), OccupancyGrid + Occupancy, DrawList, UpdateList, Condition
src/serial/<unit>.zig      module units
src/serial/behaviour/      behaviour units (one group of SceneObject slots)
src/serial/units.zig       generated index (`noite -p serial unit sync`)
```

## Object model

TIRO's (one `Object`, a `kind`, every part present), with SERIAL's
classes. Five kinds are constructed:

| Kind | Class (vtables) | Parts live |
|---|---|---|
| `gun` | Gun ← Player2D ← Actor2D ← Mover + Animation (1760, 1764, 1768) | base, mover, anim, player2d, gun |
| `target` | Target ← Actor2D (TargetVtbl 1e94, 1ea4, 1ea8) | base, mover, anim, target |
| `bullet` | Bullet ← Projectile ← Actor2D (ProjectileVtbl 21a4, 21b4, 21b8) | base, mover, anim, projectile |
| `control_panel` | SerialPanel ← ControlPanel ← Animated3D ← Animation + Object3D (109e, 10c2, 122e) | base, o3d, anim, panel |
| `status_bar` | StatusBar (1960) | base, status |

`Object.is/as` are the type-test slots 3A–4B, 52/53, 56 (`isProjectile`),
58 (`isTarget`), 59 (`isGun`; Ghidra's struct field keeps TIRO's name
`isCrossbow`). The Target part is SERIAL's (DATA.md "Classes"):
`wrapFlag` +0x40 (write-only), `timerId2` +0x42, `timerId13` +0x4a,
`clockTimerId` +0x4c (a long), `clockTicks` +0x50, `laneBusy[3]` +0x52,
`kind` +0x58. The game's own timers and lane flags are fields of every
Target but used on `g.targets[0]` (and `timerId13` on `g.targets[13]`).
The objects are DGROUP pointers: `g.gun` (also `Game.player`),
`g.targets[0..14]`, `g.bullets[0]`. A method that overrides a SceneObject
slot reads its class at a negative offset of the SceneObject (Target
−0x5c, as `target_move_tick`'s `this-0x2c` for `moving`): in the port that
is just `obj`. Mover, Animation, Actor2D, Player2D, Projectile,
Animated3D, Moveable, Portable, Actor, Player, Exit and PerspectiveBackdrop
are never constructed on their own (`dead` in the plan), but
`portable_pick_up/drop/draw_icon` are called from live code
(`game_input`, `panels`) and keep the `portable` part, as in TIRO.

## Virtual slots

TIRO's rules (docs/tiro/DESIGN.md "Virtual slots"): one `pub fn`
dispatcher per slot in the unit that owns it, declared in the skeleton
with its final signature and a `stub.unported` body; it switches on
`obj.kind` and calls one function per original implementation, each
tagged `@orig`; the default stub is the `else` arm. Thunks (462), defaults
(66) and type tests (46) are `absorbed`. Signatures: `(g: *Game, obj:
*Object, <args in source order>)`; hwnd and hdc parameters are dropped
(where the original passes its `hwnd` on, e.g. the 0x40a wParam, the port
uses `g.mainWindow`); `Backdrop *` stays; out-parameters join the return
value, except the Projectile's `int *outDir`, an in/out `*i16`. The
skeleton's signatures are TIRO's, unchanged, plus `target.startTimer`.

A class's override of a SceneObject slot lives in the slot's unit, next to
its dispatcher: `target_move_tick` (the walk step and the killers' shot)
and `target_stop_moving(_dc)` in `movement`, `target_can_step` in
`occupancy`, `target_redraw_overlapping` in `visibility`,
`gun_play`/`gun_tick` in `animation`. SERIAL's Target overrides neither
`restoreBackground` nor `tick` (TIRO's did). The class units (`target`,
`bullet`, `gallery`) hold what is not a SceneObject slot.

### SceneObject slots (kinds: gun, target, bullet, panel = control_panel, status = status_bar)

SERIAL's slot numbers (byte offset = 4 × slot) are TIRO's, slot for slot.
57 (`slot62`) and 5A (`slot65`) are defaults nothing calls and have no
dispatcher. Generated from the tracker's vtables (thunks resolved).

| slot | behaviour | unit | default | overrides (impl: kinds) |
|---|---|---|---|---|
| 00 | getWorldX | space3d | scene_object_get_world_x_default | object3d_get_world_x: panel |
| 01 | getWorldDepth | space3d | scene_object_get_world_depth_default | object3d_get_world_depth: panel |
| 02 | getWorldElev | space3d | scene_object_get_world_elev_default | object3d_get_world_elev: panel |
| 03 | getSizeW | space3d | scene_object_get_size_w_default | object3d_get_size_w: panel |
| 04 | getSizeH | space3d | scene_object_get_size_h_default | object3d_get_size_h: panel |
| 05 | getSizeD | space3d | scene_object_get_size_d_default | object3d_get_size_d: panel |
| 06 | getAnchorX | space3d | scene_object_get_anchor_x_default | object3d_get_anchor_x: panel |
| 07 | getAnchorY | space3d | scene_object_get_anchor_y_default | object3d_get_anchor_y: panel |
| 08 | getX | position | scene_object_get_x | mover_get_x: gun target bullet |
| 09 | getY | position | scene_object_get_y | mover_get_y: gun target bullet |
| 0A | getStepX | position | scene_object_get_step_x_default | mover_get_step_x: gun target bullet |
| 0B | getStepY | position | scene_object_get_step_y_default | mover_get_step_y: gun target bullet |
| 0C | slot11 | position | scene_object_slot11_default |  |
| 0D | setElevation | space3d | scene_object_set_elevation_default | object3d_set_elevation: panel |
| 0E | setAnchor | space3d | scene_object_set_anchor_default | object3d_set_anchor: panel |
| 0F | setSize | space3d | scene_object_set_size_default | object3d_set_size: panel |
| 10 | setWorldElev | space3d | scene_object_set_world_elev_default |  |
| 11 | drawBounds | space3d | scene_object_draw_bounds_default | object3d_draw_bounds: panel |
| 12 | addDirtyRect | render | scene_object_add_dirty_rect |  |
| 13 | computeOverlap | render | scene_object_compute_overlap |  |
| 14 | restoreBackground | render | scene_object_restore_background | mover_restore_background: gun target bullet |
| 15 | drawDirtyTo | render | scene_object_draw_dirty_to | mover_draw_dirty_to: gun target bullet |
| 16 | draw | render | scene_object_draw | player2d_draw: gun; animation_draw: target bullet; control_panel_draw: panel |
| 17 | drawClipTo | render | scene_object_draw_clip_to |  |
| 18 | drawClip | render | scene_object_draw_clip |  |
| 19 | erase | render | scene_object_erase | animation_erase: gun target bullet panel |
| 1A | slot1F | render | scene_object_slot1f_default | animation_slot1f: gun target bullet panel |
| 1B | redraw | visibility | scene_object_redraw | actor2d_redraw: gun target bullet; animated3d_redraw: panel |
| 1C | hideAndInvalidate | visibility | scene_object_hide_and_invalidate |  |
| 1D | blitToDc | visibility | scene_object_blit_to_dc | actor2d_blit_to_dc: gun target bullet |
| 1E | invalidate | visibility | scene_object_invalidate | mover_invalidate: gun target bullet |
| 1F | slot24 | visibility | scene_object_slot24 | mover_slot24: gun target bullet |
| 20 | hide | visibility | scene_object_hide | mover_hide: gun target bullet |
| 21 | show | visibility | scene_object_show | actor2d_show: gun target bullet; animated3d_show: panel |
| 22 | occupy | occupancy | scene_object_occupy | control_panel_occupy: panel; status_bar_occupy: status |
| 23 | vacate | occupancy | scene_object_vacate | control_panel_vacate: panel; status_bar_vacate: status |
| 24 | attach | occupancy | scene_object_attach | actor2d_attach: gun target bullet; control_panel_attach: panel; status_bar_attach: status |
| 25 | canStep | occupancy | scene_object_can_step_default | actor2d_can_step: gun bullet; target_can_step: target |
| 26 | isStepBlocked | occupancy | scene_object_is_step_blocked |  |
| 27 | nextFrame | animation | scene_object_next_frame_default | actor2d_next_frame: gun target bullet; animated3d_next_frame: panel |
| 28 | prevFrame | animation | scene_object_prev_frame_default | actor2d_prev_frame: gun target bullet; animated3d_prev_frame: panel |
| 29 | play | animation | scene_object_play_default | gun_play: gun; animation_play: target bullet; animated3d_play: panel |
| 2A | playIdle | animation | scene_object_play_idle_default |  |
| 2B | stopAndRedrawDc | animation | scene_object_stop_and_redraw_dc_default | actor2d_stop_and_redraw_dc: gun target bullet; animated3d_stop_and_redraw_dc: panel |
| 2C | stopAndRedraw | animation | scene_object_stop_and_redraw_default | actor2d_stop_and_redraw: gun target bullet; animated3d_stop_and_redraw: panel |
| 2D | tick | animation | scene_object_tick_default | gun_tick: gun; animation_tick: target bullet; control_panel_tick: panel |
| 2E | stop | animation | scene_object_stop_default | actor2d_stop: gun target bullet; animated3d_stop: panel |
| 2F | moveTo | movement | scene_object_move_to_default | mover_move_to: gun target bullet |
| 30 | moveToEdgeH | movement | scene_object_move_to_edge_h_default | mover_move_to_edge_h: gun target bullet |
| 31 | moveToEdgeV | movement | scene_object_move_to_edge_v_default | mover_move_to_edge_v: gun target bullet |
| 32 | stopMovingDc | movement | scene_object_stop_moving_dc_default | actor2d_stop_moving_dc: gun; target_stop_moving_dc: target; projectile_stop_moving_dc: bullet |
| 33 | stopMoving | movement | scene_object_stop_moving_default | actor2d_stop_moving: gun; target_stop_moving: target; projectile_stop_moving: bullet |
| 34 | moveTick | movement | scene_object_move_tick_default | player2d_move_tick: gun; target_move_tick: target; actor2d_move_tick: bullet |
| 35 | getTimerId | animation | scene_object_get_timer_id_default | actor2d_get_timer_id: gun target bullet; animated3d_get_timer_id: panel |
| 36 | isMoving | movement | scene_object_is_moving_default | actor2d_is_moving: gun target bullet |
| 37 | isRunning | animation | scene_object_is_running_default | animation_is_running: gun target bullet panel |
| 38 | moveToAndDrop | space3d | scene_object_move_to_and_drop_default | object3d_move_to_and_drop: panel |
| 39 | setPosition | position | scene_object_set_position | actor2d_set_position: gun target bullet |
| 4C | unk4E | position | scene_object_unk4e |  |
| 4D | redrawOverlapping | visibility | scene_object_redraw_overlapping | target_redraw_overlapping: target; projectile_redraw_overlapping: bullet; object3d_redraw_overlapping: panel |
| 4E | hitboxOverlaps | position | scene_object_hitbox_overlaps |  |
| 4F | boundsOverlap | position | scene_object_bounds_overlap |  |
| 50 | slot5B | position | scene_object_slot5b_default |  |
| 51 | slot5C | position | scene_object_slot5c_default |  |
| 54 | isEnabled | position | scene_object_is_enabled_default |  |
| 55 | getExitIndex | position | scene_object_get_exit_index_default |  |
| 3A–4B, 52/53, 56, 58, 59 | type tests | (Object.is/as) | | |

### Other vtables

`docs/serial/SLOTS.tsv` is this table for `noite -p serial unit dep infer`.

| vtable | slots → unit |
|---|---|
| Object3DVtbl (8) | `space3d` (Object3D's, the panel) |
| AnimationVtbl (1) | `animation.playOnce` |
| MoverVtbl (1) | `movement.placeAt` (mover_place_at) |
| TargetVtbl (4) | 00 `movement.placeAt`; 01 `target.startTimer` (target_start_timer, SERIAL's); 02 moveTick (`target_move_tick_or_stop`, dead: nothing calls the slot); 03 `target.checkEdge` (target_wrap_at_edge) |
| ProjectileVtbl (4) | 00 `movement.placeAt`; 01 moveTick (`projectile_move_tick`, dead); 02 `bullet.stepMove`; 03 `bullet.tryStep` |
| ControlPanelVtbl (9) | 00 `animation.playOnce`; 01–08 `panels` |
| GameVtbl (7) | 00 `game_input.handleMessage`; 01–06 `game` (createPlayer … onCreate) |
| SceneVtbl (13) | 00, 05, 07 `gallery` (handleMessage, createScreen, create); the rest `scene` |
| Backdrop/GridBackdropVtbl (19/20) | `backdrop` (slot 00 create = SerialBackdrop's grid and walls) |
| ConditionVtbl (3) | `game` |
| FrameVtbl (1) | `object_create.getCell` |

## State

`core/game.zig`'s `Game` is SerialGame + Game flattened (`g_game` and
`g_serialGame` are the game itself) plus every DGROUP global, checked by
`noite -p serial initdata` (49 fields, the skeleton passes): the strip
tables of the gun (`trabu.bmp`, 3×238×105), the 15 figures (with
`g_targetKinds`) and the bullet (`bala.bmp`, 3×47×31), `g_timerIds` /
`g_timerPeriods`, `g_lives` = 5, the key latches, `g_spawnToggle`, the
WaveMix state and the three waves (`g_shotWave` tiros1, `g_hitWave`
morte2, `g_pracas01Wave`), `g_occupancyCount/Object` → `g.occupancy`,
`g_score` (`i16`, BSS), `g_noiteWnd`, `g_gun`, `g_targets[15]`,
`g_bullets[1]`, `g_mainWindow` = `plat.windowHandle()`. No counterpart:
`g_setSystemTimer`/`g_killSystemTimer` (`g.setSystemTimer`), the instance
and module handles, the module path (the host's `Program.dir`,
`\SERIAL`), the CRT time-zone data. One `Game` per running SERIAL.

Timers are the queue's (`core/queue.zig`): a `SetSystemTimer` of an id
already armed re-arms it, as USER does, so K5 (the gun's id 10 taken over
by lane 2's 5-s timer, then back by `gun_play`) happens by itself. The
clock's 60 000 ms period fits the `u16` of `g.setSystemTimer`.

The backdrop: NOITE's pixel contract for its one bitmap (as TIRO). The
score box (`serial_draw_score`: " %04d" / "-%04d" at x = 460 + 32·i,
y = 408, colour 0x00EDEEEE, one `TextOut` per character, the DC's default
font) draws on it and `serial_blit_score_box` blits the 192×32 box at
(416, 400).

## Reading SERIAL

TIRO's notes hold word for word (docs/tiro/DESIGN.md "Reading TIRO"): far
pascal `__stdcall16far` with the parameters listed **reversed**
(`target_start_timer(this, index, elapse, timerId, hwnd)` is source
`(hwnd, timerId, elapse, index)` → `startTimer(g, obj, timer_id, elapse,
index)`), near data in DGROUP `1090`, `MOV BX,[SI]; CALLF [BX+off]`
virtual calls (slot = off / 4), the `_aFchkstk` probe, the `/Od` bodies,
the virtual-base residue, the 14 NULL tests. SERIAL's own:

- The handler `serial_scene_handle_message` (1068:1529) is 12.9 KB in 18
  ranges: a compare chain on the message, a `switch (rand() % 6)` through
  the code-segment table `g_spawnLane1JumpTable` (1068:22ab, cases →
  figures 7–12), seven `WM_SYSTIMER` tests in a fixed order (GAME.md
  "Timers"). Its plate and PRE comments give the layout of every branch;
  port it branch by branch, in its order (the order is K5).
- The lane-2 spawn branch (1068:2968–2cca) is unreachable in the
  original (K5) but is ported: the K5 flag reaches it.
- `target_move_tick` sends `WM_DESTROY` nested when `g_lives` reaches 0,
  then goes on with the waves freed: `sound.play` of a freed wave must do
  nothing, as `wave_play` with `g_waveCount` 0 does (BUGS.md harmless).

## Fixes (BUGS.md K-section)

| Bug | Flag | Unit | What the fix changes | In `all` |
|---|---|---|---|---|
| K1 every game reported as a win | `serial_result_won_by_lives` | gallery | the 0x40a wParam is `g_lives > 0` (1 or 0) instead of the window handle: a game that loses every life is a loss (NOITE takes a life) | yes |
| K2 the score in the high word | `serial_score_in_low_word` | gallery | the 0x40a lParam is the high word's value sign-extended (`g_lives > 0 ? 500 : g_score`) instead of `MAKELONG(g_lives, …)` | yes |
| K3 hit by x alone, any lane, 55-px bullet | `serial_hit_needs_row` | gallery | the second stage takes a figure when the x ranges overlap with touching edges counted, with the bullet's real width (`a <= t+w and t <= a+47`), **and** the y ranges overlap (bullet y..y+31, figure y..y+h), in the same lane 2, 1, 0 order, moving figures only | yes |
| K4 SPACE latch never set | `serial_space_latch` | gallery | the fire branch sets `g_keySpaceHeld` = 1 (WM_KEYUP already clears it): a held SPACE fires once | yes |
| K5 timer id 10 shared, lane-2 branch dead | `serial_lane2_own_timer` | target | `serial_create_targets` arms target 13's lane-2 timer with id 9 (`g_timerIds[6]`, unused) instead of `g_timerIds[7]` = 10: the handler's test 5 (`timerId13`) then matches it, lane 2 also spawns on its own 5-s timer, and the gun keeps id 10 at 60 ms from the start | no (a choice) |

Each unit ports the buggy code and keeps the fixed path only under its
flag (`g.fixes.serial_…`). K1 and K2 are independent (K2 alone: a win of
+500; K1 alone: a loss packed as the original packs it). K4 matters only
with key repeats (Platform). The harmless entries (the unread shot
counter, the gun's hit box, `wrapFlag`, the lane-2 toggle's frame reset,
the dead `0x3bd` case, `WinMain`'s return) get no flag; nor does the
nested WM_DESTROY (it does nothing visible).

### Owner questions

1. **K1's criterion.** The fix reads a survived game (lives left after the
   two minutes) as a win, which matches the lParam's flat 500 for one.
   TIRO's criterion is `g_score > 0`. Survival, or score, or both?
2. **K2's points.** The fix keeps what the high word holds: a flat 500 for
   a survived game whatever `g_score` is, `g_score` after a lost one
   (BUGS.md lists the flat 500 as design). Or `g_score` in both cases?
3. **K5 (choice, off in Corrigida).** Should the Corrigida give lane 2 its
   own 5-s timer, so Kennedy and the rabbit come more often (the code's
   apparent intent, confidence 6), or keep the 10-s toggle the players
   knew?
4. **K3's bullet width.** The fix uses `bala.bmp`'s 47 px, not TIRO's 55:
   is that part of the fix, or should the Corrigida keep 55 and only add
   the row test?

## Integration

SERIAL is not ported yet: `src/serial/root.zig` has `ready = false`, so
NOITE's WinExec keeps the stub and `--minigame serial` refuses to run.
The root is wired in `main.minigames` (`src/main.zig`) as TIRO's.

### The launch from NOITE

`handler_3farmcai` (`src/handlers/3farmcai.zig`; the scene comes from
`3felevad`'s stair exit): the scene start pauses the music, frees the
waves and plays the escape video (object 0x7f); at its `MM_MCINOTIFY`
NOITE closes it, reopens WaveMix, `WinExec("<CD>serial\serial.exe")` and
sets timer 0x14 (100 ms). The host matches `serial` to `serial.program`:
SERIAL's task starts `--minigame-startup` ms later (1500; its WinMain:
`app.start`, which first runs `init_static_conditions` as `_cinit` does),
FindWindow("Serial Killer") succeeds on NOITE's next 0x14 tick, NOITE
posts **0x40b** (lParam = NOITE's window); AppWndProc stores `g_noiteWnd`
and posts **0x40c** on its next message; NOITE hides itself. The game ends
in one of two ways, both a `WM_DESTROY` sent to SERIAL's own window:
- the clock's second tick (id 8, 120 s after WM_CREATE), from the handler;
- the killers' fifth shot, nested inside `target_move_tick` (the walk tick
  then goes on, as the original's).

The handler stops and frees the waves, closes WaveMix and MCI and posts
**0x40a** to `g_noiteWnd`: in the original wParam = SERIAL's window (K1),
lParam = `MAKELONG(g_lives, g_lives > 0 ? 500 : g_score)` (K2).
AppWndProc kills timer 1 and posts WM_QUIT, which comes before any timer
(`core/queue.zig`), so no second result. The host runs `app.exit`,
destroys the window and activates NOITE, which shows itself, sets
`minigameWon[2] = wParam != 0`, adds the whole lParam to its 32-bit score
and goes to `3fhall` (won, with XILINDRO's `minigameWon[3]` won too) or
`3fprisao` (won without it), or takes a life and goes to `3fprisao` (or
`6fsaida`). In the original every game is a win and the score jumps by
32 768 001–32 768 005 (B19 shows the low word: +lives), or by
`g_score`·65 536. NOITE's WM_SYSTIMER check (window gone without a
result → a 0x40a loss) is the host's window lifetime. Nothing changes in
NOITE. `--minigame-stub` keeps the stub (a win after the hello).

### Standalone

- `noite --minigame serial [--headless …]`: SERIAL alone (task 0, its
  title, `\SERIAL` directory); prints its result (the host records the
  0x40a to hwnd 0: `won` = wParam ≠ 0, score = lParam as `i32`).
- Web (at the finish, as TIRO's): `web_main.minigames` gets SERIAL as
  `noite_start`'s next minigame index; `MINIGAMES` in `web/noite.js` and
  the "Jogo" select of `web/index.html` ("Jogar só o minijogo: Serial
  Killer"); `tools/web/files.py`'s `MINIGAMES` gets `serial` (names looked
  up at the disc root, then in `SERIAL\`); `PAD_KEYS.serial = [37, 32, 39]`
  (◀, the fire button, ▶: TIRO's pad) for the one-button mode and a
  minigame alone on a touch screen. These shared files are edited only in
  the finishing step, not by unit agents and not in this design pass.

## Platform

Nothing new is needed to run SERIAL. What it uses, all there for TIRO:
every key to a minigame task (`Sim.filterInput`), the key repeat (500 ms,
33 ms; K4 needs it), `unixTime` (`time()`), the MCI sequencer
(`doom2.mid`, `src/platform/midi.zig`; replayed on `MM_MCINOTIFY`),
WaveMix, `SetSystemTimer` periods up to 60 000 ms, the host's task
lifetime.

One harness addition is needed for the tests, because K1/K2 make the
Original and the Corrigida report different results for the same game
(TIRO's scripts check one result for both): `result` takes an optional
second expectation for runs with fixes, e.g. `result won 32768005 | won
500` (the part after `|` is checked when the run has a `--fix` flag on).
It goes in `src/platform/script.zig`/`harness.zig` with the integration
step (a shared file: one change, its own commit).

## Tests

- **Planner** `tools/serial_plan.py --start MS (--win|--lose)
  [--relative-to MS] [-o FILE]`, on `tools/tiro_plan.py`'s model. `MS` is
  SERIAL's WM_CREATE (0 alone, WinExec + 1500 from NOITE); the seed is
  `(800000000 + MS / 1000) & 0xffff` (the headless `unixTime`). It
  simulates on the virtual clock what decides the game: the system timers
  in USER's table order (a timer set again keeps its slot, a killed one
  set again goes to the end: id 3 is re-armed by every spawn's
  `moveToEdgeH`, id 10 by the gun's aim keys), every `rand()` in the
  game's order (lane 0 `% 7`, lane 1 `% 6`, the lane-2 toggle's `% 2`
  drawn before its busy test), the walks (20 px per tick, frames with
  wrap, the edge tests), the killers' shots and `g_lives`, the clock, the
  bullet's 20-px Bresenham steps every 55 ms toward (0 | 325 | 640, 10),
  the occupancy grid of the first stage (32-px cells, the wall cells,
  every occupy/vacate, stale cells included), the second stage in both
  versions (K3), the hits (score by kind, the lane freed). It plans SPACE
  presses at least 110 ms apart, with the bullet free and aim keys before
  them, each with the same outcome in the Original and the Corrigida
  (`--fix all`: K1–K4):
  - `--win`: hit killers (kind 2, +200) and kind 1 (+100), never kind 0;
    kill each killer before its shot when it can, so the game lasts the
    two minutes with lives left;
  - `--lose`: shoot nothing (or kind 0 only) until the killers' shots
    take the five lives; a seed that gives too few killers in 120 s is
    helped by clearing lanes (a hit frees its lane for the next spawn
    tick), and the planner says when it cannot.
  It prints both results (the Original's packed lParam, the Corrigida's)
  and the end time. `--check FILE` / `--trace FILE` simulate a script
  (held keys repeating as a run does, `--key-repeat`); the trace is the
  port's tick for tick, checked on random games in both versions. Rerun
  it when the start time moves.
- **Scripts** (`tools/play/`), each run Original and `--fix all`, one
  script, the result checked after the later end with the two-part
  `result` (Platform):
  - `serial-alone-win.input` (`--minigame serial --ms 130000`): survives
    the clock with N lives: `result won 32768000+N | won 500`;
  - `serial-alone-lose.input`: the lives run out: `result won
    <score·65536> | lost <score>` (the Original's K1 win);
  - `serial-held-space.input` (`--key-repeat 500,33`): SPACE held a few
    seconds; the Original fires on every repeat once the bullet is free
    (K4), the Corrigida once; the planner's `--check` gives each
    version's score and result;
  - `serial-3farmcai-win.input` / `serial-3farmcai-lose.input`
    (`--scene 3farmcai`): the video, SERIAL started (NOITE hidden: a
    `dump`), the planner's shots (`--start` = the video's end + 1500,
    read from a run), the result, then NOITE back in `3fprisao` with
    `state` showing the score and the lives: the Original adds the packed
    lParam and keeps the life even on the loss (K1, K2); the Corrigida
    adds +500, or `g_score` and a life less. (The `3fhall` branch needs
    XILINDRO's `minigameWon[3]`; it is covered once XILINDRO's route is
    scripted.)
  - `full.input` and `onebutton.input` do not pass `3farmcai` (their
    route leaves the prison by the street escape): unchanged.
- **Smoke**: `tools/smoke.py --minigame serial [--fix all] [--monkey
  SEED]`: random LEFT/RIGHT and SPACE presses 110 ms or more apart for
  130 s (`KEYS_FOR["serial"]` = TIRO's generator), seeds 1–5: no panic or
  leak, and a result (by 120 s, earlier when the lives run out).
- **Web**: `tools/web/test.py` plays "Jogo" = Serial Killer: SERIAL starts
  and SPACE fires (the bullet leaves the gun: a checksum of the area
  above it).
- **Unit tests** (optional, tagged): `oracle=emulated` from tools/oracle
  (far code, DGROUP 1090, `_aFchkstk` 1080:00e4 runs as is), as worth it:
  `target_start_timer` (the index → field map), `target_wrap_at_edge`,
  `target_move_tick` (the shot frame, `g_lives`), `gun_aim`,
  `projectile_try_step`, `scene_object_restore_background` (the colour
  key), `serial_draw_score` (`asset` with `Fundo.bmp`).

## Units

20 units, 316 functions to port; 114 dead, 574 absorbed (462 thunks, 66
defaults, 46 type tests), 184 replaced (91 CRT, 93 imports). The plan is
TIRO's, function for function by name (`tiro_`→`serial_`,
`crossbow`→`gun`, `arrow`→`bullet`; TIRO's unit `arrow` is `bullet`),
plus SERIAL's four new game functions in `target` (`target_start_timer`,
`target_hide_and_blit`, `serial_hit_kind1`, `serial_hit_kind0_2`).
The dead are TIRO's dead set (the classes never constructed, the
unreferenced functions, `target_move_tick_or_stop` and
`projectile_move_tick`: slots nothing calls), the five `FUN_` (TIRO's
unnamed dead twins), and two of SERIAL's own: `dib_copy_rect` (no caller:
the restore copies with the colour key) and `frame_vector_deleting_dtor`
(no caller, no slot; the only caller of `frame_dtor`, dead in both). Hard deps are direct calls into another unit (`noite -p
serial next --blocked`); virtual calls are soft (`unit dep show`). Level =
the longest chain of hard deps below the unit: the units of one level can
run in parallel once the levels below are done.

| Level | Unit | Fns | Size | Calls into |
|---|---|---|---|---|
| 0 | `dib` | 7 | 3.0 KB | — |
| 0 | `position` | 27 | 1.2 KB | — |
| 0 | `sound` | 8 | 0.9 KB | — |
| 1 | `backdrop` | 28 | 3.7 KB | dib, position |
| 1 | `object_create` | 27 | 3.0 KB | dib, position |
| 1 | `render` | 17 | 2.3 KB | dib, position |
| 1 | `space3d` | 24 | 4.0 KB | position |
| 2 | `animation` | 26 | 1.6 KB | position, render |
| 2 | `lists` | 17 | 2.0 KB | object_create, position, render |
| 2 | `occupancy` | 17 | 1.4 KB | position, render |
| 3 | `panels` | 17 | 1.6 KB | animation, dib, lists, object_create, position, render |
| 3 | `scene` | 15 | 0.8 KB | backdrop, lists, object_create |
| 3 | `visibility` | 20 | 2.8 KB | lists, position, render |
| 4 | `movement` | 20 | 3.0 KB | animation, backdrop, occupancy, position, render, sound, visibility |
| 5 | `bullet` | 5 | 1.0 KB | movement, object_create, occupancy, position, sound, visibility |
| 5 | `target` | 9 | 2.2 KB | dib, movement, object_create, occupancy, position, sound, visibility |
| 6 | `gallery` | 3 | 12.8 KB | animation, backdrop, bullet, lists, movement, scene, sound, target |
| 6 | `game` | 18 | 2.1 KB | bullet, lists, object_create, occupancy, panels, scene, target |
| 7 | `app` | 8 | 1.3 KB | backdrop, dib, game, sound |
| 7 | `game_input` | 3 | 4.2 KB | game, lists, position, render, space3d |

Ready first (parallel): `dib`, `position`, `sound`; then `backdrop`,
`object_create`, `render`, `space3d`; then `animation`, `lists`,
`occupancy`; then `panels`, `scene`, `visibility`; then `movement`; then
`bullet`, `target`; then `gallery`, `game`; then `app`, `game_input`.
Unlike TIRO's, SERIAL's `animation` no longer calls `visibility` (its tick
invalidates through the slot), and `movement` calls `sound` and
`occupancy` (`target_move_tick`'s shot wave, `target_can_step`). The
largest single functions: `serial_scene_handle_message` (12.9 KB,
`gallery`: give it the most careful agent, or port it in parts within one
claim), `game_handle_message` (3.7 KB, `game_input`),
`target_redraw_overlapping` (1.2 KB, `visibility`).

## Tracker

`noite -p serial …` (or `NOITE_PROGRAM=serial`): DB `db/serial.sqlite`
(local; `noite -p serial import` rebuilds it from Ghidra and the plan),
plan `db/serial-plan.tsv` (committed), tree `src/serial/`, index
`src/serial/units.zig`, worktrees `work/serial-<unit>/` on branches
`port/serial-<unit>`, the non-SceneObject slot owners in
`docs/serial/SLOTS.tsv`. The program's layout
(`tools/cli/src/noite/program.py` `SERIAL`): CRT 1080, imports 10a8,
DGROUP 1090, far 4-byte vtable slots. A worktree's `.ref/env.sh` sets
`NOITE_PROGRAM`.

```
noite -p serial next [--blocked]    # units ready to claim
noite -p serial start <unit>        # worktree work/serial-<unit>/
noite -p serial show <addr|name>    # row, decompile (--asm), callers/callees
noite -p serial unit show <unit>
noite -p serial check -w <unit>     # @orig tags vs SERIAL's DB
noite -p serial initdata -w <unit>  # `// @orig g_*` defaults vs SERIAL's DGROUP
noite -p serial finish <unit>       # from the main checkout
noite -p serial failed <unit> "why" / release <unit>
```

## How to port a SERIAL unit

1. `noite -p serial next`, `noite -p serial start <unit>`, then work in
   `work/serial-<unit>/` (`. .ref/env.sh`; tools via `nix develop -c`).
   Scratch output and frame dumps go in the worktree's `zig-out/`, never
   `/tmp`.
2. Read the unit's `.ref/*.c` (plate, decompile, disassembly),
   `.ref/types.md`, `.ref/strings.md`; DATA.md / GAME.md for the class and
   the rules. Ghidra (`mcp__ghidra__*`, `program="SERIAL.EXE"`) for
   anything else.
3. Start from TIRO's ported unit of the same name (`src/tiro/<unit>.zig`;
   `bullet` ← `src/tiro/arrow.zig`): copy its functions in, rename
   (`tiro`→`serial`, `crossbow`→`gun`, `arrow`→`bullet`) and retag each
   with SERIAL's address (`noite -p serial show <name>`). Then check every
   function against SERIAL's own decompile/asm: a plate that says "SERIAL
   differs from TIRO" (FUNCTIONS.md lists them) or a function new in
   SERIAL is transcribed from SERIAL's code, not adapted. Name in the
   commit body every function whose code differs from TIRO's, and how.
   Never call a TIRO unit, except the state-free delegation in Decisions.
4. Write only `src/serial/<unit>.zig` (or `behaviour/<unit>.zig`): replace
   each declared dispatcher's body, keep its signature; one `// @orig
   <seg:off> <ghidra_name>` per function (SERIAL addresses; `(absorbed)`
   for the defaults and thunks a dispatcher's arm covers). Public names:
   the Ghidra name minus the unit's class prefix, camelCase.
5. Faithful first: port each K-bug as the code does it and put the fix
   only behind its flag (`g.fixes.serial_…`, table above). NOITE's
   conventions hold (`i16`/`i32` with wrapping where the original
   overflows, `cstr`, `?*T`, message boxes through `plat.messageBox`,
   every PostMessage/SendMessage/SetSystemTimer at the same point,
   `error.Fatal` only where the original ends). Allocate what the
   original `new`s from `g.local()`.
6. Call other units' dispatchers, never a local copy. If a declared
   signature cannot express the original, `noite -p serial failed <unit>
   "slot <name> (<owner>) needs …"`.
7. Tests optional; when written, `oracle=emulated` from tools/oracle,
   `asset` from `assets/SERIAL/`, `documented` from Ghidra.
8. `noite test`, commit (commit skill), `noite -p serial finish <unit>`
   from the main checkout.

## Finishing

Once every unit is done: the harness's two-part `result`, the planner and
the scripts (Tests), `KEYS_FOR["serial"]` in `tools/smoke.py`, the web
wiring (Integration), then `ready = true` in `src/serial/root.zig`; the
three suites (`full.input`, smoke, the SERIAL scripts) in both versions;
BUGS.md K1–K5 "Port:" lines updated to ported; README's "Running the
port" and "Testing the port" entries.
