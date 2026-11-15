# INFERNO.EXE: data map

DGROUP is Ghidra segment `1090` (0x9c9 bytes initialised, 0x72c0 allocated); `1088` is a
12-byte far BSS segment; the vtables and the engine's strings are in the code segment `1080`.
Addresses are `seg:off`. Types live in the data type category `/inferno`. INFERNO is large model,
`/Od` (`QUALITY.md` §0): data pointers, `this`, the vptr and the vbptr are all **far** (4 bytes),
and each vtable slot is a 4-byte far code pointer. TIRO (`docs/tiro/DATA.md`) is the reference for
the names; its layouts do **not** transfer (near pointers), so every layout here was measured on
INFERNO's own code.

## 1. Counts

| What | Count |
|---|---|
| Strings defined (Latin-1, exact length, `s_camelCase`) | 83: 70 in DGROUP, 13 in `1080` |
| Vtables / vbtables defined, typed and labelled | 42 / 19 (`g_<class>[<Base>]Vtbl`, `g_<class>[<Base>]Vbtbl`) |
| Vtable structs (far slots, `<Vtbl>_<field>Fn` definitions) / vbtable structs | 12 / 2 (`Vbtable`, `Vbtable3d`) |
| Class and record structs | 20 |
| Globals typed and named (non-string, non-table) | 89, among them the 24 strip tables and the occupancy matrix |

Scripts (`ghidra/scripts/`): `DefineStrings.java` (strings), `FarVtables.java /inferno 1080 …`
(vtable structs, apply, labels; it takes the table segment, so the code-segment tables needed no
change), `NearStructs.java /inferno …` (classes; `T*32` gives the far pointers),
`NearGlobals.java /inferno …` (globals, including `1088`). The specs are in
`zig-out/inferno/p3/` (`strings.arg`, `vt.arg`, `cls.arg`, `glob.arg`, not committed), with the
access-offset matcher `offs.py` and the listing dump (`DumpListing.java`).

## 2. DGROUP map

| Range | Contents |
|---|---|
| `0000–000f` | Windows instance header |
| `0010–0083` | `s_coordFormat`, `s_erroFatal`, `s_hdcOverflow`, `s_erroFatal2`, `s_layerOverflow` |
| `0080` | `g_nextId` (next SceneObject id) |
| `0082` | `g_unk0082` byte = 0x0b, read by every draw function (TIRO's `g_unk00A8`) |
| `0084` | `s_appName` "Inferno": window class, title and NOITE's `FindWindow` target |
| `008c` | `g_noiteWnd`: set from 0x40b's lParam by APPWNDPROC; the 0x40a/0x40c target |
| `008e–00c1` | `s_appIcon`, `s_alreadyRunning`, `s_userModule` ×2 |
| `00c0` | `g_started`: set by WM_CREATE; while set, APPWNDPROC posts 0x40c (§7) |
| `00c2–00d3` | `game_handle_message`'s state (TIRO's names): the arrow latches `g_keyLeft`, `g_keyRight`, `g_keyUp`, `g_keyDown`; `g_itemSelected`, `g_exitPending`, `g_selectedItem` (far, `00ce`), `g_dropElevation` (`00d2`) |
| `00d4–014f` | the 12 hero bitmap names |
| `015a–01d1` | `g_heroStrip{Files,Frames,Widths,Heights}[12]` |
| `01d2–028d` | `Plataf`, `rocha01–03`, `cerva`, `chopp`, `copo`, `3spres`, `cruz` names and the strip tables `g_platformStrip*[1]` (`01de`), `g_rockStrip*[3]` (`020c`), `g_drinkStrip*[4]` (`0252`), `g_crossStrip*[1]` (`0284`) |
| `028e–02c9` | `carvao`, `diabo`, `fogo` names, `g_hazardStrip*[3]` (`02ac`) |
| `02ca` | `s_gameName` "Mario" (passed to `game_init`) |
| `02d0–02e1` | game state: `g_heroTimerPending` (= 1 until the first walk starts the hero's move timer), `g_rockIndex` (= 3, cycles 0–5), `g_hazardIndex` (= 1, cycles 0–5), `g_floorY` (= 308), `g_scrolling` (the world scrolls this tick), `g_stompScored` (the stomp latch), **`g_lives` (= 5)**, `g_startTick` (`GetTickCount` at scene create; the grace start after the time-out) |
| `02e6–035f` | MCI strings (`mario.mid`, alias `musica`), the 5 wave names |
| `0364–0377` | the handler's key latches `g_keyRightHeld`, `g_keyLeftHeld`, `g_keyDownHeld`, `g_keyUpHeld`; `g_timeUp`, `g_lastReportTick` (the grace-second reposts) |
| `0378–0411` | MCI and WaveMix strings, `s_negScoreFormat` "-%04d", `s_scoreFormat` " %04d" |
| `0412–0469` | WaveMix: `g_unk0412`, `g_unk0414`, `g_waveMixSession`, `g_waves[20]` (far), `g_waveCount` |
| `046a–0509` | WaveMix error strings |
| `050a–09c9` | CRT data (`_C_FILE_INFO`, `R6xxx` messages; not mapped further) |
| `09ca–1e5a` | **`g_occupancyCount`** `char[65][81]` (BSS from here) |
| `1e5c–709f` | **`g_occupancyObject`** `SceneObject far *[65][81]` (4-byte entries, twice TIRO's matrix) |
| `70a0–70b9` | `g_setSystemTimer`, `g_killSystemTimer` (far, USER.11/182), `g_instance`, `g_mainWindow`, `g_appActive`, **`g_score`** (`70b0`), `g_windowWidth` (640), `g_windowHeight` (480), `g_modulePath` (far → `70ba`) |
| `70ba–7221` | `g_modulePathBuf[260]`, `g_messageText[100]` |
| `7222–72b3` | the objects: `g_game`, `g_infernoGame`, **`g_hero`**, `g_rocks[6]`, `g_platforms[4]`, `7256–7269` (unreferenced), `g_cross`, `g_hazards[6]`, `g_rockOrder[6]` (`7286`), `g_hazardOrder[6]`, the wave handles `g_deathWave` (sonicmor), `g_pickupWave` (sonicpul), `g_magWave` (sonicmag), `g_pickupWave2` (sonicpul, opened twice), `g_moduleHandle` |
| `72b4–72bf` | the CRT `sprintf` FILE |
| `1088:0000`, `0006` | `g_conditionTrue`, `g_conditionFalse` (`FlagCondition`, built by `init_static_conditions`) |

The CRT data is the large-model library's (`LLIBCEW`), as NOITE's; it was not mapped beyond the
strings.

## 3. Vtables (`1080`)

`S` = SceneObjectVtbl (91 slots), `O` = Object3DVtbl (7), `M` = MoverVtbl (1), `A` =
AnimationVtbl (1). The class of each table was found from its override pattern against TIRO's
(`FUNCTIONS.md`); sizes from `operator new` and from the vbtables.

| Class | Tables | vbtables {vbptr, SceneObject[, Object3D]} | Ctor | Size (class + SceneObject 0x480) |
|---|---|---|---|---|
| Frame | `4926` FrameVtbl | — | `frame_ctor` `45ee` | 0x12 |
| SceneObject | `492a` S | — | `scene_object_ctor` `2316`, dtor `5820` | 0x480 |
| Object3D | `4a96` O, `4ab2` S | `4c1e` {−4, 0x1a} | `object3d_ctor` `33c8` | 0x1e + SO |
| Mover | `4c22` M, `4c26` S | `4d92` {−4, 0x34} | `mover_ctor` `7b7a`, `mover_ctor_alloc_strips` `4300` | 0x38 + SO |
| Moveable | `4790` M, `4794` S, `4900` O | `491c` {−4, 0x34, 0x4b6}, `4922` {−4, −0x486} | `moveable_ctor_alloc_strips` `35e6` | |
| Portable | `4d96` M, `4d9a` S, `4f06` O | `4f22` {−4, 0x5a, 0x4dc}, `4f28` {−4, −0x486} | `portable_ctor` `1018:241f` (no caller) | |
| Game | `65fa` GameVtbl (slot 6 `_purecall`) | — | `game_ctor` `7060` | 0xac (`app_init` news 0xac for the subclass) |
| Scene | `6616` SceneVtbl (slot 0 `_purecall`) | — | `scene_ctor` `74ce` | 0x50 |
| Backdrop | `664a` BackdropVtbl (20) | — | `backdrop_ctor` `7a1c` | 0x452 |
| GridBackdrop | `83dc` GridBackdropVtbl (21) | — | `grid_backdrop_ctor` `759e` | 0x456 |
| **InfernoGame** | `7d50` GameVtbl (slots 1, 2, 6 in `1048`) | — | `inferno_game_ctor` `1048:0000` | 0xac (`Game`) |
| **InfernoBackdrop** | `7d6c` GridBackdropVtbl (slot 0 `inferno_backdrop_create`) | — | `inferno_backdrop_ctor` `7556` | 0x456 (`GridBackdrop`) |
| **InfernoScene** | `7f3c` SceneVtbl (slots 0, 5, 7) | — | `inferno_scene_ctor` `72ce` | 0x50 (`Scene`) |
| Animation | `7f70` A, `7f74` S | `80e0` {−4, 0x10} | `animation_ctor` `7aec` | 0x14 + SO |
| Actor2D | `80e4` M, `80e8` A, `80ec` S | `8258` {−4, 0x46}, `825c` {−4, 0x10} | `actor2d_ctor_strips` `77da` | 0x4a + SO |
| Player2D | `8260` M, `8264` A, `8268` S | `83d4` {−4, 0x4c}, `83d8` {−4, 0x16} | `player2d_ctor` `739a` | 0x50 + SO |
| **Hero** | `7dc0` M, `7dc4` A, `7dc8` S | `7f34` {−4, 0x5e}, `7f38` {−4, 0x28} | `hero_ctor` `70fa` | 0x62 + SO = **0x4e2** ✓ `new 0x4e2` |
| **Platform** | `89c2` PlatformVtbl (2), `89ca` A, `89ce` S | `8b3a` {−4, 0x4e}, `8b3e` {−4, 0x18} | `platform_ctor` `86c0` | 0x52 + SO = **0x4d2** ✓ |
| **Prop** | `8b42` PropVtbl (4), `8b52` A, `8b56` S | `8cc2`, `8cc6` (as Platform) | `prop_ctor` `87c0` | 0x4d2 ✓ |
| **Hazard** | `8cca` PropVtbl, `8cda` A, `8cde` S | `8e4a`, `8e4e` (as Platform) | `hazard_ctor` `88ca` (calls `prop_ctor`) | 0x4d2 ✓ |
| Flag/Compound/Condition | `8660`, `8648`, `8654` ConditionVtbl | — | `8430`, `84d2`, `85ea` | 6, 0xe, 4 |

The bold classes are INFERNO's. Their names are provisional, from what they draw
(§5): Hero is the player, Platform the moving platforms, Prop the drinks, rocks and cross, Hazard
the coal, devil and fire. The vptr stores are `MOV ES:[BX+k],off; MOV ES:[BX+k+2],0x1080`; each
has a DATA reference to its table.

**Vtable structs.** Field names are TIRO's (`docs/tiro/DATA.md`), with INFERNO's changes:
- **SceneObjectVtbl** (91) = TIRO's, with slot 0x4c (+0x130) named `getSceneName` (Portable
  returns its scene's name, the default ""). Slots 0x56–0x5a, TIRO's game type tests, are
  INFERNO's own: `isBig` (Hero: `altStrips`; nothing calls it), `isPlatform`, `isProp`, `isHazard`
  (return 1; the base returns 0), `isPowerUp` (Prop: `powerUp`, 1 for the cross).
- **Object3DVtbl** (7): TIRO's without `isInFrontOf`.
- **BackdropVtbl** (20): TIRO's without `queryRectFirst`, plus `isGridBackdrop` (18) and
  `asGridBackdrop` (19). **GridBackdropVtbl** (21) adds `createWithGrid` (20).
- **GameVtbl** (7), **SceneVtbl** (13), **ConditionVtbl** (3), **MoverVtbl**, **AnimationVtbl**,
  **FrameVtbl**: TIRO's.
- **PlatformVtbl** (2): `placeAt` (Mover's), `moveTick` (`1068:240d`).
- **PropVtbl** (4): `placeAt`, `moveTick` (Prop `1068:381d`, Hazard `1068:46f7`), `stepMove`
  (`392b`), `tryStep` (`398d`): TIRO's ProjectileVtbl shape.

Each slot is a 4-byte pointer to a `FunctionDefinition` with the current prototype of the slot's
first non-`_purecall` target and `this` a far pointer to the vtable's class
(`FarSlotSignatures.java 1080 defs large`). The decompiler reads a far slot as two words and would
take the pushed CS for an extra argument; the 376 call-site overrides (`calls large`, `site large`;
`FUNCTIONS.md`) give every live virtual call its slot's signature.

## 4. Classes (`/inferno`)

The layout convention is TIRO's: a class struct holds the non-virtual part; a leaf class ends
with its `vtordisp` word; the SceneObject virtual base follows at the vbtable's offset (vbptr at
+4, so SceneObject = this + 4 + `sceneObjectOffset`). Methods that override a SceneObject slot get
`this` = the SceneObject subobject and reach their own fields at negative offsets.

| Struct | Size | How it was measured / confidence |
|---|---|---|
| `SceneObject` | 0x480 | high for `vtbl`, `next`, `prev`, `ownerList` (far), `x`/`y`/`id`, `frames` (far, +0x1c), `stripCount`/`curStrip`/`curFrame` (+0x20–24), `bmiHeader` +0x26, `bmiColors` +0x4e, `hpalette` +0x44e, the two rects +0x470/+0x478 (`scene_object_reset_rects`). `450–46f` (TIRO's `dibFormatOk` … `nextY`, shifted and with 8 more bytes) left undefined. Size from every subclass's `new` minus its class part |
| `Frame` | 0x12 | high: `frame_init` and the vector deleting dtor's element size. No hitbox fields (TIRO has 4) |
| `ObjectList`, `UpdateList` | 4, 0x7a | high: `ObjectList` is the far `head` only (`object_list_ctor(this, head)`; NOITE's is 8 bytes); `Game.globalObjects` +0x1c, `updateList` +0x20, `UpdateList.count` at +0x78 |
| `OccupancyGrid` | 0x10 | high: `new 0x10` in `grid_backdrop_create_with_grid`; shifts are bytes at +0xc/+0xe |
| `Game` | 0xac | high: `vtbl`, `scene`, `oldScene`, `statusBar`, `controlPanel` (far, 0–0x13), `player` +0x18, `globalObjects` +0x1c, `updateList` +0x20, `unk9A` (= 2 by `game_ctor`, never read: TIRO `unk2AE`, NOITE `unk674`), `clearWidth` +0x9c, `clearHeight` +0x9e (never written; passed to the scene ctor); **no draw list** (TIRO's 0x25c `DrawList` is gone with its module). `14–17` and `a0–ab` not seen |
| `Scene` | 0x50 | high: `vtbl`, `backdrop`, `exits[10]` (far), `exitCount` +0x30, `name[20]` +0x32, `objects` +0x46, `hasPlayer` +0x4a, `hasStatusBar` +0x4c, `hasControlPanel` +0x4e (the `scene_get_has_*` getters; INFERNO's scene ctor passes 1, 0, 0) |
| `Backdrop`, `GridBackdrop` | 0x452, 0x456 | high: TIRO's fields with far `bits`/`background`/`sceneList`; `grid` at +0x452 |
| `Mover`, `Animation`, `Actor2D`, `Player2D` | 0x36, 0x12, 0x48, 0x4e | high: TIRO's fields shifted by the far vtbl/vbptr; each size checked against the vbtables |
| `Condition`, `FlagCondition`, `CompoundCondition` | 4, 6, 0xe | high (`1088` holds two 6-byte FlagConditions) |
| **`Hero`** | 0x62 | `Player2D` + `unk4E`, `powerTimer` +0x50 (the big hero's countdown, 180 move ticks), `jumpTicks` +0x52 (rise ticks left: 18 or 12), `jumpKind` +0x54 (0 UP standing, 1 UP walking, 2 DOWN standing, 3 DOWN walking), `facing` +0x56 (1 left, 2 right), `jumpPhase` +0x58 (4 rising, 8 falling), `busy` +0x5a (in a jump: arrows ignored), `walking` +0x5c, `altStrips` +0x5e (the big `marg*` strips 4–7 instead of `marp*` 0–3); `vtordisp` +0x60 |
| **`Platform`** | 0x52 | `Actor2D` + `slot` +0x48 (the next respawn slot 0–3), `presentReady` +0x4a (it carries the present and a small hero's hit opens it), `item` +0x4c (far pointer to its drink), `vtordisp` +0x50 |
| **`Prop`** | 0x52 | `Actor2D` + `index` +0x48 (for the cross: the ticks before it drops), `state` +0x4a (the cross: 2 launched right, 8 falling, 1 sliding left), `active` +0x4c (on screen), `powerUp` +0x4e (1 for the cross), `vtordisp` +0x50 |
| **`Hazard`** | 0x52 | `Actor2D` + `index` +0x48, `unk4A`, `active` +0x4c, `unk4E`, `vtordisp` +0x50 |

`this` is typed on every method: the class part (`Hero *`, …) or the SceneObject subobject
(`HeroSO`, `PlatformSO`, `PropSO`, `HazardSO`: SceneObject typedefs for the slot overrides).

## 5. Assets

All files are read from the current directory (`assets/INFERNO/`). Frames are stacked
vertically; the strip tables give frames, width and height per strip.

| Object | Files (strip: frames × w×h) | Count |
|---|---|---|
| Background | `Fundo.bmp` 640×480 (`s_backgroundBmp`, the engine's scene background) | 1 |
| Hero (`g_hero`) | `marppa` 2×38×65, `marpa` 8×, `marppal` 2×, `marpal` 8×, `margpa` 2×, `marga` 8×, `margpal` 2×, `margal` 8×, `3smort` 8×, `3smortl` 8×, `3svito` 4×, `3svitol` 4× | 1 |
| Platforms (`g_platforms`) | `Plataf` 1×84×12 | 4 |
| Drinks (Props on the platforms) | `cerva` 2×11×24, `chopp` 2×17×14, `copo` 2×16×15, `3spres` 3×82×56 | 4 |
| Rocks (`g_rocks`) | `rocha02` 94×99, `rocha01` 171×35, `rocha03` 73×86 (1 frame each) | 6 |
| Cross (`g_cross`) | `cruz` 1×24×40 | 1 |
| Hazards (`g_hazards`) | `carvao` 2×26×26, `diabo` 2×71×46, `fogo` 2×29×37 | 6 |
| Music | `mario.mid` (MCI sequencer, alias `musica`, replayed on MM_MCINOTIFY 0x3b9) | |
| Waves | `sonicmor` (life lost), `sonicpul` ×2 (+150 and +100), `sonicmag` (+300), `sonicf.WAV` (155 KB, looped from the start) | |

Hero strips: `p` = small, `g` = the alternative set (`Hero.altStrips`), `pa` = standing (2
frames), no suffix = walking (8 frames), `l` = facing left; `3smort*` = death, `3svito*` =
victory (the scene handler finishes the game when the hero's strip is 8–11).

On the disc but never named by the code: `FUNDON.BMP`, `FUNDOO.BMP`, `FOGOG.BMP`, `CAIXA.BMP`,
`COG1.BMP`, `GARRAFA.BMP`, `PRESENTE.BMP`, `MARGPP.BMP`, `MARPPP.BMP`, `MARPQA.BMP`, `PANEL.BMP`,
`STATUS.BMP`, `STATINV.BMP`, `STATNEW.BMP`, `COCO.WAV`, `OSTRA.WAV`, `SONIC.WAV`,
`SONICDIA.WAV`, `SONICPON.WAV` (leftovers of other versions or of the shared asset folder).

## 6. The game

*Inferno* is a keyboard platformer in hell; `GAME.md` describes it. In short: the hero walks and
jumps (UP 90 px, DOWN 60 px) along the floor line y 308; from x 340 facing right the world scrolls
under it; platforms hit from below give +100 (a drink, or the present that drops the cross); the
cross gives +300 and makes the hero big for about 9.8 s; hazards are stomped for +150 or cost
500 points and a life; after 3 minutes a hero with a life left wins a flat 500.

## 7. How it talks to NOITE

- NOITE (`handler_3fpapmal`) runs `inferno\inferno.exe`, polls `FindWindow("Inferno")` on timer
  0x14 and posts 0x40b with its window in lParam; APPWNDPROC stores it in `g_noiteWnd`.
- WM_CREATE calls GameVtbl `onCreate`, sets `g_started` and starts the 55-ms system timer 1 (a
  keep-alive for the clock: no branch handles it).
- **0x40c** ("ready"): APPWNDPROC posts `PostMessage(g_noiteWnd, 0x40c, hwnd, 0)` before
  forwarding **every** message once `g_started` is set (the `if (g_noiteWnd)` before it has an
  empty body; no one-shot flag).
- **0x40a** (result): `wParam = g_lives` (NOITE: non-zero = won), `lParam = g_lives ? 500 :
  g_score − 1000` (NOITE adds it to its score), on the time-out (then again every 100 ms for a
  grace second), on WM_CLOSE and on 0x12 (`WM_QUIT`, never dispatched). A 0x40a received by
  INFERNO makes it post itself WM_DESTROY.
- If the game dies without 0x40a (all lives lost), NOITE's system timer notices the vanished
  window and posts itself `(0x40a, 0, 0)`: a loss with no score change.

## 8. Original bugs

In `BUGS.md`, section INFERNO (H1–H8, and a Harmless list): the trailing `0x40c` and the time-out's
repeated reports reach NOITE's hall, a loss on lives reports nothing, closing the window with a life
left is a win, a hazard the hero runs into costs nothing, a life lost wipes the occupancy grid, and a
stomp in the scroll zone keeps the stomp latch set. `sonicpul.wav` opened twice and `sonicf.WAV`'s
handle kept only in `g_waves` (freed by `wave_free_all`) are not bugs.

## 9. Unknown

- `g_unk0082`, `g_unk0412/0414`, `7256–7269`.
- `SceneObject` `450–46f`, `Game` `14–17`, `unk9A` and `a0–ab`, `Hero.unk4E`,
  `Hazard.unk4A/unk4E`.
- The original names of the four game classes and of their slots.
