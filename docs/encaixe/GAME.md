# ENCAIXE.EXE: the game as implemented

"Encaixe Perfeito" is a falling-blocks game launched by NOITE.EXE's `3ffarao` handler. This
file describes what the code does, bugs included (they are listed in `BUGS.md`, section
ENCAIXE). Addresses are Ghidra `seg:off` in `/ENCAIXE.EXE`; names are the current Ghidra
names. Functions are in `FUNCTIONS.md`, structs and globals in `DATA.md`.

## Files

All opened by relative name: `tetrfun.bmp` (background), `peca.bmp`, `pecaa.bmp` … `pecae.bmp`
(the six piece strips, 128×128, 4 frames = 4 rotations), `panel.bmp` (status bar and panel
frames, never shown), `doom2.mid` (music), `tetris2.wav` (line sound), `arialbd.fot` (not on
the disc). `WAVEMIX.DLL` sits next to the EXE.

## Startup

1. `entry` (`1008:0018`): MSVC small-model Windows startup; `_cinit` runs the static
   initializer `1010:002e` → `init_static_conditions` (the two FlagConditions).
2. `WinMain` (`89cc`): stores the module path, resolves USER.11 `SetSystemTimer` and USER.182
   `KillSystemTimer` with `GetProcAddress`. A second instance gets the message box "O aplicativo
   ja esta aberto !!!" and exits.
3. `app_init` (`8886`): registers the class "Encaixe Perfeito", `new TetrisGame`
   (`te_game_ctor`, stored in `g_game` and `g_tetrisGame`), creates a 640×480
   `WS_POPUP|WS_CAPTION` window titled "Encaixe Perfeito", centred, and shows it.
4. `WM_CREATE` in `APPWNDPROC` (`8ae4`): `te_game_on_create` (`a0f4`), then `g_started = 1`
   and the window timer (id 1, 50 ms; every `WM_SYSTIMER` for it is swallowed by the scene).
5. `te_game_on_create` → `game_init(this, "Tetris", hwnd)` (`8d32`):
   - `te_game_create_init_scene`: a TetrisScene (`hasPlayer` = 1, no panel, no status bar,
     no exits);
   - `PatBlt` BLACKNESS; `te_scene_create` (`b6f6`): `scene_create` builds the backdrop with
     `te_scene_create_screen` (`a7d4`, `tetrfun.bmp`, 640×480 view) and
     `te_grid_backdrop_create_with_walls` (32-px occupancy grid plus wall cells); MCI
     `open doom2.mid type sequencer alias musica` and `play musica notify`; `wave_mix_init`;
     `tetris2.wav` into `g_tetrisWave`; `te_draw_score` and `te_blit_score_box`;
   - the status bar and the TetrisPanel are created and attached but stay hidden (the
     panel's attach is where `AddFontResource("arialbd.fot")` runs; the panel's constructor
     gets its arguments one word off, BUGS E11);
   - `te_game_create_player`: the Piece (`g_piece`, a Player2D: step 32×32 px, timer id 12,
     period 200 ms, start x 160), `srand(time(NULL))`, first kind `rand() % 6`;
   - `PostMessage(hwnd, 0x401)`, ignored.
6. `te_piece_new_game` (`b9e2`): board all `'0'`, column 4, row 0, the first shape written;
   `mover_move_to_edge_v` starts the fall.

## Board

`Piece.board` is `char[11][14]`: 11 columns × 14 rows, **column-major** (`board[col][row]`,
column stride 14), each cell `'0'` (empty) or `'1'` (full). The falling piece is stored in the
board as `'1'` cells too, so every move erases and rewrites its cells. `Piece.column` /
`Piece.row` are the top-left of the piece's bounding box. Cell (c, r) is drawn at
x = 32 + 32c, y = 32r (the playfield is x 32–383, y 0–447).

## Pieces

Six kinds, `kind = rand() % 6` (the SceneObject's `curStrip`, which selects the `peca*.bmp`
strip); rotation 0–3 (`curFrame`, the strip frame). A new piece spawns at column 4, row 0,
rotation 0 (`te_piece_spawn_shape`, `b898`), drawn at x = 160, y = 0. Shapes are hard-coded in
`switch (kind) switch (rotation)` code (`b898`, `bb2e`, `c41a`, `ce8c`, `d960`, `e392`, `eed8`);
there is no shape table. Rotations clockwise, `#` = cell, top-left = (column, row):

```
kind 0 (6-cell T, long stem)   kind 1 (T)        kind 2 (L)        kind 3 (J)
 r0    r1    r2    r3          r0  r1  r2  r3    r0  r1  r2  r3    r0  r1  r2  r3
 ###   ...#  .#.   #...        ### .#  .#. #.    ##  ..# #.  ###   ##  ### .#  #..
 .#.   ####  .#.   ####        .#. ##  ### ##    .#  ### #.  #..   #.  ..# .#  ###
 .#.   ...#  .#.   #...            .#      #.    .#      ##        #.      ##
 .#.         ###

kind 4 (I)                     kind 5 (O)
 r0  r1    r2  r3              r0..r3
 #   ####  #   ####            ##
 #         #                   ##
 #         #
 #         #
```

There are no S or Z pieces. The I has two shapes, the O one.

## Moves

Each move is a worker that validates and then rewrites the board (`te_piece_try_move`,
`f186`, dispatches on `Mover.direction`: 1 left, 2 right, 4 rotate, 8 down). A blocked move
returns 0 and leaves the board untouched.

- **Right** (`te_piece_move_right`, `c41a`): the key handler first computes
  `rightCol = column + width − 1` (`te_piece_calc_right_col`, `bb2e`) and ignores the key when
  `rightCol > 10`; the worker needs the new right edge ≤ 10 and every cell the shape enters
  (the shape shifted right, minus itself) to be `'0'`; then erases the vacated cells, writes
  the new ones, `column++`.
- **Left** (`te_piece_move_left`, `ce8c`): needs `column ≥ 1` and the entered cells free; then
  `column--`. The O piece's case never writes its new left column (BUGS E1).
- **Down** (`te_piece_move_down`, `d960`): needs the new bottom row ≤ 13 and the entered cells
  free; then `row++`. It stores its result in `Piece.canFall`.
- **Rotate** (`te_piece_rotate`, `e392`): writes rotation (r+1) % 4 at the same top-left. Only
  the cells of the new shape that the old one does not cover are tested; plus
  `column + newWidth ≤ 11` and, when the shape grows downwards, a bottom test that lets the
  last cell reach row 14 (BUGS E2). The O only checks `column + 2 < 11 && row + 2 < 14`. The new
  rotation reaches `curFrame` one tick later, when the sprite animation advances.

## Timing and keys

The piece has one timer, id 12. Its period is `Mover.timerPeriod`, 200 ms at start;
`mover_move_to_edge_v/h` and `animation_play` (re)start the timer with it.

- **Gravity** (`WM_SYSTIMER` id 12, `te_scene_handle_message` `f2a2`): if the rotation
  animation is running, advance its frame and stop it, then resume the fall; else
  `te_piece_step_move` (`f1fe`) moves one step (32 px) in `Mover.direction`. A blocked step
  stops the mover; if the blocked move was down (`canFall` = 0) the piece lands
  (`te_piece_on_landed`), otherwise the fall resumes (direction 8).
- **Left / Right** (`VK_LEFT`/`VK_RIGHT` down): stop, direction 1 / 2, start a horizontal move
  and take one step at once. While held, the timer keeps stepping sideways (no fall); each
  key repeat takes another step. Key up (or a blocked step) resumes the fall.
- **Up**: rotate (unless the rotation animation is still running), see Moves.
- **Down**: `SetSystemTimer(id 12, 55 ms)`. Key up does not restore the period: the faster
  fall lasts until the next timer restart (a rotation, a sideways key, or the landing). The
  guard flag is never set (BUGS E5), so every key repeat restarts the 55 ms countdown.
- Mouse buttons and moves, and `0x3bd`, are swallowed. Other keys do nothing.

Speed-up (in `te_piece_on_landed`, after the line clear): when `linesCleared % 5 == 0` and
non-zero, the period becomes 150 ms at 5 lines, 100 ms at 10 and 55 ms at 15. 10 lines is a
win, so only 150 ms is reached (and only when the count lands exactly on 5, BUGS E7).

## Landing, lines and score

`te_piece_on_landed` (`ba20`):
1. If `row < 3` (the piece's top in rows 0–2): `SendMessage(hwnd, WM_DESTROY, 0, 0)`, a loss.
   The function carries on (BUGS E6).
2. `te_piece_clear_full_lines` (`eed8`): among the rows the piece covers (`row` to
   `row + height − 1`), each row with no `'0'` in its 11 columns is full. They are removed from
   the bottom up: `linesCleared++` and `te_piece_clear_row` (`f042`) for each, which calls
   `te_score_cleared_row` (`f67a`: plays `tetris2.wav`, `g_score += 100`, redraws the score;
   `g_score == 1000` → `SendMessage(hwnd, WM_DESTROY, 0xffff, 0)`, a win) and then moves every
   row above down by one, shifting the pixels on both backdrop DCs and blitting the backdrop to
   the window. Row 0 is never rewritten: it keeps its cells and row 1 gets a copy (BUGS E10).
3. The speed-up check above.
4. The next piece: `rand() % 6`, rotation 0, spawned at column 4 row 0 (written over whatever
   is there), x 160, y 0, falling.

`g_score` starts at 0 and only grows by 100 per line, so the win is exactly the 10th line.

**Score display** (`te_draw_score`, `f710`): `sprintf("%06d", g_score)`, each digit drawn with
its own `TextOut` at x = 429 + 32·i, y = 360, colour `0xedeeee`, transparent, in the DC's
default font, on both backdrop DCs after restoring the 192×32 box at (416, 352) from the
background; `te_blit_score_box` (`f6d4`) copies that box to the window. `arialbd.fot` is
registered with `AddFontResource` (and a `WM_FONTCHANGE` sent to hwnd 0) but no font is ever
created or selected.

## End of the game

Both endings are a `WM_DESTROY` sent to the game's own window; a real window close
(`WM_CLOSE` → `DestroyWindow`) delivers `WM_DESTROY` with wParam 0, which counts as a loss.
`te_scene_handle_message` handles it: `wave_stop_all`, `wave_free_all`, `wave_mix_close`, MCI
`close musica`, then

- `g_score += (wParam == 0 ? −1000 : 0) + 500`: +500 on a win (so a win reports 1500), −500 on
  a loss;
- `PostMessage(g_noiteWnd, 0x40a, wParam, (long)(int)g_score)`.

It returns 0, so `APPWNDPROC` kills timer 1 and posts `WM_QUIT`; `app_exit` deletes the game.

## Protocol with NOITE.EXE

| Msg | Direction | wParam | lParam | Meaning |
|---|---|---|---|---|
| `0x40b` | NOITE → ENCAIXE | 0 | NOITE's main window | hello; ENCAIXE stores it in `g_noiteWnd` (in `APPWNDPROC`, after the scene and the game decline it) |
| `0x40c` | ENCAIXE → NOITE | ENCAIXE's window | 0 | ready; posted once, on the first message after `g_started` when `g_noiteWnd` is set (`g_handshakePending` 1 → 0) |
| `0x40a` | ENCAIXE → NOITE | 0 lost, `0xffff` won | score delta (sign-extended 16-bit `g_score`) | result |

NOITE's `handler_3ffarao` (1020:81f0; `src/handlers/3ffarao.zig`):
- when the pharaoh video ends (`MM_MCINOTIFY` of its AVI): closes the AVI, reinitialises
  WaveMix, `WinExec("<CD>encaixe\encaixe.exe")` and sets timer 0x14 (100 ms);
- timer 0x14: `FindWindow("Encaixe Perfeito")`; once found, kills the timer and posts `0x40b`
  with its main window in lParam;
- `0x40c`: minigame running, hides the main window;
- `WM_SYSTIMER` while running: if the window is gone, posts itself `0x40a` (0, 0), a loss
  with no score change; the tick is swallowed;
- `0x40a`: realizes the palette, shows the main window, records the result in
  `Game.minigameWon[0]`, adds lParam to the score; a loss takes a life and goes to `3fcasame`,
  or to `6fsaida` (game over) when lives reach exactly 0 (NOITE BUGS B1); a win goes to
  `3fhall` with the player at (0xf0, 200).

## Music and sound

- Music: MCI sequencer, alias `musica`. `play musica notify` at start; `MM_MCINOTIFY` with
  `MCI_NOTIFY_SUCCESSFUL` → `play musica from 0 notify` (it loops). `WM_ACTIVATE` inactive or
  minimised → `pause musica` + `wave_mix_deactivate`; active → `play musica notify` +
  `wave_mix_activate` (a failure shows "Erro Wave Mix"). `close musica` at the end.
- Sound: WaveMix, one wave (`tetris2.wav`) played once per cleared line (no notify window, so
  on the least recently used channel).
