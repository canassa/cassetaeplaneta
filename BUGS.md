# NOITE.EXE — original-game bugs

Each entry: what the code does, what the player sees, evidence, confidence (1–10).
"Latent" = the faulty code exists but the shipped game never executes it.
Addresses are Ghidra `seg:off`; names are the current Ghidra names.

---

## Bugs that affect the shipped game

### B1. Some losses take a life without the game-over test (lives can reach 0 or go negative)
- **Where:** `handler_2fsuabig` 1020:02da (shot by the robber) and 1020:064d (too many offers); `handler_2fasspap`
  1020:0d00 (hitman time-out); `handler_4fboydj` 1020:cdb8 (timer 0x14 after the boo / globe button).
- **What the code does:** `DEC g_lives` and then switches scene, with no comparison. There is no central
  "lives ≤ 0" check anywhere (all `g_lives` reads: control-panel text, save writer, loader, and three
  handler tests). The other handlers do not agree on the rule either: `handler_1fcarnbo` / `handler_baracut1` /
  `handler_2floucos` test `lives <= 0` *before* decrementing (game over instead of losing the last life);
  `3fhall`, `3fsauna`, `3ffarao`, `3farmcai`, `3fstree1`, `3fpapmal`, `4fmarte`, `4fsalgin` do `DEC; JZ/JNZ`
  (game over exactly when lives reaches 0); `4fbar` (1020:dd4e, 1020:e6a3) does `DEC; JNS` (game over only at −1).
- **Effect:** losing the last life in 2fsuabig, 2fasspap or 4fboydj does not end the game; the panel shows 0
  (then negative) lives. Once lives is negative, the `DEC; JZ` handlers never reach exactly 0 again, so the
  player cannot get a game over there any more (only the `≤ 0` and `JNS` handlers still catch it).
- **Evidence:** the 17 `DEC word ptr ES:[0x2a]` sites and the instructions around each (checked one by one).
- **Confidence:** 9 (code); 8 (that the player can reach lives = 0 in one of those three scenes — needs the lives
  to be at 1 when entering them, which is normal play).

### B2. The dance-floor music never plays (MCI path to a file that is not on the disc)
- **Where:** `handler_4fpistav` 1020:c5b2–c5ea; string 1020:d534 `fase4\4fboydj\maeemae.wav`.
- **What the code does:** `mciSendString("open <CD>fase4\4fboydj\maeemae.wav type waveaudio alias
  dancacasseta")`, then `play dancacasseta notify`; the result is not checked. MCI has no fallback (unlike
  `wave_open`).
- **Effect:** `FASE4\4FBOYDJ\` has no MAEEMAE.WAV (the disc has it only at the root and in `PAN\WAV\`), so the open
  fails and the 4fpistav scene is silent; the "replay on MCI end" loop and the WM_ACTIVATE pause/resume act on
  a device that does not exist.
- **Evidence:** disassembly above; disc listing of `FASE4\4FBOYDJ`.
- **Confidence:** 9.

### B3. Two time-out lines are never heard (double `.WAV.WAV` extension)
- **Where:** `handler_2fcopmau` (bad cop, timer 0x15) — string 1020:31d6 `fase2\2fcopmau\PMAUS08.WAV.WAV`;
  `handler_2fcopmu` (policewoman, timer 0x15) — string 1020:3246 `fase2\2fcopmu\PLMULR71.WAV.WAV`.
- **What the code does:** opens `<CD>` + that path. `wave_open` (1018:bb94) retries `<root>pan\wav\<fname>.wav`
  with `_splitpath`'s file name, which here is `PMAUS08.WAV` / `PLMULR71.WAV`, so the retry is
  `…PMAUS08.WAV.wav` and also fails; `wave_play` then posts 0x3bd (wave finished) at once.
- **Effect:** when the player waits too long at these roadblocks the cop's time-out speech is skipped; the
  scene goes straight to the arrest cutscene.
- **Evidence:** strings in the EXE; wave_open retry logic; files exist as `FASE2\2FCOPMAU\PMAUS08.WAV`,
  `FASE2\2FCOPMU\PLMULR71.WAV`, `PAN\WAV\…`.
- **Confidence:** 9.

### B4. Loading a game leaks a DOS file handle (save file never closed)
- **Where:** `ini_game_load_game` 1018:5274 (open at 1018:52f6).
- **What the code does:** `ini_open("<name>.ini")`, reads StartScene/PlayerX/PlayerY/Score/Lives and passes the
  handle to the loadObjects and createStartScene slots; nothing calls `ini_close` / `_lclose` on it (the only
  `ini_close` caller is the save writer).
- **Effect:** every load — including every *new game*, which loads `jogo0` — leaves one file handle open. A Win16
  task has a small handle table (20 by default), so a long session with many loads/new games can make later
  file opens fail (saves, INI reads).
- **Evidence:** callee list of 1018:5274 (no close), callers of `ini_close` (only 1018:48e2).
- **Confidence:** 9 (leak); 6 (that it is ever noticed in play).

### B5. 2ffesta3 plays an uninitialised path when entered from an unexpected scene
- **Where:** `handler_2ffesta3` 1020:7452, the 0x401 case (switch on `Game.prevSceneNumber` around 1020:75a0–7603).
- **What the code does:** copies a remark path into the stack buffer `wavePath` only for previous scenes 7, 11,
  13, 20 and 23; for any other previous scene it still concatenates `<CD>` + the uninitialised buffer and opens
  it as a wave.
- **Effect:** e.g. after returning from the options screen or loading a game saved in this scene, a garbage path is
  opened; normally the open fails and the remark is silently skipped (wave_play fakes the end), but the
  concatenation runs on unterminated stack data.
- **Evidence:** decompilation + disassembly of the switch; `LAB_1020_7603` reached from the default case.
- **Confidence:** 8.

### B6. The pope's-closet puzzle (3fpapclo) can never be reached
- **Where:** `handler_3fhall` 1020:7ce4–7d1b; INI `[3fhall]` `Exit=139 … 3fpapclo` (CASSETA.INI line 733).
- **What the code does:** the hall handler intercepts right clicks on all five doors (ids 139–143 = 0x8b–0x8f)
  and maps each, via a shuffled table, to sauna / TIRO / 3ffarao / 3fpapmal / 4finifes; it returns "handled",
  so the INI exit to `3fpapclo` never fires. No other INI exit or code path switches to 3fpapclo (the right-click
  hook only *returns* to it from its own drawers).
- **Effect:** the whole closet game (20 drawers, Portables 169–188, verdict waves `papar0N.wav`, `papatime.wav`)
  is dead content; the door that should lead to it gives the pope's punishment video (3fpapmal) directly, which
  in the INI design is the closet's *failure* outcome.
- **Also inside 3fpapclo** (moot because unreachable): the 60 s / 18 s timers only play a warning, and timer 0x16
  sends 0x3bd, which the handler ignores unless a verdict wave is pending — there is no real time limit.
- **Exception:** with the control panel open, a right click on the lowest ~46 px of the door reaches the engine,
  which takes the INI exit to 3fpapclo after all (B38).
- **Evidence:** hall dispatch code; INI exits; strings/xrefs for `3fpapclo`.
- **Confidence:** 8.

### B7. 4fdj's "too many offers" branch is dead (counter never incremented)
- **Where:** `handler_4fdj` 1020:b7ac; `g_s4fdjOfferCount` (DGROUP 0x0c24): writes 1020:bf7f, c00f, c293 (all 0),
  test `CMP [0xc24],3` at 1020:c2ce.
- **Effect:** offering wrong items to the DJ never triggers the "too many tries" outcome the other give-item scenes
  have. Harmless.
- **Confidence:** 9.

### B8. 2fportd2: the "right item" flag is tested but never set
- **Where:** `handler_2fportd2` 1020:505c — `if (OfferCount < 4 || g_s2fportd2RightItem == 1)`; the global is only
  ever written 0.
- **Effect:** none visible (the wallet case is handled separately); dead condition. Harmless.
- **Confidence:** 9.

### B9. Missing wave files referenced by CASSETA.INI (data)
- **Where:** INI lines; played through `wave_open` (no file, no `PAN\WAV` copy).
  - Object NomeWAVE: `[2fshardi]` Animated 11 `fase2\2fshardi\stones08` (line 357).
  - WAVE replies: `[2fshardi]` `STONESS02` (line 381, typo of STONES02); `[2fgaydir]` `BOIOL16`, `BOIOL18`
    (439, 445); `[2fblitg]` `fase2\2fcopbom\RDJDJ00` (498); `[2fcopmau]` `RPMMA08` (531, 553), `RPMMA10` (549),
    `RPMMA11` (551); `[4fbarbo2]` 22 `ESOTRnn` lines (962–983).
- **Effect:** the reply is silent and the script advances at once (wave_play's faked 0x3bd). The 4fbarbo2 lines
  are probably never looked up (that handler does no WAVE lookup), and 2fshardi's item-48 line is overridden by a
  hard-coded wave, so the audible impact is limited to the 2fgaydir/2fblitg/2fcopmau replies and 2sshaa's line.
- **Evidence:** script over the INI against the disc listing (case-insensitive) and the PAN\WAV fallback rule.
- **Confidence:** 8 (missing files); 6 (exactly which of them are ever requested).

### B10. 3fhall door destinations are shuffled once per run
- **Where:** `handler_3fhall` 1020:7b06 (`g_s3fhallShuffleDoors`, initially 1, cleared after the first shuffle and
  never set again).
- **Effect:** the door → destination table stays the same for the whole session, including after losing and
  coming back, starting a new game or loading. Possibly intended; listed for completeness.
- **Confidence:** 7 (code 9; whether it is a bug is a design question).

### B11. JARDIM: the CD drive's current directory is never restored
- **Where:** `handler_espquete` 1028:0c6f–0cc2 (same shape in `handler_4fjarvamp`).
- **What the code does:** before launching JARDIM it `_chdrive`/`_chdir`s into `<CD>jardim`; on the result message
  it restores the drive, copies `g_driveCD` into a local and strips its last character, but never calls `_chdir`
  with it.
- **Effect:** the CD drive keeps `jardim` as its current directory. Paths are built from `g_driveCD` (`\` in the
  shipped CASSETUP.INI), so they stay absolute and nothing visible follows; the game ends right after anyway.
- **Confidence:** 8 (code); effect negligible.

---

### B12. The opaque row copy skips black pixels at the end of each row
- **Where:** `dib_rows_copy32` 1000:0114 (32-bit segment), tail loop 1000:018a–019a.
- **What the code does:** rows are copied four bytes at a time unconditionally, then the last `width & 3` bytes
  go through a loop that skips the byte when it equals AH — a leftover from the transparent variant. AH is 0
  there (set by the routine's mode check), so pixel value 0 is not copied in those last 0–3 columns.
- **Effect:** in opaque blits whose width is not a multiple of 4, palette index 0 in the rightmost 1–3 columns
  keeps whatever was underneath.
- **Evidence:** disassembly; reproduced by running the original routine in an emulator against a row-copy model.
- **Confidence:** 9 (code); the visible effect depends on index 0 appearing in those columns.

### B13. A bitmap file that is not a readable DIB stays open (file-handle leak)
- **Where:** `load_dib` 1010:041c; the `read_dib_info` result test at 1010:04d5–04d7.
- **What the code does:** after `OpenFile` succeeds, `read_dib_info` returns NULL for a file that is too short,
  has an unknown header size or too many colours; `JZ 0x1010:04bb` then returns NULL directly, skipping the
  `_lclose` at 1010:05c9 that every other path after the open reaches (including the GlobalReAlloc failure).
- **Effect:** each such load leaves one DOS handle open. The shipped BMPs all read fine, so the game is not
  expected to hit it; a corrupt or truncated asset would leak a handle per load (Win16 default: 20).
- **Evidence:** disassembly of 1010:04c4–04d7 and 1010:05c6.
- **Confidence:** 9 (code); 3 (that the shipped game ever reaches it).

### B14. Every cutscene leaks its animation and bitmaps
- **Where:** `scene_dtor` 1018:2896; `Scene.animation` (+0x94), set by `ini_scene_create` for an
  `Is_1Animation` scene (its own `Exit=` line, never added to the scene's object list).
- **What the code does:** the destructor deletes the objects of the scene's list and the backdrop, but
  nothing ever deletes `Scene+0x94` (no function that reads it frees it; `GlobalFree` is called only
  by `load_dib`, `frame_dtor`, `scene_object_dtor`, `backdrop_dtor` and the CRT).
- **Effect:** each 1Animation scene left (intro, cutscenes, the 6fsaida endings…) keeps its Exit object,
  its strip array and its 640×480 DIB (≈300 KB of global memory) until the program ends. A long session
  slowly eats memory; Windows reclaims it at exit.
- **Port:** the object is parked in `Game.leakedObjects` (freed after `app_exit`, as Windows would);
  `Fixes.free_scene_animation` deletes it in the scene destructor.
- **Evidence:** disassembly of 1018:2896; xrefs of +0x94 (scene_ctor, ini_scene_create,
  ini_scene_handle_message, handler_1fcozin0, two object helpers — none frees it).
- **Confidence:** 9 (code); 5 (that the growth is ever noticed).

### B15. 3fhall: a right click on anything but a door takes the last door again
- **Where:** `handler_3fhall` 1020:7c66–7d37; `g_s3fhallDoorChoice` (1050:0bc8, initially −1).
- **What the code does:** the door id → `doorChoice` mapping (7ce4–7d1b) runs only when the pick hit door
  0x8b–0x8f, but every right click reaches `switch (doorChoice)` at 7d1e: no hit, a hit on the player or the
  floor, a bottom-strip click that hits nothing. The first time −1 matches no case (click swallowed).
- **Effect:** back in the hall after choosing a door (TIRO loss, 3ffarao/3fentseg exits, 3fstree2), a right
  click on the floor or the player goes to that door's destination again (relaunches TIRO, the sauna, …).
  The bottom-strip test (y 0x168..0x1cc, any object hit) also catches clicks on the lowest ~46 px of the
  doors, which go to 3fentseg.
- **Port:** reproduced (`src/handlers/3fhall.zig`); `Fixes.hall_door_click_only` ignores clicks that hit no door.
- **Confidence:** 9 (code); 8 (reachable).

### B16. 4fbarboy: the right item earns no score
- **Where:** `handler_4fbarboy` 1020:a050, the MM_WOM_DONE right-item path (after 1020:b0a2).
- **What the code does:** the item (Portable 273, the Martian) is hidden and moved to the used list, but its
  `scoreUse` (+0x4a) is never added; every other give-item scene adds it (2fportdi 1020:4992, 2fblitg 1595,
  2fcopmau 1f86, 2fcopmu 2aa5, 2fgaydir 6abe).
- **Effect:** the player misses 500 points (and has already paid the 50 `scoreTake` on the drop).
- **Port:** reproduced (`src/handlers/4fbarboy.zig`); `Fixes.barboy_right_item_score` adds it.
- **Confidence:** 9.

### B17. The roadblock handlers keep running after switching to the arrest scene (use after free)
- **Where:** `handler_2fblitg` (switch 1020:1557, then 18dc–18f5), `handler_2fcopmau` (23a6, then 23ab–23c6),
  `handler_2fcopmu` (2a67 time-out and 2eaf no gift, then 2eb4–2f0a).
- **What the code does:** `ini_game_switch_scene` (1018:15ea) deletes the old scene with all its objects
  (`scene_scalar_dtor` 1018:1954), the cop included; the handler then calls the cop's stopAndRedraw (slot
  0xcc) through the freed block's vtable. 2fcopmu goes on: `resetOffers` has just set
  `g_s2fcopmuGreetingPending` to 1, so it opens and plays `fase2\2fcopmu\garots05.WAV` and leaves
  `greetingSaid` = 1, `greetingPending` = 0.
- **Effect:** the use after free is normally invisible (the block still holds a vtable or has been reused
  by the new scene's object); other heap reuse would crash. In 2fcopmu the boys' line plays over the
  2apremu2 arrest, and on the next visit the stale flags skip garots05 (without the gift the arrest follows
  the cop's greeting at once).
- **Port:** the stale call on the freed cop is skipped (it cannot be reproduced; docs/DESIGN.md
  "Conventions"); the 2fcopmu wave and flags are reproduced, `Fixes.roadblock_return_after_switch`
  returns right after the switch. In 2fblitg an offer still pending when the time-out wave ends goes on
  into the wrong-item path after the switch: the item returns to the inventory (score penalty) and the
  reoccupy of the freed hit object and the cop's stopAndRedraw are skipped (in the original they would
  write a phantom into the new scene's occupancy grid).
- **Confidence:** 9 (code); 7 (effects).

### B18. 2fportdi: a second offer while the doorman answers loses the first item
- **Where:** `handler_2fportdi` 1020:4442–4515 (WM_RBUTTONUP while the doorman's animation runs).
- **What the code does:** it stops the doorman, `portable_pick_up(selectedItem)`, `wave_stop(doorman.wave)`,
  then carries on into the offer (offerCount++, a new reply, returns 0 so the engine drops the item). But
  `selectedItem` is already the new item B; item A, dropped on the scene by the previous offer, is never
  picked up, and `wave_stop` flushes the doorman's own NomeWAVE channel, not A's reply.
- **Effect:** the two replies overlap; A's reply end charges B's `scoreMisuse` and returns B; A stays on
  the scene, uncharged; the offer counter advances twice.
- **Port:** reproduced (`src/handlers/2fportdi.zig`); no fix flag (A's pointer is lost by then).
- **Confidence:** 9 (code); 6 (timing).

### B19. The 32-bit score is shown and saved as a 16-bit int
- **Where:** `control_panel_draw_texts` 1018:2184–21af (format `%7.7d`, 1018:270e); `ini_game_save_game`
  1018:4a30–4a49 (`Score=%d`, 1018:5eb8); `ini_game_load_game` 1018:542e–5447 (`ini_read_score` 1018:adbe,
  then `CWD`).
- **What the code does:** both `sprintf`s push the dword `g_score` (1050:002c) for a `%d`, which reads the
  low word only (the lives text has its own `sprintf`, so no argument shifts); the loader reads a 16-bit
  `%d` and sign-extends it into `g_score` and the player's score.
- **Effect:** above 32767 the panel shows a negative score (32768 → `-0032768`); saving and loading makes
  the wrap permanent. Reachability: the positive Portable/ZoomPort scores add up to about 18 400 (ZoomPort
  69 alone gives 10 000 on use) plus nine minigames' scores, so passing 32767 is plausible.
- **Port:** reproduced (`src/panels.zig`, `src/save.zig`); `Fixes.score_32bit` shows, writes and reads the
  whole long.
- **Confidence:** 9 (code); 6 (that a normal playthrough passes 32767).

### B20. Giving the bible to the rock star freezes the game (2fshardi)
- **Where:** `handler_2fshardi` 1020:32b2, MM_WOM_DONE with `g_s2fshardiRightItem` set (the right-item
  branch after the score/used-list block): 2sshaa (object 11) plays once and `wave_play(2sshaa.wave)`;
  only the 0x403 for object 11 leaves the scene (`2ffesta3`).
- **What the code does:** 2sshaa's NomeWAVE `fase2\2fshardi\stones08` is on neither the disc nor `PAN\WAV`
  (B9), so its wave is NULL and `wave_play` posts MM_WOM_DONE at once. The handler takes the same branch
  again (the right-item flag and the selected item are never cleared there): the score gets `scoreUse`
  again, the item is added to the used list again, 2sshaa restarts and another MM_WOM_DONE is posted.
  Posted messages come before timers, so 2sshaa's play-once never ticks and the 0x403 never comes.
- **Effect:** after the bible is accepted the scene stops redrawing and the game hangs (the queue spins).
  With the wave present the loop would only restart 2sshaa every few seconds until its 0x403.
- **Evidence:** the port reproduces it (the harness stops on a "message storm"); disc listing.
- **Port:** reproduced; `Fixes.shardi_reply_once` ignores the repeated MM_WOM_DONE once the item is in the
  used list, and the scene ends on 2sshaa's 0x403.
- **Confidence:** 8 (code and data); 6 (that the shipped CD had no other copy of the wave).

### B21. A stale animation timer takes a one-animation video scene's exit when the video ends (3fstreet, 3ffarao)
- **Where:** `ini_scene_handle_message` 1018:915e, WM_SYSTIMER for an Is_1Animation scene: the exit is ticked
  when the timer id equals the exit's NumTimer and `g_iniIsAVI` is 0; `animation_stop` is the only place that
  kills an animation's system timer (`scene_dtor` does not).
- **What the code does:** an animation still running when its scene is left keeps its system timer. When the
  video of a one-animation scene ends, `animation_close_avi` clears `g_iniIsAVI`, the handler launches the
  minigame, and the next stale tick with the exit's timer id runs `exit_tick` on the video exit, which posts
  0x402 and takes the INI exit:
  - 3fsegura's guard (timer 5, 150 ms, never stopped) → 3fstreet's video exit (timer 5) goes to `3fhall`.
  - 3fsauna's attendant `3sboal` (timer 6, 200 ms) → 3ffarao's video exit (timer 6) goes to `JTETRIS`,
    which is not an INI section: `ini_seek_section` 1018:9caa shows "Não consegui encontrar a sessão
    procurada" and returns 0 without seeking, so `ini_scene_create` 1018:6bee reads on from where the file
    was left (the `[3fhall]` header after `[3ffarao]`) and stops with "Linha [3fhall]] inválida" and
    `exit(1)`. The right click plays the attendant *once* (1020:802a–8057: Animation slot 0x1c,
    `animation_play_once`): 8 ticks, the last 1.6 s after the click, which stops it and kills its timer.
    Its wave GLOBO2.WAV ends at 1.415 s and launches SAUNA.EXE (timer 0x14 polls for its window every
    100 ms); once the minigame's 0x40c arrives, the sauna handler swallows every WM_SYSTIMER
    (1020:7fe6–8012, returns 1). If that happens before the last tick, the attendant is frozen mid-play
    with its timer running, and the timer outlives the scene. In 3ffarao the same race decides again: the
    stale tick must come after the video ends and before ENCAIXE.EXE's 0x40c, from which 3ffarao's handler
    swallows the ticks in turn.
  - A hall door's own exit animation (timer 6, B38) cut short by the hall's switch to 3ffarao (a right click
    low on the door with the panel open, then one higher up before the door has finished) keeps timer 6
    running too: the pharaoh video ends in `JTETRIS` the same way.
- **Effect:** 3fstreet: depending on which comes first, the street escape minigame result arrives in 3fhall
  (whose handler takes it for the shooting gallery's: a win sends the player to 3fprisao), or the hall's own
  FindWindow poll reports a lost game (a life) first. The player can end up in the hall without having played
  the escape, or lose a life for it. 3ffarao: once the sauna has been visited, taking the pharaoh door can
  end the program with a fatal INI error when the pharaoh video ends, if SAUNA.EXE showed its window by the first 100 ms poll and answered within the next ~85 ms (and ENCAIXE.EXE
  was not faster than the stale tick). With the port's stub minigames (window after 1.5 s) it does not
  happen; `--minigame-startup 0 --minigame-reply 0` reproduces it (faithful build, `--scene 3fhall`: right
  clicks on the sauna door (x 560 in that run's shuffle), in the sauna, then on the pharaoh door (x 210)).
- **Evidence:** port traces (`noite --trace`): timer 5 runs from 3fsegura on, timer 6 from 3fsauna on when
  the minigame answers before the attendant's last tick; the code paths above. The port used to start the
  attendant looping (SceneObject `play`), which kept timer 6 alive in every run and made the 3ffarao fatal
  error deterministic; it now plays once, as the original.
- **Port:** reproduced; `Fixes.avi_exit_ignores_timer` does not tick a video (`isAvi`) exit from the timer path.
  The playthrough script relies on the 3fstreet shortcut, so its `--fix` run leaves this fix (and the door
  reshuffle) out.
- **Confidence:** 8 (code, port traces); 5 (how often the 3fstreet timing lines up in the original, and how
  fast SAUNA.EXE and ENCAIXE.EXE start and answer on a period machine for the 3ffarao case).

### B22. 2ftaxi keeps handling a click on the scene it has just deleted (use after free)
- **Where:** `handler_2ftaxi` 1020:9a3a: a right click on the exit to 3fentseg switches scenes and returns 0.
- **What the code does:** `ini_scene_handle_message` goes on with its `this` (the deleted scene): the engine's
  WM_RBUTTONDOWN default reads `this->isClickExit`. The far heap gives the new scene (same size, allocated
  right after the delete) the same block, so `this` reads the new scene and nothing visible happens.
- **Port:** `game_scenes.switchScene` reuses the old scene's block for the new one, as the heap does.
- **Confidence:** 8 (code); 7 (block reuse).

### B23. An item picked up from the panel while a reply plays is consumed instead of the offered one
- **Where:** every give-item handler's MM_WOM_DONE (2fsuabig, 2fblitg, 2fcopmau, 2fcopmu, 2fshardi, 2fportdi,
  2fportd2, 2fgaydir, 4fbarboy, 4fdj, 4fbar): the reply's end works on `Game.selectedItem`, which the
  engine overwrites as soon as another inventory slot is pressed (`game_handle_message` WM_RBUTTONDOWN).
- **What the code does:** with a new item selected (still in the inventory) when the reply ends, the
  right-item path scores it, `object_list_remove(globalObjects)` does nothing (the item is not there) and
  `object_list_add(usedObjects)` relinks it: its `next`/`prev` now belong to the used list, the inventory
  ends at it (the items after it are cut off and lost), and the offered item stays on the scene. The
  wrong-item path charges `scoreMisuse` and "returns" the new item. A reply that ends while an item is
  merely selected (any wave end, e.g. 4fbarboy's intro) is taken as a wrong offer of it.
  Any right press during the reply also overwrites the handlers' hit object (2fportdi 1020:4306 WM_RBUTTONDOWN
  stores the query's object, NULL on the panel): at the reply's end the wrong-offer path then skips the take
  back and only clears the selection, so the offered item stays on the scene for good (2fsuabig 1020:0000 too:
  the gift, the right item, stays on the floor and the hold-up goes on). A slot pressed during the reply and released on a
  character after its end reaches the WM_RBUTTONUP offer with `itemSelected` set and `selectedItem` NULL: a
  NULL far-pointer read (2fportdi `takeItemBack`).
- **Effect:** quick players lose items and score; the inventory shows fewer items than its count, or, with
  items in the used list, more than its 8 slots (the chain runs on into the used list: the extra icons are
  drawn past the last slot, under the score box). The one-button mode makes it easy: a tap on a slot selects
  the item and it stays selected (2fportdi: offer the bible, tap the next slot while the driver answers: the
  bible stays in the car). Port repro, 2fsuabig: the gift offered, the wallet's slot held through the reply:
  the wallet is consumed, the Oscar after it is cut off, the gift stays on the floor.
- **Port:** reproduced (the lists are shared the same way); at exit only the items the inventory still owns
  are parked (`object_init.sceneObjectDtor`), the cut-off ones stay unfreed as in the original.
  `Fixes.reply_keeps_offer`: after an offer (a drop in one of these scenes, `game_input.rightUp`) the right
  button does nothing until the next MM_WOM_DONE, while the offered item is still the selected one lying in
  the scene.
- **Confidence:** 8.

### B24. A wave that ends with no item offered crashes the bar and the hold-up (4fbarboy, 2fsuabig)
- **Where:** `handler_4fbarboy` 1020:a050 and `handler_2fsuabig` 1020:0000, MM_WOM_DONE: the wrong-item path
  reads `Game.selectedItem` unchecked. 4fbarboy gets there with no dialogue flag set and
  `g_s4fbarboyRightItem` 0; 2fsuabig only tests that the selected item *and* the hit object are both NULL.
- **What the code does:** 4fbarboy swallows right clicks on most of its objects, but not on the boys
  (228, `garots08`): the engine default plays their NomeWAVE, and its end arrives with no item selected.
  In 2fsuabig any right click stores the object under it in `g_s2fsuabigHitObject`, so the next wave end
  (with no item) passes the test; the reverse (an item selected, no object hit) reaches the hit object's
  `reoccupy` through NULL. In 4fbarboy the right-item path reads it unchecked too: a right click on an empty
  inventory slot while the barman's reply to the Martian plays clears the selection, and the reply's end calls
  through the NULL item at 1020:ad7a (its NULL tests come after, from 1020:ada8). 2fshardi's gift timer (0x14, 5 s) hands the "selected item" back even when a
  reply ending in between has cleared the selection.
- **Effect:** a NULL far-pointer read: a general protection fault (the game is closed by Windows).
- **Port:** panics naming this bug, as the original faults; `Fixes.reply_without_item` ignores that wave
  end.
- **Confidence:** 7 (code; which clicks lead there).

### B25. An item dropped onto an object it overlaps leaves its image behind when picked up again
- **Where:** `game_handle_message` 1018:0000, WM_RBUTTONUP: `moveToAndDrop` (1018:0e1b, Portable's
  1010:54d0 → `mover_set_position` 1010:2b62, which keeps the old position as the previous one), then the
  item is drawn and made visible by hand; when `findSupport` returns an object whose hit box overlaps the
  item's (`scene_object_hitbox_overlaps` at 1018:0f22, JNZ 10d3) no `moveTo` follows. `mover_restore_background`
  1010:b3fa erases `(min(x, prevX), min(y, prevY), width + |stepX|, height + |stepY|)`.
- **What the code does:** only the walk to a resting place (its stop, 1010:c968) or `mover_show`/`mover_hide`
  set the previous position to the current one. Without a walk, `prevX/prevY` stay where the item was last
  picked up (often another scene). The pick-up (WM_RBUTTONDOWN: `portable_pick_up`, reset_rects,
  `hideAndInvalidate`, `redrawOverlapping`) restores a rectangle that starts at the old position and is only
  one frame (plus a step) wide, so it misses the item's image when the two are farther apart than a step.
- **Effect:** the item's picture stays on the screen (and in the backdrop bitmap) after it is back in the
  inventory; dropping it again draws a second one. E.g. the wallet dropped on the corridor's bathroom door
  (animation 256; it stays there because of B30). The give-item scenes (2fportd2, 2fblitg, 2fcopmau, 2fcopmu,
  3fprisao…) hit it when an offered item is handed back: in 4fbar the wine offered to the sportsman (396,293)
  stays drawn there once the reply has handed it back (`tools/smoke.py --offers` without the fix).
- **Port:** reproduced (`game_input.rightUp`); `Fixes.drop_syncs_previous_position` sets the previous
  position to the dropped one, as `mover_show` does.
- **Confidence:** 9 (code, port repro).

### B26. A walk that is still going on when the scene changes resumes in the new scene (and leaves a frame behind)
- **Where:** `game_take_exit` 1018:12c6, `ini_game_switch_scene` 1018:15ea and `ini_game_load_game` 1018:5274
  put the player with `moveToAndDrop` + `show` + `playIdle` and never stop its movement; WM_SYSTIMER
  (1018:04ee→050a) runs `moveTick` on the player's timer (shared with its animation) while `moving` is set.
- **What the code does:** a walk started before the exit animation ends (a click while the door opens, or
  an exit clicked mid-walk) keeps `moving`, the Bresenham state and `nextX/nextY` from the old scene. The
  first tick in the new scene steps from that stale next position: the player jumps there (`prevX/prevY`
  are the arrival point) and `mover_restore_background` 1010:b3fa (one frame plus one step from
  `min(x, prevX)`) does not cover the frame `mover_show` drew at the arrival point.
- **Effect:** a copy of the player's walking frame stays next to the player (e.g. the corridor entered from
  the bedroom), and the player is somewhere else than where the exit put it, walking on towards the old
  scene's target. It stays until something repaints that area.
- **Port:** reproduced (`game_scenes.enterScene`, `save.loadGame`); `Fixes.scene_entry_stops_walk` cancels
  the walk on arrival (no 0x404, the timer keeps running for the idle animation).
- **Confidence:** 8 (code, port repro; the click timing in the original).

### B27. The lives and score drift inside their boxes as the control panel slides
- **Where:** `control_panel_draw_texts` 1018:20a0 draws the lives at (4, 0x1db − h) and the score at
  (0x221, 0x208 − h), h = `control_panel_get_visible_height` 1010:462c = (frame + 2) × 20.
- **What the code does:** the texts move in 20-pixel steps per panel frame, but the art
  (`PAN\BMP\PAINEL.BMP`, 4 frames of 640×120 drawn at y 340) does not: the lives badge's top is at
  screen y 433, 400, 381, 362 (steps 33, 19, 19) and the score box's at 455, 436, 417 for frames 1–3
  (off screen when closed).
- **Effect:** the lives text sits 2 px below its badge's top when the panel is closed and 15, 14, 13 px
  below once it slides: the "3" jumps down to the badge's bottom edge as the panel opens. The score is off
  by 1 px only (5, 4, 3 below its box).
- **Port:** reproduced (`src/panels.zig`); `Fixes.panel_text_follows_art` takes the y per frame from the
  art — lives 2 px below the badge (the closed look), score 4 px below its box (glyphs centred).
- **Confidence:** 9 (code constants and art measurements; cosmetic).

### B28. A door sounds when it is right-clicked from too far away to take it
- **Where:** `ini_scene_handle_message` 1018:915e, WM_RBUTTONDOWN: `wave_play` of the clicked object's
  wave (any object but a portable); the reach test is later, in `game_handle_message` 1018:0000
  (player within 1.5 of its hit width of the exit, exit enabled).
- **What the code does:** the scene handler plays the wave before the game decides whether the click
  takes the exit; a click from too far (or on a disabled exit) then does nothing.
- **Effect:** the door-opening sound plays but the door does not open and the player stays.
- **Port:** reproduced (`src/scene.zig`); `Fixes.exit_sound_needs_reach` plays an exit's wave only when
  `game_input.exitTakesClick` says the click takes it. Other objects keep their sound on every click.
- **Confidence:** 9 (code).

### B29. Picking up an item can leave the item under it (or the door behind it) unclickable
- **Where:** `occupancy_grid_vacate_cell` 1010:d884 (`MOV dword [BX+0x289c],0` before the count step),
  called for every cell of the hit box by `occupancy_grid_vacate` 1010:d9be; `occupancy_grid_occupy_cell`
  1010:d840 stores its object over the previous one; `occupancy_grid_query_rect` 1010:daba returns the
  first occupied cell's count and only the objects it met (`out_obj` is set only for a non-NULL object);
  `game_handle_message` 1018:0000, WM_RBUTTONDOWN, acts only when the count is > 0 *and* the object is
  non-NULL.
- **What the code does:** a cell keeps a count of its occupants but a single object pointer, the last
  occupant's. A vacate (`hide`/`hideAndInvalidate` on a pick-up, a hidden object, each step of a walking
  moveable or a dropped item falling to its rest place, `reoccupy`) clears the pointer of every cell under
  the object even where the count says other objects remain.
- **Effect:** drop an item, drop a second one over it (or anywhere their 16-px cells meet), pick the second
  up: right-clicks on the shared cells of the first find a count with no object and do nothing, so the
  first can no longer be picked up there (all of it when it lies inside the second's box). The same happens
  to a door or hotspot under a picked-up item. Leaving and re-entering the scene rebuilds the grid and
  cures it. The walking player does not cause it (its occupy/vacate do nothing).
- **Evidence:** the asm above; port repro in the corridor (present dropped at 560,330, wallet at 570,330,
  present picked up: the wallet's 9 cells read count 2, object NULL; right-clicking it does nothing).
- **Port:** reproduced (`src/grid.zig`); `Fixes.vacate_keeps_other_occupants` points those cells back at a
  remaining occupant after each vacate (`grid.repointOccupants`, from `backdrop.vacate`: the visible scene
  and global objects covering the cell, the last in list order winning like the last occupy).
- **Confidence:** 9 (code, port repro).

### B30. A dropped item can stay in mid-air or rise instead of falling
- **Where:** `game_handle_message` 1018:0000, WM_RBUTTONUP: `moveToAndDrop` (1018:0e1b) and `setElevation`
  (0e37) at the release point, then Object3D slot 01 (0e64, `object3d_find_support` 1010:5b3c): the *first*
  visible object of the scene list, then the global list, for which `object3d_is_above_on_screen` 1010:5a2a
  (the item's hit box overlaps the other's horizontally and its top is strictly higher) or `scene_object_hitbox_overlaps`
  1010:bc1e (5bd8) holds. Overlapping hit boxes (1018:0f22, `JNZ 10d3`): no move. Otherwise the item walks to
  `y = height/2 + (front + back)/2` of the support's projected top face (two `perspective_project_point`
  1010:4964 calls, 0f80/0fed), capped at `viewHeight − 100` (1031–103f); with no support, to
  `viewHeight − 100` (108a).
- **What the code does:** "support" means any object, whatever it is and whatever its 3D size: a door, an
  invisible hotspot animation, a drawer, a wall-high exit. Size-0 objects have their top face on their anchor
  row; tall ones far above the release point. The INI's 3D placement also often misses the picture (the
  corridor table's `_3DOriginY` is 50 for a 129-row image: its 200-high top projects to rows 142–175, about
  90 rows above the drawn top, beside the Mona Lisa).
- **Effect:** in the corridor (1fcorred), an item released over the bathroom door (Animated 256, an invisible
  120×300 placeholder) or the parents' door (Exit 50) or the phone (Exit 53) overlaps it and hangs where it was
  released (the cases of B25). Released between the table and the bathroom door (x ≈ 450, y ≈ 200–240), it
  takes the table as support and climbs to row 138, next to the painting. Over the Mona Lisa it takes the
  table's drawer (Exit 49, size 0) and ends in front of the drawer. In the bedroom an item released over the
  bed overlaps the radio (animated, 177×124) and hangs; in the sitting room one dropped over the armchair
  takes a door hotspot (Exit 114) and sinks into the chair.
- **Evidence:** the asm above; port repro with the wallet (item 71, `tools/play/full.input` lines 1–27):
  released at (520,100) → support 256, overlap, stays; at (435,215) → support 47 (the table), target row 178
  (bottom), walk ends at (435,145), 70 rows up.
- **Port:** reproduced (`game_input.rightUp`). `Fixes.drop_falls_onto_support` (`fallToRest`): the item falls
  straight down from its release row onto the first support top under it, or to the original's floor row; it
  never rises. A support is a visible local, animated, exit or portable with a non-zero 3D box (doors and
  paintings drawn as size-0 hotspots are not; characters are not; a door with a 3D height has its top far
  above any release row) under the item's centre whose projected top face, kept inside its hit box (moved
  to the hit box's top row when the two miss each other, as for the corridor table), is at or below the
  release row; the item rests on the face's middle row. The item enters the draw list, and keeps its 3D
  place, on the support's top with its anchor on its bottom row (the `ZoomPort=` items' anchor is their
  top-left corner, which put them behind the bed they lie on); the fall's steps reset that place
  (`portable_move_to_and_drop`), so its stop restores it. With B25's fix, the previous position stays synced
  (the drop sets it, the fall's stop resets it). An offer is left alone: it stays where it was released, in the
  character's hands, while the reply plays. An offer is any drop in a scene whose handler answers offers (the
  eleven of B23's list, `pub const answers_offers`): each takes WM_RBUTTONUP with an item, clears the
  selection unless it was released on one of its characters, and there starts the reply and returns 0
  (2fportdi 1020:4306: the driver's head, mouth, hands and the passing bushes, of which only the mouth has
  `WAVE=` lines). The original's own drop may move an offer too (2fportdi, the bible released on the mouth
  walks 100 rows down to a support's top). `tools/smoke.py --offers` checks that with the fix an offered item
  stays put until it is taken back and leaves no image behind.
- **Confidence:** 9 (code, port repro).

### B31. The sitting room's package is cut in half by the table when the player walks by
- **Where:** `object3d_is_in_front_of` 1010:5c5c (first test: `other.depth + other.sizeD < this.depth` → behind)
  orders `draw_list_insert` 1018:2cce; `object3d_redraw_overlapping` 1010:5e10 redraws, in draw-list order,
  each object the moving player's dirty rectangle overlaps: `scene_object_draw_dirty_to` 1010:b746 draws only
  that rectangle of a local, `mover_draw_dirty_to` 1010:b8a0 the whole frame of a portable.
- **What the code does:** the package (`Portable=107`, elevation 90 = the table's top, anchor 140 rows down
  its 116-row frame) unprojects to depth −133..−93, past the back of the table (`Local=104`, −295..−145), so
  it sits behind the table in the draw list. `object_list_attach_to_scene` 1010:d4f6 shows the portables
  after the scene's locals, so it is first drawn on top; a redraw then draws it whole and the table's
  overlapped strip over it.
- **Effect:** with the player by the table (feet near x 505–590, y 365), the package's top shows the table
  instead, down to the bottom of the player's rectangle (about row 392); every later redraw there cuts it
  again. The other items with an elevation (48, 54) do not rest on a box top.
- **Port:** reproduced (`space3d.isInFrontOf`); `Fixes.item_on_support_in_front` puts an object whose
  elevation is the top of another's non-flat box, with overlapping hit boxes, in front of it.
- **Confidence:** 9 (code, port repro).

### B32. The sitting room's cat is drawn over the open control panel
- **Where:** `ini_scene_handle_message` 1018:915e, WM_SYSTIMER (ids 5–10): each running object's tick
  (slot 34, `animated3d_tick` 1010:631e → `scene_object_redraw` 1010:173e, whose erase restores the
  pristine background over the whole frame) is followed at once by `update_list_flush` 1010:e362. Only
  afterwards does `game_handle_message` 1018:0000 (WM_SYSTIMER default) draw the control panel and status
  bar (`control_panel_draw` 1018:1f1c, slot 1B) into the backdrop, and its flush finds the list empty.
- **What the code does:** the panel is not in the draw list, so `object3d_redraw_overlapping` 1010:5e10
  never puts it back; the frame rectangle goes to the screen without it, and the panel's redraw only
  reaches the backdrop bitmap.
- **Effect:** with the panel open, a right click on the cat (`Animated=111`, `handler_1fsala` 1018:ebf0, a
  click on the panel's top edge, y 340–397) plays it over the panel: a 137×85 rectangle of cat and rug
  covers it and stays after the animation ends, until something repaints that area (the player's idle
  ticks fix the part they overlap). Any scene animation under an open panel does the same.
- **Port:** reproduced (`src/scene.zig`); `Fixes.bars_over_scene_animation` draws the panel and status
  bar into the backdrop after each such tick, before the flush.
- **Confidence:** 9 (code, port repro).

### B33. The kitchen's cockroach is missing when the player comes back
- **Where:** `ini_scene_create` 1018:6bee, `Static=` line of an object already in the global list: slot 1B
  `draw` (`animation_draw` 1010:26fc → `scene_object_draw_dirty_to` 1010:b746, which draws only the dirty
  rectangle) runs before `scene_object_reset_rects` 1010:1576; `object_list_attach_to_scene` 1010:d4f6
  does the same.
- **What the code does:** the dirty rectangle is the one `scene_object_compute_overlap` 1010:bda8 last
  stored when the player overlapped the object in the previous visit (and, in the attach, the one the
  scene's later objects just stored); the new backdrop is the pristine bitmap, so only that strip is drawn.
- **Effect:** back in `1fcozin0` the cockroach (`Static=124`, a 243×135 frame the player always overlaps)
  shows only a leg and an antenna under the counter until the player walks over it and repaints it piece
  by piece. The ketchup (`Static=62`) and the father in `1fquarpa` (`Static=248`) can be cut the same way.
- **Port:** reproduced (`src/scene_loader.zig`); `Fixes.static_redraw_whole_frame` resets the rectangles
  before that first draw.
- **Confidence:** 9 (code, port repro).

### B34. A refused item comes back to the first panel slot, but the open panel still shows the old icons
- **Where:** an offer is a drop: `handler_2fsuabig` 1020:0000 starts the reply and returns 0 (1020:018b), so
  `game_handle_message` 1018:0000 WM_RBUTTONUP drops the item at the release point and redraws the panel
  without it (erase, draw, invalidate). At the reply's end (MM_WOM_DONE, 1020:057a) `portable_pick_up` 1010:6fe6
  → `object_list_add` 1010:d322 links it back at the head of the inventory: the first slot. Nothing puts the
  panel on the screen again: `control_panel_draw` 1018:1f1c (WM_SYSTIMER default) draws the icons into the
  backdrop only; a slide or a drop is needed. The other give-item handlers (B23's list) hand items back
  the same way.
- **Effect:** while the panel stays open (no mouse move above it, e.g. on a touch screen), its icons are one
  slot off from the items: dragging the first icon offers the refused item again, with the same reply. In
  2fsuabig: the camera refused, the Oscar's icon in the first slot offers the camera.
- **Port:** reproduced; `Fixes.panel_follows_inventory` redraws the open, still panel as a drop does at the
  next WM_SYSTIMER when the inventory differs from the one it last showed, after flushing the update list
  (its overlap tests would cut the queued rectangle of an item just dropped across the panel's edge to the
  strip under the panel, as `update_list_flush` 1010:e362 blits each object's rectangle as it is then).
- **Confidence:** 8 (code, port repro).

### B35. A walk that starts or stops shows the player as two poses for a moment
- **Where:** `directional_player_move_to` 1010:e5e8 (and the edge walks 1010:e6c4/e76e, the stop 1010:e818 →
  `directional_player_play_idle` 1010:e59e) switch the strip with `animation_set_strip` 1010:24fa, which
  redraws nothing when the frame size stays the same. Until the player's own timer redraws it, another
  animation's tick (`animated3d_tick` 1010:631e: `scene_object_reset_rects` on the player, then its slot 58
  `object3d_redraw_overlapping` 1010:5e10) draws the player's clip rectangle over each object it stands in
  front of with the *new* frame, over the old frame still in the backdrop, and invalidates it.
- **Effect:** with the kitchen's cockroach or ketchup animating, a click that starts a walk (or one blocked at
  once, e.g. against the stove or the tomatoes) shows the idle pose with pieces of the walking profile over
  it, for one tick (two when the first step is blocked: the stop goes back to strip 3 the same way).
- **Port:** reproduced (`1fcozin0`, the player against the tomatoes, the cockroach running);
  `Fixes.player_strip_redraws` redraws the player whole (and what stands in front of it) on its strip change.
- **Confidence:** 8 (code, port repro).

### B36. A dropped item released just above its resting place never stops falling
- **Where:** `game_handle_message` 1018:0000, WM_RBUTTONUP: the walk's x is the release point less half the
  item's width and the view origin (1018:0ee3–0ef7), and the walk (slot 37, 1018:1073/10ce →
  `mover_move_to` 1010:c3ba) takes x as the bottom centre and subtracts half the width again, so the target
  is half the item to the left. `portable_ctor` 1010:6e2c gives items a horizontal step of 0 (step 0,10).
- **What the code does:** when the fall is shorter than half the item's width, the Bresenham line is
  x-major: `mover_at_target` 1010:c1ea compares x, which never moves, so the walk never ends; y moves on the
  diagonal steps only, past the target, down off the view (up, when released below its rest row).
- **Effect:** in the sitting room the stool released over the cat (320,280) sinks through the cat and the
  control panel and is gone (it stays in the scene, off screen; it can't be picked up again). Any item
  released less than half its width above its resting row does it, in any scene; the fall stutters too
  (every other step only moves sideways).
- **Port:** reproduced (`game_input.rightUp`); `Fixes.drop_walk_straight` walks the item down its own
  column (`movement.fallTo`). B30's fall (`fallToRest`, not in the original) always does.
- **Confidence:** 9 (code, port repro).

### B37. Two doors that finish on the same tick: the second takes the next scene's exit (3fprisao → the hall with the street video playing, then a GPF)
- **Where:** `exit_tick` 1010:68d4 posts 0x402 with the exit's *index* (`POSTMESSAGE` after its last frame);
  `game_handle_message` 1018:0000 (0x402 case) takes `scene->exits[wParam]` of the *current* scene when
  `Game.exitPending` is set; `ini_scene_handle_message` 1018:915e (0x401) sets `exitPending` for every
  Is_1Animation scene that is not a click exit; `game_take_exit` 1018:12c6 reads `scene->exits[index]` unchecked.
- **What the code does:** every door of a scene ticks on the same system timer. Two doors right-clicked within
  one tick (3fprisao: 3sportcd and 3sportce share timer 6, 200 ms; a second right click is still taken until the
  first door's first frame) finish on the same WM_SYSTIMER and post two 0x402. The first takes its exit; the new
  scene's 0x401 is *sent* during the switch, so a video scene arms `exitPending` before the second 0x402, still
  queued, is read, and that one takes the new scene's exit of the old index. Nothing ties a 0x402 to the scene
  that posted it.
- **Effect:** 3sportcd (→ 3fstreet) then 3sportce (exit 0): 3fstreet's video exit 0 goes to 3fhall at once,
  skipping the street escape, with the street video still open and drawn over the hall. When it ends, its
  MM_MCINOTIFY reaches the hall: `ini_scene_handle_message` calls `exit_has_key_object` on the hall's NULL
  `animation`, a general protection fault. With an index the new scene has no exit for (two hall doors taken
  through their INI exits, B38: 3ffarao then exit 3) `game_take_exit` reads the exit through NULL, a GPF too.
- **Port:** reproduced (the panics name this entry); `Fixes.exit_finished_stays_in_scene` drops the queued 0x402
  messages when a scene is entered. Repro: `--scene 3fprisao`, right clicks at (460, 200) and, 60 ms later, at
  (220, 200).
- **Evidence:** port traces (`noite --trace`: 0x403/0x402 for both doors on one tick, the second 0x402 after the
  sent 0x401); the code paths above. An earlier port note blamed the guard's stale timer 5 (B21) for this
  3fstreet → 3fhall jump; the trace shows the other door's 0x402 instead, and no 3fsegura visit is needed.
- **Confidence:** 8 (code, port repro); 6 (how often a player double-clicks two doors inside 200 ms).

### B38. 3fhall: a right click low on a door with the control panel open takes the door's INI exit (JPASSARA: a fatal INI error)
- **Where:** `handler_3fhall` 1020:7b06, 1020:7bff–7c1f: with y ≥ 0x168 and the control panel open it returns 0
  before any door test; `game_handle_message` 1018:0000 (WM_RBUTTONDOWN) then tries the panel and, when the
  click selects no item, picks the object under it and plays the door's INI exit.
- **What the code does:** the five doors reach y 406, the open panel starts lower and the panel stays open while
  the pointer is at y ≥ 0x154, so a right click on the lowest ~46 px of a door (or on an empty part of the panel
  over a door) is not the hall's: the engine takes the door's own `Exit=` line, unshuffled: 143 → 3fsauna,
  142 → `JPASSARA`, 141 → 3ffarao, 139 → 3fpapclo, 140 → 4FINIFES.
- **Effect:** the TIRO door's exit names `JPASSARA`, which is not an INI section: "Não consegui encontrar a sessão
  procurada", then "Linha [3fpapclo]] inválida" and `exit(1)` (as `JTETRIS`, B21). The pope's-closet door goes
  to the closet game (so B6's "never" is wrong for this path). A door animation cut short by a right click
  higher up (the hall's own switch) keeps its system timer 6, which matches 3ffarao's video exit (B21: the
  pharaoh video ends in `JTETRIS`). With one-button play the panel is open after any tap near the bottom and a
  tap on a door is aimed where the finger was, so this is easy to hit on a touch screen.
- **Port:** reproduced; `Fixes.hall_low_click_takes_door` lets the engine have a low click only when it is on an
  item or the options button of the open panel; on a door it is the hall's shuffled door. Repro: `--scene 3fhall`,
  move to (300, 470), then to (300, 380), right click at (200, 380).
- **Evidence:** the disassembly at 1020:7bff; port runs (`ini: no section [jpassara]` in the log).
- **Confidence:** 8.

### B39. The player's feet show, and animate, in the slots of the open control panel
- **Where:** `control_panel_draw` 1018:1f1c → `animation_draw` 1010:26fc → `scene_object_draw_dirty_to`
  1010:b746 blits the panel frame with `dib_copy_transparent` 1010:0000 (key `g_unk001C`); the eight inventory
  slots of the panel bitmap are key-coloured holes. `game_handle_message` 1018:0000 (WM_SYSTIMER) ticks the
  player (1018:04a7 timer test, 04e5 slot 34 tick / 050a slot 3C move tick: `player_tick` 1010:65ee →
  `animated3d_tick` 1010:631e → `scene_object_redraw` 1010:173e), then draws the panel (1018:0616, slot 1B) and
  the status bar into the backdrop, then flushes (1018:065a).
- **What the code does:** the player's frame is drawn whole into the backdrop, under the panel's rectangle too;
  the panel drawn after it covers its paper but not the holes, and the flush puts both on the screen. Nothing
  is ever drawn over the panel's paper (each timer redraws the panel before the flush, apart from B32's scene
  animations), but the slots are windows onto the backdrop.
- **Effect:** with the player low in a scene (feet below row ~400: 1fgarage, 3fprisao, 3fhall, 1fquarbo…),
  the panel slides open over him and his shoes and legs stay in the slots in front of him, swaying with his
  idle frames and walking with him; an item dragged out of a slot leaves his legs in its place. It reads as the
  player drawn over the menu.
- **Port:** reproduced (`--scene 1fgarage`, click at (320, 425), then move to (320, 470));
  `Fixes.panel_slots_show_background` fills the slots of the panel's frame (key pixels no key-coloured path
  joins to its top row, so the gaps of the torn top edge still show the scene) with the pristine background
  picture each time the panel is drawn.
- **Confidence:** 8 (code, port repro).

### B40. Green bushes show through the taxi driver's face
- **Where:** `[2fportdi]` (the Portuguese taxi driver, `handler_2fportdi` 1020:4306): `Animated=21` (his head
  and body, `2sbusf`, at 384,85) has `_3DOriginY` 70, `Animated=24` (the bushes passing by the windows,
  `2smovs`, 278×54 at 170,161) 0. `scene_add_object` 1018:292e sorts both into the draw list by
  `object3d_is_in_front_of` 1010:5c5c, whose first tests compare the depths `object3d_set_elevation`
  1010:531c unprojects from the anchor rows: the head's (155) is farther than the bushes' (161).
- **What the code does:** the bushes are drawn after the head. Each tick of their animation
  (`animated3d_tick` 1010:631e) restores the background and redraws what they overlap in draw-list order
  (`object3d_redraw_overlapping` 1010:5e10): the head, then the bushes over it, then the mouth (`Animated=23`,
  anchored lower) over both.
- **Effect:** in one frame of three the right-hand bush covers the driver's face around the mouth: green
  dots above the moustache and down the left of the mouth (x 410–447, y 171–211 less the mouth), offer or
  not. Not the art (neither sprite has transparent pixels there); `[2fportd2]` anchors the same head at 100
  (row 185) and has no bushes, and `[2fshardi]`'s and `[2fgaydir]`'s drivers are anchored below theirs.
- **Port:** reproduced; `Fixes.driver_in_front_of_scenery` anchors the head at 100, as `[2fportd2]`, when the
  handler sees it created (before the bushes enter the draw list).
- **Confidence:** 9 (INI, code, port repro).

## Harmless: wrong paths rescued by the wave fallback

`wave_open` retries `<root>pan\wav\<file name>.wav`, and `PAN\WAV\` holds a copy of almost every wave, so these
handler-built paths (wrong or missing directory) still play:
`fase2\2fgaytdir\boiolr01/02/05.wav`, `boiols03.wav` (2fgaydir; directory is `2fgaydir`),
`fase2\2shardi\STONES02/04/07.wav` (directory is `2fshardi`), `<CD>STONES07.wav`, `<CD>PLMULR71.WAV` (no directory),
`fase2\2ffesta\boiols02/ASSASS02/stones03/PORTGS03.WAV` (2ffesta3; not in `2FFESTA\`), `fase2\2fcopmu\garots05.WAV`,
`fase2\2fportdi\RADIOS01.WAV`, `fase2\2fcopmau\Brasil.wav`, `fase2\2BFEDRIV\musicar.wav`, `fase2\2apolit\tiro.wav`,
`fase4\4fboydj\dance2.wav` / `djrespb2` / `djrespr` / `djpede` / `maeemae.wav` (via wave_open; the MCI one in B2 is
not rescued), `fase4\4fbarboy\barcaido.wav`, `fase4\4fbar\okvamp.wav`, `pair0/1/2.wav`, `papatime.wav`, `bumbeb.wav`,
`vaifundo.wav`, `vaias.wav`. The disc root also carries copies of ASSASS02, BOIOLS01–03, MAEEMAE, MUSICAR,
PLMULS03, PMAUS03, PORTGS03 and STONES03 — apparently a late workaround for the same problem.
Confidence 9 (string scan of the EXE + disc listing + fallback rule).

## Harmless: dead or redundant code in the handlers
- **Dead WAVE lookups:** `handler_2fgaydir`'s "present" branch (1020:63a3–6416) looks up a WAVE line into
  `g_s2fgaydirWavePath` (1050:a778) and then plays `boiolr01.wav`; `handler_4fbarboy`'s fourth offer
  (1020:a61c–a6af) runs `ini_find_wave(0xdf, 3, item)` + `ini_asset_path` and then plays `barcaido.wav`.
  Neither INI section has a matching line.
- **4fbar, sportsman answer:** reads the picture position from `g_s4fbarSpeso` (1050:aaa0, at 1020:de0a)
  instead of `g_s4fbarSpesp` (aaa8); objects 287 and 288 are both at 375,46 and never move.
- **4fbar, esoteric answer:** right answer switches to 4FSACAET, discards the update list and switches to
  4FSACAET again (1020:dd1a, e238); a wrong answer with lives < 0 builds 4FSACAET before 6fsaida
  (dd96 → e6e2). The scene is just built twice (0x401 is sent synchronously; the second switch frees the
  first scene's waves).
- **4fbar, offer counter:** `g_s4fbarOfferCount` (only at 1020:e790–e7a1) is set back to 15 on the 25th
  offer, which is swallowed (`return 1`, selection left set until the next right button); afterwards every
  10th offer gets no reply.
Confidence 8–9.

## Harmless: engine leftovers
- **Objects are deleted through their virtual-base pointer:** `scene_dtor` 1018:28da–2905 (every scene
  change), `object_list_delete_all` 1010:d474 and `game_dtor` 1010:edcc (at exit) call
  `scene_object_scalar_dtor` 1010:d762 non-virtually on list pointers, which point at the SceneObject virtual
  base placed after the derived part. Derived destructors never run, and `_ffree` 1008:21b2 only sets a bit
  at `p-2` — inside the object, not the block header — so every deleted scene object's block (~1.5 KB)
  stays in use: roughly 1 MB over a long session, no corruption. The port frees the objects (memory is not
  observable), keeping the skipped derived destructors (portable icons, inventories: see B14's parking).
- **`loadObjects` keeps x/y across lines** (`ini_game_load_objects` 1018:4c8e, locals BP-0x12/-0x14): an
  `Invent=` line for an item already carried (inventory is not cleared before a load) gets the position of
  the previous `Stat=`/`Portab=` line (4e8a–4e97). The writer always emits those lines first and dropping
  the item sets a new position. Reproduced (`src/save.zig`).
- **RealizePalette's result is read from an uninitialised local** in `AppWndProc` (WM_ACTIVATE 1018:3400–3462,
  WM_QUERYNEWPALETTE/WM_PALETTECHANGED 1018:3567–35cf) when the scene has no backdrop; that only happens
  between the scene constructor and `ini_scene_create`, when no message is pumped. The port uses 0.
Confidence 8–9.

---

## Unfinished features (never wired up)

### U1. Status-bar text is never drawn
- `status_bar_set_text` 1018:1ed2 stores text + x into `StatusBar.text` / `textX`; nothing reads `text`, and the
  StatusBar vtable (1018:5f7e) has no draw override (it draws only its bitmap). The only caller is the Moveable
  debug overlay (1010:5716, "(%03d,%03d)=>(%03d,%03d,%03d)" coordinates). `textColor` is also never read.
- Confidence 9.

### U2. Control-panel message line is never filled
- `ControlPanel.message` (+0x11e) is tested by `control_panel_draw_texts` (1018:20dc) but no code writes text into
  it. Confidence 8.

### U3. Game.clearWidth / clearHeight are never set
- `PatBlt(hdc, 0, 0, clearWidth, clearHeight, BLACKNESS)` before a scene is built (1010:ea26, 1018:4019, 1018:53b7),
  but neither field (Game +0x676/+0x678) is written anywhere, including the constructor. The values are whatever
  the heap block held (most likely 0 → no-op). Confidence 9 (no writer); 6 (actual value at run time).

### Corrigida additions (not bugs)
Usability changes the "Corrigida" version (`Fixes.all()`) turns on; the original lacks them by design.
- **The dragged item follows the pointer** (`Fixes.drag_shows_item`). Dragging an item out of the control panel
  (right button held on a slot, until the release) shows nothing in the original: `game_handle_message`
  (1018:0000) only slides the panel on WM_MOUSEMOVE and there is no `SetCursor` anywhere. With the flag the
  item's panel icon is drawn centred on the pointer, as an overlay the platform adds when it shows the frame
  (`Screen.overlay`), never into the screen buffer or backdrop; it goes with the release or anything that clears
  the selection (drop, offer, scene change). Game logic is unchanged.
- **A dropped item falls smoothly** (`Fixes.smooth_item_fall`). The original moves a falling item 10 rows per tick
  of its own timer (`portableCtor` step 0,10; timer 4 at 200 ms for most items, 100 ms for some), 5–10 frames a
  second. With the flag a system timer (id 0xfa11, a fifth of the item's period; `movement.smoothFallTick`)
  draws the item between its last step and the next, in proportion to the time since the last step (2 rows a
  frame). The steps still come from `moveTick`, unchanged, so the path, the end, the 3D place and the time the
  fall ends are the original's, and the item's timer (shared with other objects) keeps its period. Any running
  scene timer 5–10 also steps it (`ini_scene_handle_message` 1018:915e moves every moving object of the scene
  whatever the id: the sitting room's cat, 100 ms, while it plays), so the next step is the first of those
  timers and the item's.

---

## Latent bugs (code never executed by the shipped game)

### L1. RLE sprite blitter calls a bogus near address
- `rle_blit_transparent` 1018:b78a, literal-run copy at 1018:b988 and 1018:ba18: `MOV AX,0xac; CALL AX` with
  (dst, src, count) pushed. 1018:00ac is in the middle of an instruction of `game_handle_message`; the NE
  relocations fix up only the `__AHSHIFT` immediates in this function. Executing it would crash.
- Not reached: the blitter is used only when a SceneObject's RLE flag is set, and its only setter
  (`scene_object_enable_rle` 1010:b6d0, SceneObject slot 0x02) is never called; the shipped data has no RLE assets.
- Confidence 9.

### L2. RLE mode would double-free the frame bitmap
- `scene_object_enable_rle` points `SceneObject.rleBits` into the current strip's DIB; `scene_object_dtor` 1010:b002
  first destroys the frames (`frame_dtor` GlobalFrees the DIB block) and then, if the RLE flag is set,
  GlobalUnlock/GlobalFree on `GlobalHandle(rleBits segment)` — the same block again.
- Confidence 8 (latent, see L1).

### L3. Base `game_init` resets the control panel before creating it
- `game_init` 1010:e9e2 calls `control_panel_reset(this->controlPanel)` at 1010:ea68 while the pointer is still the
  NULL set by `game_ctor`; the panel is created only at 1010:eaa7. Writing through a NULL selector would fault.
- Not reached: the game object is a NoiteGame, whose slot 07 is `ini_game_init` (which creates the panel first).
- Confidence 9.

### L4. `draw_list_invalidate_nodes` would recurse forever
- 1018:2b72 recurses into `node->next` before clearing it and then into `node->prev`; on the doubly linked draw
  list the child's `prev` leads back to the parent, whose `next` is still set → unbounded recursion / stack
  overflow. No caller except itself. Confidence 8.

### L5. Removing from a full draw list writes through a NULL free-list head
- `draw_list_remove` 1018:2e88 puts the removed node back on the free list with `LES SI,[DI+0x4b0]` /
  `MOV ES:[SI+0x4],BX` (1018:2f8a–2f95): it sets `freeHead->prev` without testing `freeHead`. When all 100
  nodes are in use the free list is empty, so this writes through a NULL selector (general protection fault).
- Not reached: no shipped scene has 100 visible 3D objects (`draw_list_insert` refuses the 101st with
  "Estouro no número maximo de objetos visíveis na cena").
- Port: `draw_list.remove` panics with this id (its callers cannot return errors). Confidence 9.

### L6. Long message-box texts overrun the shared 100-byte buffer
- `message_box_printf` 1018:3644 `sprintf`s into DGROUP 1050:7cd6 (100 bytes) with no bound, then shows it.
  The bytes after it are `g_applic` (7d3a, the Game pointer `AppWndProc` dispatches through), `g_iniFile`
  (7d3e), `g_lastAssetPath` (7d40) and `g_iniPath` (7d44).
- Texts longer than 99 bytes: `update_list_add` 1010:313c "full list" (111 bytes, string 1010:936a),
  `object_list_add` 1010:d322 "full list" (131 bytes); `scene_object_init_strip` 1010:1eb2 "Não foi possível
  abrir o arquivo: %s" with a path over 65 characters. The box shows, and the next window message goes
  through a clobbered `g_applic`.
- Not reached: the lists never fill with the shipped data and every shipped bitmap path is short.
- Port: `ini.messageBoxPrintf` truncates to 99 bytes. Confidence 9 (code); the effect after the box is
  inferred.

### L7. A background larger than 1295×1039 overflows the occupancy grid
- `occupancy_grid_ctor` 1010:0ba6 sizes the grid to `(bgHeight >> 4) + 1` rows × `(bgWidth >> 4) + 1`
  columns; above 0x41 rows / 0x51 columns it shows "Estouro do número de linhas/colunas da matriz de
  ocupação" (1010:92d0 / 1010:9310) and then still clears every cell with `occupancy_grid_set_cell`, whose
  `row * 81 + col` index runs past `g_occupancyCount` (1050:140a) and `g_occupancyObject` (1050:289c, which
  ends at `g_game` 1050:7ae0). Later occupy/query calls index past them the same way.
- Not reached: every shipped `Screen=` background is 640×480 (41×41 cells).
- Port: out-of-range cells read as free and writes are dropped (`grid` module notes). Confidence 9.

### L8. A fourth closet pick overruns `Game.pickedItems`
- `noite_game_handle_message_hook` 1018:c49c–c52b writes `pickedItems[pickedCount]` (Game +0x69a, 3 × 12
  bytes; count +0x6c6) unchecked. 3fpapclo resets the count only when a verdict wave ends (1020:90dd, 92bf,
  9414), but a drawer exit (ids 146–165) still works during the verdict wave and leaving the scene means
  that wave end never reaches it. The 4th pick writes over pickActive/pickArmed/`pickRetry`/`pickAdded`
  (+0x6be..0x6c4); `returnItems` then treats 0000:0001 as an object pointer (GPF).
- Not reached: 3fpapclo is unreachable (B6). Port: `game_hook` panics with this id (reachable only with
  `Fixes.pope_closet_reachable`). Confidence 8.

### L9. Exit lookups accept `index == exitCount`; the exit table has no bound
- `game_create_exit_scene` 1018:11ea rejects only `exitCount < exitIndex`, so index == exitCount reads the
  unset `exits[exitCount]`; `game_take_exit` 1018:12c6 has no check. `scene_add_exit` 1018:2a44 (and
  `_alt` 2a8c, `_at` 298c, `_to_scene` 29e6) store `exits[exitCount++]` (`Exit *[25]`, Scene+8) unchecked:
  a 26th exit overwrites `exitCount`, then `name`.
- Not reached: exit indexes come only from the add functions; the most exits in a shipped scene is 20
  (3fpapclo). Port: a NULL slot panics (`src/game.zig`). Confidence 9.

### L10. Perspective view and axis divisors are not checked for zero
- `perspective_backdrop_set_view` 1010:ada1–adbe divides by `view3d_z − (viewHeight − view_y)`;
  `perspective_backdrop_set_axis` 1010:adfa–ae11 (axis_x == 0) by `vanishY − (viewHeight − axis_y)`. Zero
  is an integer-divide fault.
- Not reached: no shipped `Screen=` line (116) makes either divisor 0 (none is within ±4). Port: panics
  with a message (`src/backdrop.zig`). Confidence 9.

### L11. Vacating a cell that was not occupied leaves a phantom occupant
- `occupancy_grid_vacate_cell` 1010:d884 (only caller `occupancy_grid_vacate` 1010:d9be) clears the cell's
  object, then `CMP count,0; JLE inc; DEC`: a positive count is decremented, anything ≤ 0 incremented — an
  empty cell (0) becomes occupied (1) with no object, a blocked one (−1) becomes free. It also clears the
  object pointer while other occupants remain (that part is reached: B29).
- Would fire on a vacate of cells the object never occupied (hiding an object twice: the hide paths do not
  test `visible`); the cell then blocks like an invisible obstacle until the scene is rebuilt. No such
  double vacate was found in the shipped scenes (needs a trace). Port: reproduced (`src/grid.zig`).
  Confidence 9 (arithmetic); 4 (reached).

---

## Not bugs (checked)

- **4fsacaet takes no life on an INV loss:** by design — the loss scene does: `handler_4fmarte` 1028:03f9
  (`DEC; JZ`: game over at 0, else 4fbar), and 4fmarte is reached only from the 4fsacaet loss.
- **3fstree2 does nothing when `minigameWon[3]` is 0:** it is entered only from `handler_3fstreet`
  1020:8900 when the minigame was won; no INI exit leads there and it cannot be saved in (no control panel).
- **2fportdi always looks up WAVE replies for Number 0x17** (1020:4644): every `[2fportdi]` WAVE line is
  Number 23 — only the doorman answers. Its 4th-offer check in MM_WOM_DONE is always reached (the angry
  wave's end, or wave_play's faked 0x3bd).
- **2fgaydir's right-button compare chain** (`JMP 5c14` after `SUB AX,0xe1`) is a merged tail: the
  effective id is 0x10c.
- **3fhall's TIRO timer branch returns 0:** neither the engine default nor the hook handles WM_TIMER.
- **4fbarboy leaves `selectedItem` set after a wrong item:** its MM_WOM_DONE path dereferences it, so
  clearing it would turn an unclaimed wave end into a NULL dereference; nothing visible follows.
- **A wave from the previous scene does not end in the next one:** about twenty handlers (1furso,
  1fquarbo, 2bfedriv, 3fsauna, 4fbar, …) act on any MM_WOM_DONE without looking at wParam, but no wave
  outlives its scene. `game_take_exit` 1018:12c6 itself keeps the waves, yet its only caller, the
  exit-finished path of `game_handle_message` (0x402), calls `wave_free_all` first, and
  `ini_game_switch_scene` 1018:15ea flushes and frees them. WAVEMIX.DLL's `WaveMixFreeWave` (segment 1,
  offset 0x20d8) unlinks the wave from every channel queue, the playing entry included, and posts
  nothing, so e.g. the kitchen door's PORTA1.WAV (exit 61) never ends inside 1furso and the bear's
  URSOR01.WAV plays to its end. (The port's WaveMix simulation used to keep the freed wave's
  notification, which cut the bear after 2 s.) Only a completion already posted before the switch can
  still reach the new scene, as in Windows.
- **4fbarboy's barman, drunk, Smarr and boys play once; the front barman loops:** the four are cast to
  Animation and started with its slot 0x1c, `animation_play_once` (1020:a3af→a3d3, aa37→aa5d, aa6a→aa90,
  b658→b67e); only BarmanFront goes through SceneObject slot 0xc0 (looping play). (The port used to loop
  all of them, and the 3fsauna attendant too: B21.)
- **4fbar's PtInRect** compares window coordinates with scene coordinates, but `[4fbar]` is 640×480 and
  never scrolls. Its `DEC; JNS` lives test is in B1; `okvamp.wav` is rescued by `PAN\WAV`.
- **The `exit_has_key_object` call in `ini_scene_handle_message`** (1018:9548) pushes a dword NULL (66-prefixed),
  the take flag and `this`: 10 bytes, matching its `RETF 0xa`.
- **`portable_move_to_scene`'s name swap** through a stack temporary: it has 20 bytes and the names
  copied are at most 19 characters (`strncpy 0x13` everywhere they are set; the longest section name has 9).
