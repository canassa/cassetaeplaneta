# Native port of SALGIN.EXE and XILINDRO.EXE — design

SALGIN.EXE ("Sala de Ginástica", the gym's *Porrada* fist fight) and
XILINDRO.EXE ("Xilindro", the street fight after the prison escape) in
Zig, next to NOITE's, ENCAIXE's and TIRO's ports. This one file is the
design of both fights; `docs/xilindro/DESIGN.md` holds XILINDRO's own
tables (the tracker reads a slot table per program) and points here for
the rest. TIRO's `docs/tiro/DESIGN.md` (their engine twin, ported),
ENCAIXE's and NOITE's design docs and the zig-developer skill hold for
everything this file does not override. Ghidra (programs `SALGIN.EXE`,
`XILINDRO.EXE`, through the tracker snapshots `noite -p salgin show` /
`noite -p xilindro show`) is the specification; `docs/<n>/GAME.md`
(rules, protocol), `DATA.md` (classes, vtables, globals), `FUNCTIONS.md`
(names, dead code), `QUALITY.md` (the medium /Od build), BUGS.md S1–S11
and X1–X11.

## Decisions

- **Two trees, one per program; TIRO's Zig as the engine template.**
  SALGIN and XILINDRO are TIRO's build (medium model, `/Od`, stack probes,
  the same 19 segments in the same order): every engine function of
  segments `1008`–`1060`, `1070`, `1078` aligns with TIRO's byte for byte
  (relocations aside), the engine structs are TIRO's offset for offset, and
  the SceneObjectVtbl is TIRO's 91 slots (0x56–0x59 renamed). Their own
  code is segment `1068` (the fight), the game subclass in `1048` and the
  game classes' ctors and overrides in `1088`. The two fights are
  near-twins: the same classes (Fighter ← Player2D, Opponent, Banner,
  EnergyBar ← Actor2D, the scene, panel and backdrop subclasses), the same
  34 functions in `1068` at the same offsets up to the handler, with
  other data (strips, damage and reaction tables, waves, the score factor)
  and other handler rules (range 120 vs 130, trades vs clashes, recoil,
  end tests).

  So each program gets its own units under `src/salgin/` and
  `src/xilindro/`, ported from its own functions with its own `@orig`
  addresses, as TIRO got its own beside ENCAIXE. **Three ways to share
  were weighed:**
  - *one tree with per-game data* (`src/fight/`, comptime over the
    program): an `@orig` tag names one program's address and `noite check`
    scans only that program's tree (`noite -p salgin` reads `src/salgin/`),
    so a shared function would carry two tags that no check can verify,
    and `noite finish` refuses a unit that edits a file outside its
    program's tree: a SALGIN unit could not land in `src/fight/`, nor a
    XILINDRO fix there. The tracker would need a third kind of tree and
    two DBs per file;
  - *a shared fight module* (the engine per program, `fighters`/`hud`/
    `arena` shared): the same tag and tree problem for the part that
    differs most. The handler (7.2 KB / 7.5 KB) is where the rules
    diverge (reach, recoil, trades vs clashes, which energy picks the
    weak column, the end tests); a shared body would be a run of
    `if (xilindro)` branches, and every S/X fix would sit in both
    programs' code;
  - *two trees from one template* (chosen): each port is a plain
    transcription of its own binary, checked by the tracker as TIRO's and
    ENCAIXE's are. The cost is typing, and it is low: the engine units are
    TIRO's ported Zig with SALGIN's addresses (TIRO's decompiles and
    SALGIN's agree function for function, FUNCTIONS.md "named from
    TIRO"), and XILINDRO's units start from SALGIN's.
- **Who copies from whom.** Every engine unit of both programs starts from
  the TIRO unit of the same name (`src/tiro/<unit>.zig`, ported and
  checked; same slot names, signatures, struct offsets). The fight's own
  functions (the Fighter/Opponent overrides in `animation`, `movement`,
  `occupancy`, `visibility`, `object_create`, `game`, and the units
  `fighters`, `hud`, `arena`) are ported for SALGIN first; the XILINDRO
  unit of the same name starts from SALGIN's Zig once it has landed. A
  unit never imports another program's tree; it transcribes its own
  binary's decompile/asm, reuses the twin's Zig where the two decompiles
  agree, and says in its commit body which functions differ from the twin
  and how. The same state-free delegation as TIRO's is allowed (`dib`
  row copies, `read_dib_info`: segment 1000 is NOITE's, byte for byte).
- **Shared, because identical or not game code:** the platform layer,
  `core/msg.zig`, `queue.zig`, `cstr.zig`, `crt.zig` (the CRT `rand`;
  `time()` is `plat.unixTime()`), `stub.zig`, `errors.zig`,
  `core/fixes.zig` (one `Fixes`: S-flags prefixed `salgin_`, X-flags
  `xilindro_`), the Win16 data types.
- **Faithful first, the owner's rule.** S1–S11 and X1–X11 are reproduced
  by default; each fix with a visible effect exists only behind its own
  flag (off by default). Clear bugs are in Corrigida (`Fixes.all()`),
  design questions in `Fixes.choices` until the owner decides ("Owner
  questions").
- **Two programs in one process**, as ENCAIXE and TIRO: each fight is a
  host task with its own state, queue, timers, window and screen; the
  protocol runs through the platform as in Windows.
- **The local heap**, as TIRO: `Game.local()` (an arena freed with the
  task) takes every `operator new` / `_nmalloc`; what the original never
  frees (the strips, `scene_object_dtor` frees nothing) is not a leak of
  the port.

## Source layout

```
src/salgin/root.zig          program root: core, units, `ready`, `program` (host.Program)
src/salgin/core/             types only (not units)
  game.zig                   Game: SalginGame + every SALGIN DGROUP global; queue, send/post, timers, local heap
  object.zig                 Object (kinds fighter / opponent / banner / energy_bar / control_panel / status_bar), parts, Frame, ObjectList
  world.zig                  Scene (+ SalginScene.clock), Backdrop (one bitmap), OccupancyGrid + Occupancy, DrawList, UpdateList, Condition
src/salgin/<unit>.zig        module units
src/salgin/behaviour/        behaviour units (one group of SceneObject slots)
src/salgin/units.zig         generated index (`noite -p salgin unit sync`)
src/xilindro/…               the same, XILINDRO's (XilindroScene.secondsLeft, its globals and field names)
```

The core files are the design's (TIRO's core with each program's
globals, classes and field names: SALGIN `hitLock`/`frameCount`/`health`/
`playerEnergy`, XILINDRO `reacting`/`moveFrame`/`energy`/`fighterEnergy`,
as their Ghidra programs name them). A unit that needs a field the core
lacks adds it there in its own commit.

## Object model

As TIRO's (one `Object`, a `kind`, every part present), with the fight's
classes. Six kinds are constructed:

| Kind | Class (SALGIN vtables; XILINDRO's in its DATA.md) | Parts live |
|---|---|---|
| `fighter` | Fighter ← Player2D ← Actor2D ← Mover + Animation (1860, 186c, 1870) | base, mover, anim, player2d, fighter |
| `opponent` | Opponent ← Actor2D (OpponentVtbl 1f9c, 1fa4, 1fa8) | base, mover, anim, opponent |
| `banner` | Banner ← Actor2D (211c, 2120, 2124; overrides nothing) | base, mover, anim |
| `energy_bar` | EnergyBar ← Actor2D (2298, 229c, 22a0) | base, mover, anim, energyBar |
| `control_panel` | SalginPanel ← ControlPanel ← Animated3D ← Animation + Object3D (119e, 11c2, 132e) | base, o3d, anim, panel |
| `status_bar` | StatusBar (1a68) | base, status |

`Object.is/as` are the type-test slots 3A–4B, 52/53 and 56/57
(`isFighter`, asked by `opponent_can_step`; `isOpponent`, asked by
`fighter_can_step`). Mover, Animation, Actor2D, Player2D, Animated3D,
Moveable, Portable, Actor, Player, Exit and PerspectiveBackdrop are never
constructed on their own: their methods no live table reaches are `dead`
in the plan, as in TIRO (and `player2d_move_tick` with them: the Fighter
overrides moveTick, where TIRO's Crossbow used it). Struct origins are
`// @orig Struct+0xNN` with the program's offsets.

The game objects are DGROUP pointers: `g.fighter` (the player, also
`Game.player`), `g.opponent`, `g.banner`, `g.energyBar`. The overrides
reach their class at negative offsets from the SceneObject subobject, and
the decompiler shows `g_fighter + 1` as the SceneObject pseudo-this passed
to `fighter_move_tick`/`fighter_stop_moving`: in the port both are just
`obj` (or `g.fighter.?`). The decompile prints SceneObject fields reached
through the vbase as `mover.field_0xc + vbptr->sceneObjectOffset` (= `x`,
SceneObject+0xa) or `&this[0xc].contactMark + …` (= `nextX`, +0x458): read
the plate, which names the field, and the disassembly.

## Virtual slots

As TIRO's: each slot is one `pub fn` dispatcher (named after the vtable
field) in the unit that owns it, declared in the skeleton with its final
signature and a `stub.unported` body; it switches on `obj.kind` and calls
one function per original implementation, each tagged `@orig`; the default
is the `else` arm. Signatures `(g: *Game, obj: *Object, <args in source
order>)`, hwnd and hdc dropped, `Backdrop *` kept; the engine's are TIRO's
skeleton's, unchanged. The overrides of a SceneObject slot live in the
slot's unit next to its dispatcher (`fighter_tick`/`opponent_tick` in
`animation`, the two `can_step` in `occupancy`, the two
`redraw_overlapping` and `invalidate` in `visibility`, the six
moveTick/stopMoving(Dc) in `movement`); the class units (`fighters`,
`hud`, `arena`) hold what is not a SceneObject slot. Flattened
single-class tables are plain functions: Game (`game`, `game_input`),
Scene (`scene`, `arena`), Backdrop (`backdrop`), ControlPanel (`panels`),
Condition (`game`), Frame (`object_create`).

### SceneObject slots (kinds: fighter, opponent, banner, energy_bar, panel = control_panel, status = status_bar)

SALGIN's slot numbers (byte offset = 4 × slot); TIRO's and XILINDRO's are
the same. Generated from the tracker's vtables (thunks resolved).
0x58–0x5A (`slot63`–`slot65`) are defaults nothing calls and have no
dispatcher.

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
| 08 | getX | position | scene_object_get_x | mover_get_x: fighter opponent banner energy_bar |
| 09 | getY | position | scene_object_get_y | mover_get_y: fighter opponent banner energy_bar |
| 0A | getStepX | position | scene_object_get_step_x_default | mover_get_step_x: fighter opponent banner energy_bar |
| 0B | getStepY | position | scene_object_get_step_y_default | mover_get_step_y: fighter opponent banner energy_bar |
| 0C | slot11 | position | scene_object_slot11_default |  |
| 0D | setElevation | space3d | scene_object_set_elevation_default | object3d_set_elevation: panel |
| 0E | setAnchor | space3d | scene_object_set_anchor_default | object3d_set_anchor: panel |
| 0F | setSize | space3d | scene_object_set_size_default | object3d_set_size: panel |
| 10 | setWorldElev | space3d | scene_object_set_world_elev_default |  |
| 11 | drawBounds | space3d | scene_object_draw_bounds_default | object3d_draw_bounds: panel |
| 12 | addDirtyRect | render | scene_object_add_dirty_rect |  |
| 13 | computeOverlap | render | scene_object_compute_overlap |  |
| 14 | restoreBackground | render | scene_object_restore_background | mover_restore_background: fighter opponent banner energy_bar |
| 15 | drawDirtyTo | render | scene_object_draw_dirty_to | mover_draw_dirty_to: fighter opponent banner energy_bar |
| 16 | draw | render | scene_object_draw | player2d_draw: fighter; animation_draw: opponent banner energy_bar; control_panel_draw: panel |
| 17 | drawClipTo | render | scene_object_draw_clip_to |  |
| 18 | drawClip | render | scene_object_draw_clip |  |
| 19 | erase | render | scene_object_erase | animation_erase: fighter opponent banner energy_bar panel |
| 1A | slot1F | render | scene_object_slot1f_default | animation_slot1f: fighter opponent banner energy_bar panel |
| 1B | redraw | visibility | scene_object_redraw | actor2d_redraw: fighter opponent banner energy_bar; animated3d_redraw: panel |
| 1C | hideAndInvalidate | visibility | scene_object_hide_and_invalidate |  |
| 1D | blitToDc | visibility | scene_object_blit_to_dc | actor2d_blit_to_dc: fighter opponent banner energy_bar |
| 1E | invalidate | visibility | scene_object_invalidate | fighter_invalidate: fighter; opponent_invalidate: opponent; mover_invalidate: banner energy_bar |
| 1F | slot24 | visibility | scene_object_slot24 | mover_slot24: fighter opponent banner energy_bar |
| 20 | hide | visibility | scene_object_hide | mover_hide: fighter opponent banner energy_bar |
| 21 | show | visibility | scene_object_show | actor2d_show: fighter opponent banner energy_bar; animated3d_show: panel |
| 22 | occupy | occupancy | scene_object_occupy | control_panel_occupy: panel; status_bar_occupy: status |
| 23 | vacate | occupancy | scene_object_vacate | control_panel_vacate: panel; status_bar_vacate: status |
| 24 | attach | occupancy | scene_object_attach | actor2d_attach: fighter opponent banner energy_bar; control_panel_attach: panel; status_bar_attach: status |
| 25 | canStep | occupancy | scene_object_can_step_default | fighter_can_step: fighter; opponent_can_step: opponent; actor2d_can_step: banner energy_bar |
| 26 | isStepBlocked | occupancy | scene_object_is_step_blocked |  |
| 27 | nextFrame | animation | scene_object_next_frame_default | actor2d_next_frame: fighter opponent banner energy_bar; animated3d_next_frame: panel |
| 28 | prevFrame | animation | scene_object_prev_frame_default | actor2d_prev_frame: fighter opponent banner energy_bar; animated3d_prev_frame: panel |
| 29 | play | animation | scene_object_play_default | animation_play: fighter opponent banner energy_bar; animated3d_play: panel |
| 2A | playIdle | animation | scene_object_play_idle_default |  |
| 2B | stopAndRedrawDc | animation | scene_object_stop_and_redraw_dc_default | actor2d_stop_and_redraw_dc: fighter opponent banner energy_bar; animated3d_stop_and_redraw_dc: panel |
| 2C | stopAndRedraw | animation | scene_object_stop_and_redraw_default | actor2d_stop_and_redraw: fighter opponent banner energy_bar; animated3d_stop_and_redraw: panel |
| 2D | tick | animation | scene_object_tick_default | fighter_tick: fighter; opponent_tick: opponent; animation_tick: banner energy_bar; control_panel_tick: panel |
| 2E | stop | animation | scene_object_stop_default | actor2d_stop: fighter opponent banner energy_bar; animated3d_stop: panel |
| 2F | moveTo | movement | scene_object_move_to_default | mover_move_to: fighter opponent banner energy_bar |
| 30 | moveToEdgeH | movement | scene_object_move_to_edge_h_default | mover_move_to_edge_h: fighter opponent banner energy_bar |
| 31 | moveToEdgeV | movement | scene_object_move_to_edge_v_default | mover_move_to_edge_v: fighter opponent banner energy_bar |
| 32 | stopMovingDc | movement | scene_object_stop_moving_dc_default | fighter_stop_moving_dc: fighter; opponent_stop_moving_dc: opponent; actor2d_stop_moving_dc: banner energy_bar |
| 33 | stopMoving | movement | scene_object_stop_moving_default | fighter_stop_moving: fighter; opponent_stop_moving: opponent; actor2d_stop_moving: banner energy_bar |
| 34 | moveTick | movement | scene_object_move_tick_default | fighter_move_tick: fighter; opponent_move_tick: opponent; actor2d_move_tick: banner energy_bar |
| 35 | getTimerId | animation | scene_object_get_timer_id_default | actor2d_get_timer_id: fighter opponent banner energy_bar; animated3d_get_timer_id: panel |
| 36 | isMoving | movement | scene_object_is_moving_default | actor2d_is_moving: fighter opponent banner energy_bar |
| 37 | isRunning | animation | scene_object_is_running_default | animation_is_running: fighter opponent banner energy_bar panel |
| 38 | moveToAndDrop | space3d | scene_object_move_to_and_drop_default | object3d_move_to_and_drop: panel |
| 39 | setPosition | position | scene_object_set_position | actor2d_set_position: fighter opponent banner energy_bar |
| 4C | unk4E | position | scene_object_unk4e |  |
| 4D | redrawOverlapping | visibility | scene_object_redraw_overlapping | fighter_redraw_overlapping: fighter; opponent_redraw_overlapping: opponent; object3d_redraw_overlapping: panel |
| 4E | hitboxOverlaps | position | scene_object_hitbox_overlaps |  |
| 4F | boundsOverlap | position | scene_object_bounds_overlap |  |
| 50 | slot5B | position | scene_object_slot5b_default |  |
| 51 | slot5C | position | scene_object_slot5c_default |  |
| 54 | isEnabled | position | scene_object_is_enabled_default |  |
| 55 | getExitIndex | position | scene_object_get_exit_index_default |  |
| 3A–4B, 52/53, 56/57 | type tests | (Object.is/as) | | |

### Other vtables

`docs/salgin/SLOTS.tsv` (and XILINDRO's, identical) is this table for
`noite unit dep infer`.

| vtable | slots → unit |
|---|---|
| Object3DVtbl (8) | `space3d` (the panel's) |
| AnimationVtbl (1) | `animation.playOnce` |
| MoverVtbl (1) | `movement.placeAt` (mover_place_at) |
| FighterVtbl (3) | 00 `movement.placeAt`; 01 `fighters.startTimer` (fighter_start_timer); 02 `fighters.walk` (fighter_walk) |
| OpponentVtbl (2) | 00 `movement.placeAt`; 01 `fighters.walk` (opponent_walk) |
| ControlPanelVtbl (9) | 00 `animation.playOnce`; 01–08 `panels` (the game panel's getVisibleHeight) |
| GameVtbl (7) | 00 `game_input.handleMessage`; 01–06 `game` (createPlayer … onCreate) |
| SceneVtbl (13) | 00, 05, 07 `arena` (handleMessage, createScreen, create); the rest `scene` |
| Backdrop/GridBackdropVtbl (19/20) | `backdrop` (slot 00 create = the game backdrop's: the grid, no walls) |
| ConditionVtbl (3) | `game` |
| FrameVtbl (1) | `object_create.getCell` |

## State

`core/game.zig`'s `Game` is the game subclass + Game flattened plus every
DGROUP global (`g_fighterDamage` → `g.fighterDamage`, the strip tables and
the reaction table checked by `noite -p <n> initdata`, the eight key
latches, the bar marks, the three `GetTickCount` stamps, `g_roundOver`/
`g_fightOver`, `g_endTicks`, `g_endReady` (SALGIN), `g_resultSent`, the
seven wave handles, `g_reactionRow/Col` / `g_lastFighterMove/OpponentMove`,
the WaveMix state, `g_occupancy*` → `g.occupancy`, `g_fighter` …
`g_energyBar`, `g_noiteWnd`; `g_mainWindow` = `plat.windowHandle()`). No
counterpart: `g_setSystemTimer`/`g_killSystemTimer` (`g.setSystemTimer`),
the instance and module handles, the module path (the host's
`Program.dir`), the CRT's time-zone data. The round clock is the scene's
(`SalginScene.clock`, `XilindroScene.secondsLeft`: `Scene.clock` /
`Scene.secondsLeft` in `core/world.zig`). There is no score global: the
result comes from the energy bar's two energies.

**Time.** The fight runs on `GetTickCount` (`plat.ticks()`), read at the
top of every message the handler gets (the 50 ms system timer 1 makes one
every 50 ms): ≥ 200 ms since `g_lastPumpTick` is a beat, > 1000 ms a clock
second, > 100 ms after the round an end tick. `time(NULL)` is
`plat.unixTime()` (headless: the fixed epoch 800,000,000 + virtual
seconds), and `opponent_choose_attack` reseeds the CRT `rand` from it on
every choice (S5/X3): in a headless run the attacks follow the virtual
clock, so a script is deterministic, and the planner can predict them.

## Reading SALGIN and XILINDRO (medium model, /Od)

TIRO's notes hold (`docs/tiro/DESIGN.md` "Reading TIRO"): far pascal with
parameters listed **reversed** (`fighter_start_timer(this, period,
timerId, hwnd)` is source `(hwnd, timerId, period)` → `startTimer(g, obj,
timer_id, period)`), near data (DGROUP `1090`), `MOV BX,[SI]; CALLF
[BX+off]` virtual calls (slot = off / 4), `_aFchkstk` prologues, `/Od`
compare chains for every `switch`. The handlers (`1068:0d73`,
`1068:0d79`) are a WM switch with an inner key switch, preceded by the
clock block that runs on every message; Ghidra resolved their jump tables.
`backdrop_autoscroll` returns 0 right after its prologue (its old body is
dead bytes inside the function: port the `return 0`).

## Fixes (BUGS.md S- and X-sections)

| Bug | Flag | Unit | What the fix changes | In `all` |
|---|---|---|---|---|
| S1 opponent hits by the player's table | `salgin_opponent_damage_table` | arena | the opponent's attack (both branches) takes `g_opponentDamage[its strip]` {2, 1, 1, 3} from `playerEnergy` | no (choice) |
| S2 a block takes full damage | `salgin_block_holds` | arena | a player whose reaction strip is the block pose (7: End against the punch and both kicks) loses no energy | no (choice) |
| S3 key-up cuts any move | `salgin_keyup_stops_walk_only` | arena | a Left/Right key-up with the fighter not walking (strip ≠ 4) changes nothing (the latches stay set until the move ends) | yes |
| S4 Insert not locked | `salgin_insert_locked` | arena | the five attack/block key paths also set `g_keyInsertHeld` | no (choice) |
| S5 reseeded every choice | `salgin_seed_once` | fighters | `srand(time(NULL))` only before the first choice; later choices draw on | yes |
| S6 a loss closes only on `mane.WAV`'s end | — | — | no flag: the port's WaveMix always plays it to its end and posts MM_WOM_DONE | — |
| S7 closing mid-fight is a win | `salgin_close_mid_fight_loses` | arena | WM_DESTROY with `g_roundOver` 0 posts 0x40a (0, −1000) | yes |
| S8 health counters drift | `salgin_weak_reaction_by_energy` | arena | the weak column is `playerEnergy < 10` / `opponentEnergy < 6` | no (choice) |
| S9 banner never seen | `salgin_banner_shown` | hud | `salgin_redraw_arena` draws the banner into the band (after the restore, before the fighters) while the round is under 2 s old | no (choice) |
| S10 stand-off 68 px | `salgin_standoff_100` | fighters | the Right clamp sets nextX = opponent.x − 100 and moves there, without the 32-px step | yes |
| S11 walls before the step | `salgin_walls_after_step` | fighters | the step is cut so x stays within 0–400 (Left ends at 0, Right at 400) | yes |
| X1 a block takes full damage | `xilindro_block_holds` | arena | a fighter whose reaction strip is the block pose (7: End, walk or jump against the high kick) loses no energy | no (choice) |
| X2 weak reaction never shown | `xilindro_weak_reaction_by_energy` | arena | the fighter's weak column is `fighterEnergy < 10` (the bar's), as the opponent's | yes |
| X3 reseeded every choice | `xilindro_seed_once` | fighters | as S5 | yes |
| X4 key-up cuts any move | `xilindro_keyup_stops_walk_only` | arena | as S3 | yes |
| X5 Insert not locked | `xilindro_insert_locked` | arena | as S4 | no (choice) |
| X6 closing mid-fight is a win | `xilindro_close_mid_fight_loses` | arena | WM_DESTROY with `g_fightOver` 0 posts 0x40a (0, −1000) | yes |
| X7 double KO | `xilindro_double_ko_by_energy` | arena | the KO's winner is the result's (`!(fighterEnergy < opponentEnergy)`): pose, wave, end animation and result agree | yes |
| X8 bar lags | `xilindro_bar_follows_energy` | arena, hud | after every energy change (trades and the clash included) that side's mark is checked, adding a tile per 7 lost | yes |
| X9 banner never seen | `xilindro_banner_shown` | hud | as S9 | no (choice) |
| X10 stand-off 68 px | `xilindro_standoff_100` | fighters | as S10 | yes |
| X11 off the screen on the left | `xilindro_fighter_stays_on_screen` | fighters, arena | as S11, and the recoil stops at x 0 | yes |

Each unit ports the buggy code and keeps the fixed path only under its
flag (`g.fixes.salgin_…`, `g.fixes.xilindro_…`). The Harmless entries
(the stale `ReleaseDC`, write-only state, `g_opponentStripFrames` read for
the player, XILINDRO's dead MM_WOM_DONE case and unguarded reaction row,
`WinMain`'s return) get no flag; ported as the code does them (the
`ReleaseDC` of a handle the port never made is a no-op).

## Integration

Both fights are skeletons, off (`root.zig` `ready = false`) and in
`main.minigames`: until the finishing step sets `ready`, NOITE's WinExec
keeps the stub and `--minigame salgin|xilindro` says the program is not
ported yet.

### The launch from NOITE

- **SALGIN**: `handler_4fsalgin` (`src/handlers/4fsalgin.zig`), when the
  gym's `4smaoe` animation (0xf4) finishes: `stop musica`,
  `WinExec("<CD>salgin\salgin.exe")`, timer 0x14. The host matches
  `salgin` to `salgin.program`; the task starts `--minigame-startup` ms
  later (1500: WinMain, `app.start`, the static initialiser first, then
  WM_CREATE: `salgin_game_on_create`, `g_started`, system timer 1 at
  50 ms). FindWindow("Sala de Gin\xe1stica") succeeds on NOITE's next 0x14
  tick, NOITE posts **0x40b** (lParam = NOITE's window), AppWndProc stores
  `g_noiteWnd` and on its next message posts **0x40c**; NOITE hides
  itself. The end: a player win posts itself WM_DESTROY 30 end ticks
  (3 s) after the round, an opponent win on `mane.WAV`'s MM_WOM_DONE. The
  handler's WM_DESTROY stops and frees the waves, closes WaveMix and MCI
  and posts **0x40a** (won, score: playerEnergy × 100 or −1000) to
  `g_noiteWnd`; AppWndProc kills timer 1 and posts WM_QUIT; the host runs
  `app.exit`, destroys the window and activates NOITE, which shows
  itself, adds the score and goes to `espquete` (won) or takes a life and
  goes back to `4fbar` (or `6fsaida`).
- **XILINDRO**: `handler_3fstreet` (`src/handlers/3fstreet.zig`) when the
  street video ends: `WinExec("<CD>xilindro\xilindro.exe")`, timer 0x14,
  FindWindow("Xilindro"), the same handshake. Both outcomes close 31 end
  ticks (≈ 3.1 s) after the round (the handler posts WM_DESTROY on each
  tick until it arrives); 0x40a (won, fighterEnergy × 150 or −1000).
  NOITE records `minigameWon[3]` and goes to `3fstree2` (won) or
  `3fstree1` (a life; then `3fprisao` or `6fsaida`). In the Original
  B21's stale guard timer takes 3fstreet's video exit to `3fhall` while
  XILINDRO starts: the fight then runs over the hall, and its 0x40a
  reaches `3fhall`'s handler, which takes it for TIRO's (a win goes to
  `3fprisao`). Nothing changes in NOITE for that: it is B21, fixed by
  `avi_exit_ignores_timer`.
- NOITE's WM_SYSTIMER check (window gone without a result → a loss) is
  covered by the host's window lifetime, as for TIRO. `--minigame-stub`
  keeps the stub.

### Standalone, web, harness

- `noite --minigame salgin|xilindro [--headless …]`: the fight alone (its
  task 0, its title, `\SALGIN` / `\XILINDRO`); prints its result.
- Web (finishing step): both in `web_main.minigames` and in `MINIGAMES` /
  the "Jogo" select of `web/noite.js`/`index.html`; `tools/web/files.py`
  finds their files in their directories (the two share names such as
  `FUNDLUTA.BMP` and `PORRADA.MID`, each in its own directory). The
  on-screen pad needs the fight's keys (owner question 6).
- Harness scripts: the keys by number (`key 0x21` PgUp, `0x24` Home,
  `0x23` End, `0x2d` Insert; the arrows by name). The finishing step adds
  the names `pgup`, `home`, `end`, `insert` to `script.keyCode`.

## Platform: keys, repeat, timers

- **Keys.** The fights take eight keys: the four arrows, PgUp (VK_PRIOR
  0x21), Home (0x24), End (0x23), Insert (0x2d). SDL and the web page
  pass only the arrows, Enter, Esc and Space today: the finishing step
  adds the four (SDL: `SDLK_PAGEUP`, `HOME`, `END`, `INSERT`; the page:
  keyCodes 33, 36, 35, 45) to the backends' key maps; `Sim.filterInput`
  already gives a minigame every key it gets (NOITE never sees them: it
  has no use for them and they skip no video). Every key-up matters
  (Left/Right key-ups stop the walk; every key-up redraws the arena).
- **Repeat.** As TIRO: one generator in `Sim` (Windows 3.1's 500/33 ms),
  on by default. The latches make repeats harmless while a move plays;
  a held key starts its move again as soon as the latches clear, as on
  Windows. Nothing new is needed.
- **Timers.** System timer 1 (50 ms) is the heartbeat; the fighter's
  system timer 10 (1100 ms) and the end timer (0x14 SALGIN, 0xc
  XILINDRO, 100 ms) only add WM_SYSTIMERs, which the handler swallows.
  `GetTickCount` and `time()` are `plat.ticks()` / `plat.unixTime()`.
  Nothing new.
- **Sound.** MCI sequencer `porrada.mid` (alias `musica`, looped from
  MM_MCINOTIFY), WaveMix with SALGIN's `mane.WAV` the one wave with a
  notify window (its MM_WOM_DONE ends a loss) and XILINDRO's
  `murmlut2.WAV` looped (`wave_play_loop`, live in XILINDRO only).
  Nothing new.

## Tests

- **Planner** `tools/fight_plan.py --game salgin|xilindro --start MS
  (--win|--lose) [--relative-to MS]` (finishing step; MS: the fight's
  WM_CREATE, 0 alone, WinExec + 1500 from NOITE). It simulates the round
  on the virtual clock: the 50 ms system-timer messages and the
  `GetTickCount` stamps (beat, clock second, end ticks), the latches, both
  fighters' x, strips and frame counts, the opponent's approach and
  attack, `time()` → `srand`/`rand` (S5/X3), the reaction and damage
  tables, the energy bar, the KO and clock ends, and plans key presses
  (≥ 110 ms apart) that win, checked with the flags off and with `--fix
  all`. When one script cannot win in both versions, the Corrigida gets
  its own (`*-fixed.input`). `--check FILE` / `--trace FILE` simulate a
  script; the trace must match the port's (`noite --trace`) tick for tick
  on random games before the planner is trusted.
- **Scripts** (`tools/play/`), each run Original and `--fix all`:
  - `salgin-alone-win.input` / `xilindro-alone-win.input` (`--minigame
    <n> --ms 120000`): the planner's presses, `result won N`;
  - `salgin-alone-lose.input` / `xilindro-alone-lose.input`: no key at
    all; the opponent's attacks win (KO or the clock), `result lost
    -1000` (SALGIN closes on `mane.WAV`'s end);
  - `salgin-close.input` / `xilindro-close.input`: the window closed at
    5 s (a new harness command `close`, the platform's `.quit` event:
    WM_CLOSE to the active window; `quit` only ends the run): the
    Original reports a win worth 9,100 / 13,650 (S7/X6), the Corrigida a
    loss;
  - `salgin-4fsalgin-win.input` / `-lose.input` (`--scene 4fsalgin`): the
    gym's animation, NOITE hidden (`dump`), the fight, `espquete` with the
    score added / `4fbar` with a life less;
  - `xilindro-3fstreet-win.input` / `-lose.input` (`--scene 3fstreet`,
    no stale guard timer on a direct start): `3fstree2` / `3fstree1`;
  - `full.input` and `onebutton.input`: SALGIN between the sportsman's
    quiz and `espquete` becomes the real fight (the planner's winning
    presses, the result checked after the later of the two versions'
    ends); the 3fstreet line launches the real XILINDRO while B21 sends
    NOITE to the hall: the script plays it through (or the route is
    re-planned around it), re-tuned in the finishing step since every
    later random choice moves with it.
- **Smoke**: `tools/smoke.py --minigame salgin|xilindro [--fix all]
  [--monkey SEED]`: random presses of the eight keys and holds of
  Left/Right, ≥ 110 ms apart, for 120 s, seeds 1–5; no panic or leak, and
  a result.
- **Web**: `tools/web/test.py` plays each fight from the "Jogo" select:
  it starts, PgUp is answered.
- **Unit tests** (optional, tagged): `oracle=emulated` from tools/oracle
  (far code, DGROUP 1090, `_aFchkstk` 1080:00e4 runs as is) as worth it:
  `fighter_walk` (S10/S11, X10/X11), `opponent_walk`,
  `opponent_choose_attack` (with a fixed `time`), `energy_bar_add_mark`,
  the draw-clock pair (`asset` with `FUNDLUTA.BMP`).

## Units

Per program: 20 units. SALGIN 327 functions to port, 111 dead, 562
absorbed (451 thunks, 69 defaults, 42 type tests), 185 replaced (91 CRT,
94 imports). XILINDRO 328 to port (`wave_play_loop` is live), 109 dead,
468 absorbed (357 thunks), 185 replaced. Level = the longest chain of
hard deps (direct calls) below the unit: the units of one level run in
parallel once the levels below are done; virtual calls are soft (`unit
dep show`). XILINDRO's levels and deps are the same; its sizes are in
its DESIGN.md.

| Level | Unit | Fns | Size | Calls into |
|---|---|---|---|---|
| 0 | `dib` | 8 | 3.7 KB | — |
| 0 | `position` | 27 | 1.2 KB | — |
| 0 | `sound` | 9 | 0.9 KB | — |
| 1 | `backdrop` | 28 | 3.0 KB | dib, position |
| 1 | `object_create` | 27 | 3.0 KB | dib, position |
| 1 | `render` | 17 | 2.3 KB | dib, position |
| 1 | `space3d` | 24 | 4.0 KB | position |
| 2 | `animation` | 26 | 1.7 KB | position, render |
| 2 | `lists` | 17 | 2.0 KB | object_create, position, render |
| 2 | `occupancy` | 18 | 1.7 KB | position, render |
| 3 | `movement` | 20 | 2.9 KB | animation, backdrop, occupancy, position, render |
| 3 | `panels` | 17 | 1.6 KB | animation, dib, lists, object_create, position, render |
| 3 | `scene` | 15 | 0.8 KB | backdrop, lists, object_create |
| 3 | `visibility` | 22 | 1.5 KB | lists, position, render |
| 4 | `fighters` | 14 | 1.5 KB | animation, movement, object_create, occupancy, sound |
| 4 | `hud` | 6 | 1.3 KB | dib, object_create, occupancy, render, visibility |
| 5 | `arena` | 3 | 7.3 KB | animation, backdrop, fighters, hud, movement, scene, sound |
| 5 | `game` | 18 | 2.2 KB | animation, fighters, hud, lists, movement, object_create, occupancy, panels, scene |
| 6 | `app` | 8 | 1.3 KB | backdrop, dib, game |
| 6 | `game_input` | 3 | 4.2 KB | game, lists, position, render, space3d |

Order: `dib`, `position`, `sound`; then `backdrop`, `object_create`,
`render`, `space3d`; then `animation`, `lists`, `occupancy`; then
`movement`, `panels`, `scene`, `visibility`; then `fighters`, `hud`; then
`arena`, `game`; then `app`, `game_input`. The engine units (all but
`fighters`, `hud`, `arena`) of both programs can run at once (up to 8
agents per level across the two programs), each from TIRO's unit; the
fight units and the units holding the fight's overrides (`animation`,
`movement`, `occupancy`, `visibility`, `object_create`, `game`) go
SALGIN first, XILINDRO's from SALGIN's once it has landed. The largest
single functions: the scene handler (7.2 / 7.5 KB, `arena`: one agent,
the longest job; its rules are GAME.md's "The fight", "The opponent",
"End and result"), `game_handle_message` (3.7 KB, `game_input`, TIRO's
as is), `object3d_draw_bounds` (0.9 KB).

Unit contents beyond TIRO's: `fighters` = `<n>_create_opponent`,
`fighter_walk`, `opponent_walk`, `opponent_choose_attack`,
`fighter_start_timer` and the ten blow/pain wave pairs (`<n>_play_*`);
`hud` = `<n>_create_banner`, `<n>_create_energy_bar`,
`energy_bar_add_mark`, `<n>_redraw_arena`, `<n>_draw_clock`,
`<n>_blit_clock`; `arena` = `<n>_scene_handle_message`,
`<n>_scene_create`, `<n>_scene_create_screen`; the game's backdrop
create/ctor in `backdrop`, its scene ctor in `scene`, the five game
ctors in `object_create`, `wave_pump` (dead in TIRO, the beat's pump
here) in `sound`. `message_box_printf` stays in `position`, as TIRO's.

## Tracker

`noite -p salgin …` / `noite -p xilindro …` (or `NOITE_PROGRAM`): DBs
`db/<n>.sqlite` (local; `import` rebuilds them from Ghidra and the plan),
plans `db/<n>-plan.tsv` (committed), trees `src/<n>/`, indexes
`src/<n>/units.zig`, worktrees `work/<n>-<unit>/` on branches
`port/<n>-<unit>`. A worktree's `.ref/env.sh` sets `NOITE_PROGRAM`. The
programs' layout is `tools/cli/src/noite/program.py` (`_minigame`: CRT
1080, imports 10a8, DGROUP 1090, far 4-byte slots); the "Other vtables"
table is `docs/<n>/SLOTS.tsv`. The plan's dead statuses carry their
reason (TIRO's, by name, re-derived here: a function is live when a live
function calls it or it sits in a vtable that a live constructor stores
last; `player2d_move_tick` is dead here, `wave_pump` live).

```
noite -p salgin next [--blocked]    # units ready to claim
noite -p salgin start <unit>        # worktree work/salgin-<unit>/
noite -p salgin show <addr|name>    # row, decompile (--asm), callers/callees
noite -p salgin check -w <unit>     # @orig tags vs SALGIN's DB
noite -p salgin initdata -w <unit>  # `// @orig g_*` defaults vs SALGIN's DGROUP
noite -p salgin finish <unit>       # from the main checkout
noite -p salgin failed <unit> "why" / release <unit>
```

## How to port a unit

1. `noite -p <n> next`, `noite -p <n> start <unit>`, then work in
   `work/<n>-<unit>/` (`. .ref/env.sh`; tools via `nix develop -c`).
   Scratch output and frame dumps go in the worktree's `zig-out/`, never
   `/tmp`.
2. Read the unit's `.ref/*.c` (plate, decompile, disassembly),
   `.ref/types.md`, `.ref/strings.md`; `docs/<n>/DATA.md` / `GAME.md` for
   the classes and the rules. Ghidra (`mcp__ghidra__*`,
   `program="SALGIN.EXE"` / `"XILINDRO.EXE"`) for anything else.
3. Read the twin: TIRO's unit of the same name for an engine unit
   (`src/tiro/<unit>.zig`); for XILINDRO's fight code, SALGIN's
   (`src/salgin/<unit>.zig`, once landed). Transcribe each function from
   your program's own decompile/asm, reusing the twin's Zig where they
   agree; note in the commit body every function whose code differs from
   the twin's (and how). Never import another program's tree.
4. Write only `src/<n>/<unit>.zig` (or `behaviour/<unit>.zig`; a field
   the core lacks goes in `src/<n>/core/`): replace each declared
   dispatcher's body, keep its signature; one `// @orig <seg:off>
   <ghidra_name>` per function (your program's addresses; `(absorbed)`
   for the defaults and thunks a dispatcher's arm covers). Public names:
   the Ghidra name minus the unit's class prefix, camelCase.
5. Faithful first: port each S/X bug as the code does it and put the fix
   only behind its flag (table above). NOITE's conventions hold (`i16`/
   `i32` with wrapping where the original overflows, `cstr`, `?*T`,
   message boxes through `plat.messageBox`, every PostMessage/
   SendMessage/SetSystemTimer at the same point, `error.Fatal` only where
   the original ends). Allocate what the original `new`s from
   `g.local()`.
6. Call other units' dispatchers, never a local copy. If a declared
   signature cannot express the original, `noite -p <n> failed <unit>
   "slot <name> (<owner>) needs …"`.
7. Tests optional; when written, `oracle=emulated` from tools/oracle,
   `asset` from `assets/<N>/`, `documented` from Ghidra.
8. `noite test`, commit (commit skill), `noite -p <n> finish <unit>` from
   the main checkout.

## Finishing

Once every unit of a program has landed: the keys (Platform), the script
key names and the `close` command, the planner and the scripts (Tests), the smoke option
(`KEYS_FOR` in `tools/smoke.py`), `full.input` re-tuned, the web entries;
then `ready = true` in `src/<n>/root.zig` and the README's minigame list.
BUGS.md's S/X "Port:" lines then say "ported and reproduced".

## Owner questions

1. **S1** (`salgin_opponent_damage_table`): should the opponent hit by its
   own table {2, 1, 1, 3} in Corrigida? It makes the fight harder (1.75
   per attack instead of 1.5).
2. **S2 / X1** (`*_block_holds`): should a block that shows the parry
   (strip 7) save the energy in Corrigida? The proposal saves all of it
   when the reaction is the block pose; the sweep (SALGIN) and the punch
   and lower kicks (XILINDRO) still land.
3. **S4 / X5** (`*_insert_locked`): should Insert wait for the move to end
   like every other key? (SALGIN's Down path stores a second PgUp latch
   where the Insert one would be, which suggests a slip.)
4. **S8** (`salgin_weak_reaction_by_energy`): should the weak reaction
   (the fall) follow the energy bar instead of the hidden health counters?
5. **S9 / X9** (`*_banner_shown`): should Corrigida show the PORRADA
   banner, and for how long? The proposal: in the band, behind the
   fighters, for the round's first 2 s.
6. **The on-screen pad** (web, one-button mode or a fight alone on a touch
   screen): the fights use eight keys. Which pad (`PAD_KEYS`): all eight
   (← → ↑ ↓ + PgUp, Home, End, Insert labelled as moves), or a subset?
7. **X7** (`xilindro_double_ko_by_energy`, in `all`): a double KO with the
   fighter ahead is a "win" whose score (fighterEnergy × 150) is 0 or
   negative. Keep that score, or floor it at 0?
8. **S10 / X10, S11 / X11** are in `all` as clear slips (the clamp then
   the step; the wall test before the step). They change where the
   fighter stands (100 px instead of 68 from the opponent, never off the
   screen): say if either should be a choice instead.
