# SAUNA.EXE: data map

DGROUP is Ghidra segment `10b0` (0x7cda bytes, all initialised; there is no separate BSS). The
vtables and some strings live in code segment `10a0`; the two static conditions in the far data
segment `10a8`. Types live in the data type category `/sauna`. SAUNA is large model, `/Od`
(`QUALITY.md` §0): data pointers, `this` and the vptr are far (4 bytes), and every vtable slot is a
4-byte far code pointer. NOITE's far layouts and TIRO's names are the references.

## Counts

| What | Count |
|---|---|
| Strings defined (Latin-1, exact length), named `s_camelCase` | 124: 111 in DGROUP (46 had been missing and 2 cut at an accent), 13 in `10a0` |
| Vtables / vbtables applied and labelled | 42 / 19 (`10a0`) |
| Vtable structs (far slots) / vbtable structs | 14 / 2 (`Vbtable`, `Vbtable3d`) |
| Slot `FunctionDefinition`s rewritten from their targets (`FarSlotSignatures defs`) | 222 |
| Class and record structs | 27 |
| Globals typed and named (non-string, non-table) | 101 (99 in DGROUP, 36 of them the CRT's; 2 in `10a8`) |
| Functions given a far `this` and a `__stdcall16far` signature (`SaunaFarThisTypes.java`) | 373 |
| Virtual calls with a call-site override (`FarSlotSignatures … large`) | all 469 (450 `calls large`, 19 `site large`), plus the 12 calls through the two timer pointers |
| Undefined bytes left in DGROUP | 0x7c0, almost all CRT data and padding (end of file) |

## DGROUP map

| Range | Contents |
|---|---|
| `0000–000f` | Windows instance header |
| `0010` | `g_nextId`: the next SceneObject id (`next_object_id`) |
| `0012–00b9` | `s_coordFormat`, the HDC and layer overflow strings and their captions |
| `00a8–00bb` | `game_handle_message`'s latches: `g_keyLeft/Right/Up/Down`, `g_itemSelected`, `g_exitPending`, `g_selectedItem` (far `Portable *`), `g_dropElevation` (TIRO `00f2–0101`, same order) |
| `00ba–011c` | The nine Pacman strip file names `3SP*.bmp` |
| `011e–0177` | **Pacman strip tables**: `g_pacmanStripFiles` (9 far `char *`), `g_pacmanStripFrames` {2×8, 6}, `g_pacmanStripWidths` (40 ×9), `g_pacmanStripHeights` (40 ×9) |
| `0178–0195` | `s_pacinterBmp` (the panel), `s_mazeTitle` "Labirinto" (the scene name), `g_transparentColor` `0190` = 0x0b (the colour key of every transparent copy, TIRO's `g_unk00A8`) |
| `0196–01d5` | `s_appName` "Sauna Mista" (class, title, NOITE's `FindWindow` target), `s_appIcon`, `g_noiteWnd` (`01a2`), `s_alreadyRunning`, `s_userModule` ×2 |
| `01d6`, `01d8` | `g_started`, `g_handshakePending` (= 1) |
| `01da–025b` | the visible-objects overflow strings |
| `025c–02be` | The nine Ghost strip file names (the same files, other order) |
| `02c0–0319` | **Ghost strip tables**: `g_ghostStripFiles`, `…Frames`, `…Widths`, `…Heights` (same shape) |
| `031a–07e7` | **The maze**: 30 rows of 40 characters + NUL (`s_mazeRow00…29`, row stride 0x29): `1` wall, `2` peanut, `3` cork, space empty |
| `07e8–07ef` | `g_dotsLeft` (= 100), `g_powerStrip` (0, or 4 while powered), `g_powerStartPending`, `g_pacmanDying` |
| `07f0–0899` | `s_peanutBmp` "3o1amend.bmp", `s_corkBmp` "3o1rolha.bmp", `s_backgroundBmp` "3fpac2.bmp", the MCI strings (`pac.mid`, alias `musica`), the six wave names |
| `089a–08a9` | `g_keyLeftHeld`, `g_keyRightHeld`, `g_keyUpHeld`, `g_keyDownHeld`, `g_deathFramesLeft` |
| `08aa–0937` | MCI and WaveMix strings |
| `0938` | **`g_lives`** = 3 |
| `093a–0975` | `s_negScoreFormat` "-%04d", `s_scoreFormat` " %04d", `s_transrleFile` "d:\c&p\pacman\transrle.cpp", `s_assertOutputBuffer` |
| `0976–09cd` | WaveMix: `g_waveMixOpenResult`, `g_waveMixSession`, `g_waves` (20 far), `g_waveCount` |
| `09ce–0abb` | WaveMix error strings, the assert format |
| `0a6e–0f7c` | CRT data, NOITE's names (matched by the CRT instruction that reads each one): `g_crtStackLimit` `0a6e`, `g_crtPrevInstance`, `g_crtInstance`, `g_crtCmdLine` (far), `g_crtCmdShow` `0a78`, `g_crtStackOverflowHook` `0a82` (`_aFchkstk` jumps through it), `g_crtHoldRand` `0a86` (`rand`), `s_cFileInfo`, `g_crtSavedVector` `0aca`, `g_crtErrno` `0ad8`, `g_crtPsp`, `g_crtWinVersion`, `g_crtOsMinor/Major`, `g_crtOsVersion`, `g_crtOsMode`, `g_crtDosErrno`, `g_crtNFile` (20), `g_crtNHandle` (40), `g_crtOsFile[40]` `0af0`, `g_crtArgc` `0b18`, `g_crtArgv`, `g_crtEnviron`, `g_crtPgmPath`, `g_crtExitType` `0b29`, `g_crtArgvRet`, `g_crtNearHeapFail` `0b94`, `g_crtFarHeapFail`, `g_crtLastIob`, `g_crtFloatHooks` `0bb2` (7 far → `_fptrap`), `g_crtPairTable` `0bd2`, `g_crtPairTableSize`, `g_crtInitHook` `0bf4` (→ `init_static_conditions_entry`), `g_crtTermHook` `0bfa`, `g_crtExitTable` `0c06` (→ `crt_endstdio`), `g_crtIob` `0c0a` (`CrtFILE[20]`), `g_crtNmsgTable` `0df2`, the R6xxx strings. The words NOITE itself leaves `g_crtUnk…` keep placeholders |
| `0f94–1443` | `g_unk0F94`: 300 dwords, read (BX×4) only by the dead `FUN_1010_0960` |
| `1444–28d4` | **`g_occupancyCount`** `char[65][81]` |
| `28d6–7b19` | **`g_occupancyObject`** far `SceneObject *[65][81]` (twice TIRO's size) |
| `7b1a–7b3f` | `g_game`, `g_saunaGame` (the same object), **`g_pacman`**, `g_setSystemTimer`/`g_killSystemTimer` (USER.11/USER.182), `g_modulePath` (far → `7b40`), `g_instance`, `g_mainWindow`, an unreferenced word, `g_appActive`, `g_windowWidth` (640), `g_windowHeight` (480), **`g_score`** |
| `7b40–7ca7` | `g_modulePathBuf[260]`, `g_messageText[100]` |
| `7ca8–7cb3` | `g_peanut`, `g_cork` (the two dot SceneObjects), `g_saunaScene` |
| `7cb4–7ccb` | the six far wave handles (below) |
| `7ccc–7cd9` | `g_moduleHandle`, `g_crtSprintfFile` |

Segment `10a8` (12 bytes, uninitialised): `g_conditionTrue` and `g_conditionFalse`, two
`FlagCondition`s (far vptr + value) built by `init_static_conditions`.

Code segment `10a0` holds the engine's format strings next to their code, as NOITE does: the
`MAX_OBJECT_QTY` overflow (`417a`/`4188`), the five "Faltou redefinir o método Create…" warnings
and `s_warningCaption` "CUIDADO !" (`7936–79e9`), CreateScreen/CreateNewScene (`8f4a`, `8f72`),
the grid overflows and `s_cannotOpenFile` (`9952–99eb`).

## Vtables

All in `10a0`; `FUNCTIONS.md` has the class mapping and the ctors. Labels:
`g_<class>Vtbl` for the primary table, `g_<class>SceneObjectVtbl`, `…Object3dVtbl`,
`…AnimationVtbl`, and `g_<class>Vbtbl` / `…Object3dVbtbl` / `…AnimationVbtbl` for the vbtables.

The vtable structs (`/sauna`, 4-byte slots, each a pointer to `<Vtbl>_<field>Fn`):
- **SceneObjectVtbl** (98): NOITE's first five slots (`slot00`, `slot01`, `enableRle`, `isRle`,
  `getSceneName`), then TIRO's fields with ENCAIXE's `unk18` after `draw`; the type tests at
  `0x100–0x114` are `isScrollTarget`, `slot43` (Player2D overrides both), `isPlayer`, `asPlayer`,
  `isDirectionalPlayer`, `asDirectionalPlayer` (NOITE's and JARDIM's order, from the callers); no
  `unk4E`; ENCAIXE/NOITE's `slot61…slot65` at the end.
- **Object3DVtbl** (8), **MoverVtbl** (`placeAt`), **FrameVtbl** (`getCell`), **GameVtbl** (7),
  **ConditionVtbl** (3): TIRO's.
- **AnimationVtbl** (6): `setAvi`, `isAvi`, `aviSlot2–4`, `playOnce`. **ControlPanelVtbl** (14):
  those 6 + `isOpen`, `getVisibleHeight`, `slide`, `drawInventory`, `isOutside`, `contains`,
  `getInventoryItemAt`, `drawInventoryItem`.
- **SceneVtbl** (16), **BackdropVtbl** (23), **GridBackdropVtbl** (24): NOITE's.
- **SaunaSceneVtbl** (17) = SceneVtbl + `sendGhostsHome`; **PacmanVtbl** (2) = `placeAt`,
  `slot1` (`pacman_refresh_power_strip`); **GhostVtbl** (3) = `placeAt`, `slot1`
  (`ghost_choose_direction`), `slot2` (`ghost_is_next_step_free`).

The vbtables are `{vbptrOffset = −4, sceneObjectOffset[, object3dOffset]}`:

| Class | SceneObject at | Object3D at | Vbtables |
|---|---|---|---|
| Object3D | 0x1e | – | `583a` |
| Mover | 0x38 | – | `59ca` |
| Moveable | 0x38 | 0x4d6 | `54d2` (3d), `54d8` |
| Portable | 0x48 | 0x4e6 | `5688` (3d), `568e` |
| Animation | 0x18 | – | `8462` |
| Actor2D, Ghost | 0x4e | – | `7b8e`/`7b92`, `9c3c`/`9c40` |
| Player2D, Pacman | 0x54 | – | `7d3a`/`7d3e`, `829e`/`82a2` |
| Animated3D | 0x18 | 0x4b4 | `7f02` (3d), `7f08` |
| ControlPanel | 0xec | 0x588 | `80ec` (3d), `80f2` |

(offsets from the object start: the vbptr sits at +4, so SceneObject = 4 + `sceneObjectOffset`.)
Each class's 2-byte vtordisp sits just before its SceneObject. The sizes agree with the
`operator new` calls: Pacman 0x4f0 = 0x54 + 0x49c, Ghost 0x4ea = 0x4e + 0x49c, ControlPanel 0x5a4,
SaunaScene 0x7a, Game 0x560.

## Classes (`/sauna`)

Layout convention as TIRO's: a class struct holds the non-virtual part; an embedded base leaves its
vtordisp out, a leaf (Object3D, Pacman, Ghost) lists it; the SceneObject virtual base follows. The
offsets are SAUNA's own: every one was checked against the `this`-relative accesses of the class's
functions (`zig-out/sauna/offs.py`) and against the ctors.

| Struct | Size | Evidence / notes |
|---|---|---|
| `SceneObject` | 0x49c | NOITE's far layout field for field (`x` 0x12, `frames` 0x1c, `bmiHeader` 0x26, `hpalette` 0x44e … `sceneName` 0x478, `wave` 0x48e, `rleMode` 0x494, `rleBits` 0x496, `playOnceRewinds` 0x49a) without NOITE's last field `framesLeft`. high |
| `Object3D` | 0x1e | TIRO's fields, pointers doubled; `support` far at 0x18, vtordisp 0x1c. high |
| `Mover` | 0x36 | TIRO's fields + 4 (far vptr and vbptr): `direction` 0xc, `prevX` 0x16 … `moving` 0x34; NOITE's offsets without its `allowOffscreen`. high |
| `Moveable` | 0x36 | = Mover. high |
| `Animation` | 0x16 | `timerId` 8, `timerPeriod` a, `framesLeft` c, `playOnce` e, `running` 10, `unk12`, `isAvi` 14 (`animation_set_avi`). medium (0x12) |
| `Actor2D` | 0x4c | Mover + Animation at 0x36. high |
| `Player2D` | 0x52 | Actor2D + `lives` 0x4c + `score` long 0x4e (both unused: the game keeps `g_lives`/`g_score`). high |
| `Pacman`, `Ghost` | 0x54, 0x4e | Player2D / Actor2D + vtordisp: **no fields of their own**; all game state is in globals |
| `Portable` | 0x46 | `owner` far 0x36, `icon` 0x3a, `iconPath` 0x3e, `iconW`/`iconH` 0x42/0x44 (NOITE's order; TIRO's `prevSceneName` has no room). medium; no Portable is built |
| `ControlPanel` | 0xea | Animation + `isOpen` 0x16, `slideDir`, `slideStepsLeft`, `textColor` 0x1c, `text[200]` 0x20, `textX` 0xe8. high |
| `StatusBar` | 0x56a | SceneObject + `textColor`, `text[200]`, `textX` (the dead methods' offsets). Never built |
| `Frame` | 0x1a | `vtbl`, `cells` far 4, `width` 8, `height` a, `count` c, `dib` far 0xe, `hit*` 0x12–0x18 (TIRO order). medium (the hit box) |
| `ObjectList` | 8 | `head` far, `count`, `capacity` |
| `UpdateList` | 0x7a | 30 far items + `count` |
| `DrawList`, `DrawListNode` | 0x4b8, 0xc | 100 far nodes, `freeHead`, `head`; node `item`/`prev`/`next` far |
| `OccupancyGrid` | 0x10 | NOITE's |
| `Backdrop` | 0x45e | `hdc` 4, `bits` 6, `hpalette` a, `oldBitmap` c, ENCAIXE's second DC (`oldBitmap2` e, `hdc2` 10, `bits2` 12: the background with the dots), `hwnd` 0x16 and `hdcWindow` 0x18 (set by the scene handler and the move ticks), `background` 0x1a, `bgWidth/Height` 0x1e/0x20, `originX/Y` 0x22/0x24, `viewWidth/Height` 0x26/0x28, `bmiHeader` 0x2e, `bmiColors` 0x56, `dibOrientation` 0x456, `sceneList` 0x45a (all from `backdrop_ctor`/`backdrop_create`). high except 0x2a–0x2d |
| `GridBackdrop` | 0x462 | `grid` far at 0x45e |
| `Scene` | 0x62 | `backdrop` 4, `exits` (10 far) 8, `exitCount` 0x30, `name[20]` 0x32 (strncpy 0x13), `objects` 0x46, `hasPlayer/StatusBar/ControlPanel` 0x4e–0x52, `is1Animation`, `isClickExit`, `animation` far 0x58, `mayDropObject` 0x5c (= 1), `sceneNumber` 0x5e, `handlerEnabled` 0x60 (set by `scene_create`; the handler returns 0 while it is 0) |
| `SaunaScene` | 0x7a | Scene + `ghosts[4]` far 0x62, `peanut` 0x72, `cork` 0x76 |
| `Game` | 0x560 | `scene` 4, `oldScene` 8, `statusBar` c, `controlPanel` 0x10, 4 unknown bytes 0x14, `player` 0x18, `globalObjects` 0x1c (capacity 30), `lastGlobalObject` 0x24 (NOITE has it), `updateList` 0x28, `drawList` 0xa2, `unk55A` (= 2), `clearWidth/Height` 0x55c/0x55e |
| `Condition`, `FlagCondition`, `CompoundCondition` | 4, 6, 0xe | far vptr; `value`; `left`/`right` far, `isOr` |

`this` is typed on the 373 methods that the vtables and the vptr stores identify (`this.arg`):
SceneObject-slot overrides get `SceneObject *` (they receive the SceneObject subobject, as in
TIRO), the other slots and the ctors their class.

## The game data

**The maze** (`s_mazeRow00…29`, 30 × 40 cells of 16×16 px over the 640×480 window):
- `sauna_backdrop_create` marks every `1` as a wall in the occupancy grid (`grid_backdrop_create_with_grid`
  with shift 4, then `occupancy_grid_set_cell(grid, NULL, -1, col, row)` per cell).
- `sauna_scene_create` stamps the dot pictures into the background: a **peanut** (`3o1amend.bmp`,
  20×12) at each `2` and a **cork** (`3o1rolha.bmp`, 20×25) at each `3`, at (16·col + 8,
  16·row + 10). There are 96 peanuts and 4 corks, and `g_dotsLeft` starts at **100**.

**Pictures** (all 8-bpp, from the current directory):

| File | Size | Use |
|---|---|---|
| `3fpac2.bmp` | 640×460 | the scene background (`s_backgroundBmp`) |
| `pacinter.bmp` | 640×48 | the control panel (`sauna_game_create_control_panel`) |
| `3o1amend.bmp`, `3o1rolha.bmp` | 20×12, 20×25 | peanut and cork |
| `3SPEFB`, `3SPRFB`, `3SPCSB`, `3SPDFB` | 40×80 (2 frames 40×40) | Pacman strips 0–3 (normal); Ghost strips 4–7 (powered) |
| `3SPCEP`, `3SPCRP`, `3SPCSP`, `3SPCDP` | 40×80 | Ghost strips 0–3 (normal); Pacman strips 4–7 (powered) |
| `3SPCMB` | 40×240 (6 frames) | Pacman strip 8: the death animation (Ghosts get 8 strips, not 9) |

So under power Pacman and the ghosts **swap pictures**: the strip chosen is the direction plus
`g_powerStrip` (0 or 4).

Unused on the disc (no reference in the EXE): `3FPAC.BMP`, `3FPACMAN.BMP`, `3O1OVO.BMP`,
`3SPCDB/CEB/CRB/CMP/SFB/SFP/EFP/RFP/DFP.BMP`, `BOYFREN1/T.BMP`, `GHOST.BMP`, `GHOSTS.BMP`,
`GHOSTA–D.BMP`, `LABIRIN*.BMP`, `PAC{UP,DOWN,LEFT,RIGHT}.BMP`, `PANEL.BMP`, `PBD/PBE/PPD/PPE.BMP`,
`STATNEW.BMP`, `TODOS.BMP`, `COCO.WAV`, `OSTRA.WAV`, `VELHA.MID` — the remains of an earlier
Pac-Man (`LABIRIN`, `GHOSTA–D`, `PACUP…`) and of other minigames.

**Sound.** MIDI `pac.mid` through MCI (alias `musica`), replayed from 0 on every MM_MCINOTIFY
success. Six waves through WaveMix (`sauna_scene_create` opens them in this order):

| Global | File | Played by |
|---|---|---|
| `g_powerWave` `7cb4` | `pacman2.wav` (0.5 s) | a cork is eaten (`sauna_power_waves`) |
| `g_eatGhostWave` `7cb8` | `pacman4.wav` (2.1 s) | a ghost is eaten (`sauna_eat_ghost`) |
| `g_eatPeanutWave` `7cbc` | `pacman.wav` (0.1 s) | a peanut is eaten (`sauna_eat_peanut`) |
| `g_caughtWave` `7cc0` | `pacman3.wav` (3.6 s) | Pacman is caught (`sauna_lose_life`) |
| `g_powerLoopWave` `7cc4` | `control.wav` (5.1 s), looped | during the power mode; stopped by `sauna_power_stop_wave` |
| `g_paintWave` `7cc8` | `ROLHAS01.WAV` (11.9 s) | APPWNDPROC on every WM_PAINT |

**The actors.**
- **Pacman** (`g_pacman`, `pacman_ctor`, built by `sauna_game_create_player`): starts at (300, 304)
  (`0x130`), 9 strips, timer id 0x10 at 55 ms, step 16 px, hit box 24×24 at (8, 8).
- **Four ghosts** (`SaunaScene.ghosts`, `ghost_ctor`, built by `sauna_scene_ctor`): all four with
  the **same arguments**, home at (300, 230) (`0xe6`), timer id **0x11** shared by design (the
  handler steps all four on `ghosts[0]`'s id), 8 strips. Message 0x401 seeds `rand` with
  GetTickCount and calls each ghost's `ghost_choose_direction`.

## The game

*Sauna Mista* is Pac-Man in a sauna; `GAME.md` describes it. In short: arrows (or a left click)
send Pacman along the maze in 16-px steps; a peanut is +100, a cork +0 and 5 s of power (the
pictures swap, the ghosts flee, a ghost eaten is +500 and goes home); a ghost met unpowered costs
500 and a life; all 100 dots won (+1000), the third life lost (−1000) ends it.

## How it talks to NOITE

- NOITE (`handler_3fsauna`) runs `sauna\sauna.exe`, polls `FindWindow("Sauna Mista")` on timer
  0x14 and posts 0x40b with its window in lParam; APPWNDPROC stores it in `g_noiteWnd`.
- **0x40c** ("ready"): APPWNDPROC posts it once (`g_handshakePending`), with SAUNA's window in
  wParam, on the first message after `g_started` that finds `g_noiteWnd` set.
- **0x40a** (result): the scene handler's `WM_DESTROY` case posts `(wParam, (long)g_score)` after
  adding ±1000: wParam 0xffff from the win, 0 from the last life or any other destroy (End Task).
- If the window vanishes without 0x40a, NOITE's system timer posts itself `(0x40a, 0, 0)`.

## Original bugs

In `BUGS.md`, section SAUNA (P1–P9, and a Harmless list).

## Decompiler residue

- The calls into the 32-bit segments and the CRT function-pointer calls keep the default model.
- The remaining parameters are `undefined2` words; far pointer parameters show as two words.

## Unknown

- `g_unk0F94` (300 dwords), `Game` 0x14–0x17, `Backdrop` 0x2a–0x2d, `Animation.unk12`,
  `FrameCell`.
- `SceneObjectVtbl.slot43` (Player2D's `player2d_as_scroll_target` returns the object).
- The letters of the `3SP??B/P` names (two picture sets, `B` and `P`, swapped by the power mode).

## Scripts

| Script | Use here |
|---|---|
| `DefineStrings.java` | `zig-out/sauna/strings.arg` (124 strings) |
| `FarVtables.java` | `/sauna 10a0 <vt.spec>`: 14 vtable structs, 2 vbtable structs, 61 tables applied |
| `NearStructs.java` | `/sauna <cls.arg>`: the 27 class structs (far pointers as `T*32`) |
| `NearGlobals.java` | `/sauna <glob.arg>` and two more |
| `SaunaFarThisTypes.java` (new) | `/sauna <this.arg>`: far `this` + `__stdcall16far` word signature from `RETF n` |
| `FarSlotSignatures.java` | `10a0 defs large`, `10a0 calls large`, `10a0 site large …` (`FUNCTIONS.md`) |
| `CopyTypesFromProgram.java` | `/TIRO.EXE SetSystemTimerFn KillSystemTimerFn`, `/NOITE.EXE CrtFILE` |
| `UndefinedRanges.java`, `DumpListing.java` | the checks above |

Scratch in `zig-out/sauna/`: `vtspec.py`, `cls.spec`, `glob.spec`, `thisspec.py`, `offs.py`,
`gs/SaunaRun.java` (runs a script with an argument read from a file).
