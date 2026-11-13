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
