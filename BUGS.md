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

### B6. The pope's-closet puzzle (3fpapclo) is out of normal reach
- **Where:** `handler_3fhall` 1020:7ce4–7d1b; INI `[3fhall]` `Exit=139 … 3fpapclo` (CASSETA.INI line 733).
- **What the code does:** the hall handler intercepts right clicks on all five doors (ids 139–143 = 0x8b–0x8f)
  and maps each, via a shuffled table, to sauna / TIRO / 3ffarao / 3fpapmal / 4finifes; it returns "handled",
  so the INI exit to `3fpapclo` does not fire. No other INI exit or code path switches to 3fpapclo (the
  right-click hook only *returns* to it from its own drawers). The one way in is a right click on the lowest
  ~46 px of the door with the control panel open, which the engine handles with the INI exit (B38).
- **Effect:** in normal play the closet game (20 drawers, Portables 169–188, verdict waves `papar0N.wav`,
  `papatime.wav`) is never seen; the door that should lead to it gives the pope's punishment video (3fpapmal)
  directly, which in the INI design is the closet's *failure* outcome.
- **Inside 3fpapclo:** the 60 s / 18 s timers only play a warning, and timer 0x16 sends 0x3bd, which the handler
  ignores unless a verdict wave is pending: there is no real time limit.
- **Port:** reproduced; `Fixes.pope_closet_reachable` makes the hall's closet door take the INI exit.
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

### B11. JARDIM: the CD drive's current directory is never restored
- **Where:** `handler_espquete` 1028:0c6f–0cc2 (same shape in `handler_4fjarvamp`).
- **What the code does:** before launching JARDIM it `_chdrive`/`_chdir`s into `<CD>jardim`; on the result message
  it restores the drive, copies `g_driveCD` into a local and strips its last character, but never calls `_chdir`
  with it.
- **Effect:** the CD drive keeps `jardim` as its current directory. Paths are built from `g_driveCD` (`\` in the
  shipped CASSETUP.INI), so they stay absolute and nothing visible follows; the game ends right after anyway.
- **Confidence:** 8 (code); effect negligible.

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

### B20. Giving the bible to the driver of the Beetle ride freezes the game (2fshardi)
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
    procurada" and returns 0 without seeking, so `ini_scene_create` 1018:6bee reads on from the `[3fhall]`
    header after `[3ffarao]` and stops with "Linha [3fhall]] inválida" and `exit(1)`. The right click plays
    the attendant *once* (1020:802a–8057, `animation_play_once`): 8 ticks, the last 1.6 s after the click,
    which kills its timer. Its wave GLOBO2.WAV ends at 1.415 s and launches SAUNA.EXE (timer 0x14 polls for
    its window every 100 ms); from the minigame's 0x40c the sauna handler swallows every WM_SYSTIMER
    (1020:7fe6–8012). If that comes before the last tick, the attendant's timer outlives the scene. In
    3ffarao the stale tick must then come after the video ends and before ENCAIXE.EXE's 0x40c, from which
    3ffarao's handler swallows the ticks in turn.
  - A hall door's exit animation (timer 6) cut short by the hall's switch to 3ffarao (B38: a low click with
    the panel open, then one higher up before the door finishes) keeps timer 6 running too: the pharaoh
    video ends in `JTETRIS` the same way.
- **Effect:** 3fstreet: depending on which comes first, the street escape's result arrives in 3fhall (whose
  handler takes it for the shooting gallery's: a win sends the player to 3fprisao), or the hall's own
  FindWindow poll reports a lost game (a life). The player can end up in the hall without having played the
  escape, or lose a life for it. (B37 is a separate route from 3fprisao to the hall.) 3ffarao: once the sauna
  has been visited, the pharaoh door can end the program with a fatal INI error, if SAUNA.EXE showed its
  window by the first 100 ms poll and answered within the next ~85 ms (and ENCAIXE.EXE was not faster than
  the stale tick).
- **Port:** reproduced; `Fixes.avi_exit_ignores_timer` does not tick a video (`isAvi`) exit from the timer
  path. `tools/play/full.input` takes the 3fstreet route (one prison door), so its `--fix` run leaves this
  fix out. There the real XILINDRO starts 1500 ms after the video, when the hall's handler already owns
  timer 0x14 (it looks for TIRO's window): no hello reaches XILINDRO, its window stays over the hall
  with NOITE shown below, and its result goes nowhere (full.input leaves it unplayed, onebutton.input
  fights it). The stub minigames (window after 1.5 s) miss the 3ffarao race; `--minigame-startup 0
  --minigame-reply 0` hits it (`--scene 3fhall`: the sauna door, a right click in the sauna, then the
  pharaoh door).
- **Evidence:** port traces (`noite --trace`); the code paths above.
- **Confidence:** 8 (code, port traces); 5 (how often the timings line up on a period machine).

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
  stores the query's object, NULL on the panel): the wrong-offer path then skips the take back and only clears
  the selection, so the offered item stays on the scene for good (in 2fsuabig 1020:0000 the gift, the right
  item, stays on the floor and the hold-up goes on). A slot pressed during the reply and released on a
  character after its end reaches the WM_RBUTTONUP offer with `itemSelected` set and `selectedItem` NULL: a
  NULL far-pointer read (2fportdi `takeItemBack`).
- **Effect:** quick players lose items and score; the inventory shows fewer items than its count, or, with
  items in the used list, more than its 8 slots (the extra icons are drawn past the last slot, under the score
  box). The one-button mode makes it easy: a tapped slot stays selected (2fportdi: offer the bible, tap the
  next slot while the driver answers: the bible stays in the car). Port repro, 2fsuabig: the gift offered, the
  wallet's slot held through the reply: the wallet is consumed, the Oscar after it is cut off, the gift stays
  on the floor.
- **Port:** reproduced (the lists are shared the same way); at exit only the items the inventory still owns
  are parked (`object_init.sceneObjectDtor`), the cut-off ones stay unfreed. `Fixes.reply_keeps_offer`: after
  an offer (a drop in one of these scenes, `game_input.rightUp`) the right button does nothing until the next
  MM_WOM_DONE, while the offered item is still the selected one lying in the scene.
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
  never rises. A support is a visible local, animated, exit or portable with a non-zero 3D box (not size-0
  door or painting hotspots, not characters) under the item's centre whose projected top face, kept inside
  its hit box (moved to the hit box's top row when the two miss each other, as for the corridor table), is at
  or below the release row; the item rests on the face's middle row. It enters the draw list, and keeps its
  3D place, on the support's top with its anchor on its bottom row (a `ZoomPort=` item's anchor is its
  top-left corner); the fall's steps reset that place (`portable_move_to_and_drop`), so its stop restores it.
  With B25's fix the drop sets the previous position and the fall's stop resets it. An offer (any drop in a
  scene whose unit has `pub const answers_offers`: the eleven of B23's list) does not fall: it stays where
  it was released, in the character's hands, while the reply plays. (The original's drop can move an offer:
  in 2fportdi the bible released on the mouth walks 100 rows down to a support's top.) `tools/smoke.py
  --offers` checks that with the fix an offered item stays put until it is taken back and leaves no image.
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
- **Also:** that flush empties the whole update list, not only the animation's frame. A portable picked up
  (`game_handle_message` WM_RBUTTONDOWN: `portable_pick_up` 1018:0b9e, slot 84 `hideAndInvalidate` 0bed
  restores the background over its box and queues it, slot 160 `redrawOverlapping` 0c08 skips the panel,
  which is not in the draw list, and slot 1F at 0ca4 is a debug no-op, so no flush and no panel redraw)
  while an animation runs, after the engine's last timer and before the animation's next tick, reaches the
  screen with the bars cut out where its box overlapped them. In `1fquarpa` the gift (`Portable=98`,
  0,350 80×91) ends at y 441: with the moose going, the lives "3" loses its top rows and the badge's torn
  edge turns to floor until a slide repaints them (`tools/play/b32-gift-lives.input`; which timer comes
  first is a matter of timing).
- **Port:** reproduced (`src/scene.zig`); `Fixes.bars_over_scene_animation` draws the panel and status
  bar into the backdrop after each such tick, before the flush (both effects).
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
  sent 0x401); the code paths above. Unlike B21's 3fstreet case, it needs no stale timer.
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
  to the closet game (the only way there, B6). A door animation cut short by a right click
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
  player drawn over the menu, most of all while the panel slides closed: each step of the slide
  (`control_panel_tick` 1018:22cc: erase, the player's tick or draw 1018:0407/0429/044d, the panel 0649, the
  flush 065a) redraws him whole and the panel over him, and the slots slide down across his legs.
- **Port:** reproduced (`--scene 1fgarage`, click at (320, 425), move to (320, 470), then back to (320, 200));
  `Fixes.panel_slots_show_background` fills the slots with the pristine background picture each time the
  panel is drawn. A slot is a key-coloured region of the frame of at least 64 pixels that no key-coloured path
  joins to the top row, so the gaps and small pockets of the torn top edge still show the scene.
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

### B41. The bar after a wrong DJ answer never lets the control panel open (4fbarbo2)
- **Where:** `handler_4fbarbo2` 1020:c632, WM_MOUSEMOVE: returns 1 (handled) for every move at y ≥ 0x169, so
  the engine's move handler never sees the pointer reach the bottom strip that slides the panel open.
  `[4fbarbo2]` has no `Exit=` lines, and the scene (entered from `4fdj` 1020:b7ac and `4fboydj` 1020:d4fc
  with the panel on) has no player.
- **What the code does:** the only way on is a right click on the drunk's pocket (0xdc) after the barman's
  opening wave; until then nothing on screen responds, and the panel, the only route to Opções, is shut.
- **Effect:** the player can neither leave, save, load nor quit until finding the pocket; it reads as a
  soft lock. Deliberate or not, no other scene with the panel on blocks it for its whole length (4fdj
  blocks it only until its intro ends, `panelAllowed`).
- **Port:** reproduced; `Fixes.bar_panel_opens` lets the moves through. The scene's Screen line clears
  `mayDropObject`, so the open panel offers Opções only (no item can be dropped there).
- **Confidence:** 9 (code, INI, port repro).

### B42. The bad cop's arrest video plays with garbage on the mugshots (damaged file on the disc)
- **Where:** `[2apremau]` `Exit=41,…,fase2\2fcopmau\2aprema2` (the arrest after the bad-cop roadblock 2fcopmau);
  `animation_open_avi` 1010:c9f6 tries `<HD>2aprema2.avi` (INSTALAR.EXE copies a fixed list of big clips
  there, not this one), then `<CD>fase2\2fcopmau\2aprema2.avi` (absent), then `<CD>pan\avi\2aprema2.avi`
  (sprintf 1010:cbee, open 1010:cc11).
- **What the code does:** it plays `PAN\AVI\2APREMA2.AVI`, which carries the disc's recurring ~68-byte damage
  block (`… c0 c0 df df 00 40 33 2d 11 83 00 04 f0 f1 …` then spaces) three times: in audio chunk 9
  (0x1274d) and inside video frames 5 (0x186c9) and 16 (0x4d60e), FLC delta frames whose later deltas build on
  them. The disc root's `2APREMA2.AVI` is the same clip without the damage (the only bytes that differ are
  those three blocks); nothing opens it.
- **Effect:** the mugshot cutscene shows a stray orange speck left of the photo and, in the profile shots, rows
  of white/grey stripes along the bottom by the number board until the clip ends (plus a click in the audio).
  The good cop's arrest (2afotbom) and the policewoman's (2apremu2) are clean copies.
  (`PAN\AVI\2APREBO2.AVI` is damaged too, frame 8, but no INI line plays it.)
- **Evidence:** byte comparison of the two copies; the frames decoded by the port and by ffmpeg (garbage in
  both from frame 5 on with the `PAN` copy, none with the root copy).
- **Port:** reproduced (the decoder stops a damaged frame at the bad packet and keeps playing);
  `Fixes.clean_arrest_video` opens the root copy before the `pan\avi\` one.
- **Confidence:** 9 (file contents); 7 (how the period AFLC codec drew the damaged frames).

### B43. A dropped item still falling when the scene changes falls on in the next scene, drawn over it
- **Where:** `game_handle_message` 1018:0000, WM_SYSTIMER 1018:0512–059c: when the timer id is the selected
  item's (`Game.selectedItem`, +0x67c, slot F4) and it is moving (slot F8), it runs the item's `moveTick`
  (1018:059c→0507, slot F0) with the *current* scene's backdrop. `game_take_exit` 1018:12c6 and
  `ini_game_switch_scene` 1018:15ea clear `itemSelected` but neither forget `selectedItem` (set only by the
  panel picks, 1018:09e8 and the hook 1018:c0fc; cleared only by the give-item handlers that keep an offered
  item) nor stop its walk; the item is a global object, so deleting the old scene leaves
  its system timer running until `mover_stop_moving_dc` at the end of the fall.
- **What the code does:** an item dropped high in a scene falls 10 rows a tick; a
  door taken before it lands (the hall's doors switch at once) brings the rest of the fall into the next
  scene: each tick draws the item into the new backdrop at the old scene's coordinates and puts it on the
  screen. Nothing of the new scene is in its draw list, so nothing erases it.
- **Effect:** the item's picture slides down over the new scene and stays there until something repaints that
  spot; in scenes without the player or the panel (3fpapclo, the pope's closet, reached through the hall) it
  stays for good, over the drawers. With B36 the fall never ends, so it goes on through every later scene
  until it leaves the view. In the old scene the item lies where the fall would have ended. With one-button
  play a tap on the item's slot, a tap high up and a tap on a door is enough.
- **Port:** reproduced (`--scene 3fhall --take 98 --fix pope_closet_reachable`: `offer 0 420 60`, then a right
  click on the closet door at once); `Fixes.scene_change_lands_item` ends the fall in the old scene before a
  switch (`game_scenes.landFallingItem`: the remaining steps run at once; one that never arrives is stopped).
- **Confidence:** 9 (code, port repro).

### B44. The pope's closet: a drawer closed without a pick leaves the last pick in the closet, over the drawers
- **Where:** `handler_3fpapclo` 1020:8db8, scene start (0x401), 1020:94c4–94ce: the last picked item (slot
  `pickedCount - 1`) is placed whenever the closet starts, then `portable_drop` 1010:71ac (1020:94e1) copies its
  scene name into `prevSceneName`; `Game.pickAdded` (+0x6c4), which the right-click hook 1018:c0fc sets on a pick
  and 1020:9546 clears, is never tested. The verdicts give the items back with `portable_move_to_scene`
  (1020:9032, 91cb, 9355), which swaps `sceneName` and `prevSceneName`, and `moveToAndDrop` at the drawer
  position, in the closet's backdrop.
- **What the code does:** a drawer closed with a right click on nothing (no pick) brings the closet back and
  drops the last pick again: both of its scene names are now `3FPAPCLO`. When the verdict hands the items back,
  the swap leaves that one in the closet, at the coordinates it had in its drawer scene.
- **Effect:** after picking, opening and closing a drawer, then two more picks and a wrong verdict, the item's
  full drawer picture shows over the drawers (after the first failure from the next entry on; after the second,
  on the next visit), and its occupancy cells take the right clicks there: the handler returns 1 for a portable
  under the cursor, so the drawers it covers can no longer be opened. The item never comes back to its drawer,
  so a right item (0xac, 0xb4, 0xb9) caught this way makes the puzzle unsolvable.
- **Port:** reproduced (`tools/play/b44-closet-redrop.input`, `--scene 3fhall --fix pope_closet_reachable`);
  `Fixes.closet_places_new_pick_once` places the last pick only when `pickAdded` says it is new.
- **Confidence:** 9 (code, port repro).

### B45. The wine given to the taxi driver is drawn twice while he drinks it
- **Where:** `handler_2fportdi` 1020:4306, WM_RBUTTONUP with the wine (item 0x56): it hides the talking mouth,
  the hands and the head (`hideAndInvalidate`), shows and plays the drinking animation (`Animated=22`,
  `2sporb`, 286×182 at 223,86) and its hands (`Animated=290`), starts its wave and returns 0, without touching
  `Game.selectedItem`. `game_handle_message` 1018:0000 WM_RBUTTONUP then drops the wine where it was released
  and draws it; the reply's end (MM_WOM_DONE, 1020:4306) hides it and moves it to the used list.
- **What the code does:** the drinking animation's frames hold the bottle themselves, and the dropped wine
  (anchored at its bottom row, in front of the animation) is drawn over them for the whole animation.
- **Effect:** two bottles: the one at his mouth in the animation and the offered one where it was released
  (over his face when given on the mouth), until the scene changes to `2abarbei`. The right items of 2fsuabig,
  2fblitg, 2fcopmau, 2fshardi, 2fgaydir, 4fbarboy and 4fbar stay drawn too, but no accepting animation there
  shows the item (port frames); 2fportd2 consumes it at once.
- **Port:** reproduced; `Fixes.drinker_takes_bottle`: the handler asks the engine's drop
  (`Game.hideOffered`) to hide the wine as soon as it is dropped; it stays the selected item in the scene's
  list, which the reply's end consumes as before (`tools/play/taxi-wine.input`).
- **Confidence:** 9 (code, port repro).

### B46. After the party street the player walks off the bottom of the screen
- **Where:** `handler_2ffesta` 1020:771a (0x401, the walk-in) and `handler_2ffesta3` 1020:7452 (the arrivals by
  car or taxi from 2fshardi, 2fportd2, 2fgaydir, 2fasspap) set the player's Mover+0x36 (`allowOffscreen`).
  Only the mover constructors (1010:27ce, 2836, 292c, 2a20, 2d7a) write it, and the player is built once.
- **What the code does:** with the flag on, `mover_move_to` 1010:c3ba takes the click as the sprite's
  top-left corner, not its bottom centre, and does not clamp it to the background.
- **Effect:** for the rest of the game every click-walk aims the player's top-left at the click: he walks down,
  past the floor and off the screen (a door tapped from afar in one-button mode, any floor click). The
  2ffesta4 (bribe) route never sets it.
- **Port:** reproduced (`--scene 2ffesta`, then 3fhall: a door tap walks him to (-125,450));
  `Fixes.player_offscreen_per_scene` clears the flag on every scene change.
- **Confidence:** 9 (code, port repro).

### B47. A new game in the same run leaves the prison's hammer where the last game left it
- **Where:** NOVO JOGO on the title menu (`handler_fundinic` 1018:c688) and on the options screen
  (`handler_fundini1` 1018:d31e) loads slot 0, `JOGO0.INI` on the disc, with `ini_game_load_game` 1018:5274;
  `ini_game_load_objects` 1018:4c8e moves only the items a `Portab=`/`Invent=` line names (a carried or used
  one back to the global list, then its scene and position). Nothing else resets the items.
- **What the code does:** `JOGO0.INI` has a `Portab=` line for every `Portable=`/`ZoomPort=` item but the
  hammer (`Portable=273`, `3fprisao`); the saved slots (`JOGO1`–`5`) have it. So the new game keeps the hammer
  as the last game left it: carried, consumed (given to the barman), or lying in another scene.
- **Effect:** after a new game the prison floor has no hammer; carried, it is still in the panel from the
  bedroom on; given to the barman (4fbarboy, the only one who takes it) or left elsewhere, the new game cannot
  get past the barman unless the player fetches it from where it was dropped. A page reload (a new run)
  starts clean.
- **Port:** reproduced (`--scene 3fprisao`, pick the hammer up, `scene fundinic`, JOGAR, NOVO JOGO: `where
  273` says carried); `Fixes.new_game_resets_items` sends every item home (scene, position, on the floor)
  before slot 0's lines.
- **Confidence:** 9 (disc data, code, port repro).

### B48. The closing control panel is cut away around the player for a tick
- **Where:** `game_handle_message` 1018:0000, WM_MOUSEMOVE above y 340: `control_panel_slide` 1018:2250 sets the
  frame to 0 (the closed panel) for either direction, then the panel is drawn into the backdrop. Going down,
  the first `control_panel_tick` 1018:22cc step (`animated3d_prev_frame` 1010:362c) wraps back to the last,
  open frame; the panel's timer gives that step 100 ms later.
- **What the code does:** until that step the panel's frame is the closed one while the screen shows it open.
  A redraw that erases an object over the panel and flushes in between, as WM_SYSTIMER's player idle tick
  (1018:04e5, panel 0616, flush 065a), draws only the closed frame's bottom strip back in that rectangle.
- **Effect:** with the player behind the open panel (feet below ~400: 1fquarbo, 1fcorred, 1fgarage…), the panel
  starts closing with his whole frame drawn over it, and the scene around him, down to the closed strip, for
  up to 100 ms. Timing: the idle tick must come before the first step (on the web, almost always). In the
  Corrigida version B35's fix (the strip change redraws the player at once) does it on every walk that closes
  the panel: each one-button tap in the scene.
- **Port:** reproduced (`--scene 1fquarbo`: a walk down, the panel opened, a move up 30 ms off the timers'
  phase); `Fixes.panel_close_keeps_open_frame` starts the slide down on the open frame and keeps it for the
  first step (same steps, same timing). `tools/web/test.py` checks the frames the page presents.
- **Confidence:** 9 (code, port repro, web frames).

### B49. The inventory icons vanish while the control panel slides
- **Where:** `control_panel_draw` 1018:1f1c draws the panel's frame, then the inventory icons only when the
  panel is open and its slide animation is not running (`isOpen != 0` and the animation stopped).
- **What the code does:** the slide changes the panel's frame (more or less of its art shows; the panel's
  position stays), and each tick redraws the panel without the icons.
- **Effect:** the icons disappear the moment the panel starts to close and appear only once it is fully
  open: the slots slide empty both ways.
- **Port:** reproduced; `Fixes.panel_icons_while_sliding` draws them during the slide too, lowered by the
  art's offset (`panels.drawInventorySliding`; the open frame's visible height minus the current one),
  clipped at the screen's bottom.
- **Confidence:** 9 (code, port frames).

### B50. Releasing an arrow while another is held stops the player for good
- **Where:** `game_handle_message` 1018:0000, WM_KEYDOWN / WM_KEYUP: each arrow has a held flag
  (`g_keyLeft`/`Up`/`Right`/`Down`); a key-down starts a walk only when it sets its flag from 0, and any
  arrow's key-up clears its own flag and stops the player.
- **What the code does:** pressing right while left is held walks right; releasing left then stops the player,
  and right's key repeats are ignored (its flag is still 1).
- **Effect:** a quick left-to-right change of direction ends with the player standing still while right is
  held; it must be released and pressed again.
- **Port:** reproduced (`tools/play/b50-arrow-overlap.input`); `Fixes.arrow_release_resumes_held` walks
  on towards an arrow still held after the release.
- **Confidence:** 9 (code, port repro).

### B51. The bible is invisible wherever it lies (its scene picture is not on the disc)
- **Where:** `CASSETA.INI` `Portable=48,1fcorred ,314,319,p\1pbibli ,58,21,…`; `ini_game_init` 1018:3e46 builds
  the scene picture's path with `ini_asset_path(name, 0)` 1018:9d4e (`p\1pbibli0.bmp`) and the icon's with
  kind 2 (`p\1pbibli2.bmp`); `portable_ctor` 1010:6e2c → `moveable_ctor_bitmap` 1010:384a → `mover_ctor_strips`
  1010:2836 → `scene_object_init_strips` loads it with `load_dib` 1010:041c (then `pan\bmp\1pbibli0.bmp`), with
  no error box when both fail; `mover_draw_dirty_to` 1010:b8a0 skips a strip whose DIB is null (b8d0).
- **What the code does:** neither `P\1PBIBLI0.BMP` nor `PAN\BMP\1PBIBLI0.BMP` exists (the only portable picture
  of the INI that is missing), so the bible's strip has no bitmap: it is placed, falls, is hit-tested and drawn
  as usual, but nothing is drawn. The disc's `P\1OBIBLI0.BMP` (and its twin `1OBIBLI2.BMP`) is the 58×21
  picture the line describes, a bible lying flat with "Bíblia" on its spine; nothing loads it.
- **Effect:** the bible never shows in a scene: not at home on the corridor table's shelf, and not where it is
  dropped or offered. Dropped, it disappears; a click on the empty spot still picks it up.
- **Port:** reproduced; `Fixes.bible_scene_image` loads `p\1obibli0.bmp` as its scene picture
  (`game_scenes.createPortable`), so it also shows on the corridor shelf, on top of the books.
  `tools/play/b51-bible-drop.input` (`--one-button --scene 1fcozin0 --take 48`) drops it in the kitchen and
  checks it is drawn.
- **Confidence:** 9 (disc listing, code, port repro).

### B52. A column of the player's pixels stays on the corridor's Mona Lisa after he walks past it
- **Where:** `mover_restore_background` 1010:b3fa (the player's erase) and `scene_object_restore_background`
  1010:b366 restore the pristine background over the object's rectangle with `dib_copy_transparent` 1010:0000
  (→ `dib_rows_copy_transparent32` 1000:0024), key `g_unk001C` (DGROUP data 0x0b, never written), the index the
  sprites use for "not drawn"; the loop skips every source byte equal to the key (`CMP AL,AH; JE` before each store).
- **What the code does:** a background pixel of index 11 is not copied back. `FASE1\1FCORRED\1FCORRED.BMP`
  has 306 of them: the dithered right edge of the Mona Lisa picture (x 436 on even rows, 437 on odd ones, y 17-188;
  more of the same pattern inside it). The initial scene draw copies the background whole, so they show as the
  palette's blue (0,136,208).
- **Effect:** where the player's rectangle covers those pixels (he passes x 436-437 walking along the corridor), the
  pixel he drew there stays after his erase: a 1-px zigzag column of his cap, face and body, on the picture's edge,
  for the rest of the visit. The other backgrounds with index-11 pixels (1fquarpa 2406, 1fquarbo 635, 1fsala 97,
  3fhall 44, ...) do the same where an object passes over them.
- **Port:** reproduced (`render.copyBackground`; `tools/play/b52-corridor-frame-speck.input` checks the screen's
  pixels after three walks); `Fixes.restore_copies_key_pixels` restores the rectangle with a copy that has no key.
- **Confidence:** 9 (code, disc data, port repro).

### B53. Sprites have holes: stray pixels of the transparent index inside the art
- **Where:** the sprite bitmaps on the disc; every object draw (`scene_object_draw_dirty_to` 1010:b746,
  `mover_draw_dirty_to` 1010:b8a0, the inventory icons) copies with `dib_copy_transparent` 1010:0000, key
  `g_unk001C` = 0x0b.
- **What the code does:** it skips every source pixel of index 11, the blue (0,136,208) backdrop of the sprites.
  The art has index-11 pixels inside it too, mostly single ones, a palette-reduction accident against that
  blue: 1174 such pixels in 42 of the 300 bitmaps NOITE draws as sprites (the INI objects, portables and their
  icons, the player, the panel and the status bar).
- **Effect:** each one is a hole showing the scene behind: the living room's coffee table (`1OMESA.BMP`,
  26 on the plates, the glass and the candelabra), the garage skeleton's chest (`CAVE.BMP`), the bar's quiz
  parchments (`4SPESO`, `4SPESP`, `4SPVAM`), the bus-stop sign's pictogram (`2OPONIBU`), the letters of the
  credits (`CREDDIR`, `CREDESQ`), faces and clothes of the animations.
- **Port:** reproduced; `Fixes.sprite_key_specks` fills, when a bitmap is loaded (`dib.loadDib` →
  `src/key_specks.zig`), the pixels listed `fill` in `src/data/key_specks.tsv`: each reviewed by hand, with
  its fill index (the most common neighbour, or the line's own colour for the pictogram and the credits'
  anti-aliasing). 1090 are filled; 84 that may be meant are kept (gaps between the skeleton's bones, the
  horseshoe icon's nail holes, the gun smoke in `2SASSM`, a hidden AVI exit's picture) with the reason in the
  list. `tools/key_review.py` rebuilds the list and its review sheets; `tools/play/b53-sala-table-specks.input`
  checks the coffee table (`-orig.input`: the Original's holes).
- **Confidence:** 9 (disc data, port repro); the fill/keep calls are judgement.

---

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

---

## Corrigida additions (not bugs)
Changes the "Corrigida" version (`Fixes.all()`) turns on that are not bug fixes.
- `Fixes.drag_shows_item`: an item dragged out of the control panel shows its icon at the pointer (an overlay
  on the presented frame, `Screen.overlay`); the original shows nothing (no `SetCursor` anywhere).
- `Fixes.smooth_item_fall`: a falling item is drawn in 2-row frames between its 10-row steps (system timer
  0xfa11, `movement.smoothFallTick`); the steps, path, end and timing are the original's.
- `Fixes.sala_street_exit_covers_door`: the living room's exit to the street (`1fsala` `Exit=114`, to `2FPONTOC`)
  takes a right click over the whole door frame drawn in `1FSALA.BMP` (x 0-40, y 73-390). The original's hit box
  is x 0-40, y 280-390 (the INI line's y 278 and 40x110 bound). The exit's range check is unchanged.

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
- Reached only in 3fpapclo, which only B38's low click (or `Fixes.pope_closet_reachable`) opens (B6).
  Port: `game_hook` panics with this id. Confidence 8.

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

Behaviour that looks wrong but is the original's design or harmless; the port reproduces it without a flag.

- **A waiting player is arrested at the 2fcopmau / 2fcopmu roadblocks, even with the wallet:** the greeting's
  end with nothing offered (2fcopmau MM_WOM_DONE 1020:1f4a → 234c) switches to the arrest (1020:2360–23a6)
  unless the gift package (0x6b) is carried (then PMAUS03, 23ce, and he waits). The wallet must be offered
  while the cop speaks; 2fcopmu does the same after garots05. An empty inventory ends all three roadblocks
  (2fblitg too) in the arrest after timer 0x15 (5 s).
- **The roadblock arrest takes no life:** `2aprebom`, `2apremau`, `2apremu2` (scenes 24–26) have no handler
  (`register_scene_handlers` 1018:570e) and their video exits go to `1fquarbo`; the price is the drive again
  (items and score kept). 2fshardi's send-off works the same way.
- **4fsacaet takes no life on an INV loss:** the loss scene does, `handler_4fmarte` 1028:03f9 (`DEC; JZ`).
- **3fstree2 ignores `minigameWon[3]` == 0:** it is entered only from `handler_3fstreet` 1020:8900 on a win;
  no INI exit leads there and it cannot be saved in.
- **2fportdi always looks up WAVE replies for Number 0x17** (1020:4644): every `[2fportdi]` WAVE line is
  Number 23. Its 4th-offer check in MM_WOM_DONE is always reached.
- **2fgaydir's right-button compare chain** (`JMP 5c14` after `SUB AX,0xe1`) is a merged tail: the effective
  id is 0x10c.
- **3fhall's TIRO timer branch returns 0:** neither the engine default nor the hook handles WM_TIMER.
- **4fbarboy leaves `selectedItem` set after a wrong item:** its MM_WOM_DONE path dereferences it; nothing
  visible follows.
- **Handlers that act on any MM_WOM_DONE** (1furso, 1fquarbo, 2bfedriv, 3fsauna, 4fbar, …) never see the
  previous scene's wave end: the 0x402 path of `game_handle_message` calls `wave_free_all` before
  `game_take_exit` 1018:12c6, `ini_game_switch_scene` 1018:15ea frees them, and `WaveMixFreeWave`
  (WAVEMIX.DLL 1:20d8) unlinks the wave, playing entry included, without posting. Only a completion posted
  before the switch reaches the new scene.
- **4fbarboy's barman, drunk, Smarr and boys play once** (`animation_play_once`, 1020:a3d3, aa5d, aa90,
  b67e); only BarmanFront loops (SceneObject slot 0xc0).
- **4fbar's PtInRect** compares window with scene coordinates, but `[4fbar]` is 640×480 and never scrolls.
- **`exit_has_key_object`'s call in `ini_scene_handle_message`** (1018:9548) pushes 10 bytes, matching its
  `RETF 0xa`.
- **`portable_move_to_scene`'s name swap** uses a 20-byte stack temporary; the names are at most 19
  characters (`strncpy 0x13`).

---

## ENCAIXE.EXE (the "Encaixe Perfeito" minigame)

Addresses are Ghidra `seg:off` in `/ENCAIXE.EXE`; the game is described in `docs/encaixe/GAME.md`.

### E1. The O piece loses its left column in the board when it moves left
- **Where:** `te_piece_move_left` 1008:ce8c, the kind 5 case.
- **What the code does:** it tests the two cells left of the square and clears the square's right column, but
  never writes `'1'` into the new left column; `column--` and returns 1. Emulating the bytes from an O at
  (4,5)–(5,6): after the move the board holds only (4,5), (4,6); the next fall step (`te_piece_move_down`, which
  writes the new bottom row and clears the old top row) leaves (3,7), (4,6), (4,7).
- **Effect:** the sprite shows a whole square, but the board misses one or more of its cells (all of them after
  two left moves in a row until the next fall step). Other pieces can then fall into the visible square, and its
  row is not seen as full, so a line that looks complete is not cleared.
- **Confidence:** 9 (code, emulated); 8 (effect).
- **Port:** reproduced (unit `piece_sideways`, src/encaixe/); the fix is
  `Fixes.encaixe_o_piece_moves_left_whole` (`--fix encaixe_o_piece_moves_left_whole`, on in the Corrigida
  version).

### E2. A rotation near the floor writes one cell past the column (row 14)
- **Where:** `te_piece_rotate` 1008:e392, the bottom tests of the cases where the shape grows downwards
  (`14 < row + h − 1` → fail).
- **What the code does:** the test lets the new shape's bottom row reach row index 14. The board is
  `char[11][14]` column-major, so `board[c][14]` is `board[c+1][0]`: the rotation writes `'1'` into row 0 of the next
  column for each bottom cell. Emulating every rotation from every valid position: it happens for every kind but
  the O, with the piece's top at row 11 (kinds 0 and 4, the long T and the I) or row 12 (kinds 1–3), in any column
  (e.g. an I lying at row 11, columns 7–10, rotated upright writes `board[8][0]`; kind 0 r1 at column 7, row 11
  writes `board[8..10][0]`). From a valid position the write never reaches the byte after the board
  (`Piece.column`).
- **Effect:** the piece's bottom row is drawn below the playfield and is not in the board; instead invisible
  filled cells (phantoms) appear in row 0. There a phantom only blocks sideways moves in row 0. It turns dangerous
  through E10: each later line clear copies row 0 into row 1 and moves the rows below it down, so the phantom
  grows into a column one row longer per clear. Once a phantom sits in row 1 under the spawn columns (4–6), the
  next piece cannot fall and lands at row 0, which is an immediate loss. Reachable: the rotate key works while the
  piece falls through rows 11–12 and while it rests on the floor before the landing tick.
- **Confidence:** 9 (code, emulated); 7 (that players hit it).
- **Port:** reproduced (unit `piece_vertical`, src/encaixe/); the fix is `Fixes.encaixe_rotation_stays_on_board`
  (`--fix encaixe_rotation_stays_on_board`, on in the Corrigida version).

### E3. `te_piece_clear_full_lines` leaves `bottomRow` uninitialised for an unknown kind or rotation
- **Where:** `te_piece_clear_full_lines` 1008:eed8, the `switch (kind)` / `switch (rotation)` that set `bottomRow`.
- **What the code does:** the kind switch has cases 0–5 and each rotation switch cases 0–3, none with a default;
  any other kind, or a rotation outside 0–3, leaves `bottomRow` a stack garbage value and the scan runs from the
  piece's top row up to it.
- **Effect:** none: the kind is always `rand() % 6` and the rotation `(r + 1) % 4`. Latent.
- **Confidence:** 9.
- **Port:** reproduced (unit `piece`, src/encaixe/; the garbage is taken as 0); the fix is
  `Fixes.encaixe_clear_lines_unknown_kind` (`--fix encaixe_clear_lines_unknown_kind`, on in the Corrigida
  version): it scans the piece's top row only.

### E4. `frame_init` sizes the cell array from an uninitialised local
- **Where:** `frame_init` 1008:a49a; caller `te_game_create_status_bar` 1008:9fb2.
- **What the code does:** `operator_new([BP−2] << 3)` and `crt_array_construct(…, [BP−2], 8, …)` with the local
  never written, instead of the frame count. The word is what `load_dib` 1008:1fe4, called just before at the
  same stack depth, left in that slot of its frame.
- **Effect:** the status bar's frame gets a `FrameCell` array of that size (or a NULL one when the allocation
  fails). The cells are read only by `frame_get_cell`, and the status bar is never shown in the Tetris scene, so
  nothing visible follows. A count of 0x2000–0x7fff wraps the 16-bit allocation size (`count << 3`) while
  `crt_array_construct` still zeroes `count × 8` bytes: a local-heap overrun.
- **Confidence:** 9 (code); 6 (effect).
- **Port:** reproduced (unit `object_create`, src/encaixe/); the fix is `Fixes.encaixe_status_frame_cells`
  (`--fix encaixe_status_frame_cells`, on in the Corrigida version). The port does not model `load_dib`'s
  stack frame and takes the word as 0 (no cells).

### E5. The down key sets the left-key flag
- **Where:** `te_scene_handle_message` 1008:f2a2, `WM_KEYDOWN` `VK_DOWN`.
- **What the code does:** `if (g_pieceKeyDown == 0) { g_pieceKeyLeft = 1; SetSystemTimer(id 12, 55 ms); }`.
  `g_pieceKeyDown` is never set to 1.
- **Effect:** the key flags are otherwise write-only, so the wrong flag changes nothing by itself; but the guard
  never closes, so every key repeat restarts the 55 ms countdown. With a key repeat under 55 ms (the Windows
  default is 33 ms), a held DOWN stops the fall completely: the timer never fires, and the piece never lands
  while DOWN is held. Key up does not restore the period, so after the release the piece falls at 55 ms until
  the next timer restart (a rotation, a sideways key or the landing).
- **Confidence:** 9 (code); 8 (effect, with the default repeat rate).
- **Port:** reproduced (unit `tetris`, src/encaixe/); the fix is `Fixes.encaixe_down_key_guard` (`--fix
  encaixe_down_key_guard`, on in the Corrigida version).

### E6. After the result the landing code still clears lines and spawns a piece
- **Where:** `te_piece_on_landed` 1008:ba20 (the loss); `te_score_cleared_row` 1008:f67a, 1008:f6be–f6ca (the win).
- **What the code does:** a loss is `SendMessage(hwnd, WM_DESTROY, 0, 0)` when `row < 3`; the function then goes
  on: line clear (with scoring and the win test), speed check, next piece. A win is `SendMessage(hwnd,
  WM_DESTROY, 0xffff, 0)` when the score reaches 1000; `te_score_cleared_row` returns and the landing carries on
  the same way: the row is shifted down, the other full rows are cleared and scored, the speed check runs and
  the next piece spawns. In both cases the result (`0x40a`) has already been posted and `WM_QUIT` queued.
- **Effect:** after the result the game still redraws the board (no line sound: the `WM_DESTROY` handler has
  already freed the waves); the extra score is never reported. A second result cannot follow: after a loss the
  −500 keeps the score from reaching exactly 1000 with at most 4 lines, and after the win the score is past it.
- **Confidence:** 9.
- **Port:** reproduced (unit `piece`, src/encaixe/); the fix is `Fixes.encaixe_result_stops_landing` (`--fix
  encaixe_result_stops_landing`, on in the Corrigida version): the landing stops right after either result.

### E7. The speed-up is skipped when a multi-line clear jumps over 5 lines
- **Where:** `te_piece_on_landed` 1008:ba20, after `te_piece_clear_full_lines`.
- **What the code does:** the period changes only when `linesCleared % 5 == 0` after the whole landing. It sets
  `Mover.timerPeriod` and restarts timer 12 with it, but leaves `Animation.timerPeriod` at 200: `animation_play`
  re-arms the same timer with that, so each rotation still waits 200 ms for its tick.
- **Effect:** going from 4 to 6 or more lines in one landing keeps 200 ms for the rest of the game (the next
  level, 10 lines, is the win). The 100 ms and 55 ms levels (10, 15 lines) are unreachable regardless, because
  10 lines is the win; for a multiple of 5 above 15 the period would be an uninitialised local.
- **Confidence:** 9.
- **Port:** reproduced (unit `piece`, src/encaixe/); the fix is `Fixes.encaixe_speed_up_on_crossing` (`--fix
  encaixe_speed_up_on_crossing`, on in the Corrigida version): it changes the fall period only, as the original.

### E8. `actor2d_ctor_strips` sizes each strip's FrameCell array by the frame width
- **Where:** `actor2d_ctor_strips` 1008:aa92 (the Piece's strips, via `player2d_ctor`).
- **What the code does:** allocates `width` (128) 8-byte cells per strip where `animation_ctor_strips_no_hitbox`
  1008:ae7a uses the frame count (4).
- **Effect:** 6 × 1 KB of unused local heap; harmless.
- **Confidence:** 8.
- **Port:** reproduced (unit `object_create`, src/encaixe/); the fix is `Fixes.encaixe_strip_cells_by_count`
  (`--fix encaixe_strip_cells_by_count`, on in the Corrigida version).

### E9. The occupancy-grid walls do not enclose the board
- **Where:** `te_grid_backdrop_create_with_walls` 1008:b766 (loop at 1008:b848).
- **What the code does:** marks blocked cells (count −1) in the 32-px occupancy grid, indexed `row * 81 + col`,
  at (rows 1–10, columns 0 and 15) and (rows 1 and 13, columns 0–13). The board sits in grid rows 0–13, columns
  1–11 (x 32–383, y 0–447): the walls cross it and close no box around it, and no transposition or offset of
  them does either.
- **Effect:** none: the Tetris moves test `Piece.board`, and nothing in the Tetris scene queries the grid
  (`te_piece_step_move` does not, and the scene swallows the mouse messages whose engine handlers would). The
  walls are dead data.
- **Confidence:** 9 (code); 8 (effect).
- **Port:** reproduced (unit `backdrop`, src/encaixe/); no flag: there is nothing visible to fix, and the walls
  give no intended box to restore.

### E10. `te_piece_clear_row` never rewrites row 0
- **Where:** `te_piece_clear_row` 1008:f042.
- **What the code does:** the loop runs `r` from `row` down to 1 (`srcY` from `(row − 1)·32` down to 0) and copies
  `board[c][r−1]` into `board[c][r]` and the pixel strip at `srcY` 32 px down. The branches for the top row, `'0'`
  into row 0 when `srcY < −31` and `dib_copy_transparent` when `srcY < 0`, are dead: `srcY` never goes below 0 in
  the loop. So row 0 keeps its cells (and its pixels) and row 1 gets a copy of them.
- **Effect:** none by itself. When a line clears in a running game row 0 holds no `'1'`: a piece whose top is in
  rows 0–2 has already lost (E6), the next piece spawns after the clear, and the playfield's top strip is plain
  background. The exception is an E2 phantom cell in row 0: it stays there and every later clear below it copies
  the column one row further down (row 0 into row 1, the copy in row 1 into row 2, …), so the invisible column
  grows by one cell per clear. Its first copy is already in row 1; under the spawn columns (4–6) that makes the
  next piece land at row 0, a loss (E2). E2's fix removes the phantoms.
- **Confidence:** 9 (code); 8 (effect).
- **Port:** reproduced (unit `piece`, src/encaixe/), with the dead branches kept; no flag (nothing to fix once E2
  is fixed).

### E11. Rotations of a new piece before its first fall step leave the earlier rotations drawn
- **Where:** `te_piece_on_landed` 1008:ba20 (the next piece), with `te_piece_restore_background` 1008:c304.
- **What the code does:** the landing's `te_piece_stop_moving_dc` 1008:bbd8 sets `Mover.prevX/prevY` (+0x12/+0x14)
  to where the piece landed; `te_piece_on_landed` then puts the next piece at x 160, y 0 without touching them.
  Until the first fall step (`mover_place_at` sets them) or a sideways key (`mover_stop_moving`), each erase uses
  that stale position: `te_piece_restore_background` copies the clean bitmap over x from `min(x, prevX)`,
  `|stepX| + 128` (160) wide, and y from 0, 160 high. A rotation is drawn by `animation_tick` 1008:7dec
  (`actor2d_redraw`: erase, occupy, draw the new frame) on the next timer tick, and each UP press restarts that
  timer, so pressing UP faster than the fall period keeps the piece at the top and every rotation erases that rect.
- **Effect:** when the landed piece's x was below 160 (its left column 0–3), the erase stops at `prevX + 160`, and
  from the second rotation on, the earlier frames' cells right of that line stay drawn under the new one: the
  sprite at the top shows extra cells (after a landing in column 0, everything in columns 5–7). The board is not affected. The
  first fall step erases x 160–319, y 0–159 and clears them.
- **Confidence:** 9 (code; reproduced in the port, which runs the same erase).
- **Port:** reproduced (unit `piece`, src/encaixe/); the fix is `Fixes.encaixe_spawn_syncs_previous_position`
  (`--fix encaixe_spawn_syncs_previous_position`, on in the Corrigida version): the new piece's previous position
  is its spawn point. Drawing only: the moves, the fall and the timers are unchanged.

---

## TIRO.EXE (the "Tiro ao Álvaro" minigame)

Addresses are Ghidra `seg:off` in `/TIRO.EXE`; the game is described in `docs/tiro/GAME.md`.

### T1. The SPACE latch is never set, so a held SPACE fires on every key repeat
- **Where:** `tiro_scene_handle_message` 1068:1790, `WM_KEYDOWN` `VK_SPACE` (test at 1068:1997).
- **What the code does:** the fire code runs only when `g_keySpaceHeld` (1090:02c2) is 0, and `WM_KEYUP` clears
  it (1068:1d8d), but nothing ever writes 1 to it (those are its only two references). The LEFT/RIGHT latches next
  to it are set on key-down.
- **Effect:** holding SPACE runs the fire code on every auto-repeat: each repeat takes an arrow (T2) and fires
  again as soon as the arrow is free. A held SPACE drains the 16 arrows within a second or two and is the usual
  way to skip the end test (T3).
- **Confidence:** 9 (code); 8 (effect, depends on the keyboard repeat rate).
- **Port:** ported and reproduced (unit `gallery`, src/tiro/); the fix is
  `Fixes.tiro_space_latch` (`--fix tiro_space_latch`, on in the Corrigida version). With the port's key repeat
  (`--key-repeat 500,33`) `tools/play/tiro-endless.input` shows T1 and T3: the held SPACE never ends the game.

### T2. An arrow is spent on a press that fires nothing
- **Where:** `tiro_scene_handle_message` 1068:1790, `VK_SPACE`: `DEC word ptr [BX+0x40]` at 1068:19a4, then the
  free test `CMP word ptr [BX+0x30],0x0` (arrow `moving`) at 1068:19b8.
- **What the code does:** `lives` (the crossbow's arrow counter, `Player2D.lives`) is decremented before the code
  checks whether the single arrow is still flying; a press while it flies only costs the arrow.
- **Effect:** every SPACE press, or key repeat (T1), during a flight of about a second wastes one of the 16 arrows.
  The game can end with fewer shots than arrows.
- **Confidence:** 9.
- **Port:** ported and reproduced (unit `gallery`, src/tiro/); the fix is
  `Fixes.tiro_arrow_spent_on_shot` (`--fix tiro_arrow_spent_on_shot`; in Corrigida).

### T3. The end test `lives == 1` can be skipped, and then the game never ends
- **Where:** `tiro_scene_handle_message` 1068:1790, the four target branches of `WM_SYSTIMER`
  (`CMP word ptr [BX+0x40],0x1` at 1068:1e2e, 2069, 2227, 23a2; `SendMessage(hwnd, WM_DESTROY)` after each).
- **What the code does:** the game ends only on a target tick that sees `lives` exactly 1. SPACE decrements
  `lives` with no lower bound. The four target timers (100 ms) start together and drift apart only through hit
  animations, so the test can run as rarely as every 100 ms.
- **Effect:** two presses (or key repeats, T1) between target ticks take `lives` from 2 to 0; it then only goes
  further negative, the test never holds again, and the game goes on with unlimited shots (each still taking an
  arrow) until `lives` wraps round to 1 after some 65,000 more presses or the window is closed. No result reaches
  NOITE until then.
- **Confidence:** 9 (code); 8 (effect).
- **Port:** ported and reproduced (unit `gallery`, src/tiro/); the fix is
  `Fixes.tiro_end_test_at_most_one` (`--fix tiro_end_test_at_most_one`, on in the Corrigida version).

### T4. The 15th arrow is lost, so at most 14 shots can score
- **Where:** `tiro_game_create_player` 1048:0029 (`lives` = 16) and the end test of T3.
- **What the code does:** the 15th SPACE press leaves `lives` = 1 and fires the 15th arrow; the next target tick,
  at most 100 ms later, sends `WM_DESTROY`, which posts the result. An arrow needs about a second (some 18 ticks of
  55 ms) to reach the lower row.
- **Effect:** the 15th arrow is cut off in flight (it scores only if the target ticks are held up for a second),
  and the 16th is never fired: of the 16 arrows only 14 can score.
- **Confidence:** 9 (code); 8 (effect).
- **Port:** ported and reproduced (unit `gallery`, src/tiro/); the fix is
  `Fixes.tiro_last_arrow_lands` (`--fix tiro_last_arrow_lands`; in Corrigida).

### T5. A hit goes to the first target that overlaps the arrow in x, whichever row it is on
- **Where:** `projectile_try_step` 1068:1448 (first stage) and `tiro_scene_handle_message` 1068:1790, arrow branch
  (`target_hit` calls at 1068:28d0, 2a30, 2b90, 2cf0).
- **What the code does:** the first stage only says that some Target blocks the arrow in the occupancy grid, within
  47 px of that target's y. The handler then stops the arrow and gives the hit to the first of targets 2, 3, 1, 0
  whose x-range overlaps the arrow's (x..x+55 against x..x+75); y is not tested. The three overlap cases use strict
  comparisons, so arrow x = target x and arrow x = target x + 20 match none of them.
- **Effect:** an arrow that reaches an upper-row target scores for a lower-row target (2 and 3 are tested first)
  that happens to be under it in x, with that target's sign (+150 or −150). When no target matches (an exact
  alignment, or the grid cell touched but the x-ranges do not overlap) the arrow is stopped and spent with no score.
- **Confidence:** 9 (code); 7 (how often players see it).
- **Port:** ported and reproduced (unit `gallery`, src/tiro/); the fix is
  `Fixes.tiro_hit_needs_row` (`--fix tiro_hit_needs_row`, on in the Corrigida version).

### T6. `target_restore_background` erases a strip one step wider than the move
- **Where:** `target_restore_background` 1068:0e2f (`getStepX` calls at 1068:0edd and 0ef8).
- **What the code does:** the restore rect is width + |stepX| + |stepX| by height + |stepY| from
  min(previous, current) position; `mover_restore_background` 1028:0389, which it overrides, adds |stepX| once.
  The same rect goes to `addDirtyRect`.
- **Effect:** each walking step restores a 20-px-wide strip of background, the rect's full height, beyond what the
  move uncovered. Whatever else is drawn there, the arrow or a target in its hit animation (which `target_redraw_overlapping`
  skips), loses that strip until its own next redraw; elsewhere the background is restored over background.
- **Confidence:** 9 (code); 6 (effect).
- **Port:** ported and reproduced (unit `render`, src/tiro/); the fix is
  `Fixes.tiro_target_restore_one_step` (`--fix tiro_target_restore_one_step`, on in the Corrigida version).

### Latent (TIRO)

- **`perspective_backdrop_set_layer` 1020:0118 stores before it checks the index:** `layers[layer-1] = obj`, and only
  then `layer < 6` (else the "Estouro no número de Layers" message box). A layer above 5 writes past `layers[5]`
  into `layerCount` (+0x468) and the bytes after the object. Never reached: nothing calls it and no
  PerspectiveBackdrop is ever built. Confidence 9.

### Harmless (TIRO)

- **`WinMain` 1038:0202 returns an uninitialised word:** `[BP-0xe]` is 0 on the two early exits (second instance,
  failed `app_init`) and never written after a normal run. Nothing reads TIRO's exit code. Confidence 9.

---

## SALGIN.EXE (the "Porrada" gym-fight minigame)

Addresses are Ghidra `seg:off` in `/SALGIN.EXE`; the game is described in `docs/salgin/GAME.md`.
`salgin_scene_handle_message` is 1068:0d73.

### S1. The opponent's attacks take energy by the player's damage table
- **Where:** `salgin_scene_handle_message`, the beat's attack branch: `MOV AX,[BX+0x1d4]` at 1068:27c9 (player
  in strip 4–7) and 1068:2811 (any other strip), indexed by the opponent's `curStrip` (1068:27c4, 280c).
- **What the code does:** the player's energy loses `g_fighterDamage[opponent strip]` (1090:01d4, {1, 2, 1, 2}),
  the table the player's own blows use by the player's strip. `g_opponentDamage` (1090:02bc, {2, 1, 1, 3}), indexed
  by the opponent's strip, is read only in a trade (1068:1b77), where it lowers `Fighter.health`, which no score
  uses.
- **Effect:** the opponent's punch takes 1 instead of 2, its flying kick 2 instead of 1, its jump kick 2 instead of
  3 (the sweep 1 either way): 1.5 per attack on average instead of 1.75, and the two sides hit equally hard.
- **Confidence:** 9 (code); 6 (that it is a bug: a second per-strip table exists for the opponent and is indexed
  the same way, but the designers could have balanced the fight by ear).
- **Port:** ported and reproduced (unit `arena`, src/salgin/); the fix is `Fixes.salgin_opponent_damage_table` (`--fix salgin_opponent_damage_table`, a choice left out of the Corrigida version until the owner decides).

### S2. Blocking takes the full damage
- **Where:** `salgin_scene_handle_message`, the beat's attack branch (1068:26a5–27fb); End key 1068:1ec1.
- **What the code does:** a player in strip 4–7 (walk, jump, guard, block) gets a reaction strip, then loses the same
  `g_fighterDamage[opponent strip]` as an attacking player. End only sets strip 7, which only selects the row of
  the reaction.
- **Effect:** the block (End) and the jump (Insert) protect nothing. `g_reactionStrips` shows the block holding
  (strip 7 again) against the punch and both kicks, so the player sees a parry and loses the energy anyway.
- **Confidence:** 9 (code); 7 (that it is a bug).
- **Port:** ported and reproduced (unit `arena`, src/salgin/); the fix is `Fixes.salgin_block_holds` (`--fix salgin_block_holds`, a choice left out of the Corrigida version until the owner decides).

### S3. Releasing Left or Right cuts short whatever move is playing
- **Where:** `salgin_scene_handle_message`, `WM_KEYUP` `VK_LEFT` 1068:1fc4 and `VK_RIGHT` 1068:209d.
- **What the code does:** each key-up clears its own latch, stops the walk and sets strip 6 frame 0 (guard),
  whatever the current strip. An attack, a block, a jump or a hit reaction sets the Left/Right latches, so a press
  is ignored during them, but a key held from before still produces its key-up.
- **Effect:** walking, then attacking while the arrow is still held, and releasing the arrow mid-attack drops the
  attack (or a reaction) into the guard pose at once; the blow was dealt at the key press, so only the animation
  is lost, but the player now stands in guard, and the arrow's latch is free again before the move ends.
- **Confidence:** 9 (code); 8 (effect).
- **Port:** ported and reproduced (unit `arena`, src/salgin/); the fix is `Fixes.salgin_keyup_stops_walk_only` (`--fix salgin_keyup_stops_walk_only`, on in the Corrigida version).

### S4. Insert is not locked by the other moves
- **Where:** `salgin_scene_handle_message`, the latch stores after each move key (Down 1068:14df–1503, Up 1739–1757,
  PgUp 19ab–19c9, Home 1c1d–1c3b, End 1f46–1f64; `g_keyInsertHeld` is 1090:0370).
- **What the code does:** an attack or the block sets 7 of the 8 latches, never `g_keyInsertHeld`; Insert itself and
  every other path that locks the keys (a hit reaction, the KO) set all 8. Down has one store more than the others,
  a second `g_keyPgUpHeld`.
- **Effect:** Insert starts the jump in the middle of an attack or a block, replacing it (and playing its two
  waves); every other key waits for the move to end.
- **Confidence:** 9 (code); 6 (that it is a bug).
- **Port:** ported (unit `arena`, src/salgin/); the fix is `Fixes.salgin_insert_locked` (`--fix salgin_insert_locked`, a choice left out of the Corrigida version until the owner decides).

### S5. The opponent's attack is reseeded from the clock second on every choice
- **Where:** `opponent_choose_attack` 1068:0b85 (`time(NULL)` 1068:0b97, `srand` 0ba0, `rand` 0bae).
- **What the code does:** `srand((unsigned)time(NULL))` before every `rand() % 4`. The CRT `rand` is the LCG
  `x·0x343fd + 0x269ec3`, whose first value after a seed t is bits 16–30 of `t·0x343fd + 0x269ec3`; its two low
  bits advance by 3 (mod 4) per second, with an extra carry about every fourth second.
- **Effect:** the attack is not random: it is a function of the clock second, and runs through the four attacks
  in a fixed descending order (3, 2, 1, 0, …), with a repeat about every 4 s. Two attacks in the same second are the
  same attack.
- **Confidence:** 9.
- **Port:** ported and reproduced (unit `fighters`, src/salgin/); the fix is `Fixes.salgin_seed_once` (`--fix salgin_seed_once`, on in the Corrigida version).

### S6. A loss closes only when `mane.WAV` reports its end
- **Where:** `salgin_scene_handle_message`, the end tick (`g_endReady` set only on a player win, 1068:0fe9) and
  `MM_WOM_DONE` 1068:115a.
- **What the code does:** after an opponent win the handler waits for `g_endReady`, which only the `MM_WOM_DONE`
  (0x3bd) of `mane.WAV`, the one wave played with a notify window, sets (it also posts `WM_DESTROY`). The 3-s end
  count never closes a loss by itself.
- **Effect:** when `mane.WAV` does not play to its end (no wave device, WaveMix failing to open or play it), the end
  screen stays forever with every key ignored; no result reaches NOITE, whose poll waits for the window to go away.
  The window has no system menu, so only the Windows task list can close it (S7).
- **Confidence:** 9 (code); 6 (effect, needs a failing sound setup).
- **Port:** ported (unit `arena`, src/salgin/). No fix flag: the port's WaveMix always plays `mane.WAV` to its end and posts its `MM_WOM_DONE`, so the loss always closes (`tools/play/salgin-alone-lose.input`).

### S7. Closing the window mid-fight reports a win
- **Where:** `salgin_scene_handle_message`, `WM_DESTROY` 1068:10dd–114c.
- **What the code does:** the result is computed and posted whenever `WM_DESTROY` arrives, with no `g_roundOver`
  test: won = !(playerEnergy < opponentEnergy), score = playerEnergy·100.
- **Effect:** ending SALGIN from the task list (End Task: `WM_CLOSE` → `DestroyWindow`) before the opponent has
  landed more than the player is a win; at the start, 91–91, it is worth 9,100 points, the best score.
- **Confidence:** 9 (code); 7 (that a player finds it).
- **Port:** ported and reproduced (unit `arena`, src/salgin/); the fix is `Fixes.salgin_close_mid_fight_loses` (`--fix salgin_close_mid_fight_loses`, on in the Corrigida version).

### S8. The hit-reaction health counters drift from the energy bar
- **Where:** `Fighter.health` (+0x50) and `Opponent.health` (+0x46) in `salgin_scene_handle_message`: the
  opponent's is lowered by PgUp/Up/Home hits (not by the sweep, 1068:145a), the player's only in a trade
  (1068:1b77); the reaction picks at 1068:1a93 (`health < 6`) and 1068:26ee (`health < 10`).
- **What the code does:** both start at 91 like the energies, but the opponent's attacks lower only
  `playerEnergy`, the sweep only `opponentEnergy`, and a trade only `Fighter.health` (by `g_opponentDamage`). The
  weak column of `g_reactionStrips` (always the fall, strip 8) is chosen by `health`, not by energy.
- **Effect:** the player's fall-when-weak needs 82 points lost in trades, which no normal fight gives, so the
  player never shows it; the opponent shows it only in its last 5 energy points, and never once five sweeps have
  landed.
- **Confidence:** 9 (code); 6 (that it is a bug).
- **Port:** ported (unit `arena`, src/salgin/); the fix is `Fixes.salgin_weak_reaction_by_energy` (`--fix salgin_weak_reaction_by_energy`, a choice left out of the Corrigida version until the owner decides).

### S9. The PORRADA banner never stays on screen
- **Where:** `salgin_create_banner` 1068:0119 (`mover_blit_to_dc` to `GetDC(hwnd)`), `salgin_redraw_arena` 1068:0c81.
- **What the code does:** the banner (232×42 at (200, 200)) is blitted once, from `salgin_game_on_create`, i.e.
  during `WM_CREATE`, before `ShowWindow`. It is never drawn again: `salgin_redraw_arena` restores the band
  y 140–434, which contains it, from the background and redraws only the two fighters, on the first beat and after.
- **Effect:** "PORRADA" is not seen (at most for one beat).
- **Confidence:** 9 (code); 7 (effect: the blit goes to a window that is not visible yet).
- **Port:** ported and reproduced (unit `hud`, src/salgin/); the fix is `Fixes.salgin_banner_shown` (`--fix salgin_banner_shown`, a choice left out of the Corrigida version until the owner decides).

### S10. The fighter's 100-px stand-off is 68 px
- **Where:** `fighter_walk` 1068:0672, the Right branch (1068:072f–0780).
- **What the code does:** when nextX is not left of opponent.x − 100 it sets nextX = opponent.x − 100 and then takes
  the normal 32-px step (`fighter_move_tick` → `mover_step`), instead of stopping there.
- **Effect:** a Right press within 100 px of the opponent puts the fighter exactly 68 px from it (moving it by less
  than a step, or back if closer). The same clamp in `opponent_walk` 1068:0a08 is never reached.
- **Confidence:** 9 (code); 7 (that 100 px was the intent).
- **Port:** ported and reproduced (unit `fighters`, src/salgin/); the fix is `Fixes.salgin_standoff_100` (`--fix salgin_standoff_100`, on in the Corrigida version).

### S11. The wall tests use the position before the step
- **Where:** `fighter_walk` 1068:0672 (`x < 1` at 1068:069c, `x >= 400` at 06fd).
- **What the code does:** the walls test the current x and then take a full 32-px step.
- **Effect:** after a Right clamp (S10) leaves x off the 32-px grid, walking left ends at x −31…−1, the fighter's left
  edge off the screen; on the right x can reach 431. (The same tests in `opponent_walk` are never reached.)
- **Confidence:** 9 (code); 6 (effect).
- **Port:** ported and reproduced (unit `fighters`, src/salgin/); the fix is `Fixes.salgin_walls_after_step` (`--fix salgin_walls_after_step`, on in the Corrigida version).

### Harmless (SALGIN)

- **`WM_KEYUP` `VK_LEFT` releases a DC it never got:** `ReleaseDC(hwnd, [BP-0xa])` at 1068:2051; `[BP-0xa]` is
  written only by the clock tick (which already released it) and `0x401`, so it is a stale or garbage handle and
  `ReleaseDC` fails. Confidence 9.
- **The player's hit reaction reads `g_opponentStripFrames`** (1068:27a2) for its `framesLeft`; every strip but 10
  has 3 frames in both tables. Confidence 9.
- **Write-only state:** `g_keyLeftUp` (1090:0378) and the two `contactMark` bytes (`fighter_can_step`,
  `opponent_can_step`). Confidence 9.
- **`WinMain` 1038:0202 returns an uninitialised word,** as TIRO's. Confidence 9.

---

## XILINDRO.EXE (the "Xilindro" street-fight minigame)

Addresses are Ghidra `seg:off` in `/XILINDRO.EXE`; the game is described in `docs/xilindro/GAME.md`.
`xilindro_scene_handle_message` is 1068:0d79. Left out as design: a tie on the clock is a win; Insert plays
`chute3` + `dor1` with no hit; Down and Home trade blows while PgUp and Up do not; the opponent attacks from up to
130 px, beyond the fighter's 100-px reach; the fighter's recoil after a hit usually ends the opponent's reaction on
the next beat. Each is consistent code with a plausible intent, and none is reached by a slip.

### X1. Blocking takes the full damage
- **Where:** `xilindro_scene_handle_message`, the beat's attack branch (fighter strip 4–7 test 1068:2786, damage
  1068:28a2–28af); End key 1068:1fbe.
- **What the code does:** a fighter in strip 4–7 (walk, jump, guard, block) gets a reaction strip, then loses
  `g_opponentMoveDamage[opponent strip]` (1090:02b2, {4, 2, 2, 6}) like an attacking one. End only sets strip 7,
  which only selects the column of `g_reactionTable` (1090:0318).
- **Effect:** the block protects nothing. The table shows the block holding (strip 7 again) against the high kick,
  the hardest attack (6), so the player sees a parry and loses the most energy.
- **Confidence:** 9 (code); 7 (that it is a bug).
- **Port:** ported (unit `arena`, src/xilindro/); the fix is `Fixes.xilindro_block_holds` (`--fix xilindro_block_holds`, a choice left out of the Corrigida version until the owner decides).

### X2. The fighter never shows its weak-energy reaction
- **Where:** `xilindro_scene_handle_message` 1068:27cc (`CMP [g_fighter+0x50],0xa`); `Fighter.energy` (+0x50) is
  written only by `xilindro_game_create_player` 1048:0029 (91).
- **What the code does:** the fighter's reaction column is chosen by `Fighter.energy < 10`, which never changes; the
  real energy is `EnergyBar.fighterEnergy`. The opponent's column uses the energy bar (`opponentEnergy < 6`).
- **Effect:** the second column of `g_reactionTable` (always the fall, strip 8) is never used for the fighter: a
  fighter close to a KO still reels or blocks instead of falling.
- **Confidence:** 9 (code); 7 (that it is a bug).
- **Port:** ported (unit `arena`, src/xilindro/); the fix is `Fixes.xilindro_weak_reaction_by_energy` (`--fix xilindro_weak_reaction_by_energy`, on in the Corrigida version).

### X3. The opponent's attack is reseeded from the clock second on every choice
- **Where:** `opponent_choose_attack` 1068:0b85 (`time(NULL)` 1068:0b97, `srand` 0ba0, `rand` 0bae/0bcd/0c15).
- **What the code does:** `srand((unsigned)time(NULL))` before every `rand() % 4`, with the same CRT LCG as SALGIN
  (BUGS S5).
- **Effect:** the attack is a function of the clock second, in a fixed descending order (3, 2, 1, 0, …) with a
  repeat about every 4 s; two attacks in the same second are the same attack.
- **Confidence:** 9.
- **Port:** ported and reproduced (unit `fighters`, src/xilindro/); the fix is `Fixes.xilindro_seed_once` (`--fix xilindro_seed_once`, on in the Corrigida version). With no key the opponent's attacks differ, so `tools/play/xilindro-alone-lose.input` closes at 39700 in the Original, 39950 with the fix.

### X4. Releasing Left or Right cuts short whatever move is playing
- **Where:** `xilindro_scene_handle_message`, `WM_KEYUP` `VK_LEFT` 1068:20c1 and `VK_RIGHT` 1068:219a.
- **What the code does:** each key-up clears its own latch, stops the walk and sets strip 6 frame 0 (guard),
  whatever the current strip. A key held from before an attack, a block, a jump or a hit reaction still produces
  its key-up.
- **Effect:** walking, attacking with the arrow still held and releasing it mid-move drops the attack (or a
  reaction) into the guard pose at once, and frees the arrow's latch before the move ends.
- **Confidence:** 9 (code); 8 (effect).
- **Port:** ported and reproduced (unit `arena`, src/xilindro/); the fix is `Fixes.xilindro_keyup_stops_walk_only` (`--fix xilindro_keyup_stops_walk_only`, on in the Corrigida version). The scripted wins release Right before they kick, so it never matters there.

### X5. Insert is not locked by the other moves
- **Where:** `xilindro_scene_handle_message`, the latch stores after each move key (PgUp 1068:1a1a–1a38, likewise
  after Up, Down, Home and End; `g_keyInsertHeld` is 1090:03a6, Insert 1068:1f07).
- **What the code does:** an attack or the block sets 7 of the 8 latches, never `g_keyInsertHeld`; Insert itself, a
  hit reaction and the KO set all 8.
- **Effect:** Insert starts the jump in the middle of an attack or a block, replacing it (and playing its two
  waves); every other key waits for the move to end.
- **Confidence:** 9 (code); 6 (that it is a bug).
- **Port:** ported (unit `arena`, src/xilindro/); the fix is `Fixes.xilindro_insert_locked` (`--fix xilindro_insert_locked`, a choice left out of the Corrigida version until the owner decides).

### X6. Closing the window mid-fight reports a win
- **Where:** `xilindro_scene_handle_message`, `WM_DESTROY` 1068:10ce–1146.
- **What the code does:** the result is computed and posted whenever `WM_DESTROY` arrives, with no `g_fightOver`
  test: won = !(fighterEnergy < opponentEnergy), score = fighterEnergy·150.
- **Effect:** ending XILINDRO from the task list while the fighter is ahead or level is a win; at the start,
  91–91, it is worth 13,650 points, the best score.
- **Confidence:** 9 (code); 7 (that a player finds it).
- **Port:** ported and reproduced (unit `arena`, src/xilindro/); the fix is `Fixes.xilindro_close_mid_fight_loses` (`--fix xilindro_close_mid_fight_loses`, on in the Corrigida version). `tools/play/xilindro-close.input`: `won 13650 | lost -1000`.

### X7. A double KO shows the fighter winning but reports by energy
- **Where:** `xilindro_scene_handle_message`, the beat's KO test 1068:2363–24f2 (winner test `opponentEnergy > 0`
  at 23b4), the end tick 1068:0faa, `WM_DESTROY` 1068:1102–1129.
- **What the code does:** a clash (1068:28dc) or a Down/Home trade lowers both energies at once. When both end
  ≤ 0, the KO gives the round to the fighter (strip 10, `vaias`), but the end tick animates whichever side has more
  energy and `WM_DESTROY` compares the energies again.
- **Effect:** with the fighter further below 0 the victory pose freezes, the opponent's last move animates instead,
  and NOITE gets a loss (−1000 and a life); otherwise it gets a "win" worth fighterEnergy·150 ≤ 0, which lowers the
  score.
- **Confidence:** 9 (code); 6 (effect: a double KO needs a trade or a clash with both energies low).
- **Port:** ported (unit `arena`, src/xilindro/); the fix is `Fixes.xilindro_double_ko_by_energy` (`--fix xilindro_double_ko_by_energy`, on in the Corrigida version).

### X8. The energy bar lags behind the energies
- **Where:** `xilindro_scene_handle_message`: the Down/Home trades (1068:15d1–15ec, 1ded–1e08) lower
  `fighterEnergy` without checking `g_fighterBarMark` (1090:03b6); the clash (1068:28dc–293f) lowers
  `opponentEnergy` without checking `g_opponentBarMark` (1090:03b8). Each check adds at most one tile.
- **What the code does:** a side's tile is added only when the other side's action is checked, and a backlog of
  14 or more points drains one tile per later check.
- **Effect:** the bar shows fewer tiles than the energy lost (up to one per 7 points of trade or clash damage) until
  later events catch up, or for good at the end of the round.
- **Confidence:** 9 (code); 7 (that it is a bug).
- **Port:** ported (unit `arena`, src/xilindro/); the fix is `Fixes.xilindro_bar_follows_energy` (`--fix xilindro_bar_follows_energy`, on in the Corrigida version).

### X9. The PORRADA banner never stays on screen
- **Where:** `xilindro_create_banner` 1068:0119 (`mover_blit_to_dc` to `GetDC(hwnd)`), `xilindro_redraw_arena`
  1068:0c87.
- **What the code does:** the banner (232×42 at (200, 200)) is blitted once, from `xilindro_game_on_create`, during
  `WM_CREATE`, before `ShowWindow`. `xilindro_redraw_arena` restores the band y 140–434, which contains it, from the
  background and redraws only the two fighters, on the first beat and after.
- **Effect:** "PORRADA" is not seen (at most for one beat).
- **Confidence:** 9 (code); 7 (effect: the blit goes to a window that is not visible yet).
- **Port:** ported (unit `hud`, src/xilindro/); the fix is `Fixes.xilindro_banner_shown` (`--fix xilindro_banner_shown`, a choice left out of the Corrigida version until the owner decides).

### X10. The fighter's 100-px stand-off is 68 px
- **Where:** `fighter_walk` 1068:0672, the Right branch (1068:071e–0792).
- **What the code does:** when nextX is not left of opponent.x − 100 it sets nextX = opponent.x − 100 and then takes
  the normal 32-px step (`fighter_move_tick` → `mover_step`), instead of stopping there.
- **Effect:** a Right press within 100 px of the opponent puts the fighter exactly 68 px from it.
- **Confidence:** 9 (code); 6 (that 100 px was the intent).
- **Port:** ported (unit `fighters`, src/xilindro/); the fix is `Fixes.xilindro_standoff_100` (`--fix xilindro_standoff_100`, on in the Corrigida version).

### X11. The fighter leaves the screen on the left
- **Where:** `fighter_walk` 1068:0672 (x test 1068:069c, x ≥ 400 at 06fd); the recoil after a hit (PgUp 1068:1a7f,
  Up 17d5, Down 143b, Home 1d29).
- **What the code does:** the walls test the current x and then take a full 32-px step. The recoil moves the fighter
  100 px back whenever x − 100 > −50, so it can end at x −49.
- **Effect:** after a recoil or a Right clamp (X10) leaves x off the 32-px grid, the fighter's left edge goes off
  the screen (to x −49 by a recoil, −31 by walking); on the right x can reach 431.
- **Confidence:** 9 (code); 6 (effect).
- **Port:** ported and reproduced (units `fighters` and `arena`, src/xilindro/); the fix is `Fixes.xilindro_fighter_stays_on_screen` (`--fix xilindro_fighter_stays_on_screen`, on in the Corrigida version): a walk's step is cut to land on 0 or 400, and a recoil stops at x 0 (it still happens from x 51 up, shorter).

### Harmless (XILINDRO)

- **`WM_KEYUP` `VK_LEFT` releases a DC it never got:** `ReleaseDC(hwnd, [BP-0xa])` at 1068:214e; `[BP-0xa]` is
  written only by the clock tick (which already released it) and `0x401`, so it is a stale or garbage handle and
  `ReleaseDC` fails. Confidence 9.
- **Write-only state:** `g_leftReleased` (1090:03ae), `Opponent.energy` (+0x46, lowered by PgUp/Up/Home hits) and
  the two `contact` bytes (`fighter_can_step`, `opponent_can_step`). Confidence 9.
- **The `MM_WOM_DONE` case is dead:** 1068:114c calls `wave_stop_all`, but every wave is played with
  `hWndNotify` 0, so WaveMix never posts 0x3bd. Confidence 9.
- **The opponent's reaction indexes `g_reactionTable` with any strip:** 1068:15d1 (and after Up, PgUp, Home) has no
  strip guard, so an opponent in strip 8–10 would read the next row. Not reached: the opponent's reaction ends on
  the same beat as the fighter's move, or the approach replaces it first. Confidence 7.
- **`WinMain` 1038:0202 returns an uninitialised word,** as TIRO's. Confidence 9.

---

## SERIAL.EXE (the "Serial Killer" shooting-gallery minigame)

Addresses are Ghidra `seg:off` in `/SERIAL.EXE`; the game is described in `docs/serial/GAME.md`.
`serial_scene_handle_message` is 1068:1529. The letter is K (for Killer): S is SALGIN's. Left out as
design: a hit figure vanishes with no animation; a killer shoots once per animation cycle (figure 2
twice per crossing); lane 2 is tried only every 10 s and loses its turn when busy; lane-1 figures
appear whole at the right edge while lane 0 enters at x 20; the shots are unlimited and the game ends
only on the clock or the lives; a survived game is worth a flat 500 whatever `g_score` is. Each is
consistent code with a plausible intent, and none is reached by a slip.

### K1. Every game is reported as a win
- **Where:** `serial_scene_handle_message`, `WM_DESTROY` 1068:1577–15be (`PUSH word ptr [BP+0x10]` at
  1068:15b4 as the 0x40a wParam); NOITE `handler_3farmcai` 1020:8671 (`minigameWon[2] = wParam != 0`).
- **What the code does:** the wParam of the 0x40a result is the handler's own `hwnd` argument, never 0,
  whether the clock ran out or the lives did. TIRO sends `g_score > 0` there. NOITE reads any non-zero
  wParam as a win.
- **Effect:** losing all five lives still counts as a win: no life is taken, and the player goes on to
  the hall (with the jail minigame won) or back to the prison. Only NOITE's own fallback (the window
  gone without a result) posts a loss.
- **Confidence:** 9.
- **Port:** ported and reproduced (unit `gallery`, src/serial/); the fix is
  `Fixes.serial_result_won_by_lives` (`--fix serial_result_won_by_lives`, on in the Corrigida version: won = lives
  left). NOITE's side stays as the original (`src/handlers/3farmcai.zig`). `tools/play/serial-3farmcai-lose.input`
  shows it: the lost game keeps NOITE's three lives in the Original, takes one with the fixes.

### K2. The score is packed into the high word of the result
- **Where:** `serial_scene_handle_message`, `WM_DESTROY` 1068:1598–15be; NOITE `handler_3farmcai`
  1020:8679 (`g_score += lParam`, a 32-bit add).
- **What the code does:** lParam = `MAKELONG(g_lives, g_lives > 0 ? 500 : g_score)`: the lives go in the
  low word and the score (500, or `g_score` after a loss of all lives) in the high word. NOITE adds the
  whole dword to its 32-bit score.
- **Effect:** a survived game adds 500·65536 + lives (32,768,001 to 32,768,005), a lost one `g_score`·65536
  (negative when the SERIAL score is). NOITE shows and saves only the low word (B19), so on screen the
  score grows by the lives left, or not at all; the hidden high word jumps by 500 or by `g_score`.
- **Confidence:** 9 (code); 8 (that `MAKELONG(score, …)` or a plain score was meant).
- **Port:** ported and reproduced (unit `gallery`, src/serial/); the fix is
  `Fixes.serial_score_in_low_word` (`--fix serial_score_in_low_word`, on in the Corrigida version: lParam = 500 or
  `g_score`, sign-extended). NOITE's side stays as the original (`g.score +%= m.lparam`). The SERIAL scripts in
  `tools/play/` check both (`result won 32768004 | won 500`).

### K3. A hit goes to the first figure that overlaps the bullet in x, in any lane
- **Where:** `projectile_try_step` 1068:12a5 (first stage) and `serial_scene_handle_message`, the bullet
  branch (from 1068:2db2; `target_hit` calls 1068:2fe4–45ea).
- **What the code does:** the first stage only says that some Target blocks the bullet in the occupancy
  grid, within half that figure's height of its y. The handler then stops the bullet and gives the hit to
  the first moving figure of lane 2 (13, 14), lane 1 (7–12), then lane 0 (0–6) whose x-range overlaps
  the bullet's; y is not tested. The bullet is taken as 55 px wide (the constant 0x37, TIRO's arrow
  width); `bala.bmp` is 47. TIRO's three strict overlap cases leave bullet x = figure x unmatched.
- **Effect:** a bullet that reaches a lane-0 or lane-1 figure scores for a lane-2 figure (Kennedy is
  200 px wide, the rabbit 188) or a lane-1 figure that happens to be under it in x, with that figure's
  points; the one aimed at walks on (a killer keeps shooting). The 8 extra pixels also count a figure
  whose left edge is 47–54 px right of the bullet's x as overlapped. With no match the bullet is spent
  with no score.
- **Confidence:** 9 (code); 7 (how often players see it).
- **Port:** ported and reproduced (unit `gallery`, src/serial/); the fix is
  `Fixes.serial_hit_needs_row` (`--fix serial_hit_needs_row`, on in the Corrigida version).

### K4. The SPACE latch is never set, so a held SPACE fires on every key repeat
- **Where:** `serial_scene_handle_message`, `WM_KEYDOWN` `VK_SPACE` (test 1068:172b), `WM_KEYUP` 1068:1a91.
- **What the code does:** the fire code runs only when `g_keySpaceHeld` (1090:0312) is 0, and key-up
  clears it, but nothing writes 1 to it. The LEFT/RIGHT latches are set on key-down. (TIRO's T1.)
- **Effect:** holding SPACE fires again as soon as the bullet is free, on every auto-repeat: a held key
  is an automatic gun. With unlimited shots nothing else limits it.
- **Confidence:** 9 (code); 8 (effect, depends on the keyboard repeat rate).
- **Port:** ported and reproduced (unit `gallery`, src/serial/); the fix is
  `Fixes.serial_space_latch` (`--fix serial_space_latch`, on in the Corrigida version).
  `tools/play/serial-held-space.input` (`--key-repeat 500,33`) shows it: SPACE held 3 s fires 4 shots
  in the Original, 1 with the fix.

### K5. The gun's timer id is also lane 2's spawn timer, whose branch never runs
- **Where:** `serial_game_create_player` 1048:0029 (gun timer id 10); `serial_create_targets` 1068:013f
  (`startTimer` on target 13 with `g_timerIds[7]` = 10, 5000 ms); `serial_scene_handle_message`,
  `WM_SYSTIMER` test 1 (gun id, 1068:1abd–1ae7) before test 5 (`timerId13`, 1068:295a).
- **What the code does:** both timers are system timers of the same window with id 10, so the later
  `SetSystemTimer` replaces the earlier: from the start id 10 ticks every 5 s, and from the first aim key
  (`gun_play`) every 60 ms. Every id-10 tick matches the gun first, so the lane-2 spawn branch
  (1068:2968–2cca) is dead.
- **Effect:** lane 2 gets a figure only through the 10-s toggle of the id-7 spawn, never on its own 5-s
  timer; until the first aim key the gun is repainted every 5 s instead of every 60 ms (nothing draws
  over it, so this is not seen).
- **Confidence:** 9 (code); 6 (that lane 2 was meant to spawn on its own timer).
- **Port:** ported and reproduced (units `target` and `gallery`, src/serial/); the fix is
  `Fixes.serial_lane2_own_timer` (`--fix serial_lane2_own_timer`, a choice: left out of the Corrigida version
  (`Fixes.choices`) until the owner decides).

### Harmless (SERIAL)

- **The shot counter is never read:** SPACE decrements `g_gun->lives` (+0x40, 16 from
  `serial_game_create_player`) at 1068:1738 on every press, before the bullet test, and nothing reads it;
  it goes negative after 16 presses. TIRO ended the game on it. Confidence 9.
- **The gun's hit box is TIRO's crossbow box:** `serial_game_create_player` passes 0x11d×0x7f (285×127)
  for the 238×105 `trabu.bmp` frame. The extra area is right of and below the picture, where no bullet or
  figure goes. Confidence 8.
- **`WM_DESTROY` from inside a walk tick:** `target_move_tick` 1068:0dfc sends it when `g_lives` reaches 0,
  and the tick then goes on (the redraw, the other figures' steps) with the waves freed and WaveMix closed;
  `wave_play` then finds no wave (`g_waveCount` 0) and does nothing. Confidence 9.
- **A lane-2 spawn resets a walking figure's frame:** the toggle branch (1068:2602–2650) sets the chosen
  figure's `curStrip`/`curFrame` to 0 before it tests `laneBusy[2]`; when lane 2 is busy with that figure,
  its animation jumps to frame 0. Not seen in practice: a lane-2 crossing takes about 3 s, the toggle
  comes every 10 s. Confidence 9 (code).
- **Write-only state:** `Target.wrapFlag` (+0x40, set by `target_ctor` and `target_wrap_at_edge`).
  Confidence 9.
- **The `0x3bd` case is dead:** 1068:15cc returns 1 for a wave-done message, but every wave is played
  with `hWndNotify` 0. Confidence 9.
- **`WinMain` 1038:0202 returns an uninitialised word,** as TIRO's. Confidence 9.

---

## INV.EXE (the "Invasores" Space Invaders minigame)

Addresses are Ghidra `seg:off` in `/INV.EXE`; the game is described in `docs/inv/GAME.md`.
`inv_scene_handle_message` is 1068:1c9c. The letter is I (for Invasores). Left out as design: a
left-edge turn does not descend; only a column's bottom live invader can be hit; a bomb drops only
from a column within 88 px of the cannon; the saucer is worth a flat 500 and vanishes at x 518, short
of the right edge. Each is consistent code with a plausible intent. Left out as unreachable: the
column tick's second `WM_DESTROY` (wParam 0) after a win, since timer 0xf is then 65 s away (see
Harmless, the last kill's speed-up) and `WM_QUIT` comes first.

### I1. The SPACE latch is never set, so a held SPACE fires on every key repeat
- **Where:** `inv_scene_handle_message`, `WM_KEYDOWN` `VK_SPACE` (test 1068:1ed5), `WM_KEYUP`
  1068:209e.
- **What the code does:** the fire code runs only when `g_keySpaceHeld` (1090:0282) is 0, and key-up
  clears it, but nothing writes 1 to it (those are its two references). The LEFT/RIGHT latches are
  set on key-down. (TIRO's T1.)
- **Effect:** holding SPACE fires again as soon as the shot has landed, on every auto-repeat: a held
  key is an automatic gun.
- **Confidence:** 9 (code); 8 (effect, depends on the keyboard repeat rate).
- **Port:** ported and reproduced (unit `invasion`, src/inv/; `tools/play/inv-held-space.input`); the
  fix is `Fixes.inv_space_latch` (`--fix inv_space_latch`, on in the Corrigida version).

### I2. A direction key during the cannon's explosion cuts it short and lets the cannon fire
- **Where:** `inv_scene_handle_message`, the cannon branch of `WM_SYSTIMER` (isRunning 1068:220b,
  isMoving 2239, `moveTick` and `hitFrame = -1` at 1068:2244–2275); `WM_KEYDOWN` LEFT/RIGHT
  1068:1df9/1e67; the fire gate 1068:1ee2.
- **What the code does:** `cannon_lose_life` stops the cannon and plays `Brocha.bmp`; the branch
  counts the frames in `hitFrame` only while the cannon is not moving. A fresh LEFT or RIGHT press
  (or the release of one with the other held) starts it moving with no explosion test; the branch
  then takes the walking path, which steps the cannon and sets `hitFrame` to −1 on every tick.
  `cannon_lose_life` 1068:07a6 itself leaves `hitFrame` at −1 until the cannon's next tick (up to 60 ms),
  so in that tick the fire gate passes even with no key moving the cannon.
- **Effect:** the cannon drives on showing the frozen explosion frame, and with `hitFrame` −1 the
  fire gate lets it shoot; the explosion resumes from its start only when the cannon stops.
- **Confidence:** 9 (code); 7 (that the explosion was meant to hold the cannon).
- **Port:** ported and reproduced (unit `invasion`, src/inv/; `tools/play/inv-explosion-move.input`);
  the fix is `Fixes.inv_explosion_holds_cannon` (`--fix inv_explosion_holds_cannon`, on in the Corrigida
  version): while the explosion strip is on, from `cannon_lose_life` to its last frame, the arrows only
  set their latches and SPACE does not fire.

### Harmless (INV)

- **The bomb and shot creators write through null pointers into DGROUP:** `inv_create_bombs` 1068:0541
  (`MOV BX,[BX+0x68e6]; MOV word ptr [BX+0x42],1` at 1068:0566–056a, before `operator new` at 0572) and
  `inv_create_shot` 1068:03df (`MOV BX,[BX+0x68e4]; MOV word ptr [BX+0x42],0` at 1068:0404–0408, before
  `operator new` at 0410) set the object's `Missile.unk42` before allocating it, through `g_bombs[i]` /
  `g_shots[0]`, which are still 0 (BSS). The three stores hit DGROUP 0x42–0x43, inside `s_hdcOverflow`
  (1090:002e, "Estouro no número de HDCs"); the shot's 0 is the last, so that message box would read
  "Estouro no número de", but it is shown only when the engine runs out of HDC slots, which this game never
  does. The real `unk42` fields are never written (and never read). Confidence 9 (code); 8 (effect).
- **The last kill takes the speed-up, so the end-of-game branch is dead and the period goes negative:** in
  `inv_scene_handle_message` (1068:2f61–2fad; the dead branch 1068:3065), after `--g_invadersLeft` the tests are
  `left % 5 == 0` (period −= 100), else `left == 1` (period = 55), else `left < 1` (`WM_DESTROY`, wParam 0). The
  last kill leaves 0, and 0 % 5 == 0, so the period becomes 55 − 100 = −45 and `SetSystemTimer` re-arms the
  columns' timer 0xf with 65,491 ms (UINT); the `< 1` branch can never run. The win is sent by the next
  `WM_SYSTIMER` of any timer (step 0 of the chain, within 50 ms), not by the kill, and the formation timer is
  left 65 s away: the delay is not noticeable. Confidence 9 (code); 8 (effect).
- **A landing sends `WM_DESTROY`, and so the loss result, several times:** at the right-edge turn that lands,
  the leading column sends `WM_DESTROY` (wParam 0) from `invader_column_stop_moving_dc` 1068:13a8 (1068:13d4
  when `g_invadersLanded` is set, 1414 on the landing) when the bottom was already at y 390, and again from
  `invader_column_step` 1068:181f's own test (1068:194d); the handler then turns every other live column
  (`invader_column_turn` 1068:157b), and each one's `invader_column_stop_moving_dc` finds `g_invadersLanded` and
  sends it again: up to 5 in one tick. Each `WM_DESTROY` (1068:1cea) runs the teardown (`wave_stop_all`,
  `wave_free_all`, `wave_mix_close`, the last ones with `g_waveMixSession` 0) and posts `0x40a` (0, score) at
  1068:1d0b; it has no guard. NOITE's `handler_4fsacaet` takes the first result and switches to `4fmarte`,
  which ignores `0x40a`, so the score is added once and one life is taken. Confidence 9 (code); 8 (effect).
- **`invader_column_init_cells` 1068:122f adds 44·i twice:** it passes y = 60 + 44·i to
  `invader_column_set_cell` 1088:69d6, which adds 44·i itself, so cell i starts at y 60 + 88·i. The
  hit test uses the column's y, not the cells'; only the explosion is placed from the cell. The first
  formation step (500 ms) rewrites the cells right, and a kill before it needs SPACE within the first
  ~0.28 s. Such a kill bursts the explosion at y 412, over the cannon: the dead invader stays drawn (a
  column restores only the rows down to its lowest live one, and only the explosion's own restore wipes a
  dead cell), and the explosion's end restores the background over the part of the cannon it covered,
  until the cannon moves. Confidence 9 (code); 7 (effect).
- **A shot flagged '2' 44 px or more above an emptied column would kill `cells[-1]`:** the second hit stage
  (`IDIV` 1068:2e95, the match 2ea6, the cell 2ead–2ec1) computes the row as (shot.y − col.y) / 44,
  truncated, for every column whose x range holds the shot, and takes row == `lowestAlive`. An emptied
  column (`lowestAlive` −1) stops stepping where it was, so the live columns pass under it, and a shot can
  be flagged '2' above its top; row −1 would then clear `cells[-1].alive` (the column's word at +0x50),
  move the invader explosion to +0x4c (`hitState`) / +0x4e (never written), add 100 and count a kill, so
  the game could be won with an invader left. In ~4500 random games of the port such shots came at most
  36 px above an emptied column's top, never 44. The port skips row −1 (`invaderHit` in
  `src/inv/invasion.zig`): it has no such memory to read. Confidence 9 (code); 5 (that it can happen).
- **A bomb can be dropped during its impact animation:** the drop test (1068:25c1, 2732) checks only
  `moving`; `bomb_shot_down` stops the bomb and plays `Bomtir.bmp` for one 55-ms tick, so a drop in
  that tick restarts the bomb with the animation still running. Confidence 8.
- **`Missile.hitState` (+0x4a) is never initialised:** `_nmalloc` uses `LocalAlloc(LMEM_NODISCARD)`,
  which does not clear the block, and nothing writes the field before the first step; the handler
  resets it after its first switch. A stray '1'–'4' on a bomb's or the shot's first tick would act
  once. Confidence 7.
- **A shot flagged '2' that matches no column is not vanished:** it flies on (1068:2dcd), as it does
  through the empty lower part of a column; it can still hit higher up. Confidence 9.
- **`Player2D.score` (+0x42) is write-only:** the handler adds 10 per invader and 50 per saucer;
  NOITE gets `g_score`. Confidence 9.
- **Dead code:** `cannon_play` 1068:096a and `cannon_tick` 1068:0a19 (Cannon SceneObject slots 0xa4
  and 0xb4: only `game_handle_message`'s mouse and timer code calls them, and the handler never lets
  those messages through), `saucer_move_tick_or_stop` 1068:0ce6 and
  `invader_column_move_tick_or_stop` 1068:178d (slot 2 of `SaucerVtbl` and `InvaderVtbl`: no call
  site), `invader_column_start_right_dup` 1068:031b (no caller). Confidence 9.
- **The `MM_WOM_DONE` case is dead:** 1068:1d29 calls `wave_stop_all`, but every wave is played with
  `hWndNotify` 0. Confidence 9.
- **`WinMain` 1038:0202 returns an uninitialised word,** as TIRO's. Confidence 9.

---

## INFERNO.EXE (the "Inferno" platformer minigame)

Addresses are Ghidra `seg:off` in `/INFERNO.EXE`; the game is described in `docs/inferno/GAME.md`.
`inferno_scene_handle_message` is 1068:4bdc. The letter is H (for hell): I is INV's. Left out as
design: a survived game is worth a flat 500 whatever `g_score` is (as SERIAL), so the points
collected in play never reach NOITE; the game, its timers and its 3-minute clock keep running while
the window is inactive (`WM_ACTIVATE` pauses only the music and the sound); a second cross picked up
while big makes the hero small again (`hero_toggle_size` toggles); the score can go negative. Each is
consistent code with a plausible intent.

### H1. The "ready" message follows the result, and the hall takes it for its own minigame
- **Where:** `APPWNDPROC` 1038:0353, the post at 1038:0365–0385 (the empty `if (g_noiteWnd)` at 036e);
  NOITE `handler_3fhall` 1020:7b06 (cases `0x40c` and `WM_SYSTIMER`).
- **What the code does:** once `g_started` is set (WM_CREATE; never cleared) every message to
  INFERNO's window first posts `0x40c` to `g_noiteWnd`; there is no one-shot flag (TIRO, SALGIN,
  XILINDRO and SERIAL clear `g_handshakePending` after the first post). The posts go on after the
  `0x40a` result while the window lives: during the time-out's grace second (H2) and the
  `DestroyWindow` that follows `WM_CLOSE` (H4). NOITE's `3fpapmal` switches to `3fhall` on the
  first `0x40a`, so the later `0x40c` reach the hall's handler, which sets its TIRO
  `minigameRunning` and hides the main window; its `WM_SYSTIMER` test then finds no
  "Tiro ao Alvaro" window and posts itself `(0x40a, 0, 0)`.
- **Effect:** after INFERNO reports, the hall counts a lost TIRO game: a life (`6fsaida` at 0
  lives), and `3fhall` again; while `0x40c` keep coming this can repeat.
- **Confidence:** 9 (code, both sides); 6 (how many losses: the order of the posts is not traced).
- **Port:** not ported yet (NOITE's `3fpapmal` and `3fhall` are ported as is; the headless
  minigame stub posts one `0x40c` and one `0x40a`).

### H2. The time-out result is posted again for a second, and the hall takes it for TIRO's
- **Where:** `inferno_scene_handle_message`, the clock block 1068:4bf2–4d14 (time-out 4c26, reposts
  4c80, `WM_DESTROY` 4cea); NOITE `handler_3fhall` 1020:7b06 (case `0x40a`).
- **What the code does:** 180,000 ms after the start the handler posts
  `0x40a (g_lives, g_lives ? 500 : g_score − 1000)` and restarts the clock as a grace period; then
  every message at least 100 ms after the last report posts it again, with the current values, and
  only 1 s later does it post itself `WM_DESTROY`. NOITE's `3fpapmal` takes the first report and
  switches to `3fhall`; the hall's `0x40a` case has no guard, so the next report is the TIRO door's
  result there: `minigameWon[1]` = 1, `g_score` += 500, and the switch to `3fprisao`, where nothing
  handles the rest.
- **Effect:** surviving the 3 minutes adds 1000 instead of 500, marks the TIRO minigame won and puts
  the player in the prison instead of the hall, after the losses of H1 that fit in between.
- **Confidence:** 9 (code, both sides); 7 (effect: the second report comes 100 ms after the first).
- **Port:** not ported yet (as H1).

### H3. Losing the last life reports nothing
- **Where:** `inferno_lose_life` 1068:58b2 (`PostMessage(hwnd, WM_DESTROY)` at 1068:5919); the
  handler's `WM_DESTROY` case 1068:4dbe.
- **What the code does:** at 0 lives the game posts itself `WM_DESTROY`, whose case only stops the
  waves and closes WaveMix and MCI; no `0x40a` is posted. NOITE's `3fpapmal` notices the vanished
  window on its system timer and posts itself `(0x40a, 0, 0)`.
- **Effect:** the loss is counted (a life in NOITE) with a score change of 0: the report's
  `g_score − 1000` branch, the only path that sends INFERNO's points, is never taken (only in the
  sub-tick race of a `0x40a` trigger handled between the post and the `WM_DESTROY`).
- **Confidence:** 9 (code); 7 (that a loss report was meant: the time-out report computes one).
- **Port:** not ported yet.

### H4. Closing the window with a life left reports a win
- **Where:** `inferno_scene_handle_message`, `WM_CLOSE` 1068:4d50.
- **What the code does:** `WM_CLOSE` posts the time-out's report, `(g_lives, g_lives ? 500 :
  g_score − 1000)`, and returns 0, so `DefWindowProc` destroys the window. The window is
  `WS_POPUP | WS_CAPTION` with no system menu: only an external close (End Task) sends it.
- **Effect:** ending INFERNO from the task list at any time with a life left is a win worth 500
  (then H1 takes a life in the hall).
- **Confidence:** 9 (code); 7 (that a player finds it).
- **Port:** not ported yet.

### H5. A hazard the hero runs into kills it without costing a life
- **Where:** `hero_collide` 1068:0260, the hazard branch of a small hero (side hit); its callers
  `hero_jump_step` 1068:0edc and `hero_play` 1068:0bc8; `hazard_hit_player` 1068:3f86.
- **What the code does:** when the hero's own step is blocked by a hazard and the hero is not 30 px
  above it, `hero_collide` stops the hero, parks the hazard and plays the death strip (8 or 9); the
  handler's animation timer then calls `hero_anim_done`, which only resets the pose. The same
  contact found by the hazard's step (`hazard_move_tick` → `hazard_hit_player`) calls
  `inferno_lose_life` (−500, a life, `sonicmor`).
- **Effect:** jumping into a coal, devil or fire low enough to miss the stomp plays the death and
  removes the hazard for free; only a hazard that walks into the hero costs a life.
- **Confidence:** 9 (code); 7 (effect).
- **Port:** not ported yet.

### H6. A life lost wipes the whole occupancy grid
- **Where:** `hazard_hit_player` 1068:3f86 (`occupancy_grid_clear(grid, NULL)` after
  `inferno_lose_life`); `occupancy_grid_clear` 1030:01d2; `inferno_backdrop_create` 1068:0102 (the
  floor wall); `occupancy_grid_vacate_cell` 1080:591c.
- **What the code does:** with a NULL object `occupancy_grid_clear` sets every cell to (0, NULL),
  not just the hazard's: the floor wall of row 23, built once at start, is gone for the rest of the
  game, and so are the cells of every object. The next move of each object vacates cells that are now
  0, and `occupancy_grid_vacate_cell` turns a 0 into 1 (as NOITE, `L11`): each object leaves a
  phantom occupant (count 1, no object) the size of its box where it stood at the hit.
- **Effect:** the landing keeps working on the `g_floorY` clamp, and the cross on its y 327 clamp.
  The phantom cells block like walls with no object: the hero's step into one stops it as on the
  floor (a jump ends and the hero is put back on the floor line).
- **Confidence:** 9 (the wipe); 6 (the phantom cells: from the vacate arithmetic, not traced).
- **Port:** not ported yet.

### H7. A stomp in the scroll zone blocks the stomp points until a landing outside it
- **Where:** `hero_move_tick` 1068:0bf7, the two landing resets; `g_stompScored` 1090:02da, set by
  the stomps in `hero_collide` and `hazard_hit_player`.
- **What the code does:** a stomp gives +150 only while `g_stompScored` is 0 and sets it; only the
  landing outside the scroll zone (x < 340 or facing left) clears it. The scroll-zone branch
  (x ≥ 340 facing right, where the world scrolls under the hero) lands without clearing it.
- **Effect:** after a stomp landed in the scroll zone, later stomps still remove the hazard but give
  no points until the hero lands once outside the zone.
- **Confidence:** 9 (code); 7 (effect).
- **Port:** not ported yet.

### Harmless (INFERNO)

- **`hazard_ctor` gets 4 strips for 3-entry tables:** `inferno_create_hazards` 1068:3bf8 passes
  count 4 with `g_hazardStrip*` (1090:02ac, 3 entries each), so the fourth strip reads the next
  tables: its path is the far pointer 0002:0002 (the first two frame counts), which `OpenFile` and
  `FindResource` reject, so its Frame gets no DIB. No hazard selects strip 3. Confidence 7.
- **The rocks' hit boxes do not match their pictures:** `inferno_create_rocks_and_cross` 1068:272a
  gives `rocha02` (94×99) a 171×35 box, `rocha01` (171×35) 94×99, and rock 5 (`rocha03`) 94×99. The
  rocks run along the top (y 24–45), out of the hero's reach, and props ignore blockers.
  Confidence 8.
- **The hero starts 2 px above the floor line:** `inferno_game_create_player` 1048:0042 places it
  at y 306; every landing puts it at `g_floorY` 308. Confidence 9.
- **The floor wall runs past its row:** `inferno_backdrop_create` fills columns 0–89 of row 23 in
  81-column rows, so columns 81–89 land on row 24, columns 0–8, below the floor. Confidence 8.
- **`hazard_hit_player`'s branch for a non-player blocker is dead:** its only caller tests
  `isPlayer` first. Confidence 9.
- **The `0x12` (`WM_QUIT`) case is dead:** 1068:4d87 posts the report, but `WM_QUIT` is never
  dispatched to a window procedure. Confidence 9.
- **`WinMain` 1038:021a returns an uninitialised word,** as TIRO's. Confidence 9.

---

## SAUNA.EXE (the "Sauna Mista" Pac-Man minigame)

Addresses are Ghidra `seg:off` in `/SAUNA.EXE`; the game is described in `docs/sauna/GAME.md`.
`sauna_scene_handle_message` is 1080:32f7. The letter is P (for Pac-Man): S is SALGIN's. Left out
as design: closing the window (End Task, or a Windows shutdown: the window has no system menu)
forfeits, reported as a loss with −1000; the four ghosts share timer 0x11 and step together; an
arrow's key-up does not stop Pacman and there is no turn buffering; eating a ghost stops Pacman;
the ghosts chase only when aligned within a cell and otherwise turn at random; a cork is worth no
points and a second one re-arms the 5-s power; the last life costs no −500 (the loss's −1000
follows); `ROLHAS01.WAV` restarts on every `WM_PAINT`; the game runs on while inactive. Each is
consistent code with a plausible intent. Left out as unreachable: the `WM_DESTROY` case has no
guard against a second call, but the game sends it once and then quits (`app_exit` frees the game
object, and a message after that would reach a freed object; no path to one is known).

### P1. Only a move left or up meets the other actor; a move right or down passes through it
- **Where:** `pacman_can_step` 1080:0874, `ghost_can_step` 1080:20fe; `pacman_occupy` 1080:0000,
  `ghost_occupy` 1080:13be; `occupancy_grid_query_rect`.
- **What the code does:** a step queries the 2×2 block of 16-px cells under the next hit box and
  takes the object of the first occupied cell in row-major order; it is a meeting only if that
  object is the other kind (a ghost for Pacman, Pacman for a ghost). An actor occupies a 2×3 block
  of cells, and the next block of a step right or down starts with one of its own cells, so the
  object found is the mover itself and anything in the other cells is ignored. A step left or up
  scans cells it does not occupy first.
- **Effect:** Pacman running right or down into a ghost does not touch it, nor does a ghost running
  right or down into Pacman: a ghost behind Pacman going the same way never catches him, and a
  powered Pacman cannot eat a ghost he chases rightward or downward. A head-on meeting is caught by
  whichever of the two moves left or up.
- **Confidence:** 9 (code); 8 (effect).
- **Port:** unit `occupancy` (src/sauna/, docs/sauna/DESIGN.md), not ported yet; the fix is
  `Fixes.sauna_meet_any_direction` (`--fix sauna_meet_any_direction`, on in the Corrigida version).

### P2. An actor that moves clears the cells of any other actor on them
- **Where:** `pacman_vacate` 1080:01c1, `ghost_vacate` 1080:157f; `pacman_occupy`,
  `ghost_occupy`.
- **What the code does:** occupy sets each cell's count to 1 and its object to the actor (the
  engine default counts up); vacate sets the count to 0 and the object to NULL whoever owns the
  cell. Every step vacates the old cells, so an actor leaving cells it shared with another (a ghost
  through a ghost, or one that passed over Pacman by P1) empties the other's cells until that one
  redraws or steps (its next tick, up to 55 ms).
- **Effect:** for that tick the other actor is invisible to the collision test: a step into it
  passes through. Occasional missed catches or missed ghost eats.
- **Confidence:** 9 (code); 5 (how often it shows).
- **Port:** unit `occupancy` (src/sauna/, docs/sauna/DESIGN.md), not ported yet; the fix is
  `Fixes.sauna_vacate_own_cells` (`--fix sauna_vacate_own_cells`, on in the Corrigida version).

### P4. The power mode's start and end turn Pacman to face right
- **Where:** `sauna_scene_handle_message`, the power start (1080:3324) and end (1080:3ee4), which
  call `pacman_refresh_power_strip` 1080:05ef with dir 2.
- **What the code does:** `pacman_refresh_power_strip` sets the strip `g_powerStrip + (dir == 2 ?
  1 : 2)`; both callers pass 2, so the strip is always the right-facing one, whatever Pacman's
  heading. The move tick never sets the strip.
- **Effect:** when a cork is eaten and when the 5 s end, Pacman faces right (powered or normal
  picture) while he runs left, up or down, until the next arrow.
- **Confidence:** 9 (code); 8 (effect).
- **Port:** unit `animation` (src/sauna/, docs/sauna/DESIGN.md), not ported yet; the fix is
  `Fixes.sauna_power_keeps_heading` (`--fix sauna_power_keeps_heading`, on in the Corrigida version).

### P5. A click shows Pacman facing up or right instead of the way he walks
- **Where:** `pacman_move_to` 1080:074a (reached from `game_handle_message`'s `WM_LBUTTONDOWN`).
- **What the code does:** the strip is `g_powerStrip + 2` when the target is left of Pacman, else
  `g_powerStrip + 1`: NOITE's DirectionalPlayer numbering (2 walk left, 1 walk right). SAUNA's
  strips are left 0, right 1, up 2, down 3.
- **Effect:** a click to the left walks Pacman left showing the up picture; any other click, up and
  down included, shows the right picture.
- **Confidence:** 9 (code); 8 (effect).
- **Port:** unit `movement` (src/sauna/, docs/sauna/DESIGN.md), not ported yet; the fix is
  `Fixes.sauna_click_faces_walk` (`--fix sauna_click_faces_walk`, on in the Corrigida version).

### P6. The ghosts keep moving while Pacman dies, and can take another life
- **Where:** `sauna_scene_handle_message`, the ghosts' timer arm (1080:3b1c, no `g_pacmanDying`
  test) and the death sequence (1080:379e–3a5a); `ghost_can_step` 1080:20fe;
  `sauna_scene_send_ghosts_home` 1080:2404.
- **What the code does:** a catch sends the ghosts home without stopping them and starts the
  0.7-s death strip; Pacman stays at the spot, his cells occupied (the death ticks redraw him). The
  ghosts' arm keeps stepping them, and a ghost that meets the dying Pacman calls `sauna_lose_life`
  again.
- **Effect:** a catch near the ghost house can cost two lives (−1000), or end the game, for one
  death.
- **Confidence:** 9 (code); 6 (how often: the ghosts walk back along their old lines, toward the
  spot).
- **Port:** unit `occupancy` (src/sauna/, docs/sauna/DESIGN.md), not ported yet; the fix is
  `Fixes.sauna_no_catch_while_dying` (`--fix sauna_no_catch_while_dying`, on in the Corrigida version).

### P7. An arrow during the death restarts it, and Pacman reappears running
- **Where:** `sauna_scene_handle_message`, `WM_KEYDOWN` (1080:35b8, no `g_pacmanDying` test) and
  the death sequence (1080:37b7); `pacman_move_to_edge_h` 1080:037e, `pacman_move_to_edge_v`
  1080:0468.
- **What the code does:** the arrow's `moveToEdge` stops the animation, sets a walking strip and
  starts a move (moving = 1, timer 0x10 at 55 ms). The next death tick finds a strip below 8 and
  starts the death over (strip 8, 110 ms, 5 more frames); the respawn does not clear `moving`.
- **Effect:** each new arrow press while dying restarts the 0.7-s death strip, which leaves the
  ghosts more time (P6); at the respawn Pacman runs off in that direction at once.
- **Confidence:** 9 (code); 8 (effect).
- **Port:** unit `maze` (src/sauna/, docs/sauna/DESIGN.md), not ported yet; the fix is
  `Fixes.sauna_no_arrows_while_dying` (`--fix sauna_no_arrows_while_dying`, on in the Corrigida version).

### P8. A score of 10000 or more shows a tenth of its value
- **Where:** `sauna_draw_score` 1080:426e, `sauna_blit_score_box` 1080:4221.
- **What the code does:** `" %04d"` of 10000 or more is six characters, drawn every 32 px from
  x 460, so the last one lands at x 620, outside the 192-px box (416–608) that is restored and
  copied to the window.
- **Effect:** the box shows the first five characters (" 1010" for 10100); the last digit appears
  only when the window is repainted, and stays in the backdrop after the score drops below 10000.
  One ghost eaten and no life lost reach it with 95 peanuts.
- **Confidence:** 9 (code); 7 (effect).
- **Port:** unit `score` (src/sauna/, docs/sauna/DESIGN.md), not ported yet; the fix is
  `Fixes.sauna_score_fits_box` (`--fix sauna_score_fits_box`, on in the Corrigida version).

### Harmless (SAUNA)

- **`pacman_stop_and_redraw_dc` 1080:0696 sets the power strip and then strip 0:**
  `actor2d_stop_and_redraw_dc` resets it, so a powered Pacman would show the normal picture; no
  game path calls the slot (`pacman_stop_and_redraw` 1080:06e5 has no caller). Confidence 8.
- **The power mode starts on the next message:** `pacman_restore_background` sets
  `g_powerStartPending`, and the handler's preamble does the picture swap and starts timer 10 on
  the next message of any kind; timer 1 alone brings one within 50 ms. Confidence 8.
- **After the losing `WM_DESTROY` the current message runs on with WaveMix closed:**
  `sauna_lose_life` sends it and returns to the score redraw, `sauna_scene_send_ghosts_home` and
  `g_pacmanDying`; the window quits right after. Confidence 7.
- **A right click on Pacman or a ghost runs its `playOnce`** (`game_handle_message`, the
  `isAnimation` arm): the ticks of both classes ignore the play-once fields, so it only re-arms the
  actor's timer with its 55-ms period (also during Pacman's 110-ms death strip). Confidence 7.
- **The control panel is built at y 592, below the window:** a mouse move below y 440 starts its
  slide, whose timer 0xc the handler swallows, so it never moves. Nothing shows. Confidence 8.
- **Dead code:** `game_handle_message`'s `WM_KEYDOWN`, `WM_KEYUP` and `WM_SYSTIMER` arms (the
  scene handler answers those messages; the arrow arm would dereference `asDirectionalPlayer()`,
  NULL for Pacman), the DirectionalPlayer, Exit, Player and Portable methods, the second draw list.
  Confidence 9.
- **`Player2D.lives` and `score` are never used** (the game keeps `g_lives` and `g_score`), as in
  TIRO. Confidence 9.
- **`WinMain` 1058:021a returns an uninitialised word,** as TIRO's. Confidence 9.

---

## JARDIM.EXE (the "Noite Animal Jardim" first-person labyrinth)

Addresses are Ghidra `seg:off` in `/JARDIM.EXE`; the game is described in `docs/jardim/GAME.md`.
`labyrinth_backdrop_handle_message` is 1028:2609. The letter is J (for Jardim; free). B11 is
NOITE's side of the launch. Left out as design: ESC quits without a result, which NOITE's poll
reports as a loss with no score change, and closing the window (End Task: it has no system menu)
reports a loss with −1000 (both forfeits); health has no cap; a blocked step does not
slide along the wall and drops the speed to 16; every enemy on screen, at any distance, costs 1
health per animation cycle; enemies move only while on screen; a death restores every pickup and
every killed enemy and costs 500 points; the fists hit nothing; the game runs on while inactive.
Each is consistent code with a plausible intent.

### J1. The win's time bonus is a penalty
- **Where:** `labyrinth_backdrop_handle_message`, the `WM_DESTROY` win branch 1028:3d71–3d81;
  `g_startTick` (10d0:00ae), set by `labyrinth_backdrop_create` 1028:2191.
- **What the code does:** `g_startTick` holds the full 32-bit `GetTickCount()` of the first
  labyrinth. The win computes `score += 10⁹ / (now − g_startTick)` but keeps only `AX` of the new
  tick and sign-extends it (`CWD`) before the 32-bit subtraction, then truncates the quotient to
  16 bits.
- **Effect:** the difference is about −`g_startTick` (the milliseconds Windows had been running
  when the labyrinth started), so the "bonus" is about −10⁹/`g_startTick`: −833 after 20 minutes of
  Windows, −278 after an hour, never positive; it does not depend on the time played. A difference
  of 0 would divide by zero in `_aFldiv`, which needs the labyrinth to start within 33 s of Windows.
- **Confidence:** 10 (code); 8 (that a bonus for speed was meant: 10⁹ / elapsed ms).
- **Port:** unit `labyrinth_input` (src/jardim/, docs/jardim/DESIGN.md), not ported yet; the fix is
  `Fixes.jardim_time_bonus` (`--fix jardim_time_bonus`, on in the Corrigida version).

### J2. Phase 3's Chato can be shot again and again
- **Where:** `phase3_scene_hit` 10b0:264c.
- **What the code does:** a shot that stops on `enemyChato` adds 200 and stops the waves, but does
  not clear its cell; every other kill in the three phases sets `objectRows[row][col] = NULL`.
- **Effect:** Chato stays where it is (and keeps hitting), and each shot at it scores 200 again:
  the score can be farmed with the ammunition, which comes back with every death.
- **Confidence:** 9 (code); 8 (that the clear is missing: phases 1 and 2 have it).
- **Port:** unit `phase3` (src/jardim/, docs/jardim/DESIGN.md), not ported yet; the fix is
  `Fixes.jardim_chato_removed` (`--fix jardim_chato_removed`, on in the Corrigida version).

### J3. A weapon picked up while a shot flies is lost
- **Where:** `phase1_scene_touch` 1098:2823 (bra, crossbow), `phase2_scene_touch` 10a8:3227 and
  `phase3_scene_touch` 10b0:1f44 (bazooka, crossbow).
- **What the code does:** the weapon branches change the hands and the ammo only when
  `shotInFlight` is 0; the pickup is still removed from the cell (the "left behind" object stays
  NULL), and the crossbow's sound plays anyway.
- **Effect:** walking over a crossbow, bra or bazooka during the second or so a shot needs to reach
  a wall makes it vanish with no effect, until the next death puts it back.
- **Confidence:** 9 (code); 7 (that a deferred or refused pickup was meant).
- **Port:** units `phase1`, `phase2`, `phase3` (src/jardim/, docs/jardim/DESIGN.md), not ported yet; the fix is
  `Fixes.jardim_weapon_waits_for_shot` (`--fix jardim_weapon_waits_for_shot`, on in the Corrigida version).

### J4. The wall textures stay on the screen instead of on the walls
- **Where:** `raycast_render_view` 1028:0951, the calls of `wall_strip_draw_wall_a/b`
  (1028:482c/48e2).
- **What the code does:** for a wall (values 1–6) it passes the screen x of the column as the
  texture column (`& 31` in the drawer); for a door (7–12) it passes the hit coordinate & ~3, which
  the walks compute for every hit.
- **Effect:** every wall shows the same 32-px pattern aligned to the screen: when the player turns
  or walks, the walls move and their texture does not, it slides over them. Doors are textured
  right.
- **Confidence:** 9 (code); 7 (that the hit coordinate was meant: the door path uses it).
- **Port:** unit `raycast` (src/jardim/, docs/jardim/DESIGN.md), not ported yet; the fix is
  `Fixes.jardim_wall_texture_on_wall` (`--fix jardim_wall_texture_on_wall`, on in the Corrigida version).

### J5. A sprite whose top lands on row 478 crashes the game
- **Where:** `blit_scaled_sprite_transparent` 1018:0024 (the magnifying row loops at +0x177 and
  +0x30c); `dib_stretch_copy_transparent` 1068:1336; `labyrinth_draw_sprite_entry` 1028:52a8.
- **What the code does:** the sprite is clipped only to the 640×480 surface, and 1336 passes the
  clipped height minus one. The magnifying row loop starts its counter at that value minus one and
  tests it after decrementing it, so a clip of 2 rows starts at 0 and counts down from −1, 2³²
  times, stepping the destination one row per pixel.
- **Effect:** when a magnified sprite (nearer than about 2.3 cells) has its top on row 478 of the
  surface, only 2 of its rows are on the surface and the copy runs off the selector: a GP fault.
  Such a sprite is a short pickup seen from under a cell (the medkit at a depth of about 27 units,
  the bombs, the açaí, the shrimp), so it needs an exact distance while approaching one: rare.
- **Confidence:** 9 (code); 5 (how often it happens).
- **Port:** unit `scaled` (src/jardim/, docs/jardim/DESIGN.md), not ported yet; the fix is
  `Fixes.jardim_sprite_last_rows` (`--fix jardim_sprite_last_rows`, on in the Corrigida version; the Original port panics naming J5 where the original faults).

### J6. Running into a life-taking enemy takes a life every tick
- **Where:** `labyrinth_move_and_render` 1028:3e23; the held-key branch of
  `labyrinth_backdrop_handle_message` (`WM_SYSTIMER`); `phase1_scene_touch` (Seios),
  `phase2_scene_touch` (Siri), `phase3_scene_touch` (Bicho).
- **What the code does:** a step into an enemy calls `touch`, which takes a life (Seios, Siri,
  Bicho) or 5 health (Bussuf, Alemão, Chato), and the step is undone; the enemy stays. While an
  arrow is held the timer repeats the step every 55 ms; the respawn waits for the end of the
  `berro` wave.
- **Effect:** holding UP into Seios, Siri or Bicho for 165 ms costs three lives, the whole game; the
  5-health enemies drain a life in about a second.
- **Confidence:** 9 (code); 6 (that one life per contact was meant).
- **Port:** unit `labyrinth_input` (src/jardim/, docs/jardim/DESIGN.md), not ported yet; the fix is
  `Fixes.jardim_enemy_blocks_walk` (`--fix jardim_enemy_blocks_walk`, a choice: left out of the Corrigida version (`Fixes.choices`) until the owner decides).

### J7. From `espquete` the variant never reaches JARDIM: the final enemy is always the vampire's
- **Where:** `APPWNDPROC` 1020:0353 (the `FindWindow("Noite Animal")` branch at the top of every message
  and its WM_SYSTIMER retry); NOITE's `handler_espquete` 1028:0a88, `0x40c` case.
- **What the code does:** JARDIM does not wait for NOITE's hello: on its first message, sent inside
  CreateWindow, it finds NOITE's window and posts `0x40c`. NOITE cannot run before JARDIM's WinMain yields,
  so this `0x40c` is queued before NOITE's timer 0x14 can find JARDIM's window. `handler_espquete` takes any
  first `0x40c` as the reply: it kills timer 0x14 and hides itself, and its ack goes to window 0. The hello
  (`0x40b`, wParam = variant 1) is never posted and `g_variant` keeps its initial 0. `handler_4fjarvamp`
  ignores a `0x40c` while it does not know JARDIM's window, so its hello (variant 0) does arrive.
- **Effect:** after the garden cutscene the final enemy of phase 3 is `vamanf` (the vampire's picture, meant
  for `4fjarvamp`) instead of `espanf`. JARDIM never gets NOITE's ack either and posts `0x40c` on every
  message until it ends (each one a no-op for NOITE).
- **Confidence:** 9 (code); 8 (the order: Windows 3.1 runs the new task's WinMain until it first yields).
- **Port:** unit `app` (src/jardim/, docs/jardim/DESIGN.md), not ported yet; the fix is
  `Fixes.jardim_variant_hello` (`--fix jardim_variant_hello`, on in the Corrigida version): JARDIM posts
  `0x40c` only after `0x40b`, as TIRO does.

### Latent (JARDIM)

- **A door on the map border reads outside the map:** the walks read the cell behind a see-through
  door with no bound: in `raycast_walk_vertical` 1010:0024 column −1 (offset 0xffffffff of the row:
  a GP fault) or 57; in `raycast_walk_horizontal` 1008:0024 row −1 or 80 (table bytes or
  `objectRows[0]` taken as a row). The shipped doors on the border (`8` at column 0, `7` on rows 0
  and 79) all have the parity that is drawn recessed in that direction. Confidence 9.
- **`sprite_queue_insert` 1028:5ac6 has no capacity check:** a 101st cell with an object in one
  frame would write past the 100-node pool. The maps put far fewer objects in sight. Confidence 8.
- **`blit_scaled_column` 1000:0024 with a 1-row source loops 2³² times;** the source is always the
  300-row texture. Confidence 9.
- **`blit_scaled_sprite_transparent` ignores the clip when minifying,** and when magnifying a
  column past the last source column would be read from where the previous one ended. Neither
  happens: the destination is already cut to the view's columns, a minified sprite ends above
  y 342, and the column Bresenham never asks for an extra source column within the clip (checked
  for every source width below 200 and destination width below 400). Confidence 8.
- **`labyrinth_load_map` 1028:056c does not check the file's length:** a short map would fill the
  rest with `_filbuf`'s −1. The shipped maps are complete. Confidence 9.

### Harmless (JARDIM)

- **`0x40c` is re-posted on every message until NOITE answers** (`APPWNDPROC` 1020:0353): after
  `4fjarvamp`'s hello NOITE acks the first one and a few more follow; after `espquete` NOITE never acks (J7)
  and the posts go on until JARDIM ends, each ignored. Confidence 9.
- **The wall column blit is off by one row:** `blit_scaled_column` 1000:0024 writes one row more
  than the slice (above it, over the sky) when the wall is less than half the texture's height
  (beyond about 4.7 cells), and for an odd slice height taller than the view it draws the column
  1 px high and leaves the view's bottom row with the floor. Confidence 9.
- **Magnified sprites lose their last column and their last two rows** (the clip extents minus one,
  `dib_stretch_copy_transparent` 1068:1336). Confidence 9.
- **Two placements are overwritten:** phase 1 puts a crossbow and then arrows on row 6 column 53,
  phase 2 a shrimp and then a beer on row 23 column 29 (`phase1/2_scene_place_objects`): one
  crossbow and one shrimp fewer. Confidence 9.
- **Some constructor positions are in walls:** each object is also placed at its constructor
  position, inside a wall for the phase-1 medkit, beer and arrows, the phase-2 arrows and the
  phase-3 medkit and shrimp, where it is never drawn or reached; `phase3_scene_create`
  places Chato twice and never Bicho or the final enemy (their map placements follow).
  Confidence 9.
- **The phase scenes' destructors never run:** `game_take_exit` deletes the old scene through
  `scene_scalar_dtor`, which calls the base `scene_dtor` (Scene has no virtual destructor), so the
  phase's Portables leak, at most twice per game. Confidence 9.
- **The Player's picture `passo1.bmp` is not on the disc:** `load_dib` returns NULL and the
  Player, which no phase scene shows, keeps a NULL frame. Confidence 9.
- **Phase 3's exit-door branch is dead:** `phase3_scene_handle_message` 10b0:29af would post a loss
  for a `7`/`8` beyond row 5; map 3's only one is on row 3. Confidence 9.
- **Chato's attack is silent:** `phase3_scene_play_enemy_attack_sound` plays `g_phase3Waves[0]`,
  which `phase3_scene_create` never opens (`wave_play` finds nothing). `esmagar` is opened in
  every phase and never played. Confidence 9.
- **The loss can be reported several times:** while lives are 0 every visible enemy's attack and
  every touch post `WM_DESTROY` again, and each one posts another `0x40a` (another −1000) before
  `WM_QUIT` ends the program. NOITE has switched to `6fsaida` on the first (not traced further).
  Confidence 6.
- **`WinMain` 1020:021a returns an uninitialised word,** as TIRO's. Confidence 9.
