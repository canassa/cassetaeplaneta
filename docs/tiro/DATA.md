# TIRO.EXE: data map (phase 3)

DGROUP is Ghidra segment `1090` (0x255d bytes initialised, 0x64ca allocated). All addresses
below are `1090:` unless they say otherwise. Types live in the data type category `/tiro`.
TIRO is medium model, `/Od` (`QUALITY.md` §0): data pointers and `this` are near (2 bytes),
the vptr is a near pointer into DGROUP, and each vtable slot is a 4-byte far code pointer.
ENCAIXE (`docs/encaixe/DATA.md`) is the reference for the shared engine layouts.

## Counts

| What | Count |
|---|---|
| Strings defined (Latin-1, exact length) | 90, all named `s_camelCase` (the 17 cut at an accent and the 12 missing ones included) |
| Vtables / vbtables defined | 52 / 25, typed and named (77 tables) |
| Vtable structs / vbtable structs | 13 (far slots) / 2 (`Vbtable`, `Vbtable3d`) |
| Class and record structs | 30 (incl. the near `CrtFILE`) |
| Functions with a typed `this` | 163 |
| Globals typed (non-string, non-table) | 129; 104 named |
| NULL-test comments (`NearNullTests`) | 14 |
| Undefined bytes left in DGROUP | 0x47 (71), see the end |

After the typing, the decompilation of the whole program has no `DAT_1090_*` left (623
before), 5 `PTR_` (517 before, all `PTR_1090_2294`, an unnamed CRT hook) and 279 raw
`*(T *)(p + 0x..)` dereferences (506 before; nearly all of them are the SceneObject-relative
`this` of virtual overrides, below).

## DGROUP map

| Range | Contents |
|---|---|
| `0000–000f` | Windows instance header (`g_instReserved` … `g_instStackBot`) |
| `0010–00a5` | `s_coordFormat`, the HDC/layer overflow strings and their captions |
| `00a6` | `g_nextId`: the next SceneObject id (ENCAIXE `0010`) |
| `00a8` | `g_unk00A8` byte = 0x0b, read by the draw code (ENCAIXE `g_unk0012`) |
| `00aa` | `s_appName` "Tiro ao Alvaro" (class, title, NOITE's `FindWindow` target) |
| `00ba` | `g_noiteWnd` |
| `00bc–00ed` | `s_appIcon`, `s_alreadyRunning` (WinMain copies it into a local with `REP MOVSW`), `s_userModule` ×2 |
| `00ee–0101` | `g_started`, `g_handshakePending` (= 1), then game_handle_message's `g_keyLeft/Right/Up/Down`, `g_itemSelected`, `g_exitPending`, `g_selectedItem`, `g_dropElevation` (ENCAIXE `002a–003c`, same order) |
| `0102–0127` | `besta.bmp`, `bestse.bmp`; the crossbow strip tables (`0118`) |
| `0128–01e3` | the 10 target bitmaps; the target strip tables (`0194`) |
| `01e4–021d` | the 3 arrow bitmaps; the arrow strip tables (`0206`) |
| `021e–02b9` | `panel.bmp` ×2, `s_fontFace` "Mech", `s_fontFile` "arialbd.fot", the MCI strings, the 5 wave names |
| `02ba–02c5` | `g_keyRightHeld`, `g_keyLeftHeld`, 2 unreferenced words, `g_keySpaceHeld`, an unreferenced word = 1 |
| `02c6–035f` | MCI and WaveMix strings, `s_negScoreFormat` "-%04d", `s_scoreFormat` " %04d" |
| `0360–03e1` | the visible-objects overflow strings |
| `03e2–0439` | WaveMix: `g_waveMixOpenResult`, `g_waveMixSession`, `g_waves` (20 far), `g_waveCount` |
| `043a–04d9` | WaveMix error strings |
| `04da–060d` | CRT data (below) |
| `060e–0691` | `"\"` ×2, `s_fatalErrorCaption6`, `s_updateListFull` (`MAX_OBJECT_QTY`) |
| `0692–0e39` | vtables and vbtables (part 1) |
| `0e3a–0eed` | the "Faltou redefinir o método Create…" strings, `s_warningCaption` "CUIDADO !" |
| `0eee–0f09` | `g_gameVtbl` |
| `0f0a–1003` | occupancy overflow strings, `s_cannotOpenFile`, CreateScreen/CreateNewScene strings, `s_backgroundBmp` "Fundtiro.bmp" |
| `1004–228d` | vtables and vbtables (part 2) |
| `228e–22a3` | `g_crtInitHook` (far → `init_static_conditions_entry`), three far CRT hooks (`2294`, `2298`, `229c`, all 0), `g_crtExitTable` (far → `crt_endstdio`) |
| `22a4–23e3` | `g_crtIob` (`CrtFILE[20]`), `g_crtIob2` (160 bytes) |
| `23e4–255c` | `s_nmsgMarker` "<<NMSG>>", `g_crtNmsgTable`: id words and `s_nmsgR6xxx` strings, end `ffff` at `255a` |
| `255e–39ee` | **`g_occupancyCount`** `char[65][81]` |
| `39f0–6311` | **`g_occupancyObject`** `SceneObject*[65][81]` |
| `6312–6319` | `g_setSystemTimer`, `g_killSystemTimer` (USER.11 / USER.182) |
| `631a–632b` | `g_modulePath` (far → `632c`), `g_instance`, `g_mainWindow`, an unreferenced word, `g_appActive`, **`g_score`**, `g_windowWidth` (640), `g_windowHeight` (480) |
| `632c–6493` | `g_modulePathBuf[260]`, `g_messageText[100]` |
| `6494–64a3` | `g_game`, `g_tiroGame` (the same object, stored by the derived ctor), **`g_crossbow`**, **`g_targets[4]`**, **`g_arrows[1]`** |
| `64a4–64ab` | `g_conditionTrue`, `g_conditionFalse` (`FlagCondition`, built by `init_static_conditions`) |
| `64ac–64bf` | the 5 waves (far): `g_shotWave`, `g_girlHitWave`, `g_travecoHitWave`, `g_hitWave`, `g_pasars01Wave` |
| `64c0–64c9` | `g_moduleHandle`, `g_crtSprintfFile` |

The BSS starts at `255d`. The occupancy matrix is NOITE's/ENCAIXE's (65 rows × 81 columns,
byte counts then near object pointers, one pad byte at `39ef`); the two arrays end at `6311`,
right before the timer pointers. Unlike ENCAIXE, `g_score` is in the BSS, between the app
globals.

CRT data (`04da–060d`) has ENCAIXE's layout (`00d0–0237`) with the names of `docs/encaixe`,
moved by +0x40a/+0x40e/+0x412, except:
- `04ee` `g_crtStackOverflowHook` is a far pointer (`_aFchkstk` does `JMPF [0x4ee]`);
- `0564`/`0566` are two words written by `_setargv` that ENCAIXE lacks (unnamed);
- `05ca` `g_crtNearHeapHook` is a far pointer (`_nmalloc` calls it), where ENCAIXE has two
  near words;
- `05ce` `g_crtUnk05CE` is tested by `_write`, `_lseek`, `_commit`, `_flsbuf` and
  `_NMSG_WRITE`;
- `05d2–05ed` `g_crtFloatHooks` are 7 far pointers (to `_fptrap`), not 7 near words;
- there is no time-zone or `_days` data: `05f4` `g_crtDosErrnoMap` follows the hooks.

## The game data

**Pictures.** Three strip tables, each `char *files[n]`, `int frames[n]`, `int widths[n]`,
`int heights[n]`. The constructors take the four arrays and a strip count:

| Table | Files | Frames × size | Used by |
|---|---|---|---|
| `g_crossbowStrip*` (`0118`, 2) | `besta.bmp`, `bestse.bmp` | 3 × 285×127 | createPlayer `1048:0029` |
| `g_targetStrip*` (`0194`, 10) | `girla`, `girlb`, `girlc`, `travea` … `traveg` `.bmp` | 9 × 75×95 | the target creator `1068:0163` |
| `g_arrowStrip*` (`0206`, 3) | `Tiresq`, `Tirofr`, `Tirdir` `.bmp` | 2 / 4 / 2 × 55×27 | the arrow creator `1068:038a` |

A SceneObject's `curStrip` picks the picture and `curFrame` the frame in it:
- **Crossbow:** `curStrip` 0 is `besta` (loaded), 1 is `bestse` (unloaded). Firing sets it to
  1. `curFrame` is the aim: 0 left, 1 straight, 2 right (createPlayer sets 1).
- **Targets:** `curStrip` is the target's identity, `rand() % 10`, drawn on creation and on
  every respawn. **0–2 are the three girls, 3–9 the seven *travecos***, by the order of
  `g_targetStripFiles`. The identity is the only thing that separates them.
- **Arrow:** `curStrip` = the crossbow's aim at the shot (left, straight, right picture).

**Scoring** (`g_score`, an int in the BSS, so it starts at 0). The hit handler `1068:08ab`
tests the hit target's `curStrip < 3`:
- a girl gives **+150** (`1068:2e1c`, plays `g_girlHitWave` `uii.wav`);
- a traveco gives **−150** (`1068:2daf`, plays `g_travecoHitWave` `nossa.wav`);
- both also play `g_hitWave` (`tirojogo.wav`) and redraw the score (`1068:2ed4`: `" %04d"` or
  `"-%04d"`, then `1068:2e89` blits the box at (400,448)).

`g_shotWave` (`ARCFLE02.WAV`) is the shot (`1068:2d89`). APPWNDPROC plays `g_pasars01Wave`
(`PASARS01.WAV`) on WM_PAINT.

**Arrows.** The arrow counter is the crossbow's `Player2D.lives` (`Crossbow+0x40`), set to
**16** by createPlayer. On WM_KEYDOWN SPACE, when `g_keySpaceHeld` is clear, the handler
decrements it **before** it checks that the arrow is free (`g_arrows[0]->moving == 0`). A
press while the arrow is still flying therefore costs an arrow and fires nothing. There is
one arrow object (`g_arrows`, a 1-element array: the creator loops `i < 1`). It starts at
crossbow x+0x48/+0x75/+0xa2, y−0x1e/−0x1e/−0x14 for aim 0/1/2. Its flight
(`ProjectileVtbl.moveTick`, `1068:1739`) stops when x < 5 or x > 0x1d6.

**End and win.** In each target's WM_SYSTIMER tick the handler tests `lives == 1` and, if so,
sends itself WM_DESTROY. So the game ends at the first target tick after the 15th SPACE
press. The 16th arrow is never fired, and the 15th can be cut off in flight. WM_DESTROY
stops the waves, closes MCI and posts
`PostMessage(g_noiteWnd, 0x40a, g_score > 0, (long)g_score)`. **TIRO is won iff the final
score is positive.** There is no bonus and no other end condition. The mouse is ignored.

**Targets** (`g_targets[4]`, class Target, ctor `1088:603a`, 0x4be bytes each). `[0]` and
`[1]` run on the upper row (y=0x55). They enter from the left at x=0x18, direction 2 (right).
`[2]` and `[3]` run on the lower row (y=0x82). They enter from the right at
x = backdrop width − target width, direction 1 (left). The second target of a row only
starts when it is more than 0x58 px from the first. The ctor gets 0xc–0xf (likely the timer ids) and period
100. A hit:
1. stops the target;
2. plays its hit animation (`animation.framesLeft` 8, period 0x37);
3. counts the frames in `Target.hitFrame` (−1 when not hit);
4. once the count reaches `framesLeft`, respawns the target (`1068:0991`) with a new identity.

A target that walks off the screen respawns the same way.

**Aim.** WM_KEYDOWN LEFT (0x25) / RIGHT (0x27), latched by `g_keyLeftHeld` / `g_keyRightHeld`,
call `1068:0476` with 'E' (*esquerda*) / 'D' (*direita*). It **cycles** the crossbow's
`curFrame` with wrap-around (right: 0→1→2→0; left: 0→2→1→0) and then calls the crossbow's
SceneObject `play` slot. WM_KEYUP clears the latches. `g_keyLeft…g_keyDown` (`00f2–00f8`) are
the engine handler's own latches, not TIRO's.

## Vtables

`S` = SceneObjectVtbl (91 slots), `O` = Object3DVtbl (8), `M` = MoverVtbl (1), `A` =
AnimationVtbl (1), `vb` = vbtable. A class is **verified** when all of these agree:
- its ctor's vptr stores;
- the vbtable offsets;
- the `operator new` size;
- the slot override pattern against the ENCAIXE class (phase 2: Jaccard 1.0 over the 91/93
  SceneObject slots; the smaller tables slot by slot).

| Class | Tables | Ctor | Size | Status |
|---|---|---|---|---|
| Frame | `0692` FrameVtbl (`getCell`) | `frame_ctor` `1088:33f6` | 0x16 | verified |
| SceneObject | `0696` S | `1088:16a2`, `50ea`, `3b3c` | 0x46c | verified |
| Object3D | `0802` O, `0822` S, `098e` vb {−2, 0x16} | `1088:253a` | 0x16 + vbase | verified (out of line here; ENCAIXE inlines it) |
| Mover | `0992` M, `0996` S, `0b02` vb | `1088:30e4`, `31b8`, `5cf2` | 0x32 + vbase | verified |
| Portable | `0b06` M, `0b0a` S, `0c76` O, `0c96`/`0c9c` vb | `1018:1cea`, `1018:1dec` | 0x56 + vbase | verified, **live** (ENCAIXE's is dead) |
| Moveable | `0ca0` M, `0ca4` S, `0e10` O, `0e30`/`0e36` vb | `1088:26ea`, `27c4` | SO 0x34, O3D 0x4a2 | verified |
| Game | `0eee` GameVtbl (slot 6 `_purecall`) | `game_ctor` `1088:4ef6` | 0x2b4 | verified |
| TiroScene | `1004` SceneVtbl (slots 0 `1068:1790`, 5 `1088:503e`, 7 `1068:008d`) | `1088:5004` | 0x44 (`Scene`) | verified (role of TetrisScene) |
| TiroPanel | `1038` ControlPanelVtbl (slot 2 `1088:4e16`), `105c` S, `11c8` O, `11e8`/`11ee` vb | `1088:4d7e` | 0x566 (`ControlPanel`) | verified (role of TetrisPanel; no own fields) |
| TiroGame | `11f2` GameVtbl (slots 1–4, 6 in `1048`) | `1048:0000` | 0x2b4 (`Game`) | verified (role of TetrisGame) |
| Backdrop | `120e` BackdropVtbl (19) | `backdrop_ctor` `1088:5abe` | 0x44e | verified (8 bytes smaller, below) |
| Animation | `125a` A, `125e` S, `13ca` vb | `1088:5bea`, `5c3e` | 0xe + vbase | verified |
| Actor2D | `13ce` M, `13d2` A, `13d6` S, `1542`/`1546` vb | `actor2d_ctor_strips` `1088:587c` | 0x40 + vbase | verified |
| Player2D | `154a` M, `154e` A, `1552` S, `16be`/`16c2` vb | `player2d_ctor` `1088:51b0` | 0x46 + vbase | verified |
| **Crossbow** | `16c6` M, `16ca` A, `16ce` S, `183a`/`183e` vb {−2, 0x4a}/{−2, 0x18} | `1088:4f50` | 0x4b8 (`Crossbow` 0x4c + SO) | TIRO: derives Player2D; the player |
| Scene | `1842` SceneVtbl (slot 0 `_purecall`) | `scene_ctor` `1088:5390` | 0x44 | verified |
| GridBackdrop | `1876` GridBackdropVtbl (20) | `grid_backdrop_ctor` `1088:5698` | 0x450 | verified |
| StatusBar | `18c6` S | `status_bar_ctor` `1088:4e3e` | 0x53a | verified |
| ControlPanel | `1a32` ControlPanelVtbl (slots 7–8 `_purecall`), `1a56` S, `1bc2` O, `1be2`/`1be8` vb | `control_panel_ctor` `1088:5276` | 0xe4 + vbases (0x566) | verified (abstract) |
| TiroBackdrop | `1bec` GridBackdropVtbl (slot 0 `1068:0000`) | `1088:554e` (new 0x450 in `1088:503e`) | 0x450 (`GridBackdrop`) | verified (role of TetrisBackdrop) |
| Animated3D | `1c3c` A, `1c40` S, `1dac` O, `1dcc`/`1dd2` vb | `animated3d_ctor_strips_no_hitbox` `1088:5946` | SO 0x10 | verified (no struct, as in ENCAIXE) |
| FlagCondition | `1dd6` ConditionVtbl | `1088:5dd6` | 4 | verified |
| CompoundCondition | `1de2` ConditionVtbl | `1088:5e62` (factories `1050:0021`/`0062`) | 8 | verified |
| Condition | `1dee` ConditionVtbl (slot 0 `_purecall`) | `1088:5f18` | 2 | verified |
| **Target** | `1dfa` TargetVtbl (3), `1e06` A, `1e0a` S, `1f76`/`1f7a` vb {−2, 0x50}/{−2, 0x1e} | `1088:603a` | 0x4be (`Target` 0x52 + SO) | TIRO: derives Actor2D |
| **Projectile** | `1f7e` ProjectileVtbl (4), `1f8e` A, `1f92` S, `20fe`/`2102` vb {−2, 0x48}/{−2, 0x16} | `1088:6170` (only from `60d8`) | 0x48 + vbase | TIRO: derives Actor2D; never built alone |
| **Arrow** | `2106` ProjectileVtbl, `2116` A, `211a` S, `2286`/`228a` vb | `1088:60d8` | 0x4b6 (`Arrow` 0x4a + SO) | TIRO: derives Projectile; the same slots |

Labels:
- `g_<class>Vtbl` for the primary table;
- `g_<class>SceneObjectVtbl`, `g_<class>Object3dVtbl`, `g_<class>AnimationVtbl`;
- `g_<class>Vbtbl`, `g_<class>Object3dVbtbl`, `g_<class>AnimationVbtbl` for the vbtables.

The TIRO roles are `g_tiroSceneVtbl`, `g_tiroPanel*`, `g_tiroGameVtbl` and `g_tiroBackdropVtbl`.

Each slot is a 4-byte pointer to a `FunctionDefinition` (`<Vtbl>_<field>Fn`). The definition
is copied from the slot's target in the base table, or from the first table whose target is
not `_purecall`. The slot's reference is a DATA reference to the far `seg:off` target. Pure
virtual slots point to `_purecall` (`1080:02ae`); ENCAIXE stores 0 in them instead.

**The vtable structs.** Field names are ENCAIXE's:
- **SceneObjectVtbl** is ENCAIXE's 93 slots without `unk11` and `unk18`. TIRO slot *i* =
  ENCAIXE *i* for *i* < 0x11, *i*+1 for 0x11–0x16, *i*+2 from 0x17 on (`FUNCTIONS.md`).
- **Object3DVtbl** (8), **MoverVtbl** (`placeAt`), **AnimationVtbl** (`playOnce`) and
  **FrameVtbl** (`getCell`) are the same as ENCAIXE's.
- **ControlPanelVtbl** (9), **GameVtbl** (7), **SceneVtbl** (13), **BackdropVtbl** (19),
  **GridBackdropVtbl** (20) and **ConditionVtbl** (3) map 1:1.

The two TIRO extensions of MoverVtbl, named by behaviour (phase 4 to confirm):
- **TargetVtbl**:
  - `placeAt` (Mover's);
  - `moveTick` (`1068:0fcf`): calls the SceneObject `stopMoving` when y < 10, `moveTick`
    otherwise;
  - `checkEdge` (`1068:1037`): the edge test that wraps a target round and sets
    `Target.unk40`.
- **ProjectileVtbl**:
  - `placeAt`;
  - `moveTick` (`1068:1739`): stops outside 5 < x ≤ 0x1d6, else steps;
  - `stepMove` (`1068:1641`): steps, then `tryStep`, the redraw, and stops at the target;
  - `tryStep` (`1068:1448`): `actor2d_can_step`, then the overlap with `SceneObject.unk452`,
    which sets a direction 3 out-parameter.

## Classes (`/tiro`)

The layout convention is ENCAIXE's:
- Class structs hold the non-virtual part.
- A leaf class includes its 2-byte vtordisp word as a `vtordisp` field; a struct embedded as a
  base leaves it out.
- The SceneObject virtual base follows at the vbtable's offset.
- Methods that override a SceneObject virtual get `this` = the SceneObject subobject and
  reach their own fields at negative offsets, so they are not `this`-typed. In `1068` the
  class follows from the offset back to the vbptr: Crossbow −0x4a (`0586`, `05b0`), Target
  −0x50 (`0618`, `068e`, `07f4`, `0883`, `0e2f`, `1288`; `06df` is their helper),
  Projectile −0x48 (`139f`, `13f7`, `1511`).

| Struct | Size | Confidence |
|---|---|---|
| `SceneObject` | 0x46c | high: ENCAIXE's layout. Every offset that the `scene_object_*` functions use falls on an ENCAIXE field |
| `Frame`, `FrameCell` | 0x16, 8 | high (`frame_*` offsets 2–14 match); `FrameCell` unknown inside |
| `Object3D` | 0x16 | high |
| `Mover`, `Moveable` | 0x32 | medium/high, as ENCAIXE (the `mover_*` offsets match) |
| `Animation` | 0xe | high: `playOnce` +0xa, `running` +0xc. `animation_play` sets `this−4` = 1 and `this−6` = 0 on this = Animation+0x10, and `animation_is_running` returns `this−4`. ENCAIXE's struct has the same; its old `cls.args` spec swapped them |
| `Actor2D`, `Player2D` | 0x40, 0x46 | high (`Player2D.lives` is the arrow counter here; `score` is unused, the score is `g_score`) |
| `Portable` | 0x56 | high. `prevSceneName` is `char[20]` at +0x34: the ctor `strncpy`s 0x13 bytes and writes the NUL at +0x47 (ENCAIXE says `char[19]`) |
| `StatusBar` | 0x53a | high |
| `ControlPanel` | 0xe4 | high. Flattened here: `vtbl` is a `ControlPanelVtbl*` (9 slots) instead of the embedded `Animation` (whose 1-slot vtbl made the panel's virtual calls read `vtbl + 3`). The Animation fields keep their offsets |
| `Game` | 0x2b4 | high: new 0x2b4; ctor writes `globalObjects` (capacity 30), `updateList`, `drawList`, `unk2AE` = 2 |
| `Scene` | 0x44 | high (new 0x44) |
| `Backdrop` | **0x44e** | high: one WinG DC/bitmap. ENCAIXE's second DC/bitmap (`oldBitmap2`/`hdc2`/`bits2`, `c–13`) is gone. The ctor writes `background` +0xc, `bgWidth/Height` +0x10/+0x12, `originX/Y` +0x14/+0x16, `viewWidth/Height` +0x18/+0x1a, `sceneList` +0x44c; `backdrop_create` writes `hpalette` +8, `dibOrientation` +0x448, `hdc` +2, `bits` +4, `oldBitmap` +0xa and passes `bmiHeader` +0x20 to WinGCreateBitmap. `1c/1e` unknown (ENCAIXE `24/26`) |
| `GridBackdrop` | 0x450 | high: `grid` +0x44e (new 0x450 in `1088:503e`) |
| `PerspectiveBackdrop` | 0x46a | medium. The setters write `vanishX…view3dZ` at `450–45c` (ENCAIXE −8). It also holds the layers: `layers[5]` +0x45e and `layerCount` +0x468, which `1020:0118/016e/0229` use ("Estouro no número de Layers" past 5). There is no vtable or ctor: the class is never built |
| `OccupancyGrid`, `ObjectList`, `UpdateList`, `DrawList(Node)` | 0xc, 6, 0x3e, 0x25c (6) | high |
| `Condition`, `FlagCondition`, `CompoundCondition` | 2, 4, 8 | high |
| `CrtFILE` | 8 | as ENCAIXE |
| **`Crossbow`** | 0x4c | Player2D + `unk46` (= −1 from createPlayer) + `unk48` (no access found) + `vtordisp` +0x4a. The SceneObject is at +0x4c |
| **`Target`** | 0x52 | Flattened Actor2D, with `vtbl` a `TargetVtbl*` and the Mover fields, then `animation` +0x32. `unk40` is set to 1 by the ctor and to 0/1 by `checkEdge`. `hitFrame` +0x4e is −1, or the frame count of the hit animation. `vtordisp` is at +0x50; the SceneObject is at +0x52. `42–4d` show no access |
| **`Projectile`** | 0x48 | Flattened Actor2D with `vtbl` a `ProjectileVtbl*`, then `unk46` (= −1 from the arrow creator). `40–45` show no access |
| **`Arrow`** | 0x4a | Projectile + `vtordisp` +0x48; the SceneObject is at +0x4a |

`this` is typed on 163 functions:
- the 105 that ENCAIXE types, matched by name;
- the TIRO ctors and the 1048 game methods;
- the Target slots and `1068:08ab`/`0991` (`Target*`, then the target index);
- the Projectile slots;
- the PerspectiveBackdrop setters and layer functions;
- the out-of-line ctors that ENCAIXE inlines (Object3D, Mover, Moveable, Animation, Portable,
  ObjectList `50c0`, UpdateList `5256`).

The TIRO subclasses with no own fields are typed with their base struct: TiroGame → `Game`,
TiroScene → `Scene`, TiroPanel → `ControlPanel`, TiroBackdrop → `GridBackdrop`.

**NULL tests.** Fourteen `CMP SI,imm; JNZ; MOV AX,0x0` sites (the adjusted-`this` NULL test,
with `MOV` instead of ENCAIXE's `XOR` under `/Od`) carry a comment that says the constant is a
sub-object offset:
- 10 in `1018` (0x18 Object3D, 0x34 Moveable, 0x10 Animated3D, 0x36 Exit);
- `1028:011f`;
- `1058:026e` (0xe4);
- `1088:1eae`;
- `1088:2c92` (0x56 Portable).

## Decompiler residue (expected)

- **SceneObject fields reached through the virtual base.** For example,
  `*(int *)((int)&g_crossbow->player2d.actor2d.mover.stepY + vbptr->sceneObjectOffset)` is
  the crossbow's `curFrame`: the field at the same offset as vbase + 2. Virtual calls through
  the SceneObject vtable keep the `vbase(p)->vtbl + slot` shape, because the SceneObject
  subobject is not a typed field.
- **The arrow in the fire code.** In three places in `1068:1790` the decompiler folds
  `g_arrows[i]` into `g_travecoHitWave._2_2_` (`64b6` = `64a2` + 2×10). That happens after
  type propagation stops settling. The 12 bogus `64b6` references that Ghidra had made from
  those `[BX+0x64a2]` reads were deleted; the instructions themselves read `g_arrows[i]`.
- **`this->controlPanel->text + vbptr->sceneObjectOffset - 0x16`** is the panel's
  SceneObject. It is the same vbase arithmetic.

## Undefined bytes left in DGROUP (0x47)

- One-byte NUL pads after odd-length strings or tables: `0088`, `00a5`, `00a9`, `00b9`,
  `0117`, `0193`, `0205`, `0237`, `02b9`, `04d9`, `05c9`, `0e61`, `0ec3`, `0f17`, `0f7d`,
  `0fa3`, `0fcb`, `0ff5`, `1003`, `39ef`. Also `061f–0621` (3 bytes before the
  `MAX_OBJECT_QTY` string).
- `02c4–02c5`: an unreferenced word = 1 after `g_keySpaceHeld` (ENCAIXE's `0076`).
- Unreferenced CRT words that ENCAIXE also leaves undefined:
  - `04e6–04ed` (`0001 ffff 0000 0000`);
  - `0508–0511`, `0514–0517`, `0520` (02), `0526–0527` (0x14);
  - `055c–055e`, `0560–0563`;
  - `05ee–05f3` (`0000 0000 0001`, where ENCAIXE has its time-zone data);
  - `0608–0609`;
  - `2292–2293`.
- `255c–255d`: the tail after the NMSG end marker.
- `6322–6323`: an unreferenced app word between `g_mainWindow` and `g_appActive` (ENCAIXE
  `527e`).

## Unknown

- Typed but unnamed:
  - `02be`/`02c0` (two unreferenced key-latch-shaped words, perhaps up/down);
  - `0564`/`0566` (`_setargv`), `060a` (`_lseek`);
  - the six far float hooks after `g_crtFloatHooks`;
  - the CRT hooks `2294`/`2298`/`229c` (`_cinit` and `crt_restore_vectors` call `2294` when its
    segment is not 0, passing `2298`/`229c`);
  - the NMSG id words.
- `g_unk00A8` (= 0x0b), `g_crtUnk05CE`.
- `Crossbow.unk46`/`unk48`, `Target.unk40` (its meaning in `checkEdge`) and `42–4d`,
  `Projectile.40–46`, `Backdrop.1c/1e`, `FrameCell`, and the Mover fields that ENCAIXE also
  leaves open.
- Which of `moveTick`/`checkEdge` and `moveTick`/`stepMove`/`tryStep` is which in the
  original source. The slot names describe the bodies.

## Scripts (`ghidra/scripts/`)

| Script | Use here |
|---|---|
| `DefineStrings.java` | the 90 strings, `1090:off:len:name;…` |
| `FarVtables.java` (new) | far-slot vtable structs (`S|Name|fields|tbl/tbl`), plain structs (`P|`), apply and name (`A|off|Struct|label`), with one DATA reference per slot to its `seg:off`. Args: `/tiro 1090 <spec>` |
| `NearStructs.java` | the 30 class and record structs in `/tiro` |
| `NearThisTypes.java` | `this` on 163 functions |
| `NearGlobals.java` | the globals (`1090:off:name:type;…`) |
| `NearNullTests.java` (`/Od` `MOV r,0x0` form added) | per segment: `1018`, `1028`, `1058`, `1088` |
| `UndefinedRanges.java` | the undefined-byte list above (`1090:0000`) |
| `DumpListing.java` | instruction and data dumps for the offline access analysis |

Done inline or as scratch, not committed (in `zig-out/tiro/p3/`):
- the labels on the existing far pointers `05d2`, `228e` and `22a0`;
- the drop of the 12 bogus `64b6` references (`gs/TiroDropRefs.java`);
- the decompile-all dump (`gs/TiroDecAll.java`);
- the matchers: `strscan.py` (the Latin-1 string scan), `acc.py`/`imm.py`/`track.py` (direct,
  immediate and through-pointer accesses), `offs.py` (field offsets per class prefix), `gaps.py`
  (the vbtables between tables), `vtspec.py` (the vtable spec), and `thismap.py` (ENCAIXE's
  `this` list mapped by name).

The specs are in the same folder: `strings.arg`, `vt.args`, `cls.arg`, `this.arg` and `glob.arg`.
