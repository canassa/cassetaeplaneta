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
| Globals typed and named (non-string, non-table) | 156: 87 transferred from TIRO, 69 set by hand |
| NULL-test comments (`NearNullTests`) | 14 (TIRO's 14) |
| Call-site overrides | 431, every indirect call but the 11 CRT function-pointer calls: 386 by `FarSlotSignatures calls`, 24 copied from TIRO's hand-checked sites, the rest (the 14 timer-pointer calls among them) by `site` |

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
| `01dc` | `g_invadersLanded` (= 0): set by the column that lands (the loss) |
| `01de` | `g_invaderPeriod` (= 500 ms): the invaders' timer period |
| `01e0–0277` | MCI strings (`doom1.mid`, alias `musica`), the 8 wave names |
| `0278` | `g_formationMaxY` (= 60): the formation's lowest y so far; a descent below it plays `desceniv.wav` |
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

`SceneObject.curStrip` (+0x18) picks the strip: 1 is the cannon's `Brocha.bmp`
(`cannon_lose_life`), the saucer's `Explod.bmp` (`saucer_explode`) and the bomb's `Bomtir.bmp`
(`bomb_shot_down`); the handler and `invader_column_step` put it back to 0. `curFrame` (+0x1a)
picks the frame: `shot_vanish` sets the shot's to 1, the blank frame; the shot's fire, the saucer's
end of explosion, the bomb drops and `invader_explosion_start` reset it to 0.

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
| `desceniv.wav` | `g_descendWave` | `inv_play_descend_wave` | a column descends below `g_formationMaxY` (once per right-edge turn) |

Unlike TIRO, APPWNDPROC plays nothing on WM_PAINT.

### Timers

Every object runs on its own WM_SYSTIMER id (the ctor's `timerId`/`timerPeriod`):

| Id | Period | Object |
|---|---|---|
| 1 | 50 ms | the app (APPWNDPROC, WM_CREATE) |
| 6, 7 | 55 ms | the bombs; their drop timers 8, 9 at 2000 / 5000 ms (`MissileVtbl.armTimer`, ids in `Missile.timer2Id` / `timer2IdB`) |
| 0xa | 60 ms | the cannon |
| 0xc | 60 ms | the saucer; its launch timer 0xe at 10 s (`SaucerVtbl.armTimer`, `Saucer.timer2Id`) |
| 0xd | 55 ms | the shot |
| 0xf | `g_invaderPeriod`: 500, 400, 300, 200 ms (15, 10, 5 left), 55 ms (1 left), then 65,491 ms (BUGS I2) | the four invader columns (one timer) |
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
| **Cannon** : Player2D | `1876` M, `187a` A, `187e` S | `19ea` {−2,0x4a}, `19ee` {−2,0x18} | `Cannon` 0x4c | 0x4b8 | TIRO's Crossbow layout. `Player2D.lives` (+0x40) = 4; `Player2D.score` (+0x42, dword) gets +10 per invader, +50 per saucer and is never read (NOITE gets `g_score`); `hitFrame` +0x46 (−1 idle, else the explosion frame count); `unk48` +0x48; `vtordisp` +0x4a |
| **Saucer** : Actor2D | `1dba` SaucerVtbl (4), `1dca` A, `1dce` S | `1f3a` {−2,0x50}, `1f3e` {−2,0x1e} | `Saucer` 0x52 | 0x4be | TIRO's Target layout. `unk40` +0x40 (ctor 1, cleared when the saucer leaves; read only by `saucer_check_edge`'s dead left-edge branch); `timer2Id` +0x4c (0xe, the launch timer); `hitFrame` +0x4e (−1 idle, else the explosion frame count); `vtordisp` +0x50 |
| **Missile** : Actor2D | `1f42` MissileVtbl (3), `1f4e` A, `1f52` S | `20be` {−2,0x4c}, `20c2` {−2,0x1a} | `Missile` 0x4c | – | Abstract base: `unk42` +0x42 (never read; the creators' writes miss it, BUGS I1); `timer2Id` +0x44 (bomb 0's drop timer 8); `timer2IdB` +0x46 (bomb 1's drop timer 9; `missile_arm_timer` kind 2 writes both, kind 5 only this one); `hitFrame` +0x48; `hitState` +0x4a (a char: the class of what blocked the last step, set by `missile_can_step`: '1' the shot, '2' an invader, '3' the saucer, '4' the cannon, '5' a bomb; the handler also sets '4' when a bomb is over the cannon, acts on '1'/'4' for a bomb and '2'/'3' for the shot, then resets it to '\0'; never initialised) |
| **Bomb** : Missile | `20c6`, `20d2`, `20d6` | `2242`, `2246` (same) | `Bomb` 0x4e | 0x4ba | `vtordisp` +0x4c |
| **Shot** : Missile | `224a`, `2256`, `225a` | `23c6`, `23ca` (same) | `Shot` 0x4e | 0x4ba | `vtordisp` +0x4c |
| **InvaderExplosion** : Actor2D | `23ce` InvaderVtbl (3), `23da` A, `23de` S | `254a` {−2,0x76}, `254e` {−2,0x44} | `InvaderExplosion` 0x78 | 0x4e4 | Shares every slot override with InvaderColumn but `restoreBackground` and `draw` (the engine's), so it carries the column's fields at +0x40–0x4d unused (`lowestAlive` −1: the shared column slots only stop and hide it); `frameCounter` +0x4e; `vtordisp` +0x76 |
| **InvaderColumn** : Actor2D | `2552` InvaderVtbl (3), `255e` A, `2562` S | `26ce` {−2,0x70}, `26d2` {−2,0x3e} | `InvaderColumn` 0x72 | 0x4de | `landed` +0x40 (1 once it reached the cannon row, with `g_invadersLanded`); `firstPass` +0x42 (1 from the ctor until the first reversal: the left-edge test is off); `atEdge` +0x44 (read and cleared by the handler's formation step); `lowestAlive` +0x46 (index of the bottom live invader, −1 when empty); `direction` +0x48 (2 right, 1 left); `hitState` +0x4c (char, `invader_column_can_step`'s blocker class, never read); `cells` `InvaderCell[5]` +0x52 (`x`, `y` = column y + 44·i, `alive`; `invader_column_set_cell`); `vtordisp` +0x70 |

`SaucerVtbl`, `MissileVtbl` and `InvaderVtbl` extend MoverVtbl: `placeAt` (Mover's), then
- `SaucerVtbl`: `armTimer` (`saucer_arm_timer`), `moveTickOrStop` (`saucer_move_tick_or_stop`,
  no call site), `checkEdge` (`saucer_check_edge`, the 0xc tick);
- `MissileVtbl`: `armTimer` (`missile_arm_timer`, the bombs' drop timers), `moveTick`
  (`missile_move_tick`);
- `InvaderVtbl`: `step` (`invader_column_step`, the formation step), `moveTickOrStop`
  (`invader_column_move_tick_or_stop`, no call site).

Their `<Vtbl>_<field>Fn` definitions are the targets' prototypes.

The type tests (SceneObject slots that answer 1 for their class): 0x56 `shot_is_shot`, 0x57
`invader_is_invader` (column and explosion), 0x58 `saucer_is_saucer`, 0x59 `cannon_is_cannon`,
0x5a `bomb_is_bomb`.

The SceneObject overrides in `1068` take `this` as the SceneObject (`void *`) and reach their own
fields at negative offsets (Cannon −0x4c, Saucer −0x52, Missile/Bomb/Shot −0x4e, column −0x72,
explosion −0x78). The class structs embed `Actor2D`, whose `vtbl` is a 1-slot `MoverVtbl *`, so a
call through `SaucerVtbl`/`MissileVtbl`/`InvaderVtbl` can read `vtbl + 1` in the decompilation; its
call-site override gives it the slot's prototype.

## The game rules

`GAME.md` has them in full; the bugs are `BUGS.md` I1–I5. In short: *Invasores* is NOITE's
`handler_4fsacaet` minigame (`Inv\Inv.exe`, after the flying-saucer scene). 20 invaders in 4
columns of 5 at x 40 + 108·i, y 60 step 20 px together on timer 0xf (500 ms, −100 ms at 15, 10
and 5 left, 55 ms at 1 left), the leading column first by `g_formationDir`; a right-edge turn
descends 22 px, a left-edge turn does not, and a landing at y ≥ 390 loses. The cannon (4 lives)
moves 20 px per 60 ms; its one shot (20 px per 55 ms) fires when `hitFrame` is −1 and the shot is
not moving, and kills a column's bottom live invader when col.x < shot.x < col.x + 88 and
(shot.y − col.y) / 44 == `lowestAlive`. The saucer crosses at y 10 every 10 s (+500); two bombs
(drop timers 2 s and 5 s) fall from the first live column within 88 px of the cannon, each hit
−500 once and a life; the shot can meet a bomb. `g_score` (+100 per invader) goes to NOITE as
`0x40a(wParam, (long)g_score)`: 0xffff after the last kill (sent on the next tick), 0 on a loss.
NOITE adds the score and goes to `4fmarte2` on a win, `4fmarte` (a life) on a loss.

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
| `NearGlobals.java` | the INV globals |
| `FarVtables.java` | the 3 new slot structs, the 92 tables |
| `FarSlotSignatures.java` | `1090 defs`, `1090 calls`, `1090 site …` (the timer-pointer calls and the hand-checked virtual calls) |
| `NearNullTests.java` | `1018`, `1028`, `1058`, `1088` |

Inline, not committed: the TIRO → INV data transfer (shift table above) and the copy of TIRO's 24
hand-checked call-site overrides (same function, same call ordinal).
