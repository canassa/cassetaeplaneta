# JARDIM.EXE: data map

DGROUP is Ghidra segment `10d0` (0x1882 bytes initialised, 0x8c98 allocated). JARDIM is large
model (`QUALITY.md` §0): data pointers are far (4 bytes), `this` is far, the vptr is a far
pointer, and **the vtables and vbtables live in the code segment `10c0`**, not in DGROUP.
Addresses are `10d0:` for DGROUP and `10c0:` for the tables unless they say otherwise. Types live
in the data type category `/jardim`. NOITE (also large model) is the reference for the class
layouts; TIRO for the module layout of DGROUP.

## Counts

| What | Count |
|---|---|
| Strings defined (ISO-8859-1, exact length) | 254: 241 in DGROUP, 13 in `10c0`; all named `s_camelCase` |
| Vtables / vbtables applied, typed and labelled | 43 / 20 (63 tables) in `10c0` |
| Vtable structs / vbtable structs | 12 (far slots, one `FunctionDefinition` per slot) / 2 (`Vbtable`, `Vbtable3d`) |
| Class and data structs | 28 in `/jardim` (the classes, the three phase scenes, `SpriteQueue`/`SpriteQueueEntry`, `ObjectList`, `OccupancyGrid`, `UpdateList`, the three Conditions); `DrawList` and `StatusBar` have none |
| Globals typed | 88 labels in DGROUP, 84 named, plus the strings |

## DGROUP map

| Range | Contents |
|---|---|
| `0000–000f` | Windows instance header |
| `0010` | `g_unk0010` byte = 0x0a: the transparent colour of the sprites (`labyrinth_draw_sprite_entry`; TIRO's `g_unk00A8` = 0x0b) |
| `0016–0061` | `s_appName` "Noite Animal Jardim" (class, title, NOITE's `FindWindow` target, NE description), `s_appIcon`, `s_alreadyRunning`, `s_userModule` ×2; `002a` **`g_noiteWnd`**, `005e` `g_started`, `0060` `g_noiteAcked` (NOITE's 0x40a seen; never set, BUGS.md J7) |
| `0062–0095` | `s_noiteClass`/`s_noiteTitle` ×2: "Noite Animal" (JARDIM looks NOITE up itself, `QUALITY.md` §8) |
| `0096–00b5` | `0096` `g_biosTickPtr` (far 0000:046c, for the dead `labyrinth_wait_ticks`); `009a`/`009c` `g_handsBobPos`/`g_handsBobStep` (0, 2; reset to 0, 2 by each exit); the state carried across the phases: `009e`/`00a0` **`g_startX`/`g_startY`** (0x390, 0x30: col 28, row 1; the phase-1 door sets 0x6d0, 0x30, the phase-2 door 0x30, 0x70), **`g_carryHealth`** `00a2` (100), **`g_carryLives`** `00a4` (3), **`g_carryAmmo`** `00a6` (0), **`g_carryLevel`** `00a8` (1), **`g_carryScore`** `00aa` (0, + 500 per finished phase), `00ac` **`g_curWeapon`** (the hands' strip), `00ae` **`g_startTick`** (dword), `00b2` **`g_variant`** (NOITE's 0x40b wParam; stays 0, BUGS.md J7), `00b4` `g_startTickPending` (= 1) |
| `00bc–019d` | Labyrinth messages: `s_cellFormat` "(%2.2d,%2.2d)", `s_outsideLabyrinth`, `s_insideWall`, captions; `0162–017b` the backdrop handler's state: `g_keyRightDown`, `g_keyLeftDown`, `g_keyUpDown`, `g_keyDownDown`, `g_keysDownCount`, `g_lastMoveKey`, `g_keyAltContext` (written only), `g_shotSecLo/Hi`, `g_shotCscLo/Hi` (the shot's direction), `g_shotCellObject` (far: the object the shot displaced); `017c–019d` five HUD formats "%2.2d", "%3.3d", "%3.3d%%", "%3.3d", "%2.2d" |
| `019c` | `g_nextId` (TIRO `00a6`) |
| `019e–029d` | `s_coordFormat`, the HDC and visible-object overflow strings |
| `029e–02cb` | `s_transrleCpp` "d:\c&p\doom\transrle.cpp", `s_assertOutputBuffer` "pOutputBuffer!= NULL" |
| `020a–021b` | `game_handle_message`'s latches, TIRO's order: `g_keyLeft/Right/Up/Down`, `g_itemSelected`, `g_exitPending`, `g_selectedItem` (far `Portable *`), `g_dropElevation` |
| `02cc–033d` | `passo1/passladd/passlade/passolau/passtras.bmp` and **`g_playerStripFiles/Frames/Widths/Heights`** (`030c`: 5 strips, frames {1,8,8,8,8}, 166×265). These five files are **not on the disc** |
| `033e–0493` | Phase 1: `passo1.bmp`, `labinter.bmp`, the hands strip table **`g_hands1Strip*`** (`0384`: `maos1`, `maobest1`, `maosuti`, 2 frames of 230×85 each), `raymap1.dat`, `portainv`, `rosto1`, `shot1`, `paredes1`, `bussuf`, `seios`, `besta`, `sutien1`, `medkit`, `chopp`, `acai`, `setas` `.bmp`, each followed by `s_labirinto*` "Labirinto" (the object's scene name) |
| `0494–0601` | Phase 1 music and waves: `s_mciOpenMusic` "open doom.mid type sequencer alias musica", "play musica notify", the 15 waves (`busrang2`, `barang`, `seio`, `seio2`, `esmagar`, `acai`, `ARROTO`, `arcfle02`, `barul1`, `yeeha`, `abrport2`, `alivio`, `barul2`, `soco`, `berro`), the MCI and WaveMix messages |
| `0602–0659` | WaveMix: `g_waveMixOpenResult`, `g_waveMixSession`, the wave table (`0606`), `g_waveCount` (`0658`) |
| `065a–06f9` | WaveMix error strings |
| `06fa–0983` | Phase 2: `g_hands2Strip*` (`071e`: `maos2`, `maobest2`, `maobazu2`), `raymap2.dat`, `portainv`, `rosto2`, `shot2`, `paredes2`, `alemao`, `siri`, `besta2`, `bazuka2`, `medkit2`, `chopp2`, `Camarao2`, `setas2`, `bomba2`; 16 waves (`assass`, `tiros`, `siri2`, `siri3`, then phase 1's list with `bazzo`, `armad`) |
| `0984–0c2b` | Phase 3: `g_hands3Strip*` (`09a8`: `maos3`, `maobest3`, `maobazu3`), `raymap3.dat`, `rosto3`, `shot3`, `paredes3`, `Chato`, `Bicho`, `espanf`, `vamanf`, `besta3`, `bazuka3`, `medkit3`, `chopp3`, `Camarao3`, `setas3`, `bomba3`; 16 waves (`chato`, `bibliaok`, `bicho`, …) |
| `0c2c–1881` | CRT data: `_C_FILE_INFO`, assert, the math library tables and names (`sin`, `cos`, `tan`, `cotan`, `pow`, `log10`, `log`, `exp`), `0cd8` 5 far CRT pointers, `0d68` 7 far FP hooks (all to `10b8:0aa0`), `11ec` far → `init_static_conditions_entry`, `11fa–120d` CRT exit hooks (→ `crt_endstdio`), the R6xxx and M61xx messages |
| `1882–1899` | `g_setSystemTimer`/`g_killSystemTimer` (USER.11 / USER.182, far), app globals (`1890` `g_appActive`; `188a–1898` app_init/WinMain words) |
| `0c3e`, `13ee–141d` | `g_angleRadians` (float, `raycast_angle_to_radians`'s result); the table constants `g_angleStep` (π/2880), `g_angleBias` (0.0003272), `g_fixedOne16` (65536.0), `g_floatMaxLong`/`g_floatMinLong` (±2³¹), `g_cellSize` (32.0), `g_wallHeightK` (22500.0) |
| `1a02–1a1d` | **`g_labyrinthTables`**: 7 far pointers to the trigonometric tables (`raycast_build_tables`; `GAME.md` §Units) |
| `1a1e–1bfd` | **`g_columnDepth`** `long[120]`: the wall distance of each column, the sprites' depth buffer |
| `1bfe` | `g_hudTextBuffer` (the HUD's `sprintf` buffer) |
| `2000–2011` | The minimap's GDI objects: `g_hPenCyan`, `g_hPenRed`, `g_hPenWhite`, `g_hOldGdiObject`, `g_hBrushBlue`, `g_hBrushMinimapWall` (green), `g_hBrushMinimapPlayer` (red); `2010` `g_fixed12Unused` |
| `2012–34a3` | **`g_occupancyCount`** `char[65][81]` (+ one pad byte) |
| `34a4–86e7` | **`g_occupancyObject`** `SceneObject far *[65][81]` (far pointers: 21,060 bytes) |
| `86e8` | **`g_game`** (far) |
| `8b9c` | `g_jardimGame` (far; stored by `jardim_game_ctor`) |
| `8ba0–8c5f` | **`g_phase1Waves[15]`**, `8bdc` `g_moduleHandle`, **`g_phase2Waves[16]`**, **`g_phase3Waves[16]`** (far WaveMix handles, in the order of the names above; `g_phase1Waves[7]`/`[8]` are swapped against the name order) |
| `8c62–8c97` | CRT (`sprintf`'s FILE, …) |

The occupancy matrix is NOITE's (65 × 81) with far object pointers; it fills the BSS up to
`g_game`, exactly as in TIRO (where it ends at the timer pointers).

## Strings in code segments

`10c0` holds the engine strings, as NOITE's `1018`: `s_missingCreatePlayer` …
`s_missingCreateStatusBar` ("Faltou redefinir o método …", caption `s_warningCaption`
"CUIDADO !"), `s_cannotOpenFile` "Não foi possível abrir o arquivo: %s", `s_updateListFull`
(`MAX_OBJECT_QTY`), `s_missingCreateScreen`, `s_missingCreateNewScene`, and the three scene
backgrounds `s_opcao1Bmp`/`s_opcao2Bmp`/`s_opcao3Bmp` (each next to its phase scene's ctor).

## Vtables (`10c0`)

`S` = SceneObjectVtbl (97 slots), `O` = Object3DVtbl (8), `M` = MoverVtbl (1), `A` =
AnimationVtbl (6), `vb` = vbtable. A vbtable is `{self = −4, sceneObjectOffset[, object3dOffset]}`
(offsets from the vbptr at +4); an Object3D's own vbtable is `{−4, SceneObject − Object3D}`.
Sizes are the `operator new` sizes.

| Class | Tables | vbtable | Ctor (stores) | Size | Status |
|---|---|---|---|---|---|
| SceneObject | `3f0e` S `g_sceneObjectVtbl` | – | `10c0:305c`, `4c70`, `856c`, `86bc` | 0x49c–0x49e | verified (NOITE's 0x49e) |
| Game | `4092` GameVtbl (7; slot 6 `_purecall`) | – | `10c0:6fc2` (ctor), `2956` (dtor) | | verified (TIRO's) |
| JardimGame | `816a` GameVtbl (slots 1–4, 6 in `1090`) | – | `jardim_game_ctor` `1090:0000` | 0x560 | role of TiroGame |
| Frame | `40ae` FrameVtbl (`getCell`) | – | `10c0:5860` | 0x1a | verified |
| Backdrop | `48a2` BackdropVtbl (23, NOITE's) | – | `10c0:41b4`, `41de`, `42ae` | | verified |
| **LabyrinthBackdrop** | `4842` (24: Backdrop + slot 0x17 `handleMessage`; slot 0 `1028:2191` create, 0x17 `1028:2609`) | – | `1028:0dfb`, `0ecb`, `0f85` | 0x73c | JARDIM (the raycaster) |
| Portable | `59d4` M, `59d8` S, `5b5c` O | `5b7c` {−4, 0x44, 0x4e2}, `5b82` | `1048:2aed`, `portable_ctor_zoom` `2cee`, `portable_ctor` `2ed8` | 0x502 | verified; **used for every pickup and enemy** |
| Moveable | `5b86` M, `5b8a` S, `5d0e` O | `5d2e` {−4, 0x34, 0x4d2}, `5d34` | `10c0:4d6c`, `4eee`, `506a`, `78a8` | | verified |
| Object3D | `5d38` O, `5d58` S | `5edc` {−4, 0x1a} | `10c0:4cde` | NV 0x1e | verified |
| Mover | `5ee0` M, `5ee4` S | `6068` {−4, 0x34} | `10c0:51ce`, `5336`, `549a` | NV 0x38 | verified |
| FlagCondition / Condition / CompoundCondition | `6284` / `6290` / `629c` ConditionVtbl | – | `10c0:606c` / `6226` / `610e` | – / – / 0xe | verified (by who calls the ctors) |
| Scene | `6c64` SceneVtbl (16, NOITE's; slot 0 `_purecall`) | – | `10c0:7a30`, dtor `1070:0075` | | verified |
| ControlPanel | `7b84` ControlPanelVtbl (14), `7bbc` S, `7d40` O | `7d60` {−4, 0xe8, 0x584}, `7d66` | `10c0:6e2e` | 0x5a4 | verified |
| **Player** | `7d6a` M, `7d6e` A, `7d86` S, `7f0a` O | `7f2a` {−4, 0x58, 0x4f6}, `7f30` (Animation) {−4, 0x22, 0x4c0}, `7f36` | `10c0:6cdc` (from `jardim_game_create_player`) | 0x516 | verified (overrides `isScrollTarget`, `isPlayer`, `asPlayer`, occupy/vacate, draw/tick/moveTick) |
| Actor | `7f3a` M, `7f3e` A, `7f56` S, `80da` O | `80fa` {−4, 0x52, 0x4f0}, `8100` {−4, 0x1c, 0x4ba}, `8106` | `10c0:72be` | | verified (Player's base) |
| **LabyrinthScene** | `810a` (24: SceneVtbl + 8 slots `hit` … `onLifeLost`; slot 0 `1028:5dba`, 0x17 `1028:5ef1` respawn) | – | `10c0:7462`, dtor `10c0:8acc` | 0x90 | JARDIM |
| **Phase1Scene** | `834c` LabyrinthSceneVtbl (overrides in `1098` and `10c0:7630`) | – | `10c0:7076` (from `jardim_game_create_init_scene`), dtor `1098:0dd2` (never run) | 0x90 | JARDIM |
| Animated3D | `8186` A, `819e` S, `8322` O | `8342` {−4, 0x14, 0x4b0}, `8348` | `10c0:7166`, `77d0`, `8b4c` | | verified |
| Animation | `83ac` A, `83c4` S | `8548` {−4, 0x14} | `10c0:76a4`, `7ae8`, `8d24` | NV 0x18 | verified |
| **WallStrip** | `8e60` S (one override: `attach` = `wall_strip_attach` `1028:47d6`) | – | `wall_strip_ctor` `10c0:8a76` | 0x4a0 | JARDIM: the wall-texture strip (`paredesN.bmp`, 6 textures of 32×300; +0x49e the texture count, +0x49c one texture's height); no struct (a SceneObject plus one word) |
| Exit | `8fe4` A, `8ffc` S, `9180` O | `91a0` {−4, 0x5c, 0x4f8}, `91a6` | `10c0:8892` | 0x518 | verified (the door, `portainv.bmp`) |
| **Phase2Scene** | `91aa` LabyrinthSceneVtbl (overrides in `10a8`, `10c0:8cb0`) | – | `10c0:8afc` (from phase 1's `createNewScene`), dtor `10a8:0f38` (never run) | 0x94 | JARDIM |
| **Phase3Scene** | `92da` LabyrinthSceneVtbl (overrides in `10b0`, `10c0:925a`; slot 6 is the default) | – | `10c0:920a` (from phase 2's `createNewScene`), dtor `10b0:0ed6` (never run) | 0x92 | JARDIM |

Labels: `g_<class>Vtbl` for the primary table, `g_<class>SceneObjectVtbl`,
`g_<class>Object3dVtbl`, `g_<class>AnimationVtbl`, `g_<class>Vbtbl`,
`g_<class>AnimationVbtbl`, `g_<class>Object3dVbtbl`.

**The vtable structs** (`/jardim`, built by `FarVtables.java` with the code segment as its
`dataseg`):
- **SceneObjectVtbl** (97): NOITE's field names without `reoccupy`, `isAvi`, `advanceFrames`,
  `isAnimated3D`, `asAnimated3D` (the slot map is in `QUALITY.md` §5).
- **Object3DVtbl** (8), **BackdropVtbl** (23), **SceneVtbl** (16): NOITE's.
- **GameVtbl** (7): TIRO's (`handleMessage`, `createPlayer`, `createInitScene`,
  `createControlPanel`, `createStatusBar`, `init`, `onCreate`).
- **AnimationVtbl** (6): `lock` (`animation_lock`: `Animation.locked` +0x14 = 1), `isLocked`
  (`animation_is_locked`), `slot02–04` (three identical stubs that call `isLocked` and return 0,
  where NOITE has its AVI methods), `playOnce` (starts only when not locked). NOITE's 8 slots
  cannot be mapped one to one.
- **ControlPanelVtbl** (14): the 6 Animation slots, then `isOpen` (unverified),
  `getVisibleHeight`, `slide`, `drawInventory`, `isOutside`, `contains`, `getInventoryItemAt`,
  `drawInventoryItem` (NOITE's 9 without `isOnOptionsButton`).
- **LabyrinthBackdropVtbl** (24) = BackdropVtbl + `handleMessage` (0x17);
  **LabyrinthSceneVtbl** (24) = SceneVtbl + `hit` (0x10), `touch`, `placeObjects`,
  `playEnemyAttackSound`, `playEnemyStepSound`, `playFireSound`, `playDoorSound`, `onLifeLost`
  (0x17). The base table's defaults are `labyrinth_scene_*_default` (`10c0:758c–761a`: empty,
  `touch` returns 1, `placeObjects` returns this) and `labyrinth_scene_respawn` for 0x17.
- **FrameVtbl** (`getCell`), **MoverVtbl** (`placeAt`), **ConditionVtbl** (`evaluate`, `set`,
  `clear`).

Each slot is a far pointer to a `FunctionDefinition` (`<Vtbl>_<field>Fn`) copied from the
slot's target, with a DATA reference to the target. Pure virtual slots point to `_purecall`
(`10b8:0816`). `FarSlotSignatures.java 10c0 defs large` rewrote the 224 definitions from the
targets' final prototypes, and every one of the 421 virtual call sites has a call-site override
with its slot's definition (`FUNCTIONS.md` §Cleanup).

## Classes (`/jardim`)

The convention is TIRO's/ENCAIXE's: a class struct holds the non-virtual part; the SceneObject
virtual base follows at the vbtable's offset (+4, since the vbptr is at +4).

| Struct | Size | Confidence |
|---|---|---|
| `SceneObject` | 0x49e | **high**: NOITE's layout, field for field. Same size (every vbtable puts the Object3D base 0x49e after the SceneObject), and the `scene_object_attach`/`reattach`/draw functions use NOITE's offsets (`a`, `2a–30`, `44e`, `452`, `468–476`). `vtbl` is the 97-slot `/jardim/SceneObjectVtbl` |
| `Object3D` | 0x1e | high: NOITE's (vbtable {−4, 0x1a} → SceneObject at +0x1e) |
| `Mover` | 0x38 | high: NOITE's fields (vbtable {−4, 0x34} → SceneObject at +0x38); the Mover methods read `this+0x430/0x432` for SceneObject fields that NOITE reads at `0x42e/0x430`, consistent with the 2-byte larger Mover subobject in front of the base |
| `Animation` | 0x18 | medium: vtbl, vbptr, `timerId`, `timerPeriod`, `playOnce`, `running` (NOITE's first fields), `locked` +0x14 (AnimationVtbl slots 0/1); no AVI name (NOITE's is 0x114) |
| `Moveable`, `Portable`, `Animated3D`, `Exit`, `ControlPanel` | 0x38, 0x48, 0x18, 0x60, 0xec | skeletons: vtbl, vbptr and the size from the vbtables |
| `Actor`, `Player` | 0x56, 0x5c | medium: Actor = Mover part, `animation` at 0x36 (its vbptr is at 0x3a: {−4, 0x1c} → SceneObject at 0x56), `inventory` `ObjectList` at 0x4e; Player = Actor + `lives` (0x56) + `score` long (0x58), NOITE's Player tail |
| `Game` | 0x560 | medium: vtbl, `scene` +4, `statusBar` +0xc, `controlPanel` +0x10, `player` +0x18, `globalObjects` +0x1c (from `game_init`) |
| `Scene`, `LabyrinthScene` | 0x90 | skeleton; LabyrinthScene: `screen` +4, `handlerEnabled` +0x60, `backdrop` (far `LabyrinthBackdrop *`) +0x62, `mapFile` +0x66 |
| `Phase1Scene`, `Phase2Scene`, `Phase3Scene` | 0x90, 0x94, 0x92 | high: the phase's far `Portable *` from +0x6a (phase 1: `crossbow`, `bra`, `enemyBussuf`, `enemySeios`, `medkit`, `beer`, `acai`, `arrows`, `exit` +0x8a, `exitIndex` +0x8e; phase 2: `crossbow`, `bazooka`, `enemyAlemao`, `enemySiri`, `medkit`, `beer`, `shrimp`, `arrows`, `bombs`, `exit` +0x8e, `exitIndex` +0x92; phase 3 as phase 2 with `enemyChato`, `enemyBicho` and `finalEnemy` +0x8e, no exit) |
| `Backdrop` | 0x452 | skeleton (NOITE's size); `hdcSurface` +4, `bits` +6, `bgImage` +0xe, origin and size +0x16–0x1c are typed in LabyrinthBackdrop |
| `LabyrinthBackdrop` | 0x73c | high: `playerX`/`playerY` +0x452/+0x456, `viewAngle` +0x45a, `startX`/`startY` +0x45e/+0x462 (the respawn point), `skyScrollX`, `floorScrollX/Y` +0x466–0x46a, `velX`/`velY` +0x46c/+0x470, the view rectangle +0x474–0x482, `moveRamp`/`moveSpeed` +0x484/+0x486 (16.16 speed), `secAtAngle`/`cscAtAngle` +0x488/+0x48c, `wallRows` `char far *[80]` +0x490, `objectRows` `SceneObject far * far *[80]` +0x5d0, `health`, `lives`, `ammo`, `level`, `score` +0x710–0x718, `wallStrip` +0x71a, `spriteQueue` +0x71e, `hands` +0x722, `shot` +0x726, `face` +0x72a, `scene` +0x72e, `hwnd` +0x732, `active` +0x734, `moveFlag` +0x736, `shotInFlight` +0x738 |
| `SpriteQueue`, `SpriteQueueEntry` | 0x7d6, 0x14 | high: 100 entries {`object` far, `dist`, `angle`, `col`, `row`, `left` far, `right` far}, `root` +0x7d0, `nextFree` +0x7d4 |
| `ObjectList`, `OccupancyGrid`, `UpdateList` | 8, 0x10, 0x7a | high (NOITE's, checked against the users): {`head`, `count`, `capacity`}; {`lastCellObject`, `firstObject`, `rowCount`, `colCount`, `rowShift`, `colShift`}; {`items[30]`, `count`} |
| `Condition`, `FlagCondition`, `CompoundCondition` | 4, 6, 0xe | high: {`vtbl`}; + `value`; + `left`, `right`, `isOr` |
| `Frame` | 0x1a | skeleton |

`SceneObject` keeps NOITE's tail with JARDIM's uses: `slot00Flag` +0x48e (the word the slot00/01
defaults set and read, over NOITE's wave pointer), `worldX`/`worldY` +0x496/+0x498 (the labyrinth
position, over NOITE's `rleBits`; the state initialiser copies x/y there), `isEnemy` +0x49a
(NOITE's `playOnceRewinds`, set only on the enemies), `framesLeft` +0x49c (the wall strip stores one
texture's height there).

## The assets

All files are read from the current directory (`<CD>jardim`, NOITE's `_chdir`).

| What | Files | Notes |
|---|---|---|
| Maps | `raymap1/2/3.dat` | Text, 80 lines × 57 characters + CRLF (4,720 bytes). ` ` is floor; `1`–`6` walls; `7`/`8` exit doors; `9`, `A`, `B`, `C` doors that SPACE opens (`GAME.md` §The map) |
| Walls | `paredes1/2/3.bmp` (32×1800) | 6 textures each |
| Scene frame | `opcao1/2/3.bmp` (640×480), `labinter.bmp` (640×138) | the background around the 3D view, per phase |
| HUD | `rosto1/2/3.bmp` (44×330: 5 faces of 44×66), the five HUD formats | the face (by health), level, ammo, health, score, lives |
| Hands (weapons) | phase 1 `maos1` (fists), `maobest1` (crossbow), `maosuti` (bra); phases 2–3 `maosN`, `maobestN`, `maobazuN` (bazooka) | 230×170, 2 frames each; `g_curWeapon` selects the strip |
| Shots | `shot1/2/3.bmp` (64×270) | |
| Door | `portainv.bmp` (32×300) | the Exit object (never drawn: it only carries the exit index) |
| Phase 1 objects | enemies `bussuf.bmp` (4 frames), `seios.bmp` (5 frames); pickups `besta`, `sutien1`, `medkit`, `chopp`, `acai`, `setas` | each a Portable placed at a fixed point of the map |
| Phase 2 objects | enemies `alemao`, `siri`; pickups `besta2`, `bazuka2`, `medkit2`, `chopp2`, `Camarao2`, `setas2`, `bomba2` | |
| Phase 3 objects | enemies `Chato`, `Bicho`, `espanf`, `vamanf`; pickups `besta3`, `bazuka3`, `medkit3`, `chopp3`, `Camarao3`, `setas3`, `bomba3` | |
| Music | `doom.mid` (MCI alias `musica`, looped on MM_MCINOTIFY) | the same in the three phases |
| Waves | 15 / 16 / 16 per phase (`g_phaseNWaves`) | `soco` (punch), `arcfle02` (crossbow), `ARROTO` (burp: the beer), `alivio` (relief: the medkit), `abrport2` (the door), `esmagar`, `berro`, the enemies' own (`seio`, `siri2/3`, `chato`, `bicho`, …) |

Not on the disc: the Player's `passo1/passladd/passlade/passolau/passtras.bmp` (the five-strip
table at `030c`, unused; `jardim_game_create_player` loads `passo1.bmp` alone, `load_dib` returns
NULL silently and the Player is never shown). On the disc and never named by the program: `1fase`,
`garden`, `garden2`, `inter`, `inter1`, `intrface`, `luiz1–5`, `noite1`, `opcao`, `opcao2a/2b/3o`,
`statnew`, `walls*`, `brick`, `green*`, `redbric*`, `door`, `parede1–6`, `paredes`, `ceu1`,
`chao1/3`, `bussu`, `maos`, `maosbest`, `maobazuk`, `sutishot`, `setashot`, `shot`, `rosto`,
`ctrlsoco`, `panel`, the unsuffixed `bazuka`/`bomba`/`camarao` and several waves (`arcflech`,
`bara01`, `besta`, `biblia`, `busrang3`, `camar1`, `chopp2`, `duuuu`, `oops`, `parede`, `raiva`,
`seio3`, `siri`, `siri4`, `toing`): development leftovers.

## The game

`GAME.md` describes it; `BUGS.md` (section JARDIM, J1–J6) lists its bugs. Phase 4 corrected the
data picture of phase 3: the phase scenes' slot 0x12 places the objects (it is not a tick); the
variant only picks the final enemy's picture (`espanf` for 1, `vamanf` for 0); the phase-2 door
sets the phase-3 start (0x30, 0x70); the win is touching the final enemy of phase 3 (there is no
last door); `00a2–00aa` are the carried health, lives, ammo, level and score; `0162–017b` the
backdrop handler's key and shot state; `1a1e` the column depth buffer; `2000–2011` the minimap's
GDI objects; the map's `9`–`C` are doors.

## Unknown

- `g_unk0010`'s name (it is the sprites' transparent colour index, 10).
- The skeleton structs' fields (`Moveable`, `Portable`, `Animated3D`, `Exit`, `ControlPanel`,
  `Frame`; the draw list and the status bar have no struct): the labyrinth does not use them.
- The ControlPanelVtbl slot `isOpen` (unverified; only `game_handle_message`'s dead cases call it).

## Scripts (`ghidra/scripts/`)

| Script | Use here |
|---|---|
| `DefineStrings.java` | the 254 strings (`zig-out/jardim/strings.arg`, read from a file by an inline copy) |
| `FarVtables.java` | the 12 vtable structs, 2 vbtable structs and the 63 tables, with `dataseg` = `10c0` (`zig-out/jardim/vt.spec`) |
| `NearStructs.java` | the 18 class structs of phase 3 in `/jardim` (`cls.spec`; it takes far pointers as `T*32`) |
| `NearGlobals.java` | the globals (`glob.spec`, `glob2.arg`) |
| `FarSlotSignatures.java` (`large`) | the slot definitions and the call-site overrides (`FUNCTIONS.md` §Cleanup) |

The inline copies (`Jardim<Script>`) only add `@file` arguments, since the specs are longer than
a command line. The phase-4 struct fixes are `zig-out/jardim/cleanup/JardimClStructFix.java`
(inline, not committed).
