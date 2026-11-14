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
| Class structs | 18 in `/jardim` (3 verified field by field from NOITE, the others skeletons with size, vptr and vbptr) |
| Globals typed | 57 (50 named), plus the strings |

## DGROUP map

| Range | Contents |
|---|---|
| `0000–000f` | Windows instance header |
| `0010` | `g_unk0010` byte = 0x0a, read by the draw code (TIRO's `g_unk00A8` = 0x0b) |
| `0016–0061` | `s_appName` "Noite Animal Jardim" (class, title, NOITE's `FindWindow` target, NE description), `s_appIcon`, `s_alreadyRunning`, `s_userModule` ×2; `002a` **`g_noiteWnd`**, `005e` `g_started`, `0060` `g_noiteAcked` (NOITE's 0x40a seen) |
| `0062–0095` | `s_noiteClass`/`s_noiteTitle` ×2: "Noite Animal" (JARDIM looks NOITE up itself, `QUALITY.md` §8) |
| `0096–00b5` | Game state carried across the three phases: `009e`/`00a0` **`g_startX`/`g_startY`** (= 0x390, 0x30: the player's start, in 1/32 cells; the door sets 0x6d0, 0x30 for the next phase), `00a2` = 100, `00a4` = 3, `00a6–00aa`, `00ac` **`g_curWeapon`** (the hands' strip), `00ae` **`g_startTick`** (dword), `00b2` **`g_variant`** (NOITE's 0x40b wParam), `00b4` `g_startTickPending` (= 1) |
| `00bc–019d` | Labyrinth messages: `s_cellFormat` "(%2.2d,%2.2d)", `s_outsideLabyrinth`, `s_insideWall`, captions; `017c–019d` five HUD formats "%2.2d", "%3.3d", "%3.3d%%", "%3.3d", "%2.2d" |
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
| `1a02–1a21` | `g_labyrinthTables`: 7 far pointers filled by `1028:0077` and read by the renderer (`1028:0951`), and the two words `1a1e`/`1a20` |
| `2000–2011` | Labyrinth words (`1028:069b/0796/0f85/2191`) |
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
| **LabyrinthBackdrop** | `4842` (24: Backdrop + slot 0x17; slot 0 `1028:2191` create, 0x17 `1028:2609`) | – | `1028:0dfb`, `0ecb`, `0f85` | 0x73c | JARDIM (the raycaster) |
| Portable | `59d4` M, `59d8` S, `5b5c` O | `5b7c` {−4, 0x44, 0x4e2}, `5b82` | `1048:2aed`, `portable_ctor_zoom` `2cee`, `portable_ctor` `2ed8` | 0x502 | verified; **used for every pickup and enemy** |
| Moveable | `5b86` M, `5b8a` S, `5d0e` O | `5d2e` {−4, 0x34, 0x4d2}, `5d34` | `10c0:4d6c`, `4eee`, `506a`, `78a8` | | verified |
| Object3D | `5d38` O, `5d58` S | `5edc` {−4, 0x1a} | `10c0:4cde` | NV 0x1e | verified |
| Mover | `5ee0` M, `5ee4` S | `6068` {−4, 0x34} | `10c0:51ce`, `5336`, `549a` | NV 0x38 | verified |
| FlagCondition / Condition / CompoundCondition | `6284` / `6290` / `629c` ConditionVtbl | – | `10c0:606c` / `6226` / `610e` | – / – / 0xe | verified (by who calls the ctors) |
| Scene | `6c64` SceneVtbl (16, NOITE's; slot 0 `_purecall`) | – | `10c0:7a30`, dtor `1070:0075` | | verified |
| ControlPanel | `7b84` ControlPanelVtbl (14), `7bbc` S, `7d40` O | `7d60` {−4, 0xe8, 0x584}, `7d66` | `10c0:6e2e` | 0x5a4 | verified |
| **Player** | `7d6a` M, `7d6e` A, `7d86` S, `7f0a` O | `7f2a` {−4, 0x58, 0x4f6}, `7f30` (Animation) {−4, 0x22, 0x4c0}, `7f36` | `10c0:6cdc` (from `jardim_game_create_player`) | 0x516 | verified (overrides `isScrollTarget`, `isPlayer`, `asPlayer`, occupy/vacate, draw/tick/moveTick) |
| Actor | `7f3a` M, `7f3e` A, `7f56` S, `80da` O | `80fa` {−4, 0x52, 0x4f0}, `8100` {−4, 0x1c, 0x4ba}, `8106` | `10c0:72be` | | verified (Player's base) |
| **LabyrinthScene** | `810a` (24: SceneVtbl + 8 slots `slot10–slot17`; slot 0 `1028:5dba`, 0x17 `1028:5ef1`) | – | `10c0:7462`, dtor `10c0:8acc` | 0x90 | JARDIM |
| **Phase1Scene** | `834c` LabyrinthSceneVtbl (overrides in `1098` and `10c0:7630`) | – | `10c0:7076` (from `jardim_game_create_init_scene`), dtor `1098:0dd2` | 0x90 | JARDIM |
| Animated3D | `8186` A, `819e` S, `8322` O | `8342` {−4, 0x14, 0x4b0}, `8348` | `10c0:7166`, `77d0`, `8b4c` | | verified |
| Animation | `83ac` A, `83c4` S | `8548` {−4, 0x14} | `10c0:76a4`, `7ae8`, `8d24` | NV 0x18 | verified |
| **Unk8E60** | `8e60` S (one override: `attach` = `1028:47d6`) | – | `10c0:8a76` | 0x4a0 | JARDIM: the wall-texture strip object (`paredesN.bmp`, 6 textures of 32×300, map digits `1`–`6`) |
| Exit | `8fe4` A, `8ffc` S, `9180` O | `91a0` {−4, 0x5c, 0x4f8}, `91a6` | `10c0:8892` | 0x518 | verified (the door, `portainv.bmp`) |
| **Phase2Scene** | `91aa` LabyrinthSceneVtbl (overrides in `10a8`, `10c0:8cb0`) | – | `10c0:8afc` (from phase 1's `createNewScene`), dtor `10a8:0f38` | 0x94 | JARDIM |
| **Phase3Scene** | `92da` LabyrinthSceneVtbl (overrides in `10b0`, `10c0:925a`) | – | `10c0:920a`, dtor `10b0:0ed6` | | JARDIM |

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
- **AnimationVtbl** (6): `slot00` (sets the word at +0x14), `slot01` (returns it), `slot02–04`
  (three identical stubs that call slot 1 and return 0, where NOITE has its AVI methods),
  `playOnce`. NOITE's 8 slots cannot be mapped one to one.
- **ControlPanelVtbl** (14): the 6 Animation slots, then `isOpen` (unverified),
  `getVisibleHeight`, `slide`, `drawInventory`, `isOutside`, `contains`, `getInventoryItemAt`,
  `drawInventoryItem` (NOITE's 9 without `isOnOptionsButton`).
- **LabyrinthBackdropVtbl** (24) = BackdropVtbl + `slot17`; **LabyrinthSceneVtbl** (24) =
  SceneVtbl + `slot10–slot17`. The new slots are named by number until phase 4 reads them;
  what is known: slot 0x10 is the hit handler (`1098:2dd3`, `10a8:38c5`, `10b0:264c`), 0x12 the
  per-phase tick (`1098:0f6e`, 6 KB).
- **FrameVtbl** (`getCell`), **MoverVtbl** (`placeAt`), **ConditionVtbl** (`evaluate`, `set`,
  `clear`).

Each slot is a far pointer to a `FunctionDefinition` (`<Vtbl>_<field>Fn`) copied from the
slot's target, with a DATA reference to the target. Pure virtual slots point to `_purecall`
(`10b8:0816`).

## Classes (`/jardim`)

The convention is TIRO's/ENCAIXE's: a class struct holds the non-virtual part; the SceneObject
virtual base follows at the vbtable's offset (+4, since the vbptr is at +4).

| Struct | Size | Confidence |
|---|---|---|
| `SceneObject` | 0x49e | **high**: NOITE's layout, field for field. Same size (every vbtable puts the Object3D base 0x49e after the SceneObject), and the `scene_object_attach`/`reattach`/draw functions use NOITE's offsets (`a`, `2a–30`, `44e`, `452`, `468–476`). `vtbl` is the 97-slot `/jardim/SceneObjectVtbl` |
| `Object3D` | 0x1e | high: NOITE's (vbtable {−4, 0x1a} → SceneObject at +0x1e) |
| `Mover` | 0x38 | high: NOITE's fields (vbtable {−4, 0x34} → SceneObject at +0x38); the Mover methods read `this+0x430/0x432` for SceneObject fields that NOITE reads at `0x42e/0x430`, consistent with the 2-byte larger Mover subobject in front of the base |
| `Animation` | 0x18 | medium: vtbl, vbptr, `timerId`, `timerPeriod`, `playOnce`, `running` (NOITE's first fields); no AVI name (NOITE's is 0x114) |
| `Moveable`, `Portable`, `Animated3D`, `Exit`, `ControlPanel` | 0x38, 0x48, 0x18, 0x60, 0xec | skeletons: vtbl, vbptr and the size from the vbtables |
| `Actor`, `Player` | 0x56, 0x5c | medium: Actor = Mover part, `animation` at 0x36 (its vbptr is at 0x3a: {−4, 0x1c} → SceneObject at 0x56), `inventory` `ObjectList` at 0x4e; Player = Actor + `lives` (0x56) + `score` long (0x58), NOITE's Player tail |
| `Game` | 0x560 | medium: vtbl, `scene` +4, `statusBar` +0xc, `controlPanel` +0x10, `player` +0x18, `globalObjects` +0x1c (from `game_init`) |
| `Scene`, `LabyrinthScene` | 0x90 | skeleton; LabyrinthScene: `backdrop` (far `LabyrinthBackdrop *`) +0x62, `sceneNumber` +0x8e, the phase's objects at +0x6a…+0x8a (below) |
| `Backdrop` | 0x452 | skeleton (NOITE's size) |
| `LabyrinthBackdrop` | 0x73c | medium: `playerX`/`playerY` long +0x452/+0x456 (fixed point, 32 per cell), `wallRows` `char far *[80]` +0x490, `objectRows` `SceneObject far * far *[80]` +0x5d0 (the 57×80 map, `raymapN.dat`), the HUD objects +0x71a (wall textures), +0x722 (the hands/weapon), +0x726 (the shot), +0x72a (the face), `score` +0x718, `hwnd` +0x732 |
| `Frame`, `ObjectList` | 0x1a, 8 | skeletons |

## The assets

All files are read from the current directory (`<CD>jardim`, NOITE's `_chdir`).

| What | Files | Notes |
|---|---|---|
| Maps | `raymap1/2/3.dat` | Text, 80 lines × 57 characters + CRLF (4,720 bytes). ` ` is floor; `1`–`6` walls (the texture index into `paredesN.bmp`, 6 × 32×300); `9`, `A`, `B`, `C`, `7`, `8` special cells (`8` at row 2, column 0 of map 1 and `7` in the bottom wall look like the entry and the exit door); the code checks columns < 0x39 and rows < 0x50 |
| Walls | `paredes1/2/3.bmp` (32×1800) | 6 textures each |
| Scene frame | `opcao1/2/3.bmp` (640×480), `labinter.bmp` (640×138) | the background around the 3D view, per phase |
| HUD | `rosto1/2/3.bmp` (44×330: 5 faces of 44×66), the five HUD formats | the face (health?), counters |
| Hands (weapons) | phase 1 `maos1` (fists), `maobest1` (crossbow), `maosuti` (bra); phases 2–3 `maosN`, `maobestN`, `maobazuN` (bazooka) | 230×170, 2 frames each; `g_curWeapon` selects the strip |
| Shots | `shot1/2/3.bmp` (64×270) | |
| Door | `portainv.bmp` (32×300) | the Exit object |
| Phase 1 objects | enemies `bussuf.bmp` (4 frames), `seios.bmp` (5 frames); pickups `besta`, `sutien1`, `medkit`, `chopp`, `acai`, `setas` | each a Portable placed at a fixed point of the map |
| Phase 2 objects | enemies `alemao`, `siri`; pickups `besta2`, `bazuka2`, `medkit2`, `chopp2`, `Camarao2`, `setas2`, `bomba2` | |
| Phase 3 objects | enemies `Chato`, `Bicho`, `espanf`, `vamanf`; pickups `besta3`, `bazuka3`, `medkit3`, `chopp3`, `Camarao3`, `setas3`, `bomba3` | |
| Music | `doom.mid` (MCI alias `musica`, looped on MM_MCINOTIFY) | the same in the three phases |
| Waves | 15 / 16 / 16 per phase (`g_phaseNWaves`) | `soco` (punch), `arcfle02` (crossbow), `ARROTO` (burp: the beer), `alivio` (relief: the medkit), `abrport2` (the door), `esmagar`, `berro`, the enemies' own (`seio`, `siri2/3`, `chato`, `bicho`, …) |

Not on the disc: the Player's `passo1/passladd/passlade/passolau/passtras.bmp` (the five-strip
table at `030c`; the player is never drawn in a first-person view, so the missing files may never
be loaded). On the disc and never named by the program: `1fase`, `garden`, `garden2`, `inter`,
`inter1`, `intrface`, `luiz1–5`, `noite1`, `opcao`, `opcao2a/2b/3o`, `statnew`, `walls*`,
`brick`, `green*`, `redbric*`, `door`, `parede1–6`, `paredes`, `ceu1`, `chao1/3`, `bussu`,
`maos`, `maosbest`, `maobazuk`, `sutishot`, `setashot`, `shot`, `rosto`, `ctrlsoco`, `panel`,
the unsuffixed `bazuka`/`bomba`/`camarao` and several waves (`arcflech`, `bara01`, `besta`,
`biblia`, `busrang3`, `camar1`, `chopp2`, `duuuu`, `oops`, `parede`, `raiva`, `seio3`, `siri`,
`siri4`, `toing`): development leftovers.

## The game, as far as the data shows

*Noite Animal Jardim* is a **first-person, Doom-like raycaster** in three phases (levels), each a
57 × 80 labyrinth from `raymapN.dat`, drawn by the 32-bit column loops in `1008`/`1010` and the
scaled-sprite copies of `1068`/`1018`.

- **Moving:** the keyboard, polled with `GetKeyState` (8 calls in `1028`; which keys is a
  phase-4 question); the position is fixed point (32 units per cell,
  `LabyrinthBackdrop.playerX/Y`).
- **Weapons:** fists, the crossbow (`besta`) and, in phase 1, the bra (`sutien`); the bazooka in
  phases 2–3. The pickups (`besta`, `sutien1`, `bazuka`) give the weapon, `setas`/`bomba` its
  ammunition (inferred from the names), `medkit` (`alivio.wav`) and `chopp` (`ARROTO.WAV`),
  `acai`, `camarao` look like health/food.
- **Enemies:** two Portables per phase in the scene at +0x72 and +0x76 (phase 1 `bussuf`,
  `seios`). The hit handler (LabyrinthSceneVtbl slot 0x10) kills an enemy only with the right
  weapon: in phase 1 the +0x76 enemy needs weapon 2 (+100 points) and the +0x72 one weapon 1
  (+200); in phase 2 the +0x76 one needs weapon 2 (+100), the +0x72 one any weapon (+200); in
  phase 3 the +0x76 one any weapon (+100) and the +0x72 one gives +200 **without being
  removed** (J3 below). A killed enemy's map cell is cleared.
- **The door:** SPACE (WM_KEYDOWN 0x20) on a cell whose map value is 7 or 8 sets the next phase's
  start (`g_startX/Y` = 0x6d0, 0x30) and posts 0x402 (exit) to go to the next phase scene
  (phase 1's `createNewScene` builds Phase2Scene, phase 2's Phase3Scene).
- **The result** (`1028:2609`, `QUALITY.md` §8): a loss posts `0x40a` with wParam 0 and
  score − 1000; a win (the last door) posts wParam 1 and score + 10⁹ / elapsed ms (see J1).
  The score is `LabyrinthBackdrop.score`; the time counts from the first labyrinth.
- **The variant** (`g_variant`, NOITE's wParam: 1 from the cutscene `espquete`, 0 from
  `4fjarvamp`) is read once, by the phase 3 create (`10b0:0000`); what it changes is a phase-4
  question.

## Candidate original bugs (for later)

- **J1** (`QUALITY.md` §10): the time bonus mixes a sign-extended 16-bit tick with the 32-bit
  start tick.
- **J2** (`QUALITY.md` §10): 0x40c is re-posted on every window message until NOITE answers.
- **J3**: in phase 3 the hit handler (`10b0:264c`) adds 200 for the +0x72 enemy but never clears
  its map cell (phases 1 and 2 do), so every hit scores again and the enemy stays. To check
  against the tick (it may be removed elsewhere).
- **J4**: the Player's five strip files (`passo1.bmp` …) are not on the disc; if anything loads
  them, `load_dib` fails ("Não foi possível abrir o arquivo").

## Unknown

- The new LabyrinthSceneVtbl slots 0x11, 0x13–0x17 and LabyrinthBackdropVtbl slot 0x17 (named
  by number).
- `g_unk0010`, `00a2–00aa` (100, 3, 0, 1, 0: likely health, lives and counters carried across
  phases), `1a02–1a21`, `2000–2011`, `0162–017b` (`1028:2609`'s state).
- The fields of the skeleton structs, `Frame`, `ObjectList`; the AnimationVtbl and
  ControlPanelVtbl slot names other than `playOnce`, `getVisibleHeight`, `slide`, `isOutside`,
  `getInventoryItemAt`, `drawInventoryItem`.
- What the special map cells `9`, `A`, `B`, `C` are.

## Scripts (`ghidra/scripts/`)

| Script | Use here |
|---|---|
| `DefineStrings.java` | the 254 strings (`zig-out/jardim/strings.arg`, read from a file by an inline copy) |
| `FarVtables.java` | the 12 vtable structs, 2 vbtable structs and the 63 tables, with `dataseg` = `10c0` (`zig-out/jardim/vt.spec`) |
| `NearStructs.java` | the 18 class structs in `/jardim` (`cls.spec`; it takes far pointers as `T*32`) |
| `NearGlobals.java` | the globals (`glob.spec`, `glob2.arg`) |

The inline copies (`Jardim<Script>`) only add `@file` arguments, since the specs are longer than
a command line. Not done yet: `FarSlotSignatures.java` (its `defs` step types `this` as a near
pointer and its call resolution needs typed `this`; adapt it for 4-byte `this` once phase 4 has
typed the methods).
