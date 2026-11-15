# JARDIM's walls up close

The texture investigation behind the Corrigida's wall fixes (docs/jardim/DESIGN.md "Decisions", "The
walls up close"; BUGS.md J4 and "Harmless (JARDIM)"). Its verdict: the port draws what JARDIM.EXE
draws; two things make the walls look broken up close. The texture sampling (in the Original J4:
the texture fixed to the screen; in the first J4 fix, `hit & ~3` with the dword blit, combs) and the
heights computed from whole-unit distances, which bend and step the brick courses. Smaller: walls
taller than the view with an odd height sit one row too high.

**Reproducing the frames.** The 1995 controls reach every distance: from the start (912, 48),
angle 480, 25 RIGHT presses face −y toward the row-0 brick wall (face at y = 32): y 48 is ½ cell
from it, one DOWN (y 64) 1 cell, four more (y 128) 3 cells with the exit door `7` on the right; two
UP presses from y 48 reach y 32 (1 unit: the −y walk starts at line 31) and then y 40 (the step into
the wall is pushed back: ¼ cell). Five RIGHT presses turn 30°. Run the Original and `--fix
all,-jardim_smooth_movement,-jardim_wolf_keys,-jardim_controls_screen,-jardim_game_timer_only,-jardim_wall_margin,-jardim_fair_enemies`
with `--dump` on the same presses and crop the 480×300 view at (20, 42).

## Artefacts, mechanism, classification (before the fixes)

### A. Original: thin vertical stripes up close, and the texture slides when you turn (J4)

- **Mechanism.** `raycast_render_view` passes a wall's screen x as the texture column:
  1028:0d39–0d64 pushes `[BP-0x28]`, the column x, to `wall_strip_draw_wall_a` (482c; and
  0c17→48e2). The drawer masks it with `(hitW−1)` = 31 (4860–4866).
  `blit_scaled_column` (1000:0024) copies **one dword per row**: texels x..x+3 onto the 4
  screen pixels. The texture is therefore drawn at 1 texel per screen pixel across the whole
  screen, at every distance, while it is stretched vertically by h/300.
- **What you see.** At 3 cells the bricks look right. At 1 cell they are 16 px wide and
  28 px tall. At ¼ cell and below they become stripes 1 px wide and tens of px tall.
  The pattern also stays put on the screen while the walls move.
- **Class: Original.** Verified against the disassembly. The blit is proven by the oracle
  (`src/jardim/testdata/blit_scaled_column.zig`, emulated).

### B. Corrigida: smeared "comb" walls, and bricks turned into flat slabs

- **Mechanism.** The fix passes `(hit >> 16) & ~3`, the same as the door path. The drawer's
  `& 31` then leaves **8 possible start columns per cell**, and the blit still copies 4
  adjacent texels per 4-px column. At 1 cell a cell is about 415 px (104 columns) wide, so
  each 4-texel slice is repeated about 13 times. Close up you get vertical combs with streaks.
  Even mapped exactly, one copy of the texture per cell would turn the bricks into slabs about
  7:1 wide. The wall textures are 32×300 and are
  drawn as tiling wallpaper: bricks, hedge, mosaic. They were tuned for the
  Original's 1:1 horizontal scale.
- **Class: side effect of the Corrigida fix** (J4's granularity plus the dword blit). The
  Corrigida looks worse than the Original from 1 to 3 cells.

### C. Doors: repeated 4-px slices ("IIII" combs on the handle, frame and rivets)
- **Mechanism.** The same `hit & ~3` plus dword copy, on the door path: 1028:0bf3–0bf6 and
  0d15–0d18 do `AND AX,0xfffc`. A door texture is a whole door, so one copy per cell is right.
  Only the 8-step granularity and the 4-texels-per-column copy are wrong.
- **Class: Original** (and identical in both modes).

### D. Curved and stepped brick courses (a "smile" above the horizon, jumps at an angle)
- **Mechanism.** The fisheye correction itself is right. Table 4 is 22500/cos·65536 for the
  column's relative angle, and the walks return the Euclidean ray length, so
  h = 22500/(cos·dist) is the planar height. But the walks return the length as a whole
  number of units: `((line − own) * csc) >> 16`, proven against the oracle (2,000 rays).
  Rounding down by up to 1 unit inflates h by up to 1/dist: 12 % at 8 units, 50 % at 2, 100 %
  at 1. Across the screen the error is 0 in the middle and grows toward the edges, so the
  courses bend. Wherever the rounded distance changes, h jumps.
- **Class: Original.**

### E. Vertical clipping when h > 300
- **Mechanism.** The magnify path draws exactly 300 rows starting from the slice bottom. It
  skips `((h−300)>>1) + (h&1)` rows and moves the source by `300·skip/h` rows. I modelled the
  port's transcription for h = 600, 1406, 2812, 26030: the rows shown are the centre of the
  texture to within ±1 texel (h = 2812 shows rows 133..165 against an exact 134..166). The
  texture-row offset is correct.
- **The off-by-one.** `top = 42 + ((300 − h) >> 1)` rounds toward −∞, but the skip adds
  `h & 1`. So for odd h > 300 the 300 rows land on 41..340: row 41 is outside the view, and
  row 341, the view's last row, keeps the floor. At d = 1, 46 of 120 columns show floor specks
  on row 341 (30 of 120 at 1 cell).
- **Class: Original.** The blit oracle covers h = 299/300/301/302/340/399. The top
  computation is 1028:0c93–0cb7.

### F. Very small distances, overflow
- **Mechanism.** The minimum reachable distance is 1, which gives h ≈ 22500–25980. The view
  then shows 4 texture rows, each about 75 px tall: the blur in 01. The 0x65ae (26030) used
  for dist 0 would need a wall hit with `line − own` = 0, which the walks never produce for a
  wall. Every intermediate value fits: h < 32768 as i16, `300·skip` ≤ 3.9 M, and the 32-bit
  offsets. There is **no overflow and no fault**, only extreme magnification.
- **Class: Original.** The real cause is that the movement code lets the player stand 1 unit
  from a wall face.

### G. Shading
k = min(3, dist >> 6) per column. All of a close wall is k = 0. A long oblique wall changes
shade in hard vertical steps at 2/4/6 cells. **Original**, by design (4 palette copies). Not an
up-close issue.

### H. Sprites (J5 and related)
J5 is a crash, not a texture artefact: a magnified sprite whose top is on row 478. It is
already fixed by `jardim_sprite_last_rows`. Two related original traits, from the code and
docs, not reproduced here:
- Sprites are not shaded, so they look brighter than the walls behind them beyond 2 cells.
- Sprites are placed by the planar projection (240·lateral/(d·tan 30°)), but wall columns are
  0.5° apart. The `g_columnDepth` occlusion can therefore be off by about 2 columns (≈9 px)
  half-way to the screen edge.

**Original.** I suggest leaving both alone.

### Port bugs
None found. `drawColumn` matches 1028:0951 (height `MOV AX,DX; CWD`, top, cell clamp, the
wall/door arguments). The drawers match 482c. The blits, walks and tables are all proven
against the original by emulation, and those tests pass.

## The fixes (Corrigida)

1. **Texture column per pixel** (`jardim_texture_per_pixel`, A–C): u = the 16.16 hit × tiling,
   & 31; tiling 4 for walls (1–6), 1 for doors (7–12); each of the 4 pixels its own u, interpolated
   between this ray's hit and the next column's (extrapolated from the previous one at a plane's
   edge). A fix-only blit gathers 4 bytes per row with 1000:0024's row stepping.
2. **Exact height** (`jardim_wall_height_exact`, D): table 4 / the unshifted 16.16 length, in i64.
3. **Odd-height row** (`jardim_wall_odd_height_row`, E): the top one row lower for an odd h > 300.
4. **Minimum distance** (`jardim_wall_margin`, F's cause): at least 8 units from every wall face.

Checked with `--dump` at ¼, ½, 1 and 3 cells, square and at 30°, Original against the fixes: the
bricks keep the Original's size at 1–3 cells and stay on the walls; at ¼ cell they are magnified
bricks instead of 1-px stripes; the courses are straight; doors show their frame, handle and rivets
once.

## The far wall (the end of a long corridor)

The owner's report: "at the end of the corridor the wall texture looks broken" (a grey, grainy block). It
is not a wrong cell, a wrong texture or an overflow: the block is the stone texture (cells `5`, `6`:
texture 2 of `paredesN.bmp`, four palette entries of light grey) drawn right.

- **The cell and texture.** In the frame (map 1, row 3 looking −x from column 13: `raycast.zig`'s walk
  returns cell 6, 400 units away) the end wall is a `6`, texture (6+1)/2 − 1 = 2, the stone. The
  shading steps (`min(3, dist >> 6)` = 3 at 400 units) add 0x45 to the entry and land on the darkest
  of the four grey copies; the rows and columns are the right ones.
- **The distance.** 400 units is h = 22500/400 = 56 px; the whole-unit rounding
  is 0.25 % at that distance. Nothing overflows: the distances that overflow are the 1-unit ones
  (F above).
- **What is wrong is the minification.** The texture is 32 × 300 texels of high-frequency noise,
  tuned for one texel per screen pixel. At 12.5 cells the wall is 34 px wide and 56 px tall: with the
  4-times-a-cell tiling (`jardim_texture_per_pixel`) a pixel spans about 4 texels across and 5 down,
  and the original's nearest-row/column sampling keeps one of them at random. A noise texture sampled
  one texel in twenty is static; it also flickers while walking. The hedge walls do the same,
  but their dark green hides it (at the grazing angles of the corridor's sides it shows as comb stripes).
- **Fix** (`jardim_raycaster`): the wall textures are box-filtered into mip levels per axis (a 2^i × 2^j
  average, each result snapped to the texture's own palette entries, because the picture is 8-bit and the
  wall shading adds a fixed step to the entry) and the level is chosen from the texels a pixel spans
  (across the wall: from the ray's angle to the wall; down: 300 / the slice's height). The far stone is
  one grey with a few speckles; up close the texture is untouched (level 0 until a pixel spans 2 texels).

The Corrigida's earlier wall fixes (`jardim_texture_per_pixel`, `jardim_wall_height_exact`,
`jardim_wall_odd_height_row`) are replaced by the raycaster when it is on: it computes the exact height,
the exact column and the clipping itself (DESIGN.md "The raycaster"). They remain for the 1995 renderer.
