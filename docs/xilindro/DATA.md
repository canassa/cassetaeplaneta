# XILINDRO.EXE: data map (phase 3)

DGROUP is Ghidra segment `1090` (0x669c bytes, all of it in the file; the BSS starts at `2728`).
All addresses below are `1090:` unless they say otherwise. Types live in the category `/xilindro`.
XILINDRO is TIRO's build (`QUALITY.md` §0): near data, 2-byte `this`, a near vptr into DGROUP,
4-byte far vtable slots. TIRO (`docs/tiro/DATA.md`) is the reference for every shared layout;
this file gives XILINDRO's addresses and what is new.

## Counts

| What | Count |
|---|---|
| Strings defined (Latin-1, exact length) | 99, named `s_camelCase` (TIRO's names where the text is TIRO's) |
| Vtables / vbtables typed and labelled | 52 / 25 (`FarVtables.java`) |
| Vtable structs | 15 (TIRO's 13 + `FighterVtbl`, `OpponentVtbl`) and the 2 vbtable structs |
| Class and record structs | 30 copied from TIRO (`XilindroCopyCategory.java /TIRO.EXE /tiro /xilindro`, TIRO's game classes excluded) + 5 new (`Fighter`, `Opponent`, `Banner`, `EnergyBar`, `XilindroScene`) |
| Slot `FunctionDefinition`s | 180 (`FarSlotSignatures.java 1090 defs`) |
| Call-site overrides | 382: 339 resolved (`FarSlotSignatures.java 1090 calls`), 30 virtual calls and 13 timer-pointer calls by hand (`site`); 11 CRT function-pointer calls left |
| Globals typed (non-string, non-table) | 150: 73 game/app/engine (`NearGlobals.java`, spec in `zig-out/xilindro/glob.txt`) + 75 CRT and engine-handler globals mapped from TIRO's by matched DGROUP bytes (`crtglob.py`) + the 2 timer pointers |
| NULL-test comments (`NearNullTests.java`) | 14, at TIRO's 14 sites |

## DGROUP map

| Range | Contents |
|---|---|
| `0000-000f` | Windows instance header |
| `0010-00a5` | `s_coordFormat`, the HDC/layer overflow strings and captions |
| `00a6`, `00a8` | `g_nextId`, `g_unk00A8` (= 0x0b) |
| `00aa` | `s_appName` **"Xilindro"** (class, title, NOITE's `FindWindow` target) |
| `00b4` | `g_noiteWnd` (set by 0x40b) |
| `00b6-00e7` | `s_appIcon`, `s_alreadyRunning`, `s_userModule` ×2 |
| `00e8`, `00ea` | `g_started`, `g_handshakePending` (= 1) |
| `00ec-00fb` | `game_handle_message`'s `g_keyLeft/Right/Up/Down`, `g_itemSelected`, `g_exitPending`, `g_selectedItem`, `g_dropElevation` |
| `00fc-0173` | the 11 fighter bitmaps `sbsoco` … `sbflut.bmp` |
| `0174-01e1` | **fighter strip tables**: `g_fighterStripFiles[11]`, `Frames`, `Widths`, `Heights`, then **`g_fighterMoveDamage[11]`** (`01cc`) |
| `01e2-0259` | the 11 opponent bitmaps `sasoco` … `sacome.bmp` |
| `025a-02c7` | **opponent strip tables** and **`g_opponentMoveDamage[11]`** (`02b2`) |
| `02c8-02ef` | banner (`porrada.bmp`) and energy (`energia.bmp`) strip tables, 1 strip each |
| `02f0-0317` | `panel.bmp` ×2, `s_fontFace` "Virtual", `s_fontFile` "arialbd.fot" |
| **`0318-0397`** | **`g_reactionTable[4][8][2]`** |
| `0398-03cb` | the fight state: 8 key latches, `g_leftReleased`, the two bar marks, three `GetTickCount` stamps, `g_fightOver`, `g_endTicks`, `g_resultSent` |
| `03cc-04ed` | MCI strings (`porrada.mid`, alias `musica`), WaveMix messages, the 8 wave names |
| `04ee` | `s_clockFormat` `"%2.2d"` |
| `04f4-056f` | visible-objects overflow strings |
| `0576-05cd` | WaveMix module: `g_waveMixOpenResult`, `g_waveMixSession`, `g_waves[20]` (far), `g_waveCount` |
| `05ce-066d` | WaveMix error strings |
| `066e-07ef` | CRT data: TIRO's `04da-060d` layout moved by +0x194 (`g_crtStackOverflowHook` `0682`, `g_crtEnviron` `06ea`, `g_crtPgmPath` `06ec`, `g_crtLastIob` `0764`, `g_crtFloatHooks` `0766` ×7) and, new, the time-zone data: `g_crtLpdays[13]` `0788`, `g_crtDays[13]` `07a2`, `s_tzVar` "TZ" `07bc`, `g_crtTimezone` `07c0` (28800 = 8 h), `g_crtDaylight` `07c4` (1), `s_tzStd` "PST", `s_tzDst` "PDT", `g_crtTzname[2]` `07ce` |
| `07f0-086f` | `s_fatalErrorCaption6`, `s_updateListFull` (`MAX_OBJECT_QTY`) |
| `0870-100d` | vtables and vbtables (part 1) |
| `1018-10cb` | the "Faltou redefinir o método Create…" strings, `s_warningCaption` "CUIDADO !" |
| `10cc` | `g_gameVtbl` |
| `10e8-11e1` | occupancy overflow strings, `s_cannotOpenFile`, CreateScreen/CreateNewScene strings, `s_backgroundBmp` "fundluta.bmp" |
| `11e2-2457` | vtables and vbtables (part 2) |
| `2458-246d` | `g_crtInitHook`, three far CRT hooks, `g_crtExitTable` |
| `246e-2727` | `g_crtIob[20]`, `g_crtIob2`, the NMSG table and its `R6xxx` strings, end `ffff` at `2724` |
| `2728-3bba` | **`g_occupancyCount`** `char[65][81]` (BSS from here) |
| `3bba-64db` | **`g_occupancyObject`** `SceneObject*[65][81]` |
| `64dc-64e3` | `g_setSystemTimer`, `g_killSystemTimer` (`SetSystemTimerFn*32`, `KillSystemTimerFn*32`) |
| `64e4-665b` | `g_instance`, `g_mainWindow`, (`64e8` unreferenced), `g_appActive`, `g_modulePath` (far → `64f0`), `g_modulePathBuf[260]`, `g_windowWidth`/`Height` (640/480), `g_messageText[100]` |
| `665c-6667` | `g_game`, `g_xilindroGame` (same object), **`g_fighter`**, **`g_opponent`**, **`g_banner`**, **`g_energyBar`** |
| `6668-666f` | `g_conditionTrue`, `g_conditionFalse` |
| `6670-668b` | the 7 far wave handles (below) |
| `668c`, `668e` | `g_lastFighterMove`, `g_lastOpponentMove` (indices into `g_reactionTable`) |
| `6690-669b` | `g_moduleHandle`, `g_crtSprintfFile` (`CrtFILE`), `g_tzsetDone` |

There is no `g_score`: the result is computed from the energies at the end (below).

## Vtables

`S` = SceneObjectVtbl (91 slots, TIRO's: ENCAIXE's 93 without `unk11`/`unk18`), `O` = Object3DVtbl,
`M` = MoverVtbl, `A` = AnimationVtbl, `vb` = vbtable. The engine tables are TIRO's, slot for slot
(`vtcmp.py`: every slot target is the aligned twin of TIRO's, thunks aside). Labels follow TIRO's
scheme (`g_<class>Vtbl`, `g_<class>SceneObjectVtbl`, `g_<class>Vbtbl`, …).

| XILINDRO `1090:` | Class | TIRO `1090:` | Ctor (vptr store) |
|---|---|---|---|
| `0870` | Frame | `0692` | `frame_ctor` |
| `0874` S | SceneObject | `0696` | `scene_object_ctor` & co. |
| `09e0` O, `0a00` S, `0b6c` vb | Object3D | `0802`… | `object3d_ctor` |
| `0b70` M, `0b74` S, `0ce0` vb | Mover | `0992`… | `mover_ctor`… |
| `0ce4` M, `0ce8` S, `0e54` O, `0e74`/`0e7a` vb | Portable (linked, never built) | `0b06`… | `portable_ctor`, `portable_ctor_zoom` |
| `0e7e` M, `0e82` S, `0fee` O, `100e`/`1014` vb | Moveable | `0ca0`… | `moveable_ctor`… |
| `10cc` | Game (slot 6 `_purecall`) | `0eee` | `game_ctor`, `game_dtor` |
| `11e2`, `1206` S, `1372` O, `1392`/`1398` vb | **XilindroPanel** (ControlPanelVtbl; no own fields) | `1038`… (TiroPanel) | `xilindro_panel_ctor` `1088:4c7c` |
| `139c` | **XilindroGame** (GameVtbl, slots 1-4 and 6 in `1048`) | `11f2` | `xilindro_game_ctor` `1048:0000` |
| `13b8` | Backdrop (19) | `120e` | `backdrop_ctor`, `backdrop_dtor` |
| `1404` A, `1408` S, `1574` vb | Animation | `125a`… | |
| `1578` M, `157c` A, `1580` S, `16ec`/`16f0` vb | Actor2D | `13ce`… | `actor2d_ctor_strips` |
| `16f4` | **XilindroScene** (SceneVtbl: 0 `xilindro_scene_handle_message`, 5 `xilindro_scene_create_screen`, 7 `xilindro_scene_create`) | `1004` (TiroScene, which sits earlier) | `xilindro_scene_ctor` `1088:4f4e` |
| `1728` M, `172c` A, `1730` S, `189c`/`18a0` vb | Player2D | `154a`… | `player2d_ctor` |
| **`18a4` FighterVtbl (3), `18b0` A, `18b4` S, `1a20`/`1a24` vb {−2, 0x54}/{−2, 0x22}** | **Fighter** (derives Player2D) | where TIRO has the Crossbow | `fighter_ctor` `1088:4e4e` |
| `1a28` | Scene (slot 0 `_purecall`) | `1842` | `scene_ctor` |
| `1a5c` | GridBackdrop (20) | `1876` | `grid_backdrop_ctor` |
| `1aac` S | StatusBar | `18c6` | `status_bar_ctor` |
| `1c18`, `1c3c` S, `1da8` O, `1dc8`/`1dce` vb | ControlPanel (slots 7-8 `_purecall`) | `1a32`… | `control_panel_ctor` |
| `1dd2` | **XilindroBackdrop** (GridBackdropVtbl, slot 0 `xilindro_backdrop_create`) | `1bec` | `xilindro_backdrop_ctor` `1088:549c` |
| `1e22` A, `1e26` S, `1f92` O, `1fb2`/`1fb8` vb | Animated3D | `1c3c`… | `animated3d_ctor_strips_no_hitbox` |
| `1fbc`, `1fc8`, `1fd4` | FlagCondition, CompoundCondition, Condition | `1dd6`… | |
| **`1fe0` OpponentVtbl (2), `1fe8` A, `1fec` S, `2158`/`215c` vb {−2, 0x4a}/{−2, 0x18}** | **Opponent** (derives Actor2D) | where TIRO has the Target | `opponent_ctor` `1088:5f88` |
| **`2160` M, `2164` A, `2168` S, `22d4`/`22d8` vb {−2, 0x40}/{−2, 0xe}** | **Banner** (derives Actor2D, overrides nothing) | Arrow's place | `banner_ctor` `1088:6026` |
| **`22dc` M, `22e0` A, `22e4` S, `2450`/`2454` vb {−2, 0x48}/{−2, 0x16}** | **EnergyBar** (derives Actor2D) | Projectile's place | `energy_bar_ctor` `1088:60be` |

Other far pointers: `0766` (7 CRT float hooks → `_fptrap`), `2458` (`g_crtInitHook` →
`init_static_conditions_entry`), `246a` (`g_crtExitTable` → `crt_endstdio`).

**The two new vtable structs** (MoverVtbl extensions, field names by behaviour):
- `FighterVtbl`: `placeAt` (Mover's), `startTimer` (`fighter_start_timer`: stores the timer id in
  `Fighter.timerId` and calls `g_setSystemTimer`; called by `xilindro_game_on_create` 1048:023e with
  id 10, 1100 ms), `walk` (`fighter_walk`).
- `OpponentVtbl`: `placeAt`, `walk` (`opponent_walk`).

**SceneObjectVtbl type tests.** The fields TIRO called `isProjectile`, `slot62`, `isTarget`,
`isCrossbow` (slots 0x56-0x59) are renamed `isFighter`, `isOpponent`, `slot63`, `slot64`, and their
slot definitions `SceneObjectVtbl_isFighterFn`, `_isOpponentFn`, `_slot63Fn`, `_slot64Fn` (the type is
XILINDRO's own copy, `/xilindro/SceneObjectVtbl`):
Fighter answers 1 to 0x56 (`fighter_is_fighter`), Opponent to 0x57 (`opponent_is_opponent`); the
base answers 0. `opponent_can_step` asks the blocker `isFighter`, `fighter_can_step` asks
`isOpponent`. Slots 0x58/0x59 have no XILINDRO override.

Game-class overrides (`gamevt.py`; all through adjustor thunks):

| Slot | Fighter | Opponent |
|---|---|---|
| S 0x1e invalidate | `fighter_invalidate` (empty) | `opponent_invalidate` (returns 0) |
| S 0x25 canStep | `fighter_can_step` | `opponent_can_step` |
| S 0x2d tick | `fighter_tick` | `opponent_tick` |
| S 0x32 stopMovingDc | `fighter_stop_moving_dc` | `opponent_stop_moving_dc` |
| S 0x33 stopMoving | `fighter_stop_moving` | `opponent_stop_moving` |
| S 0x34 moveTick | `fighter_move_tick` | `opponent_move_tick` |
| S 0x4d redrawOverlapping | `fighter_redraw_overlapping` (draws the opponent) | `opponent_redraw_overlapping` (draws the fighter) |
| S 0x56 / 0x57 | `fighter_is_fighter` | `opponent_is_opponent` |

The EnergyBar's table differs from Actor2D's only by thunks (its Animation slots reach the same
`animation_*` bodies through other adjustments); the Banner's not at all.

## Classes (`/xilindro`)

The engine structs are TIRO's, copied unchanged: `SceneObject` 0x46c, `Object3D`, `Mover`,
`Moveable`, `Animation`, `Actor2D` 0x40, `Player2D` 0x46, `Portable`, `StatusBar`, `ControlPanel`,
`Game` 0x2b4, `Scene` 0x44, `Backdrop` 0x44e (TIRO's 8-byte-smaller layout), `GridBackdrop`,
`PerspectiveBackdrop`, `OccupancyGrid`, the lists, `Condition`s, `Frame`, `CrtFILE`, the vtable
and vbtable structs. Every one of them is used at TIRO's offsets by code that aligns with TIRO's
instruction for instruction, operands included (`exact3.py`), and the ctor sizes agree
(`operator_new(0x2b4)` for the game, 0x450 for the backdrop, 0x566 for the panel).

The new ones (NearStructs; the SceneObject virtual base follows each, at the vbtable offset):

| Struct | Size | Fields (offsets hex) |
|---|---|---|
| `Fighter` | 0x56 | `player2d` (Player2D) 0; `reacting` 48 (1 while playing a reaction strip chosen from `g_reactionTable`); `moveFrame` 4a (frames played of the current move); `timerId` 4e (10, `fighter_start_timer`); `energy` 50 (= 0x5b at creation, **never written again**, tested `< 10` for the reaction column); `contact` 52 (char, `'0'`, `'2'` when blocked by the opponent); `vtordisp` 54. `46` and `4c` show no access |
| `Opponent` | 0x4c | `actor2d` 0; `unk40` 40 (= 1 from the ctor); `reacting` 42; `moveFrame` 44; `energy` 46 (0x5b, lowered by the PgUp, Up and Home hits, not by Down; never read); `contact` 48 (`'0'`, `'1'`); `vtordisp` 4a |
| `Banner` | 0x42 | `actor2d` 0; `vtordisp` 40 |
| `EnergyBar` | 0x4a | `actor2d` 0; `leftX` 40 (0x122), `rightX` 42 (0x14d): the two ends of the marker strip; **`fighterEnergy` 44**, **`opponentEnergy` 46** (both 0x5b = 91); `vtordisp` 48 |
| `XilindroScene` | 0x46 | `scene` (Scene) 0; **`secondsLeft` 44** (= 90, from `xilindro_scene_ctor`) |

In the Actor2D the `Mover.direction` field (+8) is the walking direction (1 left, 2 right) and
`animation.framesLeft` (+0x3a) the frame count of the current strip. The current move is the
SceneObject's `curStrip` (SceneObject +0x1a), reached through the vbase, which the decompiler
prints as `mover.stepX + vbptr->sceneObjectOffset`; `curFrame` is +0x1c.

## The assets

All read from the current directory (`assets/XILINDRO/`), 8-bpp.

| File | Size | Use |
|---|---|---|
| `fundluta.bmp` | 640×480 | the background (`xilindro_scene_create_screen`) |
| `sb*.bmp` ×11 | 231×798 = 3 frames of 231×266 | **the fighter** (the player), strips 0-10 |
| `sa*.bmp` ×11 | 252×590 / 252×886 = 2 or 3 frames of 252×295 | **the opponent**, strips 0-10 (`g_opponentStripFrames` = 3,2,3,2,2,3,2,2,3,3,3) |
| `porrada.bmp` | 232×42 | the banner ("Porrada!"), drawn once |
| `energia.bmp` | 16×19 | one tick of the energy bar |
| `panel.bmp` | 21×30 | the control panel |
| `porrada.mid` | — | music through MCI (alias `musica`), restarted on MM_MCINOTIFY |
| `soco2`, `soco`, `dor3`, `dor1`, `chute3`, `vaias`, `lutamal3`, `murmlut2` `.wav` | 0.2-15 s | the 8 WaveMix waves, opened in this order; the first 7 go to `g_soco2Wave` … `g_lutamal3Wave`, `murmlut2` (crowd murmur) is played looped and its handle is not kept |
| `arialbd.fot` | — | the status-bar font file (not on the disc, as in TIRO) |

On the disc but **not referenced** by the EXE: `CENAPEQ2.BMP`, `SFINTERF.BMP`, `CHUTE.WAV`,
`CHUTE2.WAV`, `CHUTES.WAV`, `GOLPE.WAV`…`GOLPE4.WAV`, `LUTA.WAV`, `LUTA3.WAV`.

The strip index is the move, by the order of the file tables:

| # | Fighter (`sb`) | Opponent (`sa`) | Meaning (inferred from the names and the code) |
|---|---|---|---|
| 0 | `sbsoco` | `sasoco` | *soco*, punch |
| 1 | `sbchme` | `sachme` | *chute médio*, middle kick |
| 2 | `sbrast` | `sarast` | *rasteira*, leg sweep |
| 3 | `sbchal` | `sachal` | *chute alto*, high kick |
| 4 | `sbanda` | `saanda` | *anda*, walk |
| 5 | `sbpula` | `sapula` | *pula*, jump |
| 6 | `sbdefa` | `sadefa` | the guard stance (strip after every move) |
| 7 | `sbdefe` | `sadefe` | *defesa*, block |
| 8 | `sbcai` | `sacai` | *cai*, falls |
| 9 | `sbsego` | `sasego` | the hit reaction |
| 10 | `sbflut` | `sacome` | the winner's pose (*comemora*) |

## The game rules

`GAME.md` has them in full; the bugs are `BUGS.md` X1–X11. In short: *Xilindró* is the street fight
of NOITE's `handler_3fstreet` (`xilindro\xilindro.exe`, after the street-escape video); one round of
90 s, 91 energy a side (the energy bar's `fighterEnergy`/`opponentEnergy`); the fighter's blows land
at the key press within |dx| ≤ 100, take `g_fighterMoveDamage[strip]` {1, 2, 1, 2} and throw the
fighter 100 px back; Down and Home also cost the fighter `g_opponentMoveDamage[opponent strip]`; the
opponent walks in to 99–130 px and attacks on the 200 ms beat, `rand() % 4` reseeded from `time()`,
taking `g_opponentMoveDamage[its strip]` {4, 2, 2, 6} whether the fighter blocks or not (both sides
lose when the fighter is attacking), then jumps back 100 px; a KO or the clock ends the round, the
fighter wins unless its energy is below the opponent's, both outcomes close ~3.1 s later, and
`0x40a(won, won ? energy·150 : −1000)` goes to NOITE (`3fstree2` on a win, `3fstree1` and a life on
a loss).

## Undefined and unknown

- Small pads between strings and tables, as in TIRO, and the unreferenced CRT words TIRO also
  leaves undefined (`zig-out/xilindro/data.tsv`).
- `64e8` (unreferenced app word), `03a8-03ad` and `03b0-03b4` (unreferenced fight words; `03b0` = 1).
- `Fighter` +0x46/+0x4c, `Opponent.unk40`, the meaning of strips 6/7/9 (from the bitmaps).
- The original names of the game classes and their MoverVtbl slots; the names here describe the
  roles.

## Scripts

| Script | Use here |
|---|---|
| `XilindroCopyCategory.java` (new) | `/TIRO.EXE /tiro /xilindro ^(Crossbow\|Target\|Projectile\|Arrow)(Vtbl)?(_.*)?$` |
| `XilindroCopyPrototypes.java` (new) | `/TIRO.EXE <pairs.tsv> /tiro /xilindro` |
| `FarVtables.java` | the 2 new vtable structs and the 77 tables (`zig-out/xilindro/vt.spec.txt`) |
| `FarSlotSignatures.java` | `1090 defs`, `1090 calls`, `1090 site …` (30 engine sites mapped from TIRO's hand-checked ones, 13 timer-pointer calls; `1048:023e=FighterVtbl`, the startTimer call, which `calls` mode reads as MoverVtbl.placeAt) |
| `NearStructs.java` | the 5 new structs |
| `NearGlobals.java` | `glob.arg`, `crtglob.arg` |
| `DefineStrings.java` | `strings.arg` |
| `NearNullTests.java` | `1018`, `1028`, `1058`, `1088` |
| `CopyTypesFromProgram.java` | `/TIRO.EXE` (SDK + imports), `/TIRO.EXE SetSystemTimerFn KillSystemTimerFn` |
