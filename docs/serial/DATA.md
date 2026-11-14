# SERIAL.EXE: data map (phase 3)

DGROUP is Ghidra segment `1090` (0x25fb bytes initialised, 0x6578 allocated). All addresses are
`1090:` unless they say otherwise. Types live in the category `/serial`: TIRO's `/tiro`
copied by `SerialFromTiro.java types` (Crossbow→`Gun`, Arrow→`Bullet`), then adjusted where
SERIAL differs. SERIAL is TIRO's sibling build (`QUALITY.md` §0): near data, 2-byte `this`, near
vptr into DGROUP, 4-byte far vtable slots. `docs/tiro/DATA.md` is the reference for every engine
layout and name; this file records where SERIAL's data sits and what is SERIAL's own.

## Counts

| What | Count |
|---|---|
| Strings defined (Latin-1, exact length) | 93, named `s_camelCase` (TIRO's names where the string is TIRO's) |
| Vtables / vbtables applied | 52 / 25 (77 tables), labelled, one DATA reference per slot |
| Vtable structs | TIRO's 13 + SERIAL's **`TargetVtbl` (4 slots)**; `Vbtable`, `Vbtable3d` |
| Class and record structs | TIRO's 30, **`Target` redone (0x5c)**, `Crossbow`→`Gun`, `Arrow`→`Bullet` |
| Slot `FunctionDefinition`s / virtual-call overrides | 181 / 428 of 455 sites (`FarSlotSignatures.java`) |
| Globals typed (non-string, non-table) | 138 |
| NULL-test comments (`NearNullTests`) | 14 (the same sites as TIRO) |
| Undefined bytes left in DGROUP | 46 (pads and unreferenced CRT words, below) |

The decompilation of the whole program (`decall.c`, scratch) has **no `DAT_1090_*` left**. One
function does not decompile: `_output` (`1080:09be`, "bad instruction count exceeded"; the CRT
printf engine).

## How it was mapped

1. **A TIRO→SERIAL DGROUP map** (`dmap.py`): in every function pair that phase 2 matched, the
   instructions that align one for one carry DGROUP immediates and displacements that differ only
   by where the data moved. The votes give a piecewise map:

   | TIRO range | SERIAL | Δ | What moved it |
   |---|---|---|---|
   | `0000–00a9` | same | 0 | |
   | `00aa` title | `00aa` | | "Serial Killer" is 2 bytes shorter than "Tiro ao Alvaro" |
   | `00ba–0101` | `00b8–00ff` | −2 | |
   | `0102–02b9` | `0100–0309` | — | the game's own strip tables and strings (below) |
   | `02ba–02c5` | `030a–0315` | +0x50 | key latches |
   | `02c6–05ed` | `031a–0641` | +0x54 | MCI/WaveMix strings, WaveMix data, CRT data |
   | — | `0642–0691` | | **new: CRT time-zone data** (`_lpdays`, `_days`, `"TZ"`, `_timezone`, `_daylight`, `"PST"`/`"PDT"`, `_tzname`) |
   | `05f4–1003` | `0692–10a1` | +0x9e | CRT, vtables part 1, Game strings, `Fundo.bmp` |
   | `1004` TiroScene table | `1258` | | SERIAL links its Scene table after the panel's |
   | `1038–11f1` | `109e–1257` | +0x66 | the panel tables |
   | `11f2–1df9` | `128c–1e93` | +0x9a | |
   | `1dfa` TargetVtbl (3) | `1e94` (4) | | one more slot |
   | `1e06–6499` | `1ea4–6537` | +0x9e | the rest of the tables, CRT, NMSG, the BSS up to the player |
   | `649a–64a3` | `6538–6557` | — | the game objects (15 targets, not 4) |
   | `64a4–64ab` | `6558–655f` | +0xb4 | conditions |
   | `64ac–64bf` | `6560–656b` | — | 3 waves, not 5 |
   | `64c0–64c9` | `656c–6575` | +0xac | |

2. Every TIRO data item (`tiro_data.tsv`, exported read-only) in a mapped range was placed at its
   SERIAL address with its TIRO name and type, strings only where the bytes are the same string
   (all were, except TIRO's game strings and `Fundtiro.bmp`). `gen.py` writes the three specs
   (`strings.arg`, `vt.arg`, `glob.arg`) for `DefineStrings`, `FarVtables`, `NearGlobals`.
3. SERIAL's own data was read from the code (`1048`, `1068`) and typed by hand.

## DGROUP map

| Range | Contents |
|---|---|
| `0000–000f` | instance header (`g_instReserved` … `g_instStackBot`) |
| `0010–00a5` | `s_coordFormat`, HDC/layer overflow strings and captions |
| `00a6` / `00a8` | `g_nextId`, `g_unk00A8` (= 0x0b) |
| `00aa` | **`s_appName` "Serial Killer"**: window class, title, NOITE's `FindWindow` target |
| `00b8` | **`g_noiteWnd`** (set by 0x40b; the 0x40a/0x40c target) |
| `00ba–00eb` | `s_appIcon`, `s_alreadyRunning`, `s_userModule` ×2 |
| `00ec–00ff` | `g_started`, `g_handshakePending` (= 1), the engine handler's `g_keyLeft/Right/Up/Down`, `g_itemSelected`, `g_exitPending`, `g_selectedItem`, `g_dropElevation` |
| `0100–0111` | `s_trabuBmp`; **`g_gunStrip{Files,Frames,Widths,Heights}[1]`** = {`trabu.bmp`}, 3, 238, 105 |
| `0112–01b5` | the 15 target bitmaps `s_arabBmp` … `s_coelBmp` (`3s*.bmp`) |
| `01b6–024b` | **the target table**: `g_targetStripFiles[15]`, **`g_targetKinds[15]`**, `g_targetStripFrames[15]`, `g_targetStripWidths[15]`, `g_targetStripHeights[15]` |
| `024c–025d` | `s_balaBmp`; `g_bulletStrip*[1]` = {`bala.bmp`}, 3, 47, 31 |
| `025e–027d` | **`g_timerIds[8]`** = 3…10 and **`g_timerPeriods[8]`** = 200, 200, 200, 100, 5000, 5000, 10000, 10000 ms |
| `027e–02a5` | `s_panelBmp` ×2, `s_fontFace` "Serial", `s_fontFile` "arialbd.fot" |
| **`02a6`** | **`g_lives`** = 5 |
| `02a8–0309` | `s_mciOpenMusic` (`doom2.mid`, alias `musica`), `s_mciPlayMusic`, `s_tiros1Wav`, `s_morte2Wav`, `s_pracas01Wav` |
| `030a–0319` | `g_keyRightHeld`, `g_keyLeftHeld`, 2 unreferenced words, `g_keySpaceHeld`, 2 unreferenced words = 1, **`g_spawnToggle`** (`0318`) |
| `031a–04aa` | MCI and WaveMix strings, `s_negScoreFormat`/`s_scoreFormat`, overflow strings, WaveMix data (`g_waveMixOpenResult`, `g_waveMixSession`, `g_waves[20]`, `g_waveCount`) |
| `04aa–0641` | CRT data (TIRO's `04da–05ed` layout, +0x54); `g_crtUnk0622` is TIRO's `g_crtUnk05CE` |
| `0642–0691` | **CRT time-zone data** (new): `g_crtLpdays[13]`, `g_crtDays[13]`, `s_tzVar` "TZ", `g_crtTimezone` (28800 = PST), `g_crtDaylight` (1), `s_crtTzStd`/`s_crtTzDst`, `g_crtTzname[2]` |
| `0692–06bf` | `g_crtDosErrnoMap`, `g_crtAmblksiz`, `s_backslash` ×2, `s_fatalErrorCaption6` |
| `06c0–072f` | `s_updateListFull` (`MAX_OBJECT_QTY`) |
| `0730–0ed7` | vtables and vbtables, part 1 |
| `0ed8–10a1` | "Faltou redefinir o método Create…", `s_warningCaption`, occupancy overflow strings, `s_cannotOpenFile`, **`s_backgroundBmp` "Fundo.bmp"** (`1094`) |
| `10a2–232b` | vtables and vbtables, part 2 |
| `232c–2341` | `g_crtInitHook` (→ `init_static_conditions_entry`), three CRT hooks, `g_crtExitTable` (→ `crt_endstdio`) |
| `2342–2481` | `g_crtIob[20]`, `g_crtIob2` |
| `2482–25f9` | `s_nmsgMarker`, `g_crtNmsgTable` and the R6xxx strings |
| `25fc–3a8c` | `g_occupancyCount` `char[65][81]` |
| `3a8e–63af` | `g_occupancyObject` `SceneObject*[65][81]` |
| `63b0–6531` | `g_setSystemTimer`, `g_killSystemTimer`, `g_modulePath`, `g_instance`, `g_mainWindow`, `g_appActive`, **`g_score`** (`63c4`), `g_windowWidth`/`Height`, `g_modulePathBuf[260]`, `g_messageText[100]` |
| `6532–6557` | `g_game`, `g_serialGame`, **`g_gun`**, **`g_targets[15]`** (`6538`), **`g_bullets[1]`** (`6556`) |
| `6558–655f` | `g_conditionTrue`, `g_conditionFalse` |
| `6560–656b` | the 3 waves (far): **`g_shotWave`** (`tiros1.WAV`), **`g_hitWave`** (`morte2.wav`), **`g_pracas01Wave`** (`PRACAS01.WAV`, played by APPWNDPROC on every WM_PAINT) |
| `656c–6577` | `g_moduleHandle`, `g_crtSprintfFile`, `g_crtTzsetDone` (`6576`, `__tzset`'s once flag) |

## Strings

93 strings, Latin-1, exact lengths. 76 are TIRO's (same text, same name) at mapped addresses;
`s_nullString` and `s_nmsgMarker` keep TIRO's lengths (no NUL in the table). New:
`s_appName`, `s_trabuBmp`, the 15 `s_<name>Bmp` target files, `s_balaBmp`, `s_panelBmp`/`2`,
`s_fontFace`, `s_fontFile`, `s_mciOpenMusic`, `s_mciPlayMusic`, `s_tiros1Wav`, `s_morte2Wav`,
`s_pracas01Wav`, `s_tzVar`, `s_crtTzStd`, `s_crtTzDst`, `s_backgroundBmp`.

## Vtables

52 vtables and 25 vbtables, applied with `FarVtables.java` (labels as in TIRO; `tiro`→`serial`,
`crossbow`→`gun`, `arrow`→`bullet`). FUNCTIONS.md has the slot-by-slot comparison with TIRO: every
engine table is TIRO's.

| SERIAL `1090:` | Class | TIRO | Ctor |
|---|---|---|---|
| `0626` (7 far) | CRT float hooks | `05d2` | — |
| `0730` | Frame | `0692` | `frame_ctor` |
| `0734` | SceneObject | `0696` | |
| `08a0`, `08c0`, `0a2c` vb | Object3D | `0802` | |
| `0a30`, `0a34`, `0ba0` vb | Mover | `0992` | |
| `0ba4`, `0ba8`, `0d14`, `0d34`/`0d3a` vb | Portable | `0b06` | |
| `0d3e`, `0d42`, `0eae`, `0ece`/`0ed4` vb | Moveable | `0ca0` | |
| `0f8c` | Game | `0eee` | `game_ctor` |
| `109e`, `10c2`, `122e`, `124e`/`1254` vb | SerialPanel (ControlPanelVtbl) | `1038` | `serial_panel_ctor` `1088:5580` |
| `1258` | **SerialScene** (SceneVtbl: slot 0 `serial_scene_handle_message`, 5 `serial_scene_create_screen`, 7 `serial_scene_create`) | `1004` | `serial_scene_ctor` `1088:5806` |
| `128c` | **SerialGame** (GameVtbl: slots 1–4, 6 in `1048`) | `11f2` | `serial_game_ctor` `1048:0000` |
| `12a8` | Backdrop | `120e` | |
| `12f4`, `12f8`, `1464` vb | Animation | `125a` | |
| `1468`, `146c`, `1470`, `15dc`/`15e0` vb | Actor2D | `13ce` | |
| `15e4`, `15e8`, `15ec`, `1758`/`175c` vb | Player2D | `154a` | |
| `1760`, `1764`, `1768`, `18d4`/`18d8` vb | **Gun** (TIRO's Crossbow: overrides `play` 0x29, `tick` 0x2d, `isGun` 0x59) | `16c6` | `gun_ctor` `1088:5752` |
| `18dc` | Scene | `1842` | |
| `1910` | GridBackdrop | `1876` | |
| `1960` | StatusBar | `18c6` | |
| `1acc`, `1af0`, `1c5c`, `1c7c`/`1c82` vb | ControlPanel | `1a32` | |
| `1c86` | **SerialBackdrop** (GridBackdropVtbl, slot 0 `serial_backdrop_create`) | `1bec` | `serial_backdrop_ctor` `1088:5d50` |
| `1cd6`, `1cda`, `1e46`, `1e66`/`1e6c` vb | Animated3D | `1c3c` | |
| `1e70`, `1e7c`, `1e88` | FlagCondition, CompoundCondition, Condition | `1dd6` | |
| `1e94` (4), `1ea4` A, `1ea8` S, `2014`/`2018` vb {−2, **0x5a**} | **Target** | `1dfa` (3) | `target_ctor` `1088:683c` |
| `201c` (4), `202c`, `2030`, `219c`/`21a0` vb | Projectile | `1f7e` | `projectile_ctor` `1088:6976` |
| `21a4` (4), `21b4`, `21b8`, `2324`/`2328` vb | **Bullet** (TIRO's Arrow) | `2106` | `bullet_ctor` `1088:68de` |
| `232c`, `233e` | CRT init / exit entries | `228e`, `22a0` | |

**TargetVtbl** (SERIAL, 4 slots): `placeAt` (Mover's), **`startTimer`** (`target_start_timer`,
new), `moveTick` (`target_move_tick_or_stop`), `checkEdge` (`target_wrap_at_edge`). TIRO's has
no `startTimer`. ProjectileVtbl is TIRO's (`placeAt`, `moveTick`, `stepMove`, `tryStep`).

**Virtual calls.** `FarSlotSignatures.java 1090 defs` rewrote the 181 slot definitions (one
changed: `TargetVtbl_placeAtFn`), `1090 calls` put overrides on 428 of 455 virtual-call sites.
**27 are unresolved**: the 24 engine sites TIRO fixed by hand (`1018:091f`, `09f0`, `0a3c`,
`0c3d`, `0c87`, `0cc8`, `0ce9`, `14b4`, `14ff`, `15e1`, `1876`, `1bc7`, `1028:043b`, `046d`,
`04aa`, `1037`, `1030:0800`, `085e`, `08d4`, `1040:06be`, `0a3c`, `0b84`, `1058:017a`,
`1088:3394`) and the three CRT function-pointer calls. They are left to the phase-4 group that
owns each function (`FarSlotSignatures.java 1090 site <addr>=<Vtbl>`).

## Classes (`/serial`)

TIRO's layouts apply as they are to every engine class (same build; the ctors' `operator new`
sizes, the vbtable offsets and the field offsets of the 590 transferred functions agree). The
SERIAL classes:

| Struct | Size | Layout | Confidence |
|---|---|---|---|
| `Gun` | 0x4c (+ SceneObject = `new 0x4b8`) | TIRO's `Crossbow`: `Player2D` + `unk46` (= −1) + `unk48` + `vtordisp` +0x4a. `Player2D.lives` (+0x40) = 16 from `serial_game_create_player`, decremented on every shot; nothing tests it (the shots are unlimited) | high (byte-identical ctor) |
| **`Target`** | **0x5c** (+ SceneObject = `new 0x4c8`) | 0–0x3f TIRO's flattened Actor2D (`vtbl` a `TargetVtbl*`, `vbptr`, Mover fields, `animation` +0x32); `wrapFlag` +0x40; `timerId2` +0x42; `timerId13` +0x4a; `clockTimerId` +0x4c (long); `clockTicks` +0x50; `laneBusy[3]` +0x52; **`kind`** +0x58; `vtordisp` +0x5a. TIRO's `hitFrame` (+0x4e) is gone | medium-high: every offset seen in `1068`; `42–49` partly unread |
| `Projectile` | 0x48 | TIRO's | high |
| `Bullet` | 0x4a (+ SO = `new 0x4b6`) | TIRO's `Arrow`: `Projectile` + `vtordisp` | high |
| SerialGame / SerialScene / SerialPanel / SerialBackdrop | — | typed with their bases `Game`, `Scene`, `ControlPanel`, `GridBackdrop` (no own fields) | high |

`timerId2`, `timerId13`, `clockTimerId`, `clockTicks` and `laneBusy` are fields of every Target
but the game uses them on `g_targets[0]` (and `timerId13` on `g_targets[13]`) as the game's own
timers and lane flags.

## The game data

**The objects** (built by `serial_game_create_player`, `serial_create_targets`,
`serial_create_bullets`):
- **`g_gun`**: `trabu.bmp`, 3 frames of 238×105 (`curFrame` = the aim: 0 left, 1 straight, 2
  right; `gun_aim` cycles it with 'D'/'E' from the RIGHT/LEFT keys). `ARMA.BMP` (same size) is
  on the disc, unused.
- **`g_bullets[0]`**: `bala.bmp`, 3 frames of 47×31, step 20, timer 0xc at 55 ms. SPACE fires only while the bullet is not moving
  (`g_keySpaceHeld` is tested but, as in TIRO, nothing sets it, so key repeat fires again), plays `tiros1.WAV` and launches it from
  the gun at x+0x2a / +0x61 / +0xa2, y−0x1e / −0x1e / −0x14 by aim.
- **`g_targets[15]`**, one per bitmap, all created at start (`srand(time(0))` first). Targets 0–12
  get timer id 3 at 200 ms, 13–14 timer id 6 at 100 ms (`g_timerIds`/`g_timerPeriods` pairs).
  Each has a `kind` from `g_targetKinds`:

  | # | File | Frames × w×h | Kind | # | File | Frames × w×h | Kind |
  |---|---|---|---|---|---|---|---|
  | 0 | `3sarab` | 6 × 80×177 | 0 | 8 | `3snoel` | 4 × 48×95 | 0 |
  | 1 | `3sbaba` | 10 × 88×100 | 0 | 9 | `3snoem` | 16 × 124×105 | **2** |
  | 2 | `3sbabt` | 12 × 88×99 | **2** | 10 | `3svelh` | 10 × 74×102 | 1 |
  | 3 | `3sclu` | 13 × 92×127 | 0 | 11 | `3sesco` | 12 × 128×147 | 1 |
  | 4 | `3sfada` | 12 × 88×121 | 1 | 12 | `3spira` | 12 × 52×120 | 0 |
  | 5 | `3shitl` | 10 × 52×111 | 0 | 13 | `3skenn` | 2 × 200×67 | 1 |
  | 6 | `3slenn` | 11 × 40×136 | 1 | 14 | `3scoel` | 6 × 188×60 | 1 |
  | 7 | `3smafi` | 9 × 88×105 | 0 | | | | |

  The frame counts and sizes match the BMPs on the disc (vertical strips).

**Lanes and spawning** (in `serial_scene_handle_message`, WM_SYSTIMER):
- three **lanes** = three groups: targets 0–6, 7–12 and 13–14, one on screen at a time each
  (`g_targets[0]->laneBusy[0..2]`, cleared when a target leaves or is hit);
- every **5 s** (timer id 7 on target 0): if lane 0 is free, a random one of 0–6
  (`rand() % 7`) enters at x 20, y 1 and walks right; if lane 1 is free, one of 7–12 (`rand() %
  6` through the handler's jump table);
- every **10 s** (timer id 10 on target 13): lane 2 alternates (`g_spawnToggle`) and picks 13 or
  14 (`rand() % 2`) — Kennedy's car or the rabbit;
- the shared timers (id 3, id 6) step every walking target (`isMoving` → `checkEdge`).

**Scoring** (`target_hit` → `serial_hit_kind1` / `serial_hit_kind0_2`, `g_score` a 16-bit int in
the BSS, starts at 0, drawn as `" %04d"`/`"-%04d"` by `serial_draw_score`):
- kind 1: **+100**;
- kind 0: **−100**;
- kind 2: **+200**;
- each hit plays `morte2.wav`, stops the target, frees its lane and redraws it.

**Lives** (`g_lives` = 5): a **kind-2** target that reaches the frame two before the end of its
strip "shoots": `target_move_tick` plays `tiros1.WAV` and decrements `g_lives`; at 0 it sends
WM_DESTROY. Kinds 0 and 1 never cost a life.

**The clock**: target 0's `clockTimerId` (timer id 8, 60 000 ms, `startTimer` index 99). The first
tick counts (`clockTicks` 0→1), the second sends WM_DESTROY: **a game lasts 2 minutes** unless the
lives run out first.

**The result** (WM_DESTROY, `1068:1529`): stop the waves, close WaveMix and MCI, then
`PostMessage(g_noiteWnd, 0x40a, hwnd, MAKELONG(g_lives, g_lives > 0 ? 500 : g_score))`.

So the game, as the data shows: survive two minutes of passers-by in three lanes, shoot the
kind-2 "killers" before they fire (+200), the kind-1 ones for +100, avoid the kind-0 ones
(−100). Which of the 15 figures is which is only in the table above; the meaning of the kinds (who
is the serial killer) is a reading of the bitmaps for phase 4.

**Music and waves:** `doom2.mid` through MCI (alias `musica`, replayed from 0 on MM_MCINOTIFY, paused
and resumed on WM_ACTIVATE like TIRO); `tiros1.WAV` (the shot, both the player's and a killer's),
`morte2.wav` (a hit), `PRACAS01.WAV` (every WM_PAINT). On the disc but not loaded: `CARREGA.WAV`,
`CARREGA2.WAV`, `LPVITOR.WAV`, `METRAL.WAV`, `TIROS.WAV`, `VELHA.MID`, `ARMA.BMP`.

**The grid** (`serial_backdrop_create`): TIRO's 32-px grid, walls at columns 0 and 19 for rows
5–13 and row 13 for columns 0–18. **Background** `Fundo.bmp` (640×480); the score box is the
192×32 rectangle at (416, 400), text at x = 460 + 32·i, y = 408.

## Candidate original bugs (for BUGS.md later; not verified at run time)

- **S1 — always a win.** The 0x40a `wParam` is the minigame's own `hwnd` (`[BP+0x10]`, the
  handler's window argument), never 0. NOITE's `handler_3farmcai` stores `wParam != 0` in
  `minigameWon[2]`, so SERIAL always reports a win, even when the lives ran out (TIRO sends
  `g_score > 0`). NOITE's own fallback (the window vanished) posts `wParam` 0.
- **S2 — the score is packed into the high word.** `lParam = MAKELONG(g_lives, g_lives > 0 ? 500 :
  g_score)`; NOITE adds the whole 32-bit lParam to its score, i.e. `500·65536 + lives` (32 768 005
  with 5 lives) for a survived game, or `g_score·65536` (0 lives) — the intent was probably
  `MAKELONG(score, …)` / a 16-bit score.
- **S3 — `Gun.lives` counts down forever.** `serial_scene_handle_message` decrements the gun's
  `Player2D.lives` (16) on every SPACE press, even one ignored because the bullet is still flying,
  and never tests it (TIRO ended the game on it); after 16
  shots it goes negative. Harmless.

## Undefined bytes left in DGROUP (46)

One-byte NUL pads after odd strings (`0088`, `00a5`, `00a9`, `0255`, `0299`, `0309`, `052d`,
`061d`, `067f`, `0eff`, `0f61`, `0fb5`, `101b`, `1041`, `1069`, `1093`, `3a8d`); the two
unreferenced words = 1 at `0314–0317` (TIRO's `02c4`); unreferenced CRT words as in TIRO
(`053a–0541`, `055c–0565`, `0568–056b`, `0574`, `057a`, `05b0–05b2`, `05b4–05b7`, `0642–0647`,
`06a6`, `06bd–06bf`, `2330`); `25fa–25fb` after the NMSG end; `63c0` (TIRO's `6322`).

## Scripts

| Script | Use here |
|---|---|
| `SerialFromTiro.java types` | the `/serial` category from TIRO's `/tiro` |
| `CopyTypesFromProgram.java /TIRO.EXE SetSystemTimerFn KillSystemTimerFn` | the two timer function types |
| `FarVtables.java /serial 1090 <vt.arg>` | `TargetVtbl` (S), `Vbtable`/`Vbtable3d` (P), the 77 tables (A) |
| `DefineStrings.java <strings.arg>` | the 93 strings |
| `NearGlobals.java /serial <glob.arg>` | the 138 globals |
| `FarSlotSignatures.java 1090 defs`, `1090 calls` | slot definitions, 428 overrides |
| `NearNullTests.java 1018`, `1028`, `1058`, `1088` | the 14 NULL-test comments |
| `UndefinedRanges.java 1090:0000` | the list above |

The `Target` struct was rebuilt inline (Structure API: TIRO's first 0x40 bytes kept, the tail
replaced). Scratch, not committed (`zig-out/serial/`): `dmap.py` (the DGROUP map), `gen.py` (the
three specs), `SerialExportData.java`, `handler.c`/`decall.c` (decompile dumps).
