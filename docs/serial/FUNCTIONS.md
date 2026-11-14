# SERIAL.EXE: function inventory (phase 2)

The Ghidra program `/SERIAL.EXE` after the phase-2 mapping: every code byte is in a function, every
function is classified, and 628 of the 633 code functions are named. Addresses are Ghidra
`seg:off`. SERIAL is TIRO's sibling build (`QUALITY.md` §0): medium model, `/Od`, far code, near
data, `this` at `[BP+6]`, 4-byte far vtable slots. **TIRO (`docs/tiro/`) is the reference for the
names**; ENCAIXE and NOITE behind it. The data is in `DATA.md`.

## Counts

**1,188 functions:** 93 import thunks, 462 adjustor thunks, 633 code functions. 628 of the 633 are
named; 5 stay `FUN_` (TIRO's 5 unnamed twins, below). Every code function has a plate.

| Kind | Fns | Where / names |
|---|---|---|
| Import thunk | 93 | `10a8`, all typed (copied from TIRO) |
| Adjustor thunk | 462 | `1088:005a–1b37` (335: 54 fixed + 281 vtordisp), `1088:4ac8–557f` (127: 21 + 106); `<target>_thunk[_k]` |
| CRT | 91 | `1080`: TIRO's 81 (with `entry`) + the 10 time/env routines |
| Blitter | 2 | `1000:0024`, `1000:0114` (32-bit code, untyped) |
| DIB | 15 | `1008`, `1010` |
| App shell | 10 | `1038` |
| WaveMix | 11 | `1078` |
| Engine | 458 | `1018–1060`, `1070`, `1088` |
| SERIAL game | 46 | `1048` (6), `1068` (29), the game-class ctors and type tests in `1088` (11) |
| — of which dead | 18 | see "Dead code" |

By segment (code functions, adjustor thunks excluded):

| Seg | Fns | Named | Seg | Fns | Named |
|---|---|---|---|---|---|
| `1000` | 2 | 2 | `1048` | 6 | 6 |
| `1008` | 4 | 4 | `1050` | 4 | 4 |
| `1010` | 11 | 11 | `1058` | 15 | 15 |
| `1018` | 51 | 51 | `1060` | 4 | 4 |
| `1020` | 7 | 7 | `1068` | 29 | 29 |
| `1028` | 49 | 47 | `1070` | 11 | 11 |
| `1030` | 9 | 9 | `1078` | 11 | 11 |
| `1038` | 10 | 10 | `1080` | 91 | 91 |
| `1040` | 2 | 2 | `1088` | 317 | 314 |

Conventions: 501 `__stdcall16far` (far pascal, `this` first, parameters listed in stack order),
98 `__cdecl16far`, 4 `__cdecl16far_dx_ax`, 4 `__cdecl16far_dxax_ptr`, 24 CRT near helpers, and
the 2 untyped blitters.

**Final state** (after phase 4 and the cleanup): 633 code functions, **628 named, 5 `FUN_`**,
**0 `sig?`, 0 `review`** (the tags copied from TIRO and set in phase 2 were checked and resolved,
"Phase 4 results"); 462 adjustor thunks, every name matching its target's final name
(`NearAdjustorThunks.java` rerun, `far`); 464 call-site overrides, every indirect call typed but the
11 CRT function-pointer calls (`DATA.md`).

## How the functions were found

In this order (all in the program now):
1. **Vtable slots** — `FarVtSlots.java 1090 0626 2340`: 1,665 slots, 560 targets, **418 new
   functions**, 69 vptr stores referenced, each slot typed as a 4-byte pointer. One target
   (`1088:264c`) sat inside a TIRO-shaped absorbed tail; the transfer (step 5) split it off.
2. **Adjustor thunks** — `NearAdjustorThunks.java 1088 005a 1b38 far` and `1088 4ac8 5580 far`:
   **462 thunks**; 13 bodies that had run on into their `JMPF` target were cut back. Rerun after
   every renaming pass so the thunk names follow their targets.
3. **Gap sweep** — `CodeGapSweep.java <seg> <report> create` on `1088`, `1080`, `1068`, `1038`,
   `1020`, `1058`: 22 more (`1038:0000` APPABOUT, `1020:0000`, 11 CRT entries, 9 in `1088`).
4. **Dead jumps** — `DeadJumps.java` on all code segments: 61 unreachable `/Od` epilogue `JMP`s
   folded into their functions (22 of them in the handler `1068:1529`).
5. **Transfer from TIRO** — `SerialFromTiro.java` (new, below) with `zig-out/serial/fmap.py`'s
   map: 592 TIRO functions at their aligned SERIAL address, with their bodies, names, prototypes,
   tags and plates. It fixed the CRT boundaries on the way: the 5 `INC BP` far prologues one byte
   early (`0f1c`, `0f8a`, `195e`, `1a6a`, `1aa8`), the frameless entries (`_aNchkstk` `00c4`,
   `_cintDIV` `0874`, `crt_dosret_maperr` `161d`, the heap helpers `1674`/`1700`/`1766`,
   `crt_ltoa_body` `1d14`, `crt_xtoa` `1d20`), `_output`'s 7 near helpers. Before it, by hand:
   `FATALEXIT` no-return, `_amsg_exit` (`0879`) cut at its `CALLF FATALEXIT` so that `_flsbuf`
   (`08bc`) is its own function, and `_output`'s jump table (`1080:09ae`, 8 words, `JMP
   CS:[BX+0x9ae]` at `0a17`) typed with its COMPUTED_JUMP references.
6. **The 10 new CRT routines** (in TIRO's five insert points) by normalised-opcode match against
   NOITE's CRT (`crtmatch.py`); `atoi` `1786` is NOITE's 3-byte `JMP atol`, right before `getenv`.
7. **The game** (`1068`, the `1088` game ctors) by vtable slot against TIRO's tables, by role, or
   by reading (below).

Uncovered bytes left (all data or padding): `1068:22ab–22b6` (the handler's jump table
`g_spawnLane1JumpTable`), `1080:0000–0011` (segment prefix), `1080:09ae–09bd` (`_output`'s table), `1080:1570–1571`
(`90 90` inside `_isindst`), and 379 one-byte fillers between functions in `1088` plus 46 in
`1080`.

## Names and how they were applied

Every plate's first line says where the name comes from:

| Plate head | Method | Names |
|---|---|---|
| `Name from TIRO <name> at <addr> (byte-aligned, q=…)` | `fmap.py`: TIRO and SERIAL segments aligned with `difflib`; the TIRO function's entry and every body range map to an aligned block, the length is unchanged and q (the fraction of equal bytes) is ≥ 0.6. Then **checked**: every pair has the same set of `RETF n` immediates (`retcheck.py`, 0 mismatches over 590 pairs). The TIRO plate follows. `tiro_`→`serial_`, `crossbow`→`gun`, `arrow`→`bullet` | 590 |
| `Twin of TIRO FUN_…` | the same, for TIRO's 5 unnamed functions (left `FUN_`) | 5 |
| `Name from NOITE <name> at 1008:<addr> (CRT; …)` | normalised-opcode match ≥ 0.73 against NOITE's CRT (`atoi` by its place and body) | 10 |
| `Name by <slot or role> (TIRO <name>)` | the SERIAL game, by vtable slot (same table and slot as TIRO's, `vtpairs.py`) or by role; TIRO's prototype copied when the `RETF n` matches (it does for all 24) | 24 |
| `Name by behaviour` / `Name by body` / `Name from TIRO … (role: …)` | read: `target_start_timer`, `target_hide_and_blit`, `target_move_tick_or_stop`, `target_wrap_at_edge`, `serial_hit_kind1`, `serial_hit_kind0_2`, `target_ctor`, `frame_vector_deleting_dtor` | 8 |
| `Name from TIRO …` on the imports | `CopyTypesFromProgram.java /TIRO.EXE` (phase 1) | 93 |
| adjustor thunks | `NearAdjustorThunks`, after their targets | 462 |

**Vtables check the transfer.** `vtpairs.py` pairs SERIAL's 54 tables with TIRO's (same classes,
same order, except that SERIAL puts the game's ControlPanel tables before its Scene table) and
compares every slot's target name: **all engine tables agree slot for slot** (SceneObject,
Object3D, Mover, Portable, Moveable, Game, Backdrop, Animation, Actor2D, Player2D, Scene,
GridBackdrop, StatusBar, ControlPanel, Animated3D, the Conditions, the CRT hooks). The only
differences are the game's own overrides, which named them:

| SERIAL table | Slot | SERIAL target | TIRO target |
|---|---|---|---|
| SerialScene `1258` | 0, 7 | `1068:1529`, `1068:008d` | `tiro_scene_handle_message`, `tiro_scene_create` |
| SerialBackdrop `1c86` | 0 | `1068:0000` | `tiro_backdrop_create` |
| Gun S `1768` | 0x29, 0x2d | `1068:05d1`, `05fb` | `crossbow_play`, `crossbow_tick` |
| TargetVtbl `1e94` | 1, 2, 3 | `035c` (new), `0d94`, `0f59` | (3 slots) `move_tick_or_stop`, `wrap_at_edge` |
| Target S `1ea8` | 0x14, 0x2d | not overridden (`mover_restore_background`, `animation_tick`) | `target_restore_background`, `target_tick` |
| Target S `1ea8` | 0x25, 0x32, 0x33, 0x34, 0x4d | `0c1a`, `0663`, `06d9`, `0dfc`, `072a` | `target_can_step`, `…stop_moving_dc`, `…stop_moving`, `…move_tick`, `…redraw_overlapping` |
| ProjectileVtbl `201c`, Bullet `21a4` | 1, 2, 3 | `14d2`, `13d7`, `12a5` | `projectile_move_tick`, `…step_move`, `…try_step` |
| Projectile/Bullet S | 0x32, 0x33, 0x4d | `120b`, `1254`, `135f` | `projectile_stop_moving_dc`, `…stop_moving`, `…redraw_overlapping` |

**SERIAL's TargetVtbl has 4 slots, TIRO's 3:** SERIAL inserted `startTimer` at slot 1 and moved
`moveTick` and `checkEdge` down one.

Engine functions whose bytes differ from TIRO's (each plate has a "SERIAL differs from TIRO" line):
- `mover_move_tick` (`1028:0fb9`, −6), `scene_object_redraw_overlapping` (`1100`, −6),
  `animation_stop_and_redraw_dc` (`170b`, −6) and `animation_tick` (`17b7`, −28: no DC of its own)
  repaint with SceneObject slot 0x78 `invalidate(this)` where TIRO calls slot 0x74
  `blitToDc(this, backdrop, hdc)`;
- `scene_object_restore_background` (`0311`, +4) restores with the colour-key copy
  `dib_copy_transparent` (key `g_unk00A8` = 0x0b), as ENCAIXE, where TIRO calls the opaque
  `dib_copy_rect`; `Fundo.bmp` has no pixel of index 0x0b, so the key changes nothing here;
- `wave_play` (`1078:01e6`, +9): flags `5 | (hWndNotify == 0 ? 2 : 0)`, 7 for every SERIAL call (TIRO 5).

None changes the function's own frame or `RETF`. TIRO's engine had been edited for its crossbow and
target ticks; SERIAL keeps the plainer version.

## Signatures

Copied with the names: 590 from TIRO (types resolved into the `/serial` category, which is TIRO's
`/tiro` copied by `SerialFromTiro.java types` with `Crossbow`→`Gun`, `Arrow`→`Bullet`), 24 + 6 game
functions by hand or from TIRO by role, the 10 new CRT routines from the C library:

| Addr | Prototype |
|---|---|
| `1080:020c` | `long __cdecl16far_dx_ax time(long *timer)` |
| `1080:0f9e` | `long __cdecl16far_dx_ax __loctotime_t(int year, int month, int day, int hour, int min, int sec)` |
| `1080:1400` / `141c` | `void __tzset(void)` / `void _tzset(void)` |
| `1080:1520` | `int _isindst(void *tm)` |
| `1080:1786` | `int atoi(char *s)` (`JMP atol`) |
| `1080:178a` | `char *getenv(char *name)` |
| `1080:17f0` | `long _aFlrem(uint dividendLo, int dividendHi, uint divisorLo, int divisorHi)` (`_aFldiv`'s shape) |
| `1080:19dc` | `int strncmp(char *s1, char *s2, int n)` |
| `1080:1a16` | `long __cdecl16far_dx_ax atol(char *s)` |

The CRT `"PST"`/`"PDT"` defaults, `getenv("TZ")`, `atoi` and `atol` come in only because
`serial_create_targets` seeds `rand` with `time(NULL)`; nothing else calls them.

Adjustor thunks keep no signature.

## Segment inventory

| Seg | Fns | Content | Source of the names |
|---|---|---|---|
| `1000` | 2 | blitters | identical segment |
| `1008` | 4 | DIB copy, transparent copy | TIRO, byte-aligned |
| `1010` | 11 | DIB load, palette, remap | TIRO, identical segment |
| `1018` | 51 | Object3D, Moveable, Portable, Player, Exit | TIRO |
| `1020` | 7 | perspective backdrop, layers | TIRO |
| `1028` | 49 | SceneObject, Mover, Animation, Player2D, object list (5 functions differ, 2 `FUN_`) | TIRO |
| `1030` | 9 | occupancy grid, Backdrop (WinG) | TIRO |
| `1038` | 10 | app shell (APPABOUT, `app_init`, WinMain, APPWNDPROC, …) | TIRO |
| `1040` | 2 | `game_handle_message`, `game_take_exit` | TIRO |
| `1048` | 6 | SerialGame: `serial_game_ctor`, `_create_player` (the Gun, `trabu.bmp`), `_create_control_panel`, `_create_status_bar`, `_create_init_scene`, `_on_create` | TIRO (`tiro_game_*`, byte-aligned) |
| `1050` | 4 | Conditions | TIRO |
| `1058` | 15 | StatusBar, ControlPanel | TIRO |
| `1060` | 4 | Scene | TIRO |
| `1068` | 29 | **the game** (below) | slot / role / reading |
| `1070` | 11 | draw lists (one copy dead) | TIRO |
| `1078` | 11 | WaveMix | TIRO (`wave_play` differs) |
| `1080` | 91 | CRT | TIRO + NOITE (time family) |
| `1088` | 317 + 462 thunks | defaults, getters, ctors, dtors, Game/Frame init; game-class ctors `serial_panel_ctor` `5580`, `gun_ctor` `5752`, `gun_is_gun` `57ea`, `serial_scene_ctor` `5806`, `serial_scene_create_screen` `5840`, `target_is_target` `588a`, `projectile_is_projectile` `58a6`, `serial_backdrop_ctor` `5d50`, `target_ctor` `683c`, `bullet_ctor` `68de`, `projectile_ctor` `6976` | TIRO |

### `1068`, the game module

| Addr | Name | What |
|---|---|---|
| `0000` | `serial_backdrop_create` | GridBackdrop slot 0: the 32-px occupancy grid, walls at columns 0/19 rows 5–13 and row 13 (TIRO's grid) |
| `008d` | `serial_scene_create` | Scene slot 7: MCI `doom2.mid`, WaveMix, the 3 waves, the score box |
| `013f` | `serial_create_targets` | `srand(time(0))`, the 15 targets (13 with one parameter set, 2 with another), their timers, the 60-s game clock on target 0 |
| `035c` | `target_start_timer` | TargetVtbl 1: store the timer id by index, `SetSystemTimer` |
| `03d5` | `serial_create_bullets` | the one Bullet (`bala.bmp`) |
| `04c1` | `gun_aim` | 'D' / 'E' cycle the gun's `curFrame` 0→1→2→0 / 0→2→1→0 |
| `05d1`, `05fb` | `gun_play`, `gun_tick` | Gun SceneObject overrides |
| `0663`, `06d9`, `072a`, `0c1a`, `0dfc` | `target_stop_moving_dc`, `target_stop_moving`, `target_redraw_overlapping`, `target_can_step`, `target_move_tick` | Target SceneObject overrides; `target_move_tick` is the walk step, and a kind-2 figure's shot (a **life**; `WM_DESTROY` at 0) |
| `0c42` | `target_hit` | score by the target's kind, stop it, clear its lane flag, redraw |
| `0d0d` | `target_hide_and_blit` | hide the hit figure and blit its rect to the window |
| `0d94`, `0f59` | `target_move_tick_or_stop`, `target_wrap_at_edge` | TargetVtbl 2, 3 |
| `120b`, `1254`, `12a5`, `135f`, `13d7`, `14d2` | `projectile_*` | the Projectile overrides (the Bullet uses them) |
| `1529` | `serial_scene_handle_message` | **the handler, 12,899 bytes**: keys, 7 timer tests, the spawns, the hit test, the 60-s clock, the 0x40a result |
| `478c` | `serial_play_shot_wave` | `tiros1.WAV` |
| `47b2`, `480c` | `serial_hit_kind1`, `serial_hit_kind0_2` | score +100 / −100 or +200, `morte2.wav`, redraw the score |
| `4871`, `48bc` | `serial_blit_score_box`, `serial_draw_score` | the score box (TIRO's) |

## Dead code

No caller and no slot (or a slot nothing calls), 18:
- the TIRO dead set, at the same places: the second draw-list copy (`dead_draw_list_ctor`
  `1070:0037`, `_insert` `00ff`, `_remove` `01f5`, `_invalidate_all` `0319`),
  `dead_scene_object_empty_dc_hook` `1028:02d3`, `dead_blit_view_to_dc` `1088:3e00`,
  `dead_slot24_blit_view_to_dc` `3e24`, `dead_restore_background` `3e62`,
  `dead_mover_draw_clipped_to` `3e84`, `dead_mover_redraw` `41e4`;
- the 5 `FUN_` (below);
- `frame_vector_deleting_dtor` `1088:0000` (new, SERIAL only);
- `target_move_tick_or_stop` (TargetVtbl 2) and `projectile_move_tick` (ProjectileVtbl 1): no call
  site uses those slots (the handler calls `checkEdge` and `projectile_step_move`); the Portable
  ctors are dead as in TIRO;
- the lane-2 spawn branch of the handler (1068:2968–2cca), unreachable (`BUGS.md` K5).

The 5 `FUN_` are TIRO's 5 unnamed functions, at the mapped addresses (no caller, slot or data
reference settles a role):
`1028:0e75` (empty member, `RETF 0xa`), `1028:1c8d` (far cdecl huge-pointer arithmetic, no caller),
`1088:3dcc`/`3de6` (empty `(this, backdrop)` twins), `1088:3e48` (empty `(this)`).

## Phase 4: function groups

One `ghidra-investigate` agent per group. **Mechanical** groups were transferred from TIRO by
address and checked by `RETF` and by vtable: the agent verifies the decompile reads right with the
`/serial` types, fixes what the DGROUP shift changed (global names, string arguments), and closes
the `sig?`/`review` tags. **SERIAL** groups need real reading.

| # | Range | Fns | Content | Kind / effort |
|---|---|---|---|---|
| 1 | `1080:0000–08bb` | 33 | CRT startup, strings, `time`, `srand`/`rand`, long math, array ctor/dtor, `_cinit`, exit, `_setargv`/`_setenvp`, `_amsg_exit` | mechanical, low |
| 2 | `1080:08bc–1191` | 21 | `_flsbuf`, `_output` + helpers, heap, `__loctotime_t`, NMSG | mechanical, low |
| 3 | `1080:1192–1d72` | 37 | I/O, `_tzset`/`_isindst`, dosret, heap helpers, flush/close, `getenv`, `_aFlrem`, `strncmp`, `atol`, `_itoa` | mechanical, low |
| 4 | `1000`, `1008`, `1010` | 17 | blitters, DIB copy, DIB load/palette/remap (4 `sig?`) | mechanical, medium |
| 5 | `1018:0000–0f2a` | 31 | Object3D/Moveable/Portable attach, projection, draw bounds, getters, overlap | mechanical, low |
| 6 | `1018:0f2b–21c7` | 20 | Object3D below/support/front, Moveable tick, Player/Exit, Portable | mechanical, low |
| 7 | `1020`, `1030`, `1050` | 20 | perspective backdrop, occupancy grid, Backdrop/WinG, Conditions | mechanical, low |
| 8 | `1028:0000–0d30` | 21 | SceneObject/Mover blit, restore (differs), draw, attach, overlap | mechanical, medium |
| 9 | `1028:0d31–1d28` | 28 | Mover step/move (differs), Animation (2 differ), Player2D, object list, 2 `FUN_` | mechanical, medium |
| 10 | `1038`, `1040:0e6b`, `1048` | 17 | app shell, `game_take_exit`, SerialGame subclass | mixed, medium |
| 11 | `1040:0000` | 1 (3.7 KB) | `game_handle_message` | mechanical, high (alone) |
| 12 | `1058`, `1060` | 19 | StatusBar, ControlPanel, Scene | mechanical, low |
| 13 | `1070`, `1078` | 22 | draw lists, WaveMix (`wave_play` differs) | mechanical, low |
| 14 | `1088:0000–1fff` | 28 | `frame_vector_deleting_dtor`, Frame, SceneObject defaults and getters | by slot, low |
| 15 | `1088:2000–23ff` | 37 | SceneObjectVtbl default stubs | by slot, low |
| 16 | `1088:2400–27ff` | 24 | defaults, the type tests (`is_projectile`/`is_target`/`is_gun`) | by slot, low |
| 17 | `1088:2800–2bff` | 21 | Mover/Actor2D getters and overrides | by slot, low |
| 18 | `1088:2c00–2fff` | 20 | Player2D, update list, Object3D getters | by slot, low |
| 19 | `1088:3000–33ff` | 23 | Moveable overrides | by slot, low |
| 20 | `1088:3400–37ff` | 31 | Portable/ControlPanel/StatusBar type tests and getters | by slot, low |
| 21 | `1088:3800–3fff` | 17 | Mover/SceneObject ctors, `frame_ctor`/`frame_init`, 3 `FUN_` | mixed, low |
| 22 | `1088:4000–4ac7` | 34 | backdrop blit, scene-object dtors, object list, frame getters | mixed, low |
| 23 | `1088:5580–59ff` | 17 | **`serial_panel_ctor`, `gun_ctor`, `gun_is_gun`, `serial_scene_ctor`/`_create_screen`**, StatusBar | SERIAL + mechanical, medium |
| 24 | `1088:5a00–5fff` | 32 | ControlPanel/Scene/Backdrop ctors, `game_ctor`, update list, `serial_backdrop_ctor` | mixed, low |
| 25 | `1088:6000–6a31` | 33 | grid backdrop, Actor2D/Animated3D/Animation/Mover ctors, Conditions, **`target_ctor`, `bullet_ctor`, `projectile_ctor`** | mixed, medium (the Target class is new: 0x5c bytes) |
| 26 | `1068:0000–1528`, `1068:478c–49b5` | 28 | **the SERIAL game**: grid, scene create, target/bullet creators, gun, the Target class (timer, move, wrap, hit, redraw), the Projectile class, score helpers | SERIAL, high |
| 27 | `1068:1529` | 1 (12.9 KB) | **`serial_scene_handle_message`** (keys, 7 timer tests, spawns, the hit test by lane, the game clock, WM_DESTROY → 0x40a) | SERIAL, high (alone) |

Order: 1–4 and 10 first (CRT, DIB and app names anchor the rest), then 5–9 and 11–13, then
14–25 (after `DATA.md`'s vtable structs and `FarSlotSignatures`), then 26–27.

## Phase 4 results

All 27 groups are done: every function is named or noted, plated and typed. The game is described in
`GAME.md`, its bugs in `BUGS.md` (section SERIAL, K1–K5). What phase 4 corrected in the earlier
picture:
- **Names:** `target_redraw` → `target_hide_and_blit` (it erases the hit figure, it does not draw it).
- **Timers:** the handler has **7 timer tests**, not one per target: gun 10 (60 ms), walk 3 (figures
  0–12, 200 ms), walk 6 (13–14, 100 ms), spawn 7 (5 s), lane 2 10 (5 s, `g_timerPeriods[4]`), bullet
  0xc (55 ms), clock 8 (60 s). The lane-2 test is dead: id 10 is the gun's too, and the gun is tested
  first (`BUGS.md` K5). Lane 2 gets a figure every 10 s through `g_spawnToggle` in the id-7 branch.
  `g_timerPeriods[5..7]` and `g_timerIds[1]`, `[2]`, `[6]` are never read.
- **Lives:** `target_move_tick` takes a life only through a kind-2 figure's shot (the step that
  brings its frame to two before the end of the strip), not when a figure gets through.
- **`target_move_tick_or_stop`** compares the SceneObject's y (`< 10`), not `curFrame`.
- **Engine differences:** the four `invalidate`-for-`blitToDc` swaps, the colour-key restore and
  `wave_play`'s flags (above), not "pushes fewer".
- **The hit test:** stage 2 tests lanes 2, 1, 0 by x only with TIRO's 55-px arrow width
  (`BUGS.md` K3).

Cleanup:
- **Tags:** `message_box_printf` is far cdecl `(caption, format, int arg)`, not varargs (all 14
  callers push 3 words and pop 6); `perspective_project_point`/`_unproject_point` keep 7 words (every
  caller pops 0xe); the 4 unreferenced DIB functions keep TIRO's prototypes (their bodies are TIRO's);
  `FUN_1028_1c8d` is `(ulong, ulong) -> DX:AX`. The 5 `FUN_` plates end with a one-line note: no
  caller, slot or data reference settles a role.
- **Overrides:** the 12 calls through `g_setSystemTimer` (8) and `g_killSystemTimer` (4) have
  `/SetSystemTimerFn` and `/KillSystemTimerFn` (`FarSlotSignatures.java 1090 site
  <addr>=/SetSystemTimerFn …`); the 452 virtual calls are typed (phase 3's 428 and the 24 engine
  sites by `site`). 11 CRT function-pointer calls stay untyped.
- **Plates:** the stale TIRO table, scene-table and background references in `serial_panel_ctor`,
  `serial_scene_ctor`, `serial_scene_create_screen`, `target_ctor`, `bullet_ctor` and
  `projectile_ctor` now give SERIAL's; the handler plate and its pre-comments cite the K entries.
- **The jump table** `1068:22ab` is `g_spawnLane1JumpTable`, `word[6]` (cases 0–5 → `2269`…`2291`,
  figures 7–12).

## Scripts

| Script | Use here |
|---|---|
| `SerialFromTiro.java` (new) | `types /TIRO.EXE /tiro /serial T:Crossbow=Gun T:Arrow=Bullet`; `fns /TIRO.EXE <map.tsv> /tiro /serial tiro_=serial_ crossbow=gun arrow=bullet T:…` |
| `FarVtSlots.java` | `1090 0626 2340` |
| `NearAdjustorThunks.java` | `1088 005a 1b38 far`, `1088 4ac8 5580 far` (rerun after renaming) |
| `CodeGapSweep.java` | per segment, `create` |
| `DeadJumps.java` | all code segments |
| `RenameFunctions.java` | the game names (`force` to replace the transfer's plate) |
| `CopyTypesFromProgram.java` | `/TIRO.EXE` (phase 1) |

Scratch (not committed, `zig-out/serial/`): `fmap.py` (the TIRO→SERIAL map, `xfer.tsv`),
`retcheck.py` / `ret2.py` (RETF agreement), `vtpairs.py` (slot-by-slot table comparison),
`crtmatch.py` (CRT against NOITE), `fdiff.py` (instruction diff of a function pair), `dis.py`
(offline listing with relocations), `SerialExportFns.java`, `SerialVtDump.java`,
`SerialDecomp.java`.

**Note for scripts:** `GhidraScript.runScript` from an inline script takes a script *name*, not a
path; with a path it opens a modal "Script does not exist" yes/no dialog and holds the program's
transaction (no save possible) until it is answered.
