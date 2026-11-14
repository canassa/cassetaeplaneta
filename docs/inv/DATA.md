# INV.EXE: data map

DGROUP is Ghidra segment `1090` (0x29a5 bytes initialised, 0x6926 allocated). Addresses are
`1090:` unless they say otherwise. Types live in the category `/inv`. INV is TIRO's
medium-model `/Od` build (`QUALITY.md` §0): near data and `this`, a near vptr into DGROUP, 4-byte
far vtable slots. TIRO's `docs/tiro/DATA.md` is the reference for the shared engine layouts.

## Counts

| What | Count |
|---|---|
| Strings defined (Latin-1, exact length) | 82, all named `s_camelCase` (TIRO's names where the text is the same), plus `s_nmsgMarker` `char[8]` |
| Vtables / vbtables applied, typed and labelled | 64 / 28 (92 tables) |
| Vtable structs | 16: TIRO's 13 (far slots) + `SaucerVtbl`, `MissileVtbl`, `InvaderVtbl`; plus `Vbtable`, `Vbtable3d` |
| Class and record structs | TIRO's engine set (copied with their slot `FunctionDefinition`s, 487 types in all) + 8 new: `Cannon`, `Saucer`, `Missile`, `Bomb`, `Shot`, `InvaderColumn`, `InvaderExplosion`, `InvaderCell`. TIRO's game types (`Crossbow`, `Target`, `Projectile`, `Arrow` and their vtables) were deleted |
| Globals typed and named (non-string, non-table) | 157: 87 transferred from TIRO, 70 set by hand |
| NULL-test comments (`NearNullTests`) | 14 (TIRO's 14) |
| Virtual-call overrides | 410 of 420 sites: 386 by `FarSlotSignatures calls`, 24 copied from TIRO's hand-checked sites |

## How the data was mapped

INV's DGROUP is TIRO's in shifted runs:

| TIRO range | INV | Shift | Why |
|---|---|---|---|
| `0000–00a9` | `0000–00a9` | 0 | Instance header, coordinate format, HDC/layer strings, `g_nextId`, `g_unk00A8` |
| `00ba–0101` | `00b4–00fb` | −6 | App globals after the app name ("Invasores" is 6 bytes shorter than "Tiro ao Alvaro") |
| `03e2–04f1` | `03a8–04b7` | −0x3a | WaveMix module data, the start of the CRT data |
| `04f6–0691` | `04b8–0653` | −0x3e | the rest of the CRT data; TIRO's `g_crtHoldRand` (4 bytes) went with `rand` |
| `228e–6319` | `26d6–6761` | +0x448 | CRT hooks, `g_crtIob`, the NMSG table, **the BSS** (occupancy matrix, timer pointers) |

An inline script (`zig-out/inv`, not committed) moved every non-string TIRO data item in those
runs (type mapped `/tiro` → `/inv`, label kept) and compared the initialised bytes. The only
differences are pointer values (code offsets that moved), as expected. Everything else (the game
tables, INV's own app globals and game objects) was typed from INV's accesses with
`NearGlobals.java`.

## DGROUP map

| Range | Contents |
|---|---|
| `0000–000f` | Windows instance header (`g_instReserved` … `g_instStackBot`) |
| `0010–00a5` | `s_coordFormat`, the HDC/layer overflow strings and captions |
| `00a6` / `00a8` | `g_nextId` / `g_unk00A8` (= 0x0b) |
| `00aa` | `s_appName` "Invasores": class, title, NOITE's `FindWindow` target |
| `00b4` | `g_noiteWnd` (set by 0x40b) |
| `00b6–00e7` | `s_appIcon`, `s_alreadyRunning`, `s_userModule` ×2 |
| `00e8–00fb` | `g_started`, `g_handshakePending` (= 1), then `game_handle_message`'s `g_keyLeft/Right/Up/Down`, `g_itemSelected`, `g_exitPending`, `g_selectedItem`, `g_dropElevation` |
| `00fc–01a7` | The 9 bitmap names and 6 strip tables (below) |
| `01a8–01b3` | `g_bombTimerIds` {6, 7}, `g_bombDropTimerIds` {8, 9}, `g_bombDropPeriods` {2000, 5000} |
| `01b4–01d9` | `panel.bmp` ×2, `s_fontFace` "Mech", `s_fontFile` "arialbd.fot" |
| `01da` | `g_formationDir` (= 2): the invaders' direction, 1 or 2 |
| `01dc` | `g_unk01DC` (= 0), read by the column code |
| `01de` | `g_invaderPeriod` (= 500 ms): the invaders' timer period |
| `01e0–0275` | MCI strings (`doom1.mid`, alias `musica`), the 8 wave names |
| `0276`, `0278` | `g_unk0276` (= 0x76), `g_unk0278` (= 0x3c, read by `1068:13a8`) |
| `027a–0285` | `g_keyRightHeld`, `g_keyLeftHeld`, 2 unreferenced words, `g_keySpaceHeld` (never set: the latch is dead, as in TIRO), `g_unk0284` (= 1) |
| `0286` | **`g_invadersLeft`** (= 20) |
| `0288` | `g_bombHitCannon[2]`: set when bomb *i* hits the cannon, cleared when it is dropped again |
| `028c–039f` | MCI and WaveMix strings, `s_negScoreFormat` "-%04d", `s_scoreFormat` " %04d", the visible-objects overflow strings |
| `03a8–03ff` | WaveMix: `g_waveMixOpenResult`, `g_waveMixSession`, `g_waves` (20 far), `g_waveCount` |
| `0400–049f` | WaveMix error strings |
| `04a0–0593` | CRT data (TIRO's layout, shifted as above) |
| `0594–05b3` | `g_crtFloatHooks` (7 far pointers to `_fptrap`) |
| `05d4–0653` | `s_fatalErrorCaption6`, `s_updateListFull` (`MAX_OBJECT_QTY`) |
| `0654–0dfb` | vtables and vbtables (part 1) |
| `0dfc–0fc3` | "Faltou redefinir o método Create…" strings, the occupancy overflow strings, `s_cannotOpenFile`, `s_backgroundBmp` "Espaco.bmp" |
| `0fc4–26d5` | vtables and vbtables (part 2) |
| `26d6–26eb` | `g_crtInitHook` (far → `init_static_conditions_entry`), the CRT hooks, `g_crtExitTable` |
| `26ec–282b` | `g_crtIob` (`CrtFILE[20]`), `g_crtIob2` |
| `282c–29a4` | `s_nmsgMarker`, `g_crtNmsgTable` (the R6xxx strings) |
| `29a6–3e36` | **`g_occupancyCount`** `char[65][81]` (BSS starts at `29a5`) |
| `3e38–6759` | **`g_occupancyObject`** `SceneObject*[65][81]` |
| `675a–6761` | `g_setSystemTimer`, `g_killSystemTimer` (USER.11 / USER.182) |
| `6762–676d` | `g_instance`, `g_mainWindow`, an unreferenced word, `g_appActive`, `g_modulePath` (far → `676e`) |
| `676e–6877` | `g_modulePathBuf[260]`, `g_windowWidth`, `g_windowHeight`, **`g_score`** (`6876`) |
| `6878–68db` | `g_messageText[100]` |
| `68dc–68f3` | `g_game`, `g_invGame` (the same object), **`g_cannon`**, **`g_saucer`**, **`g_shots[1]`**, **`g_bombs[2]`**, **`g_invaderColumns[4]`**, **`g_invaderExplosion`** |
| `68f4–68fb` | `g_conditionTrue`, `g_conditionFalse` (`FlagCondition`) |
| `68fc–691b` | the 8 waves (far): `g_shotWave`, `g_explosWave`, `g_saucerWave`, `g_explo1Wave`, `g_cannonHitWave`, `g_explo5Wave`, `g_marchWave`, `g_descendWave` |
| `691c–6925` | `g_moduleHandle`, `g_crtSprintfFile` |

Unlike TIRO, INV's app globals put `g_modulePath` after `g_appActive` and `g_score` after the
window size; TIRO's order is `g_modulePath`, `g_instance`, `g_mainWindow`, …, `g_score`,
`g_windowWidth`.

## The game data

### Pictures

Six strip tables, each `char *files[n]`, `int frames[n]`, `int widths[n]`, `int heights[n]`. The
class ctors take the four arrays and the strip count (TIRO's ctor shape):

| Table | Files (frames, w×h) | Class / object |
|---|---|---|
| `g_cannonStrip*` (`0112`, 2) | `Canhao.bmp` (1, 65×67), `Brocha.bmp` (7, 65×67) | Cannon `g_cannon`: the cannon and its destruction |
| `g_saucerStrip*` (`0138`, 2) | `Disco.bmp` (3, 61×32), `Explod.bmp` (8, 111×103) | Saucer `g_saucer`: the saucer and its explosion |
| `g_shotStrip*` (`0152`, 1) | `Tiro.bmp` (2, 12×22) | Shot `g_shots[0]` |
| `g_bombStrip*` (`0170`, 2) | `Bomba.bmp` (1, 12×22), `Bomtir.bmp` (3, 25×28) | Bomb `g_bombs[2]`: the bomb and its impact |
| `g_columnStrip*` (`018c`, 1) | `Movein.bmp` (2, 88×217) | InvaderColumn `g_invaderColumns[4]`: one picture is a column of invaders, 2 animation frames |
| `g_explosionStrip*` (`01a0`, 1) | `Naboom1.bmp` (8, 88×44) | InvaderExplosion `g_invaderExplosion`: one invader (88×44) exploding |

The background is `Espaco.bmp` (640×480, `inv_scene_create_screen`); `panel.bmp` is the control
panel's and the status bar's. **On the disc but not named in DGROUP:** `NABOOM.BMP` (92×490),
`EXPLO2/3/4.WAV`, `QUEDANAV.WAV` and `TIROESP.WAV`.

### Sounds

`doom1.mid` through MCI (alias `musica`: opened and played by `inv_scene_create`, looped on
MM_MCINOTIFY, paused/resumed on WM_ACTIVATE, closed on WM_DESTROY). 8 waves through WaveMix,
opened by `inv_scene_create`, each played by one helper:

| Wave | Global | Played by | When |
|---|---|---|---|
| `tiroes2.wav` | `g_shotWave` | `inv_play_shot_wave` | SPACE fires the shot |
| `explos.wav` | `g_explosWave` | `inv_score_invader_hit` | an invader is hit (+100) |
| `nave.wav` | `g_saucerWave` | `inv_play_saucer_wave` | the saucer passes |
| `explo1.wav` | `g_explo1Wave` | `inv_score_saucer_hit` | the saucer is hit (+500) |
| `brocha3.wav` | `g_cannonHitWave` | `inv_score_cannon_hit` | a bomb hits the cannon (−500) |
| `explo5.WAV` | `g_explo5Wave` | `inv_play_explo5_wave` | the shot meets a bomb |
| `marcha.wav` | `g_marchWave` | `inv_play_march_wave` | the formation steps |
| `desceniv.wav` | `g_descendWave` | `inv_play_descend_wave` | the formation goes down (to confirm) |

Unlike TIRO, APPWNDPROC plays nothing on WM_PAINT.

### Timers

Every object runs on its own WM_SYSTIMER id (the ctor's `timerId`/`timerPeriod`):

| Id | Period | Object |
|---|---|---|
| 1 | 50 ms | the app (APPWNDPROC, WM_CREATE) |
| 6, 7 | 55 ms | the bombs; second timers 8, 9 at 2000 / 5000 ms (`MissileVtbl` slot 1) |
| 0xa | 60 ms | the cannon |
| 0xc | 60 ms | the saucer; second timer 0xe at 10 s (`SaucerVtbl` slot 1) |
| 0xd | 55 ms | the shot |
| 0xf | `g_invaderPeriod` (500 ms, then faster) | the invader columns |
| 0x10 | 55 ms | the invader explosion |

## Vtables and classes

The engine tables are TIRO's classes one for one (`FUNCTIONS.md` has the matching); the labels
follow TIRO's scheme (`g_<class>Vtbl`, `g_<class>SceneObjectVtbl`, `g_<class>Object3dVtbl`,
`g_<class>AnimationVtbl`, `g_<class>Vbtbl`, `g_<class>AnimationVbtbl`). INV's roles replace TIRO's:
`g_invGameVtbl` (`117e`), `g_invSceneVtbl` (`11e6`), `g_invPanel*` (`0fc4`, `0fe8`, `1154`),
`g_invBackdropVtbl` (`1d46`).

The 7 INV classes. Sizes come from the vbtables (`{−2, k}`: the SceneObject sits at k + 2) and
agree with each `operator new` (class + the 0x46c SceneObject):

| Class | Tables | vbtables | Struct | `new` | Notes |
|---|---|---|---|---|---|
| **Cannon** : Player2D | `1876` M, `187a` A, `187e` S | `19ea` {−2,0x4a}, `19ee` {−2,0x18} | `Cannon` 0x4c | 0x4b8 | TIRO's Crossbow layout. `lives` (+0x40) = 4; `score` (+0x42, dword) gets +10 per invader, +50 per saucer (not reported: NOITE gets `g_score`); `hitFrame` +0x46 (−1 idle) |
| **Saucer** : Actor2D | `1dba` SaucerVtbl (4), `1dca` A, `1dce` S | `1f3a` {−2,0x50}, `1f3e` {−2,0x1e} | `Saucer` 0x52 | 0x4be | TIRO's Target layout. `timer2Id` +0x4c (0xe), `hitFrame` +0x4e |
| **Missile** : Actor2D | `1f42` MissileVtbl (3), `1f4e` A, `1f52` S | `20be` {−2,0x4c}, `20c2` {−2,0x1a} | `Missile` 0x4c | – | Abstract base: `unk42` +0x42, `timer2Id` +0x44, `hitFrame` +0x48, `hitState` +0x4a (a char: '0' none, '1' hit the other missile, '2' hit an invader, '3' hit the saucer, '4' hit the cannon) |
| **Bomb** : Missile | `20c6`, `20d2`, `20d6` | `2242`, `2246` (same) | `Bomb` 0x4e | 0x4ba | `vtordisp` +0x4c |
| **Shot** : Missile | `224a`, `2256`, `225a` | `23c6`, `23ca` (same) | `Shot` 0x4e | 0x4ba | `vtordisp` +0x4c |
| **InvaderExplosion** : Actor2D | `23ce` InvaderVtbl (3), `23da` A, `23de` S | `254a` {−2,0x76}, `254e` {−2,0x44} | `InvaderExplosion` 0x78 | 0x4e4 | `frameCounter` +0x4e; `42–75` mostly unread. Shares every slot override with InvaderColumn and is 6 bytes bigger: it may derive from it (to check in phase 4) |
| **InvaderColumn** : Actor2D | `2552` InvaderVtbl (3), `255e` A, `2562` S | `26ce` {−2,0x70}, `26d2` {−2,0x3e} | `InvaderColumn` 0x72 | 0x4de | `atEdge` +0x44, `lowestAlive` +0x46 (index of the bottom live invader, −1 when the column is empty), `unk4C` +0x4c, `cells` `InvaderCell[5]` +0x52 (`x`, `y` = column y + 44·i, `alive`; set by `invader_column_set_cell`) |

`SaucerVtbl`, `MissileVtbl` and `InvaderVtbl` extend MoverVtbl: `placeAt` (Mover's), then
`slot1…` whose `FunctionDefinition`s are copied from INV's targets; phase 4 names them. Missile's
`slot1` (`1068:0e26`) arms the second timer through `g_setSystemTimer`; `slot2` (`1068:0f2f`) is
the step that sets `hitState`.

The type tests (SceneObject slots that answer 1 for their class): 0x56 `shot_is_shot`, 0x57
`invader_is_invader` (column and explosion), 0x58 `saucer_is_saucer`, 0x59 `cannon_is_cannon`,
0x5a `bomb_is_bomb`.

Not done yet (phase 4): `this` typing of the 1068 overrides, which reach their own fields at
negative offsets from the SceneObject (Cannon −0x4c, Saucer −0x52, Missile/Bomb/Shot −0x4e,
column −0x72, explosion −0x78); flattening the class structs so that `vtbl` points to
`SaucerVtbl`/`MissileVtbl`/`InvaderVtbl` (they now embed `Actor2D`, whose `vtbl` is a 1-slot
`MoverVtbl*`, so `vtbl + 1` shows in the handler); the 7 virtual calls in `1068` that stay
unresolved.

## The game, as far as the data shows

*Invasores* is Space Invaders on a 640×480 starfield (`Espaco.bmp`):

- **The player** is the Cannon at the bottom (x 340, y 380). LEFT/RIGHT (latched by
  `g_keyLeftHeld`/`g_keyRightHeld`) move it; releasing one key with the other still held turns it
  round. SPACE fires the Shot from (cannon x + 27, cannon y − 30) when the cannon is not exploding
  and no shot is in flight. The SPACE latch is never set, so auto-repeat fires again as soon as the
  shot has landed.
- **The invaders** are 4 columns of 5 (20 in all, `g_invadersLeft`), drawn as one 88×217 picture
  per column at x 40 + 108·i, y 60, all moving together on timer 0xf (500 ms). `g_formationDir`
  flips when a column reaches the edge (`atEdge`), and the formation then goes down
  (`desceniv.wav`; to confirm). Each step plays `marcha.wav`.
- **A shot that hits** the bottom live invader of a column clears that cell, moves
  InvaderExplosion over it (`Naboom1.bmp`) and scores **+100** (`g_score`). **Every 5 kills the
  period drops by 100 ms** (500 → 400 → 300 → 200); at 1 invader left it is 55 ms.
- **The bombs**: 2 bombs. On its second timer (8 or 9: 2 s and 5 s), a bomb that is not falling is
  dropped from just below the bottom live invader of a column that is over the cannon.
  A bomb that lands within the cannon's x … x + 0x41 below y 0x19a hits it: **−500** and **one life
  lost** (4 lives; `1068:07a6` plays `Brocha.bmp`). The shot and a bomb can destroy each other
  (`explo5.WAV`).
- **The saucer** (`Disco.bmp`) crosses the top on a 10 s timer (`nave.wav`); a hit scores **+500**
  (`Explod.bmp`, `explo1.wav`).
- **The end**:
  - **Win:** after the last kill, `g_invadersLeft` is 0. The next WM_SYSTIMER sends
    `WM_DESTROY` with **wParam 0xffff** and sets the counter to −1.
  - **Loss:** at 0 lives, `1068:07a6` sends `WM_DESTROY` with **wParam 0**. Whether invaders that
    reach the cannon also end the game is for phase 4 (the column code `1068:1272–1b03`).
- **The result** (`inv_scene_handle_message`, WM_DESTROY): stop and free the waves, close WaveMix
  and MCI, then **`PostMessage(g_noiteWnd, 0x40a, wParam, (long)g_score)`**. Unlike TIRO (won =
  `g_score > 0`), **INV forwards WM_DESTROY's own wParam as the won flag**: 0xffff when every
  invader is dead, 0 otherwise. A user close also arrives with wParam 0. NOITE adds lParam (the
  score, which can be negative) and goes to `4fmarte2` on a win, `4fmarte` on a loss.

## Candidate original bugs (for BUGS.md, after checking in phase 4)

1. **Writes through null object pointers before they are allocated.** `inv_create_bombs`
   (`1068:0541`) stores `g_bombs[i]->unk42 = 1` *before* `operator new` (asm confirmed: `MOV BX,
   [BX+0x68e6]` then the store), and `inv_create_shot` (`1068:03df`) stores `g_shots[0]->unk42 = 0`
   the same way. Both pointers are 0 (BSS), so the stores hit DGROUP `0x42`/`0x44`, inside
   `s_hdcOverflow` "Estouro no número de HDCs" (`002e`). That string is shown only on an HDC
   overflow. The real `+0x42` fields are never initialised by these writes.
2. **A second 0x40a after a win.** The win path sets `g_invadersLeft = -1` after sending
   WM_DESTROY (0xffff). The column tick then still finds `g_invadersLeft < 1` and sends
   WM_DESTROY with wParam 0, and so a second `PostMessage(0x40a, 0, score)` (a loss) follows. It
   happens if an object timer message is dispatched before WM_QUIT ends the loop. APPWNDPROC's
   WM_DESTROY kills only system timer 1; the objects' timers 6–0x10 keep running. NOITE would add
   the score twice and switch to `4fmarte` after `4fmarte2`. This depends on the Win16 queue order.
3. **The last-kill branch is dead and the period goes negative.** After the last kill,
   `g_invadersLeft == 0` and `0 % 5 == 0`, so the "speed up" branch runs (`g_invaderPeriod` =
   55 − 100 = −45, so `SetSystemTimer(…, 0xffd3)`). The `else if (< 1)` branch that would send
   WM_DESTROY at once is unreachable; the game ends on the next WM_SYSTIMER instead.
4. **A user close is a loss.** Closing the window gives WM_DESTROY with wParam 0. This matches
   ENCAIXE and TIRO (both lose on close), but there the flag is computed from the score.

## Decompiler residue

- The `_aFchkstk` frame-size immediates (`MOV AX,2`) sometimes carry a DATA reference to
  `1090:0002` (`inv_create_saucer`, `inv_create_invader_explosion`); they are not accesses.
- The virtual-base arithmetic (`p + vbptr->sceneObjectOffset + …`) stays, as in TIRO.
- The NULL tests print their constant as a DGROUP symbol; each has a PRE comment.

## Scripts

| Script | Use here |
|---|---|
| `DefineStrings.java` | the 82 strings |
| `SalginCopyFromTwin.java` | `types` (TIRO's `/tiro` → `/inv`); `fns` for the ctor prototypes |
| `NearStructs.java` | the 8 INV structs |
| `NearGlobals.java` | the 70 INV globals |
| `FarVtables.java` | the 3 new slot structs, the 92 tables |
| `FarSlotSignatures.java` | `1090 defs`, `1090 calls` |
| `NearNullTests.java` | `1018`, `1028`, `1058`, `1088` |

Inline, not committed: the TIRO → INV data transfer (shift table above) and the copy of TIRO's 24
hand-checked call-site overrides (same function, same call ordinal).
