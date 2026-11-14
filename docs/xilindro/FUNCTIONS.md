# XILINDRO.EXE: function inventory (phase 2)

The Ghidra program `/XILINDRO.EXE`: every function mapped, classified and named. Addresses are
Ghidra `seg:off`. XILINDRO is a medium-model `/Od` build of TIRO's engine (`QUALITY.md` §0), so
**TIRO (`docs/tiro/`) is the name source**: its program is fully named and typed, and the shared
segments align to it function for function. The data is in `DATA.md`.

## Counts

**1,090 functions:** 94 import thunks, 357 adjustor thunks and 639 code functions. **634 of the 639
are named**; 5 stay `FUN_` (the same 5 dead stubs TIRO leaves unnamed, below). Every code function
has a plate saying where its name comes from.

| Kind | Fns | Where / names |
|---|---|---|
| Import thunk | 94 | `10a8`, all typed (from TIRO) |
| Adjustor thunk | 357 | `1088:0000-1334` (241), `1088:42d8-4c7d` (116); `<target>_thunk[_k]` |
| CRT | 91 | `1080` (TIRO's 81 + `time`, `__loctotime_t`, `__tzset`, `_tzset`, `_isindst`, `getenv`, `_aFlrem`, `strncmp`, `atol` and the `atoi` thunk) |
| Blitter | 2 | `1000:0024`, `1000:0114` (32-bit, not typed) |
| DIB | 15 | `1008` (4), `1010` (11) |
| App shell | 10 | `1038` |
| WaveMix | 11 | `1078` |
| Engine | 457 | `1018-1060`, `1070`, `1088` |
| **XILINDRO game** | 53 | `1048` (6), `1068` (34), `1088` (13: the game-class ctors, type tests and two slot overrides) |
| Dead, unnamed | 5 | `1028:0e71`, `1028:1c6f`, `1088:35c6`, `1088:35e0`, `1088:3642` (inside the engine count) |

By segment (code functions other than the adjustor thunks):

| Seg | Fns | Named | Seg | Fns | Named |
|---|---|---|---|---|---|
| `1000` | 2 | 2 | `1048` | 6 | 6 |
| `1008` | 4 | 4 | `1050` | 4 | 4 |
| `1010` | 11 | 11 | `1058` | 15 | 15 |
| `1018` | 51 | 51 | `1060` | 4 | 4 |
| `1020` | 7 | 7 | `1068` | 34 | 34 |
| `1028` | 49 | 47 | `1070` | 11 | 11 |
| `1030` | 9 | 9 | `1078` | 11 | 11 |
| `1038` | 10 | 10 | `1080` | 91 | 91 |
| `1040` | 2 | 2 | `1088` | 318 | 315 |

Conventions of the 638 non-thunk code functions: 502 `__stdcall16far` (far pascal, parameters
listed reversed, `this` first), 110 far cdecl (`__cdecl16far`, `_dx_ax`, `_dxax_ptr`), 24 CRT near
helpers, the 2 untyped blitters. `atol` carries `sig?` (only reached through the `atoi` `JMP`).

## Function discovery

The TIRO procedure (`docs/tiro/FUNCTIONS.md`), with XILINDRO's ranges:
- **Vtable slots** (`FarVtSlots.java 1090 0600 2700`): 1,660 relocated far slots in 54 tables,
  547 distinct targets, **408 functions created**, 68 vptr stores referenced. Among them
  `game_handle_message` (`1040:0000`) and `_purecall` (`1080:0340`).
- **Adjustor thunks** (`NearAdjustorThunks.java 1088 0000 1335 far`, `1088 42c0 4c7e far`): 357
  (37 + 21 fixed, 204 + 95 vtordisp). FarVtSlots had already created them as slot targets.
- **Gap sweep** (`CodeGapSweep.java`, every code segment): 20 more, among them `1038:0000`
  (APPABOUT), `1020:0000`, 4 CRT entries and 14 in `1088`.
- **CRT by hand** (scratch inline script, TIRO's `TiroCrtFix` with XILINDRO offsets, every target
  checked byte for byte against TIRO, `crtmap.py`): `FATALEXIT` no-return; `_amsg_exit` `0879`
  split from `_flsbuf` `08bc`; `_nrealloc`/`_nmsize` moved onto their `INC BP` (`0f1c`, `0f8a`);
  `_output` `09be` with its 8-word jump table `09ae` (COMPUTED_JUMP references) and its 7 near
  helpers `0dd4-0e69`; the frameless entries `_aNchkstk` `00c4`, `_cintDIV` `0874`,
  `crt_dosret_maperr` `161d`, `crt_heap_try_grow` `1674`, `crt_heap_realloc_segment` `1700`,
  `crt_heap_find_end` `1766`, `crt_ltoa_body` `1d14`. Sizes equal TIRO's to the byte.
- **Dead jumps** (`DeadJumps.java`, all segments): 52 unreachable `JMP rel16` added to their
  functions.
- **Dead tail** of `backdrop_autoscroll` (`1030:0691`): its body starts with `return 0`; the 576
  bytes after it (TIRO's autoscroll) are disassembled and added to the function's body.
- **Jump tables**: `_output`'s (above) and three in `1068` that Ghidra resolved itself
  (`switchdataD_1068:208a`, `22ac` in the scene handler, `2d0c` in
  `xilindro_play_opponent_move_waves`).

Left uncovered, all data or padding: `1080:0000-0011` (segment prefix), the jump tables, 2
bytes `1080:1570`, and 360 one-byte fillers (45 in `1080`, 315 in `1088`).

## Names and how they were applied

Every name has a plate: `Name from TIRO <name> at <addr> (in-order alignment of segment <s>,
pair score <r>).`, `Name from NOITE <name> at <addr> (…)`, or a one-line description for the
game functions.

| Method | Names |
|---|---|
| Import signatures and the 4 WinG ordinal names, from TIRO (`CopyTypesFromProgram.java /TIRO.EXE`) | 94 |
| **In-order alignment per segment against TIRO** (`xalign.py`: global alignment of the functions in address order, pair score = difflib ratio of normalised ops). Accepted: score ≥ 0.8, TIRO name not game-specific and not `FUN_`. All 17 shared segments align end to end (`1018` 51/51, `1028` 49/49, `1088` 316/318, CRT 80/91…); `exact3.py` then shows the paired bodies equal operand for operand apart from DGROUP addresses and the few changes of `QUALITY.md` §0 | 566 |
| By alignment below 0.8, checked by hand: `backdrop_autoscroll` (score 0, its body is `return 0` + TIRO's dead tail), `crt_dosret_maperr` (6 bytes, identical) | 2 |
| CRT that TIRO lacks, named from NOITE by body (`time`, `__loctotime_t`, `__tzset`, `_tzset`, `_isindst`, `getenv`, `_aFlrem`, `atoi`, `atol`) or by the MSVC body (`strncmp`) | 10 |
| The game: by vtable slot (which table of which new class holds it, `gamevt.py`), the role of the TIRO counterpart in the same place, and a reading of the body | 53 |
| SceneObject type-test defaults renamed for XILINDRO: slot 0x56 `scene_object_is_fighter_default`, 0x57 `scene_object_is_opponent_default`, 0x58/0x59 `scene_object_slot58/59_default` (TIRO's isProjectile/slot62/isTarget/isCrossbow, whose TIRO names were left out of the alignment pass) | 4 |
| Adjustor thunks after their targets (`NearAdjustorThunks`, rerun) | 357 |

**Prototypes**: `XilindroCopyPrototypes.java` copied the TIRO prototype of 584 aligned functions
(the engine structs were first copied into `/xilindro` by `XilindroCopyCategory.java`, see
`DATA.md`). The 6 whose TIRO prototype uses a TIRO game class (crossbow/target/arrow/projectile
ctors and type tests) were typed by hand with the XILINDRO class. The new CRT functions and the
main game functions (ctors, scene handler and create, creators, walks, energy-bar shift,
`opponent_choose_move`, the ring redraw, the clock, the sound switch) are typed by hand;
`NearSignatures.java` set the mechanical conventions of the rest.

## The game functions

### `1048`: XilindroGame (GameVtbl `1090:139c`)

| Addr | Name | What |
|---|---|---|
| `0000` | `xilindro_game_ctor` | `game_ctor`, the vtable, `g_xilindroGame` |
| `0029` | `xilindro_game_create_player` | new 0x4c2 **Fighter** (`fighter_ctor`, the 11 `sb*.bmp` strips), `g_fighter`; curStrip 6 (guard), energy 0x5b, contact `'0'` |
| `0106` | `xilindro_game_create_control_panel` | new 0x566 XilindroPanel (`panel.bmp`) |
| `0164` | `xilindro_game_create_status_bar` | status bar, font "Virtual" / `arialbd.fot` |
| `01c0` | `xilindro_game_create_init_scene` | new 0x46 **XilindroScene** |
| `0210` | `xilindro_game_on_create` | `game_init`, place and play the fighter, then the opponent, banner and energy bar |

### `1068`: the fight

| Addr | Name | Slot / role |
|---|---|---|
| `0000` | `xilindro_create_opponent` | new 0x4b8 **Opponent** (`sa*.bmp`), curStrip 4 (walk), energy 0x5b |
| `0119` | `xilindro_create_banner` | new 0x4ae **Banner** (`porrada.bmp`), blitted once |
| `01ea` | `xilindro_create_energy_bar` | new 0x4b6 **EnergyBar** (`energia.bmp`), both energies 0x5b (91) |
| `02d1` | `energy_bar_shift` | stamps the marker one picture further left/right |
| `044a` | `xilindro_backdrop_create` | GridBackdropVtbl.create: `grid_backdrop_create_with_grid(this, 5)` |
| `0470` | `fighter_can_step` | Fighter SO canStep; contact `'2'` against the opponent |
| `051e` | `fighter_redraw_overlapping` | Fighter SO redrawOverlapping (draws the opponent) |
| `0546` | `fighter_tick` | Fighter SO tick |
| `05ac` | `fighter_move_tick` | Fighter SO moveTick |
| `0672` | `fighter_walk` | FighterVtbl slot 2 (`walk`) |
| `07a0` | `fighter_stop_moving_dc` | Fighter SO stopMovingDc |
| `07f8` | `fighter_stop_moving` | Fighter SO stopMoving |
| `0836` | `opponent_redraw_overlapping` | Opponent SO redrawOverlapping (draws the fighter) |
| `085e` | `opponent_can_step` | Opponent SO canStep; contact `'1'` against the fighter |
| `08dc` | `opponent_tick` | Opponent SO tick |
| `0942` | `opponent_move_tick` | Opponent SO moveTick |
| `0a08` | `opponent_walk` | OpponentVtbl slot 1 (`walk`) |
| `0afd` | `opponent_stop_moving_dc` | Opponent SO stopMovingDc |
| `0b47` | `opponent_stop_moving` | Opponent SO stopMoving |
| `0b85` | `opponent_choose_move` | `srand(time(0))`, next move `rand() % 4` |
| `0c87` | `xilindro_redraw_ring` | redraws the band y 0x8c..0x127 with both fighters |
| `0d79` | `xilindro_scene_handle_message` | SceneVtbl.handleMessage (7,482 bytes) |
| `2ae7` | `xilindro_scene_create` | SceneVtbl.create: MCI `porrada.mid`, WaveMix, 8 waves |
| `2bc9` | `xilindro_blit_clock` | blits the clock box |
| `2c16` | `xilindro_draw_clock` | prints the seconds left (`"%2.2d"`) |
| `2ccf` | `xilindro_play_opponent_move_waves` | switch on the opponent's move (jump table `2d0c`) |
| `2d1d`…`2e6f` | `xilindro_play_kick_dor1`, `_punch_dor1`, `_soco2`, `_boos`, `_kick_dor3`, `_punch_dor3`, `_soco2_2`, `_lutamal3` | one or two `wave_play` each |

### `1088`: the game classes

| Addr | Name | What |
|---|---|---|
| `4c7c` | `xilindro_panel_ctor` | ControlPanel subclass, no own fields (TIRO's `tiro_panel_ctor`) |
| `4e4e` | `fighter_ctor` | Fighter (derives Player2D) |
| `4ee6` | `fighter_start_timer` | FighterVtbl slot 1; no caller |
| `4f18` | `fighter_is_fighter` | SO slot 0x56 → 1 |
| `4f34` | `fighter_invalidate` | SO slot 0x1e, empty |
| `4f4e` | `xilindro_scene_ctor` | Scene subclass; `secondsLeft` = 90 |
| `4f8e` | `xilindro_scene_create_screen` | new XilindroBackdrop on `fundluta.bmp` |
| `4fd8` | `opponent_is_opponent` | SO slot 0x57 → 1 |
| `4ff4` | `opponent_invalidate` | SO slot 0x1e, returns 0 |
| `549c` | `xilindro_backdrop_ctor` | GridBackdrop subclass |
| `5f88` | `opponent_ctor` | Opponent (derives Actor2D) |
| `6026` | `banner_ctor` | Banner (derives Actor2D, no override) |
| `60be` | `energy_bar_ctor` | EnergyBar (derives Actor2D) |

The four game ctors have TIRO's bodies byte for byte (crossbow, target, arrow, projectile), with
other tables: same build, other classes. TIRO's Arrow-derives-Projectile link has no counterpart:
`banner_ctor` and `energy_bar_ctor` both call `actor2d_ctor_strips`.

## Dead code

- The 5 `FUN_` functions, dead in TIRO too: `1028:0e71` (empty `RETF 0xa`), `1028:1c6f` (TIRO
  `1028:1cb7`, huge-pointer arithmetic), `1088:35c6`, `1088:35e0` (empty `RETF 4`), `1088:3642`
  (empty `RETF 2`).
- TIRO's dead-but-named engine functions are dead here as well (the second draw-list copy,
  `draw_list_invalidate_chain/_all`, the PerspectiveBackdrop functions, the Portable ctors, …).
- `backdrop_autoscroll`'s tail (unreachable after `return 0`).
- `fighter_start_timer` (FighterVtbl slot 1): no call site.
- `xilindro_play_soco2_2` duplicates `xilindro_play_soco2`.

## Phase 4: function groups

Most of the engine is already named **and typed** from TIRO; its groups are verification work
(check the TIRO prototype against the body, fix the plate, look at the few bodies `QUALITY.md` §0
lists as changed). The game groups need real reading. Counts exclude adjustor thunks.

| # | Range | ~Fns | Content | Effort |
|---|---|---|---|---|
| 1 | `1080:0000-08bb` | 31 | CRT startup, strings, `time`, rand, long math, `_cinit`, exit, `_setargv`, `_setenvp`, `_amsg_exit` | low |
| 2 | `1080:08bc-1191` | 26 | `_flsbuf`, `_output` and helpers, heap, `__loctotime_t`, NMSG | low |
| 3 | `1080:1192-1d72` | 34 | CRT I/O, dosret, heap growth, `__tzset`/`_tzset`/`_isindst`, `getenv`, `_aFlrem`, `strncmp`, `atol`, flush/close, `_itoa` | low |
| 4 | `1000`, `1008`, `1010` | 17 | Blitters, DIB copy, DIB load/palette/remap | low |
| 5 | `1018:0000-0f5b` | 31 | Object3D/Moveable/Portable attach, project, bounds, overlap, elevation | low |
| 6 | `1018:0f5c-21c7` | 20 | Object3D below/front, Moveable tick, Player/Exit, Portable pick up/drop | low |
| 7 | `1020`, `1030`, `1050` | 20 | Perspective backdrop, occupancy grid, Backdrop/WinG (autoscroll disabled), Conditions | low |
| 8 | `1028:0000-0e89` | 22 | SceneObject/Mover blit, restore, draw, attach | low |
| 9 | `1028:0e8a-1d0a` | 27 | Mover step/move/edges, Animation, Player2D, object list. `mover_step` and the slot-0x1e calls differ from TIRO | medium |
| 10 | `1038`, `1040:0e6b`, `1048` | 18 | App shell (APPWNDPROC: 0x40b/0x40c), `game_take_exit`, XilindroGame | medium |
| 11 | `1040:0000` | 1 | `game_handle_message` (3.7 KB), verify against TIRO's | medium, alone |
| 12 | `1058`, `1060` | 19 | StatusBar, ControlPanel, Scene | low |
| 13 | `1070`, `1078` | 22 | Draw lists, WaveMix (`wave_play`'s new flags) | low |
| 14 | `1088:1335-17ff` | 28 | Frame, defaults, getters | low (by slot) |
| 15 | `1088:1800-1bff` | 36 | SceneObjectVtbl default stubs | low |
| 16 | `1088:1c00-1fff` | 24 | type tests, Animation/Mover getters | low |
| 17 | `1088:2000-23ff` | 21 | defaults, Animated3D | low |
| 18 | `1088:2400-27ff` | 20 | defaults, Moveable ctors | low |
| 19 | `1088:2800-2bff` | 23 | defaults, Actor2D | low |
| 20 | `1088:2c00-2fff` | 31 | SceneObject getters, Portable, Game defaults | low |
| 21 | `1088:3000-37ff` | 17 | Mover ctors, `frame_init`, dead stubs | low |
| 22 | `1088:3800-42d7` | 34 | Game defaults, `game_init`, Scene defaults | low |
| 23 | `1088:4c7e-52ff` | 24 | XilindroPanel, Fighter, XilindroScene ctors and slots, game ctor, status bar, Player2D | medium (game) |
| 24 | `1088:5300-5f87` | 41 | ControlPanel, Scene, GridBackdrop/XilindroBackdrop, Actor2D/Animated3D ctors, Conditions | low |
| 25 | `1088:5f88-6179` | 4 | Opponent, Banner, EnergyBar ctors; draw-list node | medium (game) |
| 26 | `1068:0000-0c86` | 22 | Creators, energy bar, Fighter and Opponent methods, `opponent_choose_move` | high |
| 27 | `1068:0c87-2e94` | 12 | Scene handler (7.5 KB: keys, hits, energies, clock, end, 0x40a), scene create, clock, sounds | high, alone |

Order: 1-13 and 14-25 can run in parallel (they only verify); 26 before 27, which needs the
Fighter/Opponent/EnergyBar fields settled.
