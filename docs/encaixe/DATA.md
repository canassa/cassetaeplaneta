# ENCAIXE.EXE: data map

DGROUP is Ghidra segment `1018` (0x14bd bytes initialised, 0x5410 allocated). All addresses
below are `1018:` unless they say otherwise. Types live in the data type category `/encaixe`.
ENCAIXE is small-model: data and `this` pointers are 2 bytes, vtables hold near offsets into
`1008`. See `QUALITY.md` §0.

## Counts

| What | Count |
|---|---|
| Strings defined (Latin-1, exact length) | 66, all named `s_camelCase` |
| Vtables / vbtables defined | 41 / 20, typed and named |
| Vtable structs / vbtable structs | 12 / 2 (`Vbtable`, `Vbtable3d`) |
| Class and record structs | 27 (incl. near `CrtFILE`) |
| Functions with a typed `this` | 265 |
| Globals typed (non-string, non-table) | 116; 97 named |
| Undefined bytes left in DGROUP | 0x48 (72), see the end |

## DGROUP map

| Range | Contents |
|---|---|
| `0000–000f` | Windows instance header (`g_instOldSp` … `g_instStackBot`; the CRT reads `000a/000c`) |
| `0010` | `g_nextId`: the next SceneObject id (NOITE has it at the same offset) |
| `0012` | `g_unk0012` byte (13 reads by the draw code; NOITE `g_unk001C`) |
| `0014` | `s_appName` "Encaixe Perfeito" (class, title) |
| `0026–0034` | `g_noiteWnd`, `g_score`, `g_started`, `g_handshakePending`, `g_keyLeft/Right/Up/Down` (game_handle_message) |
| `0036–003c` | handle_message state: 2 flags, a `SceneObject*` from the panel, a word (unnamed, typed) |
| `003e–006d` | the piece strip tables (below) |
| `006e–0074` | `g_pieceKeyRight/Left/Up/Down`: arrow keys held, in the Tetris scene's handler |
| `0076` | word = 1, unreferenced |
| `0078–00cf` | WaveMix: `g_waveMixOpenResult`, `g_waveMixSession`, `g_waves` (20 far), `g_waveCount` |
| `00d0–0236` | CRT data (names follow NOITE's `g_crt*`, near pointers): startup args, rand seed, errno, PSP, OS version, `_osfile[40]`, argc/argv/environ, `_output` state table, `(null)`, heap hook, last iob, float hooks, `_days`/`_lpdays`, tz (`TZ`, timezone, daylight, "PST"/"PDT", tzname), dosmaperr table, `_amblksiz` |
| `0238–02f3` | `"\"` ×2 (`_searchenv`?), engine error strings, `s_empty` at `024a` |
| `0302–06f3` | vtables and vbtables (part 1) |
| `06f4–0951` | engine/app strings, the bitmap file names |
| `0952–108d` | vtables and vbtables (part 2), `07fe` sits inside the strings |
| `108e–1215` | font, MCI, WaveMix strings, `%06d` |
| `1218` | `g_crtInitHook`: far pointer `1010:002e` (NE-relocated segment), the static-init stub that builds the two FlagConditions |
| `121e–1229` | CRT `_cinit` far hooks (typed, unnamed) |
| `122a` | `g_crtExitTable`: one near entry, `1008:14c2` |
| `122c–136b` | `g_crtIob` (`CrtFILE[20]`, 8 bytes each), `g_crtIob2` (20 × 8) |
| `136c–14bc` | `<<NMSG>>`, the R6xxx table (id word + string, ends `ffff` at `14ba`) |
| `14be–294e` | **`g_occupancyCount`** `char[65][81]` |
| `2950–5271` | **`g_occupancyObject`** `SceneObject*[65][81]` |
| `5272–5279` | `g_setSystemTimer`, `g_killSystemTimer` (USER.11 / USER.182) |
| `527a–5285` | `g_instance`, `g_mainWindow`, `g_appActive`, `g_windowWidth` (640), `g_windowHeight` (480) |
| `5286–538d` | `g_modulePath` (far, → `528a`), `g_modulePathBuf[260]` |
| `538e–53f1` | `g_messageText[100]`: message_box_printf's buffer |
| `53f2–53f7` | `g_game` (`Game*`), `g_tetrisGame` (the same object, stored by the derived ctor), `g_piece` (`Piece*`) |
| `53f8–53ff` | `g_conditionTrue`, `g_conditionFalse` (`FlagCondition`, value 1 / 0) |
| `5400–5405` | `g_tetrisWave` (far, tetris2.wav), `g_moduleHandle` (GetModuleHandle of the EXE path, for WaveMixOpenWave) |
| `5406–540f` | `g_crtSprintfFile`, `g_crtTzsetDone` |

The 0x3db4-byte BSS block at `14be` is NOT a Tetris board: it is NOITE's occupancy matrix
(65 rows × 81 columns, byte counts then near object pointers; `IMUL 0x51`; the
"matriz de ocupação" overflow checks compare against 0x41 and 0x51). The two arrays fill
`14be–5271` exactly, with one pad byte at `294f`.

## The Tetris board and the pieces

- **Board:** `Piece.board` (`char[11][14]` at `Piece+0x52`, 154 bytes), inside the player
  object `g_piece`. Cells are ASCII `'0'` (empty) and `'1'` (filled); a new game fills it
  with `'0'` (`b9e2`, `STOSD` × 0x26 + `STOSW`). The first index (stride 14) is the column
  (`Piece.column`, `+0xec`, checked `< 11`), the second the row (`Piece.row`, `+0xee`), so
  the playfield is 11 columns × 14 rows, stored column-major. A new piece starts at column 4,
  row 0 (`b898`). Cells are 32 px (the backdrop's grid uses shift 5).
- **Pieces:** 6 kinds, chosen with `rand() % 6` and kept in the SceneObject's `curStrip`; the
  rotation is 0–3. The shapes are **not tables**: `b898` (spawn), `bb2e`, and the four
  per-direction giants `c41a/ce8c/d960/e392` are `switch (kind) switch (rotation)` code
  that tests and writes the board cells directly. There is no shape or rotation table in
  DGROUP or in the code segment.
- **Piece bitmaps:** `g_pieceStripFiles` (`char*[6]` → `peca.bmp`, `pecaa–e.bmp`),
  `g_pieceStripFrames` (`int[6]`, all 4: one frame per rotation), `g_pieceStripWidths` and
  `g_pieceStripHeights` (`int[6]`, all 128). createPlayer (`9e74`) passes the four arrays to
  the Player2D constructor.
- **Timers:** no timer-id globals. The window timer is the constant id 1 (SetSystemTimer,
  50 ms); objects keep their own ids in `Mover.timerId` and `Animation.timerId`.
- **Bitmaps:** no bitmap-handle globals; they live in `Backdrop` (two WinG DCs/bitmaps, the
  background DIB) and in each `Frame` (`dib`, far).
- **MCI:** no state in DGROUP; the device is addressed by its alias ("musica").

## Vtables

`S` = SceneObjectVtbl (93 slots), `O` = Object3DVtbl (8), `M` = MoverVtbl (1), `A` =
AnimationVtbl (1), `vb` = vbtable. "Verified" means the class follows from its constructor
(the vptr stores, the vbtable offsets and the operator new size) and the slot overrides
agree with NOITE's class.

| Class | Tables | Ctor | Size | Status |
|---|---|---|---|---|
| Frame | `0302` FrameVtbl (`getCell`) | `6716` | 0x16 | verified (new in ENCAIXE: NOITE's Frame has no vtable) |
| SceneObject | `0304` S | `8014` (dtor) | 0x46c | verified |
| Object3D | `03be` O, `03ce` S | inline | 0x16 + vbase | verified |
| Mover | `0488` M, `048a` S, `0544` vb | `6418` | 0x32 + vbase | verified |
| Portable | `0548` M, `054a` S, `0604` O, `0614`/`061a` vb | none | 0x56 + vbase | dead: no vptr store, no ctor; derives Moveable; methods `portable_*` |
| Moveable | `061e` M, `0620` S, `06da` O, `06ea`/`06f0` vb | `661c` | SO 0x34, O3D 0x4a2 | verified |
| Game | `07fe` GameVtbl (7, slot 6 pure) | `9e28` | 0x2b4 | verified |
| Backdrop | `0952` BackdropVtbl (19) | inline in `a7d4` | 0x456 | verified |
| Animated3D | `0978` A, `097a` S, `0a34` O, `0a44`/`0a4a` vb | `ade4` | SO 0x10, O3D 0x47c | verified |
| Animation | `0a4e` A, `0a50` S, `0b0a` vb | `ae7a` | 0xe + vbase | verified |
| TetrisPanel | `0b0e` ControlPanelVtbl, `0b20` S, `0bda` O, `0bea`/`0bf0` vb | `a59e` | 0x566 | verified (the game's panel, derives ControlPanel) |
| GridBackdrop | `0bf4` GridBackdropVtbl (20) | inline in `a7d4` | 0x458 | verified |
| Actor2D | `0c1c` M, `0c1e` A, `0c20` S, `0cda`/`0cde` vb | `aa92` | 0x40 + vbase | verified |
| Player2D | `0ce2` M, `0ce4` A, `0ce6` S, `0da0`/`0da4` vb | `a520` | 0x46 + vbase | verified |
| Scene | `0da8` SceneVtbl (13, slot 0 pure) | inline in `a08c` | 0x44 | verified |
| StatusBar | `0dc2` S | inline in `9fb2` | 0x53a | verified |
| ControlPanel | `0e7c` ControlPanelVtbl (slots 7–8 pure), `0e8e` S, `0f48` O, `0f58`/`0f5e` vb | `acfe` | 0x566 | verified (abstract) |
| TetrisGame | `0f62` GameVtbl | `9e28` | 0x2b4 | verified |
| TetrisScene | `0f70` SceneVtbl | `a08c` | 0x44 | verified |
| Piece | `0f8a` PieceVtbl (3), `0f90` A, `0f92` S, `104c`/`1050` vb | `9e74` | 0x578 | verified (the player: derives Player2D) |
| TetrisBackdrop | `1054` GridBackdropVtbl | inline in `a7d4` | 0x458 | verified (overrides `create` with a 32-px grid and the wall cells) |
| FlagCondition | `107c` ConditionVtbl | `b064` | 4 | verified |
| CompoundCondition | `1082` ConditionVtbl | none | 8 | layout from `b0c6`; never constructed |
| Condition | `1088` ConditionVtbl (slot 0 pure) | `b064` | 2 | verified |

Labels are `g_<class>Vtbl` for the primary table, `g_<class>SceneObjectVtbl`,
`g_<class>Object3dVtbl`, `g_<class>AnimationVtbl`, and `g_<class>Vbtbl` /
`g_<class>Object3dVbtbl` / `g_<class>AnimationVbtbl` for the vbtables. Each slot is a 2-byte
pointer to a `FunctionDefinition` copied from the base target; its default reference (to
`1018:`) is replaced by a DATA reference to `1008:`. A pure virtual slot holds 0.

The Portable tables (`0548–061d`) have no vptr store; the class is reached only through them
(its methods are `portable_*`, with thunks). Actor, Player and Exit have methods but no tables
(`actor_*` `603c–628c`, `player_*` `3a5c–3a9c` and `6312–6330`, `exit_*` `3b04`, `3b8a`,
`6334–637c`), all unreferenced. `7f56` is `object_list_contains`.

**SceneObjectVtbl, 93 slots vs NOITE's 102** (by the override pattern of the 12 tables
against NOITE's tables, by RET sizes and by body similarity). Field names are NOITE's.
- Missing in ENCAIXE: NOITE `00 01 02 03 04` (slot00/01, enableRle, isRle, getSceneName),
  `29` reoccupy, `2D` isAvi, `36` advanceFrames, `42` isScrollTarget, `43` slot43, `4A/4B`
  isAnimated3D/asAnimated3D.
- New in ENCAIXE: `11` (`unk11`, GetDC/ReleaseDC then returns `this`), `18` (`unk18`, a
  draw variant), `4E` (`unk4E`, returns `""`; Portable returns `prevSceneName`).
- ENCAIXE slot = NOITE slot − k (hex slot indices; byte offset = 2 × slot here, 4 × slot in
  NOITE):

  | ENCAIXE | NOITE | k | First / last |
  |---|---|---|---|
  | `00–10` | `05–15` | 5 | getWorldX … setWorldElev |
  | `12–17` | `16–1B` | 4 | drawBounds … draw |
  | `19–25` | `1C–28` | 3 | drawClipTo … vacate |
  | `26–28` | `2A–2C` | 4 | attach … isStepBlocked |
  | `29–30` | `2E–35` | 5 | nextFrame … stop |
  | `31–3B` | `37–41` | 6 | moveTo … setPosition |
  | `3C–41` | `44–49` | 8 | isPlayer … asAnimation |
  | `42–4D` | `4C–57` | 10 | isMover … asPortable |
  | `4F–5C` | `58–65` | 9 | redrawOverlapping … slot65 |

- Less certain: `18/19/1A` (which of the three never-overridden draw slots is new) and `11`
  vs `12` (one of the two Object3D-overridden `return this` stubs draws the 3D box: that one
  is `drawBounds`).

The other vtables, against NOITE: Object3DVtbl 1:1 (8); BackdropVtbl = NOITE `00–12` (the four
type tests are gone), GridBackdropVtbl adds `createWithGrid`; SceneVtbl = NOITE `00–0C` (slot
12 `getExit`, `a7ac`; slot 5 `createScreen`, TetrisScene's is `a7d4`, which builds the
backdrop);
GameVtbl drops handleMessageHook and createExitScene: `handleMessage, createPlayer,
createInitScene, createControlPanel, createStatusBar, init, onCreate` (WM_CREATE calls slot
6); ControlPanelVtbl is AnimationVtbl's one slot (`playOnce`, AVI removed) plus NOITE's
ControlPanel slots minus `isOnOptionsButton`; PieceVtbl = `placeAt` (Mover's), `tryStep`
(`te_piece_try_move`, switch on direction 1/2/4/8 into the four workers), `moveTick`
(`te_piece_step_move`). `0e7c` is the abstract ControlPanel's ControlPanelVtbl; the game's
panel is TetrisPanel (`0b0e`).

## Classes (`/encaixe`)

Class structs hold the non-virtual part, as NOITE's do. In a most-derived object a 2-byte
vtordisp word follows that part and the SceneObject virtual base comes right after it (at the
vbtable's offset). The structs that other structs embed as a base leave the vtordisp word
out; the leaf classes include it as a `vtordisp` field:

| Struct | Size | vtordisp | SceneObject vbase |
|---|---|---|---|
| `Animation` | 0xe | +0xe (not in the struct) | +0x10 |
| `Mover`, `Moveable` | 0x32 | +0x32 (not in the struct) | +0x34 |
| `Actor2D` | 0x40 | +0x40 (not in the struct) | +0x42 |
| `Player2D` | 0x46 | +0x46 (not in the struct) | +0x48 |
| `Portable` | 0x56 | `vtordisp` +0x54 | +0x56 |
| `ControlPanel` | 0xe4 | `vtordisp` +0xe2 | +0xe4 (Object3D +0x552) |
| `Piece` | 0x10c | `vtordisp` +0x10a | +0x10c |

Each struct's description in Ghidra says the same. Methods that override a SceneObject
virtual get `this` = the SceneObject subobject and reach their own fields at negative
offsets, so they are not `this`-typed.

| Struct | Size | Confidence |
|---|---|---|
| `SceneObject` | 0x46c | high: StatusBar (0x53a − 0xce) and the vbase gaps agree; fields from attach (`72e0`), the StatusBar ctor and the occupancy code. `10/12` unknown. No sceneName, wave or RLE fields (their slots are gone too) |
| `Frame` | 0x16 | high: vptr, `cells` (8-byte `FrameCell`, unknown), width, height, count, far dib, hit rect |
| `Object3D` | 0x16 | high: the eight getters |
| `Mover` | 0x32 | medium: NOITE's fields at −4 (the far vtbl/vbptr shrink); `direction` (+8) and `moving` (+0x30) verified, `allowOffscreen` gone |
| `Moveable` | 0x32 | high: only its Mover base (Moveable's SceneObject is at +0x34, Object3D at +0x4a2) |
| `Portable` | 0x56 | high for the fields read by `portable_pick_up/drop/draw_icon` and `63ba`: Moveable +0, `owner` +0x32 (its inventory list at owner+0x40), `prevSceneName` +0x34 `char[19]`, far `icon` DIB +0x4a, `iconW` +0x50, `iconH` +0x52; `48`, `4e` unknown. Unlike NOITE's: no scores, no home scene, no icon path |
| `Animation` | 0xe | high: timerId +4, timerPeriod +6, framesLeft +8, playOnce +0xa, running +0xc (isRunning `5626` returns this−4 = +0xc; play `7ce8` sets +0xc = 1, +0xa = 0) |
| `Actor2D`, `Player2D` | 0x40, 0x46 | high (Player2D lives + long score) |
| `Piece` | 0x10c | partial: board, column, row, rightCol, canFall, linesCleared verified; `46`, `48`, `4e` (written only), `f2–108` (written by the dead `bc72` only) unknown |
| `ControlPanel` | 0xe4 | high: Animation +0, isOpen, slideDir, slideStepsLeft, `textColor` +0x14 (dword), `text[200]` +0x18, `textX` +0xe0 (as StatusBar's; `control_panel_draw_texts`) |
| `StatusBar` | 0x53a | high |
| `Game` | 0x2b4 | high: ctor/dtor/defaults; `UpdateList` holds 30 items here (NOITE 100), DrawList 100 nodes |
| `Scene` | 0x44 | high for the ctor-written fields; `exits[10]` inferred from the gap |
| `Backdrop`, `GridBackdrop` | 0x456, 0x458 | high: create (`8414`); has a second WinG DC/bitmap (`c–13`) that NOITE lacks; `24/26` unknown |
| `OccupancyGrid` | 0xc | high |
| `ObjectList`, `UpdateList`, `DrawList(Node)` | 6, 0x3e, 0x25c (6) | high |
| `Condition`, `FlagCondition`, `CompoundCondition` | 2, 4, 8 | high |
| `CrtFILE` | 8 | high (near `_iob` entry) |

## Undefined bytes left in DGROUP (0x48)

- One-byte NUL pads after odd-length strings or tables (`0013`, `0025`, `01b7`, `020b`,
  `0249`, `024b`, `0301`, `0743`, `07a5`, `07fd`, `0819`, `087f`, `08a5`, `08cd`, `08f7`,
  `090d`, `0951`, `10c5`, `10d9`, `110d`, `113d`, `1155`, `115b`, `1191`, `119f`, `1201`,
  `1217`, `294f`).
- Unreferenced CRT words: `00dc–00e3` (`0000 0001 ffff 0000`), `00fa–0103`, `0106–0109`,
  `0112` (02), `0118` (0x14), `014e–0150`, `0152–0153`, `01ce–01d3`, `0232–0233`,
  `121c–121d`.
- `14bc–14bd`: tail after the NMSG end marker.
- `527e–527f`: an unreferenced app word between `g_mainWindow` and `g_appActive`.

## Unknown

- The 19 typed-but-unnamed globals: handle_message's `0036/0038/003a/003c`, `0076`, `0234`,
  the three `_cinit` far hooks at `121e–1229`, and the NMSG id words.
- `g_unk0012` (byte read by the draw code), `Game.unk0A`, `Game.unk2AE` (= 2).
- `FrameCell` (8 bytes), the Piece fields listed above, Portable `48`/`4e`, the Mover fields
  other than direction/moving and the Bresenham/timer fields.
- The `_iob` entries' flag/file bytes read `01 14`, `02 14`, `02 14`; the 0x14 is not a
  file number, so the near `CrtFILE` layout of the last two bytes is unconfirmed.

## Scripts (`ghidra/scripts/`)

| Script | Use |
|---|---|
| `DumpListing.java` | Dumps every instruction (with refs) and every data item to TSVs for offline access analysis. Args: `<outdir>` |
| `DefineStrings.java` | Strings with an exact length and the ISO-8859-1 charset, named. Args: `seg:off:len[:name];…` |
| `NearVtables.java` | Small-model vtable structs (near function pointers built from the slot targets), applies them and replaces the bogus DGROUP slot references by code references. Args: `<cat> <codeseg> <dataseg> <spec>` |
| `NearStructs.java` | Unpacked structs at explicit offsets in a category, two passes. Args: `<cat> Name@size=off:name:type,…;…` |
| `NearThisTypes.java` | Types the first parameter as a near `Struct *this`. Args: `<cat> Struct=seg:off,…;…` |
| `NearGlobals.java` | Typed, named globals (near/far pointers, nested arrays). Args: `<cat> seg:off:name:type;…` |
| `UndefinedRanges.java` | Lists undefined runs in a block and stale `undefinedN` items. Args: `<seg:off>` |

Run them with `run_ghidra_script` and the absolute path (it copies the file into
`~/ghidra_scripts`; delete the copy afterwards). The offline matchers (`acc.py`, `track.py`,
`align.py`, `multi.py`, `region.py`) and the specs used are scratch in `zig-out/encaixe/p3/`.
