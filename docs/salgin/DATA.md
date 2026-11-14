# SALGIN.EXE: data map

DGROUP is Ghidra segment `1090` (0x6658 bytes; initialised data up to `26e2`, the BSS after it,
both stored in the file). All addresses below are `1090:` unless they say otherwise. Types live
in the data type category `/salgin`. SALGIN is TIRO's medium-model `/Od` build (`QUALITY.md` §0):
near data and `this`, a near vptr into DGROUP, 4-byte far vtable slots. TIRO
(`docs/tiro/DATA.md`) is the reference for every shared layout; the `/salgin` category started
as a copy of TIRO's `/tiro` (`SalginCopyFromTwin.java … types`), with TIRO's own game classes
(Crossbow, Target, Projectile, Arrow and their vtables) removed.

## Counts

| What | Count |
|---|---|
| Strings defined (Latin-1, exact length, `DefineStrings.java`) | 98, all named `s_camelCase` |
| Vtables / vbtables applied and named (`FarVtables.java`) | 54 / 23 (77 tables) |
| Vtable structs | 15 (13 from TIRO + `FighterVtbl` 3, `OpponentVtbl` 2) |
| Class structs new to SALGIN (`NearStructs.java`) | 5: `Fighter`, `Opponent`, `Banner`, `EnergyBar`, `SalginScene` |
| Globals typed (`NearGlobals.java`, non-string, non-table) | 142, 136 named |
| Virtual-call overrides (`FarSlotSignatures.java`) | 335 of 359 sites (24 left, below) |
| NULL-test comments (`NearNullTests.java`) | 14 (the same sites as TIRO) |
| Undefined bytes left in DGROUP | 86 |

## DGROUP map

| Range | Contents |
|---|---|
| `0000–000f` | Windows instance header (`g_instReserved` … `g_instStackBot`) |
| `0010–00a5` | `s_coordFormat`, HDC/layer overflow strings and captions (TIRO's) |
| `00a6`, `00a8` | `g_nextId`; `g_unk00A8` byte 0x0b (the transparent colour index the draw code passes) |
| `00aa` | `s_appName` "Sala de Ginástica" (class, title, NOITE's `FindWindow` target). 3 bytes longer than TIRO's title, so everything up to `0103` sits 2 bytes later than in TIRO |
| `00bc` | `g_noiteWnd` (set by 0x40b) |
| `00be–00ef` | `s_appIcon`, `s_alreadyRunning`, `s_userModule` ×2 |
| `00f0–0103` | `g_started`, `g_handshakePending` (= 1), `game_handle_message`'s `g_keyLeft/Right/Up/Down`, `g_itemSelected`, `g_exitPending`, `g_selectedItem`, `g_dropElevation` |
| `0104–01e9` | The 11 fighter bitmaps `vb*.bmp`; **`g_fighterStrip{Files,Frames,Widths,Heights}[11]`** (`017c`/`0192`/`01a8`/`01be`); **`g_fighterDamage[11]`** (`01d4`) |
| `01ea–02d1` | The 11 opponent bitmaps `ma*.bmp`; **`g_opponentStrip*[11]`** (`0264`/`027a`/`0290`/`02a6`); **`g_opponentDamage[11]`** (`02bc`) |
| `02d2–02f9` | Banner strip (`02d2` frames 1, `02d4` width 232, `02d6` height 42, `02d8` "porrada.bmp", `02e4` files); EnergyBar strip (`02e6` 1, `02e8` 16, `02ea` 19, `02ec` "energia.bmp", `02f8` files) |
| `02fa–0321` | `panel.bmp` ×2, `s_fontFace` "Virtual" (passed to `game_init`; TIRO's was "Mech"), `s_fontFile` "arialbd.fot" |
| `0322–0361` | **`g_reactionStrips[16][2]`**: the reaction strip of a fighter that is hit, `[(defenderStrip-4)*4 + attackerStrip][strong/weak]` |
| `0362–0397` | The game's key latches and clocks (below) |
| `0398–04af` | MCI strings, WaveMix captions, the 7 wave names, `s_clockFormat` "%2.2d" |
| `04b0–0531` | Visible-objects overflow strings |
| `0532–05a9` | WaveMix: `g_waveMixOpenResult`, `g_waveMixSession`, `g_waves[20]` (far), `g_waveCount`; then WaveMix error strings |
| `062a–0721` | CRT data, TIRO's `04da–05d1` moved by +0x150 (same names) |
| `0722–073d` | `g_crtFloatHooks[7]` (far, to `_fptrap`) |
| `0744–078d` | **New CRT time data**: `g_crtLpdays[13]`, `g_crtDays[13]`, `s_tzEnvName` "TZ", `g_crtTimezone` (long, 28800 = PST), `g_crtDaylight` (1), "PST", "PDT", `g_crtTzname[2]` |
| `078e–07bb` | The DOS errno map (undefined), `"\"` ×2, `g_crtAmblksiz` `07a6` (0x1000), `s_fatalErrorCaption6`, `s_updateListFull` (`MAX_OBJECT_QTY`) |
| `082c–2413` | Vtables and vbtables, with the "Faltou redefinir…" strings, `s_warningCaption`, occupancy/file/CreateScreen strings and `s_fundlutaBmp` "fundluta.bmp" (`1190`) between them, as in TIRO |
| `2414–2429` | `g_crtInitHook` (→ `init_static_conditions_entry`), three CRT hooks, `g_crtExitTable` (→ `crt_endstdio`) |
| `242a–2569` | `g_crtIob` (`CrtFILE[20]`), `g_crtIob2` |
| `256a–26e2` | `s_nmsgMarker` "<<NMSG>>", `g_crtNmsgTable` and the `s_nmsgR6xxx` strings |
| `26e4–3b74` | **`g_occupancyCount`** `char[65][81]` (BSS from here) |
| `3b76–6497` | **`g_occupancyObject`** `SceneObject*[65][81]` |
| `6498–64ab` | `g_setSystemTimer`, `g_killSystemTimer` (USER.11 / USER.182), `g_instance`, `g_mainWindow`, an unreferenced word (`64a4`; TIRO's `g_score` sits at this rank), `g_appActive`, `g_modulePath` |
| `64ac–6617` | `g_modulePathBuf[260]`, `g_windowWidth`/`Height` (`65b0`/`65b2`), `g_messageText[100]` |
| `6618–662b` | `g_game`, `g_salginGame`, **`g_fighter`**, **`g_opponent`**, **`g_banner`**, **`g_energyBar`**, `g_conditionTrue`, `g_conditionFalse` |
| `662c–6647` | The 7 waves (far): `g_punch2Wave` soco2, `g_punchWave` soco, `g_pain4Wave` dor4, `g_pain2Wave` dor2, `g_kickWave` chute3, `g_boosWave` vaias, `g_maneWave` mane |
| `6648–6657` | `g_reactionRow`/`g_reactionCol` (the indices into `g_reactionStrips`), `g_moduleHandle`, `g_crtSprintfFile`, `g_crtTzsetDone` |

The game's flags and clocks (`0362–0397`, all initialised data):

| Addr | Name | Init | Use |
|---|---|---|---|
| `0362` … `0370` | `g_keyRightHeld`, `g_keyLeftHeld`, `g_keyUpHeld`, `g_keyDownHeld`, `g_keyPgUpHeld`, `g_keyHomeHeld`, `g_keyEndHeld`, `g_keyInsertHeld` | 0 | One latch per move key. A key starts its move only while its latch is 0; starting **any** move sets **all** of them (one move at a time); they clear when the move's animation ends. |
| `0378` | `g_keyLeftUp` | 1 | 0 while LEFT is held |
| `0380`, `0382` | `g_playerMarkLevel`, `g_opponentMarkLevel` | 91 | The energy at which the next energy-bar mark is drawn: each 7 points lost adds a mark and lowers the level by 7 |
| `0384`, `0388`, `038c` | `g_lastClockTick`, `g_lastAnimTick`, `g_lastPumpTick` | 0 | GetTickCount stamps: the 1 s round clock, the 100 ms end-of-round animation, the 200 ms WaveMix pump / fight beat |
| `0390` | `g_roundOver` | 0 | Set when the clock or an energy reaches 0 |
| `0392` | `g_endTicks` | 0 | 100 ms ticks since the round ended |
| `0394` | `g_endReady` | 0 | The end may post WM_DESTROY |
| `0396` | `g_resultSent` | 0 | WM_DESTROY already reported 0x40a |
| `0372–0377`, `037a–037f` | — | 0 | Unreferenced (more latch-shaped words) |

## The game data

**Pictures** (all in `assets/SALGIN/`, read from the current directory):

| Table | Files | Size per frame | Object |
|---|---|---|---|
| `g_fighterStrip*` (11) | `vbbsoc vbbvoo vbras vbbsal vbbgan vbbsat vbgin vbbdef vbtomb vbbmup vbbmen` | 173 × 279, 3 frames each (`vbbmen` 11) | the player, Fighter |
| `g_opponentStrip*` (11) | `magaso machvi maband machsa magaan magasa maging magade matomb matoup macofi` | 216 × 295, 3 frames each (`macofi` 22) | the computer, Opponent |
| `g_bannerStrip*` (1) | `porrada.bmp` | 232 × 42 | Banner, "PORRADA" |
| `g_energyStrip*` (1) | `energia.bmp` | 16 × 19 | EnergyBar's mark |
| — | `fundluta.bmp` 640 × 480 | | the background (`salgin_scene_create_screen`) |
| — | `panel.bmp` 21 × 30 | | the (unused) control panel |

A fighter's `curStrip` is its move; `curFrame` steps through the strip. By the code and the file
names (Portuguese: *soco* punch, *voadora* flying kick, *rasteira* sweep, *salto* jump, *ginga*
the guard sway, *defesa* block, *tombo* fall):

| Strip | Fighter | Opponent | Role in the code |
|---|---|---|---|
| 0 | `vbbsoc` | `magaso` | attack (fighter: PgUp) |
| 1 | `vbbvoo` | `machvi` | attack (Up) |
| 2 | `vbras` | `maband` | attack (Down) |
| 3 | `vbbsal` | `machsa` | attack (Home) |
| 4 | `vbbgan` | `magaan` | walk (Left/Right; the opponent's approach) |
| 5 | `vbbsat` | `magasa` | Insert's move |
| 6 | `vbgin` | `maging` | guard stance, the rest state |
| 7 | `vbbdef` | `magade` | block (End) / hit reaction |
| 8, 9 | `vbtomb`, `vbbmup` | `matomb`, `matoup` | hit reactions (from `g_reactionStrips`) |
| 10 | `vbbmen` (11 frames) | `macofi` (22 frames) | the round winner's animation |

**Damage** (energy lost by the one who is hit, by the attacker's strip):
`g_fighterDamage` = {1, 2, 1, 2, 0…} and `g_opponentDamage` = {2, 1, 1, 3, 0…}.

**Sounds.** MIDI `porrada.mid` through MCI (alias `musica`, looped on MM_MCINOTIFY). Seven
WaveMix waves: `soco2`, `soco` (punches), `chute3` (kick), `dor2`, `dor4` (pain), `vaias` (the
crowd boos), `mane.WAV`. The helpers `1068:2bb3–2d53` pair them (a hit plays the blow and a
pain wave). `COMECESP.WAV`, `LUTA.WAV`, `LUTA2.WAV`, `LUTAMAL.WAV`, `LUTAMAL2.WAV` and
`APANHA.WAV` are on the disc but never opened.

## Vtables

`S` = SceneObjectVtbl (91 slots), `O` = Object3DVtbl (8), `M` = MoverVtbl (1), `A` =
AnimationVtbl (1), `vb` = vbtable (`Vbtable` {−2, soOffset} or `Vbtable3d` {−2, soOffset,
o3dOffset}). Labels follow TIRO's scheme (`g_<class>Vtbl`, `g_<class>SceneObjectVtbl`,
`g_<class>Vbtbl`, …). Each slot is a 4-byte pointer to a `FunctionDefinition`
(`<Vtbl>_<field>Fn`) with one DATA reference to its far target.

| Class | Tables | Ctor | Size |
|---|---|---|---|
| Frame | `082c` | `frame_ctor` | 0x16 |
| SceneObject | `0830` S | | 0x46c |
| Object3D | `099c` O, `09bc` S, `0b28` vb | `object3d_ctor` | |
| Mover | `0b2c` M, `0b30` S, `0c9c` vb | | 0x32 |
| Portable | `0ca0` M, `0ca4` S, `0e10` O, `0e30`/`0e36` vb | `1018:1cea`/`1dec` (never called) | |
| Moveable | `0e3a` M, `0e3e` S, `0faa` O, `0fca`/`0fd0` vb | | |
| Game | `1088` GameVtbl | `game_ctor` `1088:55fa` | 0x2b4 |
| SalginPanel | `119e` ControlPanelVtbl, `11c2` S, `132e` O, `134e`/`1354` vb | `salgin_panel_ctor` `1088:5482` | 0x566 |
| SalginGame | `1358` GameVtbl (slots 1–4, 6 in `1048`) | `salgin_game_ctor` `1048:0000` | 0x2b4 |
| Backdrop | `1374` BackdropVtbl (19) | `backdrop_ctor` | |
| Animation | `13c0` A, `13c4` S, `1530` vb | | 0xe |
| Actor2D | `1534` M, `1538` A, `153c` S, `16a8`/`16ac` vb {−2,0x40}/{−2,0xe} | `actor2d_ctor_strips` | 0x40 |
| SalginScene | `16b0` SceneVtbl (0 handleMessage `1068:0d73`, 5 createScreen `1088:5794`, 7 create `1068:29e2`) | `salgin_scene_ctor` `1088:5754` | 0x46 |
| Player2D | `16e4` M, `16e8` A, `16ec` S, `1858`/`185c` vb {−2,0x46}/{−2,0x14} | `player2d_ctor` | 0x46 |
| **Fighter** | `1860` FighterVtbl (placeAt, startTimer, walk), `186c` A, `1870` S, `19dc`/`19e0` vb {−2,0x54}/{−2,0x22} | `fighter_ctor` `1088:5654` | 0x4c2 = 0x56 + SO |
| Scene | `19e4` SceneVtbl | `scene_ctor` | 0x44 |
| GridBackdrop | `1a18` (20) | `grid_backdrop_ctor` `1088:5dec` | 0x450 |
| StatusBar | `1a68` S | `status_bar_ctor` | 0x53a |
| ControlPanel | `1bd4`, `1bf8` S, `1d64` O, `1d84`/`1d8a` vb | `control_panel_ctor` | |
| SalginBackdrop | `1d8e` GridBackdropVtbl (0 `salgin_backdrop_create`) | `salgin_backdrop_ctor` `1088:5ca2` | 0x450 |
| Animated3D | `1dde` A, `1de2` S, `1f4e` O, `1f6e`/`1f74` vb | | |
| FlagCondition, CompoundCondition, Condition | `1f78`, `1f84`, `1f90` | | 4, 8, 2 |
| **Opponent** | `1f9c` OpponentVtbl (placeAt, walk), `1fa4` A, `1fa8` S, `2114`/`2118` vb {−2,0x4a}/{−2,0x18} | `opponent_ctor` `1088:678e` | 0x4b8 = 0x4c + SO |
| **Banner** | `211c` M, `2120` A, `2124` S (identical to Actor2D's), `2290`/`2294` vb {−2,0x40}/{−2,0xe} | `banner_ctor` `1088:682c` | 0x4ae = 0x42 + SO |
| **EnergyBar** | `2298` M, `229c` A, `22a0` S, `240c`/`2410` vb {−2,0x48}/{−2,0x16} | `energy_bar_ctor` `1088:68c4` | 0x4b6 = 0x4a + SO |

SceneObjectVtbl field renames for SALGIN: slot 0x56 `isFighter` (TIRO `isProjectile`), 0x57
`isOpponent` (TIRO `slot62`), 0x58 `slot63` (TIRO `isTarget`), 0x59 `slot64` (TIRO `isCrossbow`).

The overrides per class are in `FUNCTIONS.md` ("The game classes").

## Classes (`/salgin`)

The convention is TIRO's: a class struct holds the non-virtual part, a leaf class ends with its
`vtordisp` word, and the SceneObject virtual base follows at the vbtable's offset. SceneObject
overrides get `this` = the SceneObject sub-object and reach their own class at negative
offsets (Fighter −0x56, Opponent −0x4c), so they stay untyped.

| Struct | Size | Fields | Confidence |
|---|---|---|---|
| `Fighter` | 0x56 | `player2d` (`Player2D`), `unk46`, `hitLock` +0x48 (1 while a hit reaction plays; blocks the next hit), `frameCount` +0x4a (frames shown of the current move; the move ends when it reaches `animation.framesLeft`), `unk4c`, `timerId` +0x4e (`fighter_start_timer`, 10), `health` +0x50 (91; lowered when the fighter trades blows, chooses the weak/strong reaction below 10), `unk52` byte (`'0'`), `vtordisp` +0x54 | medium |
| `Opponent` | 0x4c | `actor2d`, `unk40` (1 from the ctor), `hitLock` +0x42, `frameCount` +0x44, `health` +0x46 (91; weak/strong reaction below 6), `unk48` byte (`'0'`), `vtordisp` +0x4a | medium |
| `Banner` | 0x42 | `actor2d`, `vtordisp` | high |
| `EnergyBar` | 0x4a | `actor2d`, `leftEdge` +0x40 (0x122), `rightEdge` +0x42 (0x14d), **`playerEnergy`** +0x44, **`opponentEnergy`** +0x46 (both 91), `vtordisp` +0x48 | high |
| `SalginScene` | 0x46 | `scene` (`Scene`), **`clock`** +0x44 (90 seconds) | high |

Everything else (`SceneObject`, `Mover`, `Animation`, `Actor2D`, `Player2D`, `Game`, `Scene`,
`Backdrop`, `GridBackdrop`, `ControlPanel`, `StatusBar`, the lists, the conditions, `CrtFILE`) is
TIRO's struct as is; the code that uses them is byte-identical.

The move fields the game uses inside the engine structs: `Mover.direction` (+8; 1 left, 2
right), `Mover.stepX` (+0x1a), `Mover.targetX` (+0x16), `Mover.moving` (+0x30),
`Animation.framesLeft` (+0x3a, set from the strip's frame count) and the SceneObject's
`curStrip`/`curFrame` (+0x1a/+0x1c of the SceneObject) and x (+0xc).

## The game rules, as far as the data and the handler show

*Porrada na Sala de Ginástica*: a **one-round fight against the clock**. The player's Fighter
stands on the left (x 0), the Opponent to its right (created at x 200), both
at y 0x8c; the PORRADA banner and the energy bar sit above. Each side has **91 energy**; the
round lasts **90 seconds** (`SalginScene.clock`, drawn "%2.2d" at (0x136, 0x16)).

Controls (WM_KEYDOWN in `salgin_scene_handle_message`; the mouse does nothing):

| Key | Move (fighter strip) |
|---|---|
| PgUp | strip 0 attack (damage 1) |
| Up | strip 1 attack (damage 2) |
| Down | strip 2 attack (damage 1; plays `soco2`) |
| Home | strip 3 attack (damage 2) |
| End | strip 7, block |
| Insert | strip 5 (plays kick + pain2 at once; deals no damage) |
| Left / Right | walk (strip 4), 32 px a step; never closer than 100 px to the opponent, never right of x 400 |

- A move locks every move key until its animation ends; then the fighter returns to the guard
  stance (strip 6).
- **Hitting**: an attack within 0x79 (121) px takes `g_fighterDamage[strip]` off the opponent's
  energy (and its own `health`) and plays the blow waves. If the opponent is walking, in its
  strip 5 or in guard (4–6; 4–7 for the Down sweep) it plays a reaction from `g_reactionStrips`
  (weak or strong by its health); otherwise (it was attacking) the fighter's `health` loses
  `g_opponentDamage[the opponent's strip]` (a trade).
- **The opponent** (on the 200 ms beat): farther than 100 px it walks toward the fighter; within
  100 px and idle it **counterattacks**: `opponent_choose_attack` picks strip `rand() % 4`, the
  waves play, and the fighter's energy loses `g_opponentDamage[strip]`, **whether or not the
  fighter blocks** (a blocking or walking fighter only gets a reaction animation instead).
  After its attack ends the opponent steps back 100 px (at most to x 500).
- Every 7 energy lost adds an `energia.bmp` mark to the loser's side of the bar.
- **End**: at 0 seconds, or as soon as either energy is below 1. **The player wins unless their
  energy is below the opponent's** (a tie is a win). The winner plays strip 10; a player win
  also plays the boos, a loss plays `mane.WAV`. The game closes 3 s later on a win; on a loss
  when `mane.WAV` ends (MM_WOM_DONE 0x3bd posts WM_DESTROY).
- **Result** (WM_DESTROY): `PostMessage(noite, 0x40a, won, won ? playerEnergy * 100 : -1000)`.
  So a win scores 100 to 9,100 points; NOITE adds the score, takes a life on a loss, and on a
  win goes to the `espquete` cutscene (`src/handlers/4fsalgin.zig`).

## Candidate original bugs (for later, not in `BUGS.md`)

1. **`opponent_choose_attack` reseeds `srand(time(NULL))` on every call**, so every counterattack
   within the same second gets the same "random" strip.
2. **A stale DC is released**: WM_KEYUP LEFT calls `ReleaseDC(local_c, hwnd)` where `local_c` is
   only assigned by the 1-second clock branch of the same call (otherwise it is whatever the
   stack holds).
3. **Blocking does not reduce damage**: the counterattack takes the same energy from a fighter
   in strip 4–7 (walk, Insert move, guard, block) as from one that is attacking; only the
   reaction animation differs.
4. `Fighter.health`/`Opponent.health` and the EnergyBar energies are separate counters that do
   not always move together (a trade lowers only `Fighter.health`); only the EnergyBar decides
   the result.
5. The unreferenced word `64a4` sits where TIRO keeps `g_score`: SALGIN reports the energy instead
   and never uses it. (0x401, which restarts the clock stamp, is the engine's "scene started" post from
   `game_init` and `game_take_exit`.)
6. `backdrop_autoscroll` returns 0 before its body (`QUALITY.md` §3): compiled out, not a bug in
   play.

## Decompiler residue

- **24 virtual calls without an override** (`FarSlotSignatures.java 1090 calls` leaves them):
  the Object3D/Backdrop-range slots `[BX+0x4…0x4c]` in `1018` (`moveable_can_step`,
  `*_drop_to_support`, `*_move_to_and_drop`, `*_move_to_at_elev`, `object3d_redraw_overlapping`,
  `animated3d_tick`, `exit_tick`), `mover_restore_background` (3), `mover_move_tick`,
  `moveable_move_tick` (`[BX]`), `game_handle_message` (3), `control_panel_draw`,
  `exit_is_enabled`, and the 3 CRT function-pointer calls. TIRO typed its 28 by hand (`site`
  mode); phase 4 can do the same from TIRO's listing.
- The 216 SceneObjectVtbl calls (`[BX+k]`, k ≥ 0x50) were given their override with `site`
  mode: no other far vtable is that long.
- SceneObject fields through the virtual base keep TIRO's shape
  (`*(int *)((int)&g_opponent->actor2d.mover.stepX + vbptr->sceneObjectOffset)` is the
  opponent's `curStrip`), and the NULL tests print as DGROUP symbols.
- Per-strip table lookups with a computed index print as raw offsets (`strip * 2 + 0x27a`).

## Undefined bytes left in DGROUP (86)

One-byte NUL pads after odd strings/tables; the unreferenced latch words `0372–0377`,
`037a–037f`; CRT words also undefined in TIRO (`0636–063d`, `0658–0667`, `0670`, `0676`,
`06ac–06b3`, `0711` "(null)", `073e–0743`, `078e–07a3` the DOS errno map, `07a8` the two `"\"`);
the NMSG id words between the `s_nmsgR6xxx` strings; `26e0–26e3`; `3b75` (the occupancy pad);
`64a4`.

## Scripts (`ghidra/scripts/`)

| Script | Use here |
|---|---|
| `SalginCopyFromTwin.java` (new) | `/TIRO.EXE /tiro /salgin types`, then `fns <tsv>` |
| `DefineStrings.java` | the 98 strings |
| `FarVtables.java` | `FighterVtbl`/`OpponentVtbl` (`S|`) and the 77 tables (`A|`), with `/salgin 1090` |
| `NearStructs.java` | the 5 game structs |
| `NearGlobals.java` | the 142 globals |
| `FarSlotSignatures.java` (category no longer fixed to `/tiro`) | `1090 defs`, `1090 calls`, `1090 site …` |
| `NearNullTests.java` | `1018`, `1028`, `1058`, `1088` |
| `UndefinedRanges.java` | the list above |

Scratch, not committed (`zig-out/salgin/p3/`): `strings.arg`, `vt.args`, `glob.args`,
`so_sites.txt`, the TIRO/SALGIN DGROUP dumps `dg_*.tsv`, and the instruction-pair global map
`globmap.tsv` (`gs/SalginGlobMap.java`: each TIRO/SALGIN function pair with the same instruction
count votes TIRO global → SALGIN global; it fixed the CRT shift +0x150, the `+0x186` CRT tail and
the reordered app globals).
