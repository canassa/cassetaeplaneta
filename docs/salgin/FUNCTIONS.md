# SALGIN.EXE: function inventory

The Ghidra program `/SALGIN.EXE` after phase 2: every function boundary fixed, every function
classified, the twins named. Addresses are Ghidra `seg:off`. SALGIN is TIRO's medium-model `/Od`
build (`QUALITY.md` §0), so **TIRO (`docs/tiro/`) is the reference for every shared name**; its
own references were ENCAIXE and NOITE. The data is in `DATA.md`.

## Counts

**1,280 functions** in Ghidra: 94 externals, 94 import thunks, 451 adjustor thunks, and
**640 code functions** (one of them, `atoi`, a one-`JMP` thunk to `atol`).

| | Fns |
|---|---|
| Code functions (non-thunk) | 640 |
| named | **634** |
| `FUN_` | **6** (5 unknown twins of TIRO's own 5 unknowns, below) |
| with a plate | 639 |
| named from TIRO (plate "Name from TIRO …") | 567 |
| named by hand / by role (game, new CRT, Frame dtor) | 67 |
| Adjustor thunks (`<target>_thunk[_k]`) | 451, all after named targets |
| Import thunks | 94, all typed (`CopyTypesFromProgram /TIRO.EXE`) |
| CRT (`1080`) | 90 (+ `atoi`) |
| Dead (no caller, no slot) | see "Dead code" |

| Kind | Fns | Where |
|---|---|---|
| Import thunk | 94 | `10a8` |
| Adjustor thunk | 451 | `1088:005a–1b39` (335), `1088:4ade–547d` (116) |
| CRT | 91 | `1080` (TIRO's 81 + 10 of the `time()` family) |
| Blitter | 2 | `1000:0024`, `1000:0114` (32-bit, not typed) |
| DIB | 15 | `1008`, `1010` |
| App shell | 10 | `1038` |
| WaveMix | 11 | `1078` |
| Engine | 454 | `1018–1060`, `1070`, `1088` |
| SALGIN game | 57 | `1048` (6), `1068` (34), `1088` (17: the game classes' ctors and overrides, Frame's vector dtor, the 3 type-test defaults renamed) |

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
| `1040` | 2 | 2 | `1088` | 319 | 316 |

Conventions (non-thunk): 503 `__stdcall16far` (far pascal, parameters listed reversed), 111 far
cdecl (`__cdecl16far` 103, `__cdecl16far_dx_ax` 4, `__cdecl16far_dxax_ptr` 4), 24 CRT near
helpers, 2 register-argument CRT entries left unknown. Tags copied from TIRO: 9 `sig?`, 5
`review` (on the TIRO unknowns).

## Function discovery

The TIRO procedure (`docs/tiro/FUNCTIONS.md`), in this order:

1. **Vtable slots**: `FarVtSlots.java 1090 0722 242c`: 1,660 slots, 547 targets, **409 new
   functions** (among them `game_handle_message` `1040:0000`, 3,688 bytes, and `_purecall`),
   each slot typed as a 4-byte pointer, 69 vptr stores referenced.
2. **Adjustor thunks**: `NearAdjustorThunks.java 1088 005a 1b80 far` and `1088 4ade 5482 far`:
   451 (75 fixed, 376 vtordisp). Run from a local copy with a null guard
   (`zig-out/salgin/gs/SalginAdjThunks.java`): one function made from TIRO's map at `1088:0235`
   was the second half of the vtordisp thunk `1088:022c` and crashed the shared script. It was
   deleted and `022c` given its full body.
3. **Gap sweep**: `CodeGapSweep.java` per code segment: 13 (APPABOUT `1038:0000`, `1020:0000`,
   4 in `1080`, 7 in `1088`).
4. **CRT by hand** (`gs/SalginCrtFix.java`, TIRO's `TiroCrtFix` at the mapped addresses):
   FATALEXIT no-return, `_amsg_exit`/`_flsbuf` split at `08bc`, the `INC BP` entries `_nrealloc`
   `0f1c` and `_nmsize` `0f8a`, the `_output` jump table `1080:09ae` (COMPUTED_JUMP references),
   7 frameless entries. `_output`'s epilogue `0e9a` had become a function through a `JMP`
   flagged `CALL_RETURN`; the override is cleared and the epilogue is back in `_output` (1,057
   bytes, as TIRO's).
5. **Dead jumps** (`DeadJumps.java`, all code segments): 52 added to their functions.

What stays uncovered: the `1080:0000–0011` segment prefix, the `_output` jump table, one-byte
`00`/`90` fillers, and **`1030:06ad–08ec`**, the unreachable body of `backdrop_autoscroll`
(it returns 0 right after its prologue; `QUALITY.md` §3).

## Names and how they were applied

| Method | Names |
|---|---|
| Imports: `CopyTypesFromProgram.java /TIRO.EXE` (94 signatures, 4 WinG ordinals renamed) | 94 |
| **Byte alignment against TIRO** (`bmap.py`): every TIRO entry mapped through the difflib matching block it falls in, onto a SALGIN function at that address; not used in `1068`; TIRO game names (`crossbow`, `target`, `projectile`, `arrow`, `tiro`) held back; thunks left to the thunk script. Applied with **`SalginCopyFromTwin.java`**: name, prototype (TIRO types mapped into `/salgin`), flags, tags, and the plate "Name from TIRO <name> at <addr> (byte alignment[; sizes])" followed by TIRO's plate | 566 |
| **Vtable slot** check (`vtpair.py`): the 55 SALGIN tables paired with TIRO's tables of the same class, slot by slot. 171 functions agree with the alignment; 2 disagree (the alignment had slid by one stub in the Backdrop default run `1088:5cd6–5dd0`) and were renamed by slot; 2 more stubs named by slot; `grid_backdrop_ctor` moved to `1088:5dec` by its vptr store | 5 |
| By role from TIRO (the subclass's ctor/slots ↔ TIRO's subclass): the 6 `1048` functions, panel/backdrop ctors, createScreen, the scene create/handleMessage, backdrop create (TIRO's prototype, then renamed `salgin_*`) | 13 |
| CRT by body: `time`, `__loctotime_t`, `__tzset`, `_tzset`, `_isindst`, `getenv`, `_aFlrem`, `strncmp`, `atol`, `atoi` | 10 |
| By hand: the game (`1068`, the game classes in `1088`), `frame_vector_deleting_dtor` | 47 |
| Adjustor thunks after their targets (rerun of the thunk script) | 451 |

**Plates copied from TIRO quote TIRO's addresses** (DGROUP offsets such as `0x22a0`, sibling
functions); the first line names the TIRO function they came from. SALGIN's own addresses are in
`DATA.md`.

Code that differs from TIRO inside named functions (the name is still right):
- `backdrop_blit_to_dc` (`1088:4244`) selects and realizes the backdrop palette before the
  `WinGBitBlt`;
- `backdrop_autoscroll` (`1030:0691`) is disabled (returns 0);
- `animation_tick` (`1028:17b3`, 165 vs 193 bytes), `mover_move_tick`,
  `scene_object_redraw_overlapping`, `animation_stop_and_redraw_dc` (6 bytes shorter);
- `APPWNDPROC` (560 vs 578), `wave_play` (182 vs 173), `salgin_game_on_create` (155 vs 70).

## The game classes

| Class | Derives | Ctor | Tables (`1090:`) | Object | Global |
|---|---|---|---|---|---|
| SalginGame | Game | `salgin_game_ctor` `1048:0000` | `1358` GameVtbl | 0x2b4 | `661a` |
| SalginScene | Scene (+ round clock `+0x44`) | `salgin_scene_ctor` `1088:5754` | `16b0` SceneVtbl (0 handleMessage `1068:0d73`, 5 createScreen `1088:5794`, 7 create `1068:29e2`) | 0x46 | — |
| SalginPanel | ControlPanel | `salgin_panel_ctor` `1088:5482` | `119e`, `11c2` S, `132e` O | 0x566 | — |
| SalginBackdrop | GridBackdrop | `salgin_backdrop_ctor` `1088:5ca2` | `1d8e` (0 `salgin_backdrop_create`) | 0x450 | — |
| **Fighter** (the player) | Player2D | `fighter_ctor` `1088:5654` | `1860` FighterVtbl (placeAt, `fighter_set_period`, `fighter_walk`), `186c` A, `1870` S | 0x4c2 | `661c` |
| **Opponent** | Actor2D | `opponent_ctor` `1088:678e` | `1f9c` OpponentVtbl (placeAt, `opponent_walk`), `1fa4` A, `1fa8` S | 0x4b8 | `661e` |
| **Banner** (PORRADA) | Actor2D, no overrides | `banner_ctor` `1088:682c` | `211c`, `2120`, `2124` (= Actor2D's) | 0x4ae | `6620` |
| **EnergyBar** | Actor2D, no overrides | `energy_bar_ctor` `1088:68c4` | `2298`, `229c`, `22a0` | 0x4b6 | `6622` |

SceneObject overrides (through the thunks of block `4ade–547d`):
- Fighter: canStep `1068:0470`, tick `0546`, moveTick `05ac`, stopMovingDc `07a0`, stopMoving
  `07f8`, redrawOverlapping `051e`, invalidate (empty) `1088:573a`, slot 0x56 `fighter_is_fighter`.
- Opponent: canStep `085e`, tick `08dc`, moveTick `0942`, stopMovingDc `0afd`, stopMoving `0b47`,
  redrawOverlapping `0836`, invalidate (empty) `1088:57fa`, slot 0x57 `opponent_is_opponent`.

The SceneObjectVtbl type-test slots: 0x56 (TIRO `isProjectile`) and 0x57 (TIRO/ENCAIXE
`slot62`) are SALGIN's `isFighter`/`isOpponent`; 0x58 and 0x59 (TIRO `isTarget`/`isCrossbow`)
answer 0 for every SALGIN class. Their defaults are renamed `scene_object_is_fighter_default`,
`scene_object_slot58_default`, `scene_object_slot59_default`.

## Dead code

- `frame_vector_deleting_dtor` (`1088:0000`): no caller, not in FrameVtbl.
- `backdrop_autoscroll`'s body after `return 0`.
- Whatever TIRO lists as dead and SALGIN shares (the second draw list, the PerspectiveBackdrop
  functions, the Portable ctors, `status_bar_draw_text`, …): their plates say so.
- The 6 `FUN_`: `1028:0e71` (empty member, `RETF 0xa`), `1028:1c89` (huge-pointer arithmetic,
  no caller), `1088:3dcc`/`3de6` (empty `(this, backdrop)` methods), `1088:3e48` (empty
  `(this)` method); the same 5 TIRO leaves unnamed (tag `review`); and none else.

## Phase 4: function groups

One `ghidra-investigate` agent per group. "Verify" groups were named, typed and plated from
TIRO: their agents check the copy against SALGIN's own addresses, rewrite the plates in SALGIN
terms where they cite TIRO addresses, and fix the `sig?` ones. "Game" groups need real reading.

| # | Range | Fns | Content | Kind / effort |
|---|---|---|---|---|
| 1 | `1080:0000–0873` | 31 | CRT startup, strings, `rand`, long math, `_cinit`, exit, `_setargv`, `_setenvp` | verify, low |
| 2 | `1080:0874–0f9d` | 15 | `_amsg_exit`, `_flsbuf`, `_output` and its helpers, heap | verify, low |
| 3 | `1080:0f9e–1d72` | 44 | **the `time()` family (new: `time`, `__loctotime_t`, `_tzset`, `_isindst`, `getenv`, `strncmp`, `atol`, `_aFlrem`)**, `_NMSG_*`, I/O, dosret, flush, commit, close, `_itoa` | verify + new, low |
| 4 | `1000`, `1008`, `1010` | 17 | Blitters, DIB copy/load/palette/remap (`1010` identical to TIRO) | verify, low |
| 5 | `1018:0000–0f2a` | 31 | Object3D/Moveable/Portable attach, project, draw bounds, getters, overlap | verify, low |
| 6 | `1018:0f2b–21c8` | 20 | Object3D below/support/front, Player/Exit, Portable pick up/drop/icon | verify, low |
| 7 | `1020`, `1030`, `1050` | 20 | Perspective backdrop, occupancy grid, Backdrop/WinG (**`backdrop_autoscroll` disabled**), Conditions | verify, low |
| 8 | `1028:0000–0d30` | 21 | SceneObject/Mover blit, restore, draw, attach, overlap | verify, low |
| 9 | `1028:0d31–1d24` | 28 | Mover step/move, Animation (`animation_tick` differs), Player2D, object list | verify, medium |
| 10 | `1038`, `1040:0e6b`, `1048` | 17 | App shell (APPWNDPROC differs), `game_take_exit`, the SalginGame subclass | verify + game, medium |
| 11 | `1040:0000` | 1 (3.7 KB) | `game_handle_message` | verify, high, alone |
| 12 | `1058`, `1060` | 19 | StatusBar, ControlPanel, Scene | verify, low |
| 13 | `1070`, `1078` | 22 | Draw lists, WaveMix (`wave_play` differs) | verify, low |
| 14 | `1088:0000–1fff` | 28 | Frame (+ the vector dtor), SceneObjectVtbl defaults | verify, low |
| 15 | `1088:2000–23ff` | 37 | SceneObjectVtbl defaults (trivial stubs) | verify, low |
| 16 | `1088:2400–27ff` | 24 | type-test defaults (renamed), Animation/Mover getters | verify, low |
| 17 | `1088:2800–2bff` | 21 | Mover/Actor2D overrides | verify, low |
| 18 | `1088:2c00–2fff` | 20 | Player2D, SceneObject getters, Moveable ctors | verify, low |
| 19 | `1088:3000–33ff` | 23 | Moveable, Player/Exit methods | verify, low |
| 20 | `1088:3400–37ff` | 31 | Portable, Animated3D, Animation methods | verify, low |
| 21 | `1088:3800–3fff` | 17 | Mover ctors, dead Mover draw helpers | verify, low |
| 22 | `1088:4000–4add` | 34 | Game defaults, `game_init`, update list, `backdrop_blit_to_dc` (differs) | verify, medium |
| 23 | `1088:5801–5fff` | 39 | Engine ctors (Game, Player2D, ControlPanel, Scene, GridBackdrop, Actor2D), Backdrop defaults | verify, low |
| 24 | `1088:6000–697f` (without the 3 game ctors) | 26 | Animated3D/Animation/Mover ctors, Conditions, Backdrop dtor, draw-list node | verify, low |
| 25 | `1088:5482–5800`, `678e`, `682c`, `68c4` | 19 | **The game classes**: SalginPanel/SalginScene/SalginBackdrop ctors, Fighter/Opponent/Banner/EnergyBar ctors, the Fighter/Opponent slot overrides; their struct typing (`DATA.md`) | game, medium |
| 26 | `1068:0000–0d72` | 21 | **Fighter and Opponent behaviour**: creators, energy bar, canStep/tick/moveTick/stop/walk, `opponent_choose_attack`, `salgin_redraw_arena` | game, medium |
| 27 | `1068:0d73` | 1 (7.2 KB) | **`salgin_scene_handle_message`**: keys, clocks, hits and damage, reactions, round end, 0x40a | game, high, alone |
| 28 | `1068:29e2–2d7a` | 12 | Scene create (MCI, waves), the clock draw/blit, the wave helpers | game, low |

Order: 1–4 and 10 first (CRT, DIB, app), then the verify groups, then 25 → 26 → 28 → 27. The
`1088` groups gain from phase 3's vtable typing and `FarSlotSignatures.java` (phase 3,
`DATA.md`).
