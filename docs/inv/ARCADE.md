# INV's arcade rules: the numbers and where they come from

The Corrigida's INV (`Fixes.inv_arcade_rules`, `inv_clean_render`, `inv_controls_screen`; `--fix all`) plays
**Taito's 1978 Space Invaders** on INV's own art and sounds. This file is the research: what the arcade does,
with the address in its program, and what we do with it on a 640 x 480 screen whose invaders are 88 px wide.
How the game plays is GAME.md "Arcade rules (Corrigida)"; the code is DESIGN.md "Arcade rules (Corrigida)".

## Sources

1. **Computer Archeology, "Space Invaders" (Code)**, the annotated disassembly of the arcade's 8080 program,
   <https://www.computerarcheology.com/Arcade/SpaceInvaders/Code.html> (with its RAM-use page). Every
   `0xxx`/`1xxx` address below is from it; its comments are quoted where they say what the code is for. The
   routines that matter were read (the interrupt routines, the game objects, the shot handlers, the saucer, the
   shield and drawing routines, the data tables). The tables below are copied byte for byte from it (`ColFireTable` 1D00,
   `SaucerScrTab` 1D54, `ShieldImage` 1D20, `ShotExploding` 1C91, `AShotExplo` 1CDC, `AlienScores` 1DA0,
   `AReloadScoreTab` 1CB8 and 1AA1).
2. For the saucer's score rule (the 8th shot, the 23rd, then every 15th is worth 300) the Atari Compendium's
   arcade Space Invaders page and the players' guides ("the Furrer trick": count 22 shots, then fire at the
   saucer, then count 14) agree with the table in (1): the pointer advances once per shot and wraps after 15.
3. The screen and the hardware: the 8080 board draws a 224 x 256 picture (the monitor on its side) at 60 Hz
   with two interrupts a frame (the middle of the screen, `0008`, and the end of it, `0010`).

The arcade's own pixel is the unit of its tables; `x` is across the 224-px screen, `y` up it from the bottom
(256 px). Its coordinates in the listing are offset by 32 in `x` (the video RAM starts at 0x2400, 32 lines
into the 0x2000 pixel space): the rack's first `x` 0x38 is 24 on screen.

## What a frame is

| Arcade | Ours |
|---|---|
| 60 frames a second, two interrupts each. The game objects run in both (an object works in the interrupt that is not drawing its half of the screen: no flicker), the player only in the end-of-screen one (`007B`), the alien cursor in the middle one (`00AB`). | `sim.frame()` is one frame; `driver.zig` runs `elapsed * 60 / 1000` of them a tick (a 16-ms timer, at most 6 a tick), so the speeds hold whatever the timer's jitter. The picture is drawn at the display rate between the frames (what moves smoothly is shown from where it was a frame ago to where it is). |

## The rack

| What | Arcade | Ours |
|---|---|---|
| Invaders | 55: 11 x 5, 16-px pitch both ways (`01C0`, `017A`) | **20: 4 x 5**, pitch 108 x 38 (art: 88 x 34 cell in `MOVEIN.BMP`). See "Four columns" |
| The march | one invader a frame, bottom row left to right, then the next row up; dead ones are skipped (`0141`); when the cursor wraps, the reference (bottom left) invader moves (`01A1`) and the picture toggles (two pictures). A full step therefore takes as many frames as there are invaders left: **the whole rack speeds up as they die** | the same speed, moved **as one block** (`Sim.updateRack`): every frame the whole rack advances 6 px / invaders left (sub-pixel, 24.8), so with 20 left a step is 20 frames (a third of a second), with 1 left 6 px a frame. All invaders share one picture, toggled each time the rack has moved a step but never oftener than every 8 frames. Why not the ripple: with the 1995 art's big two-pose sprites, one invader jumping 6 px and flipping its pose every frame reads as flicker; drawn between frames, the block moves smoothly |
| Step | 2 px (`1B08`); 3 px going right with one invader left (`18F1`) | 6 px (2 x 2.857, the width ratio); 9 px for the lone invader going right |
| The last invader | 2 or 3 px a frame: 120 or 180 px/s on a screen of 224 | 6 or 9 px a frame: 360 or 540 px/s on 640. Crosses the screen in 1.8 or 1.2 s as the arcade's does in 1.9 or 1.25 |
| Turn | a lit pixel on the wall's column (x = 9 left, 213 right: `RackBump` `1597`) flips the direction at once; **the drop (8 px, `1B0E`) comes with the next move of the reference invader** | the visible part of an invader at x = 6 or 634 (`checkWalls`); the whole rack turns at once and takes the drop at once (no ripple), sideways motion paused meanwhile |
| Drop | 8 px = one sprite height (half the 16-px row); **10 drops** from the start (y 0x78 = 120) to the invasion line (y < 0x28 = 40, `016B`) | **16 px, taken 2 px a frame**, 10 drops from the start (row 0 at y 194, bottom 228) to the line (cannon's top, 380) |
| Invasion | an invader placed below y 0x28 kills the player (`016D`: the game is over, whatever the ships left) | an invader placed with its bottom on or below y 380 is a landing: the cannon blows up and the game is lost (all lives) |
| A kill | the rack stands still 16 frames while the invader bursts (`0105`, `152C`) | the same: 16 frames (the `NABOOM1.BMP` strip, 8 frames of 2) |
| The rack stands | while the player blows up (`0141`) | the same |
| Starts | `1DA3`: the next racks start lower (60, 50, 48, 48, 48, 40, 40, 40) | not used: one wave |

**Four columns.** The art decides. An invader is 88 x 34 on a 640 px screen, 14 % of its width; the arcade's is
12 of 224, 5 %. Eleven columns would be 968 px. Six (the most that would fit, 576 px) leave 32 px each side for
the turn, the cannon's walls and the bunkers. Four are the original's, leave 106 px each way (35 steps of a
sweep, the arcade's rack has about 16), and show the five invader pictures. The arcade's bomb tables are for 11
columns and are mapped onto 4 (see "Bombs"). The first thing to overrule if the owner wants a bigger rack.

## The cannon and its shot

| What | Arcade | Ours |
|---|---|---|
| Speed | 1 px a frame (`0381`, `038E`), x from 0x30 to 0xD9: 169 px in 2.8 s | **3 px a frame** (180 px/s), x from 24 to 551: 527 px in 2.9 s. Constant, no steps; the last arrow pressed wins when both are held |
| Starts | at the left (`1B1B`: 0x30), and again after each death (`02B9`) | the same (x 24) |
| Shot | **one at a time** (`162A`); 4 px a frame (`1B2C`); starts at the cannon's middle (`03FF`: +8); ends at y 0xD8 (40 from the top, `14E4`) with a burst of 10 frames (`1B26`) | one at a time; **7 px a frame** (420 px/s: from the cannon to the top in 0.74 s, as the arcade's 176 px at 240 px/s); starts at the barrel's tip; ends at y 2 with a burst of 10 frames (`BOMTIR.BMP`) |
| Fire button | a button still down when the last shot ends does not fire again; it must be released and pressed (`fireBounce`, `1632`-`1651`) | the same; a tap shorter than a frame still counts (the driver) |
| A hit on an invader | the shot waits for the invader's burst (status 5, `1512`): 16 frames, then it counts as ended | the same |
| Death | 12 changes of the 2 blow-up pictures, 5 frames each (`1B16`, `1B17`): 60 frames; the rack stands (`0141`) and the alien shots may not start for another 0x30 = 48 frames (`02A1`) | **60 frames** of the 7 `BROCHA.BMP` pictures (6 frames each, the last held); everything stands; then the cannon is back at the left, the bombs and the shot are gone, **48 frames** with no new bomb |
| Ships | 3 to 6 by the DIP switches (`08D1`); extra ship at 1500 or 1000 (`093D`) | 3; no extra ship (1500 x 10 is out of a wave's reach) |

## The bombs

Three alien shots exist, one object each: the **rolling** shot (aimed at the player), the **plunger** and the
**squiggly** (they fall from the columns of a table); the squiggly's object is also the saucer's.

| What | Arcade | Ours |
|---|---|---|
| Speed | 4 px (`1B7E`: 0xFC) every 3 frames: the three objects take their turns on three frames (`0072`: the rolling shot's timer syncs the others), and an object moves only in the interrupt that is not drawing it; 5 px with fewer than 9 invaders left (`SpeedShots`, `08D8`) | **7 px every 3 frames** (2.33 px a frame, 140 px/s; the field is 1.76 times as tall); 8.75 per 3 (175 px/s) with fewer than 4 invaders left (9 of 55, scaled) |
| Ratio to the cannon | bomb 80 px/s : cannon 60 px/s : shot 240 px/s | bomb 140 : cannon 180 : shot 420 |
| Which column | rolling: the rack column over the player's middle (`061B`, `FindColumn`), the last one if beyond; plunger: `ColFireTable` from index 0 to 15; squiggly: index 6 to 20 (`1D00`: 01 07 01 01 01 04 0B 01 06 03 01 01 0B 09 02 08 02 0B 04 07 0A), each type keeping its place, wrapping; a column with no invader left fires nothing that turn (the entry is used) | rolling: the column over the cannon's middle (clamped to 0..3); the tables are the arcade's, **column c (1..11) is our column (c-1) * 4 / 11** (1-3 -> 0, 4-6 -> 1, 7-9 -> 2, 10-11 -> 3), the pointers and wraps are the arcade's. The bomb leaves the lowest invader of the column (`FindInColumn`, `062F`) |
| The first turns | the rolling shot lets its first turn after each burst pass (`0480`); the plunger does not fall with one invader left (`04B7`) | the same |
| How many fall | a bomb may start only when each of the other two has taken more than **the reload rate** steps, or none (`057C`-`0595`). The rate is looked up from the score's hundreds (`AShotReloadRate`, `170E`; tables `1CB8`: 02 10 20 30 and `1AA1`: 30 10 0B 08 07): score under 300 -> **48** steps (so one at a time: a shot never lives that long), under 1100 -> 16, under 2100 -> 11, under 3100 -> 8, else 7 | the same rule with the steps counted in 3-frame steps. Score thresholds **scaled by 20/55** (our wave is 20 invaders of the arcade's 55): 108, 399, 763, 1127 arcade points (`reloadRate`). A wave is worth 360 of them: one bomb at a time for the first 30 % of it, then up to three |
| Hitting the cannon | the shot's y between 0x1E and 0x27 and a pixel collision (`0603`-`060F`) | the bomb's box (10 px) meets a pixel row of the cannon's art (`cannon_art`: its barrel is narrow, a bomb passes beside it) |
| Ground | ends at y 0x15 (`05F6`), the burst takes 3 more turns (`0644`) | ends at the ground line (y 452); the burst takes 9 frames (`BOMTIR.BMP`) |
| Shot meets bomb | the pixels meet: the player's shot finds no invader where it hit and bursts (`1530`), the bomb meets the burst | **both burst** (nearly always the arcade's outcome; the exception depends on which one moved into the other) |

## The saucer

| What | Arcade | Ours |
|---|---|---|
| When | a timer counts 0x600 = 1536 frames (25.6 s, `0921`) once the rack has dropped at least once (y < 0x78, `0916`), and flags a saucer; it comes when there are 8 invaders or more (`069E`) and no squiggly shot is falling (the object is shared, `0691`) | **0x300 = 768 frames (12.8 s)**, half of it (a wave of ours lasts a third of the arcade's: the first one comes about 20 s into a game, a second about 33 s); 3 invaders or more (8 of 55 scaled), no squiggly bomb falling |
| Flight | 2 px every 3 frames (40 px/s): from x 0x29 right or from x 0xE0 left, ends at x < 0x28 or >= 0xE1 (`0465`, `06CB`); direction by the shot count's low bit (the listing's comment: odd goes left to right; the code reads a ROM byte at an address made of it) | 1.9 px a frame (114 px/s, the width ratio 2.857 over the arcade's); x 8 to 571; by the shot count's low bit: odd left to right |
| Score | `SaucerScrTab` `1D54` (x 10): 100 50 50 100 150 100 100 50 **300** 100 100 100 50 150 100 (+ a 16th, 50, never used: the pointer wraps at 15, the bug at `044C`). The pointer advances at every shot's end, hit or miss (`0447`); the score is read when the saucer's burst shows it (`0711`) | the same table, the pointer advanced by `endShot` (and for a shot lost to a death). **The 300 comes with the 8th shot, the 23rd, the 38th ...** (the famous rule) |
| Hit | the burst on the saucer (0x20 frames), the score drawn at its place and added 8 frames after the hit (`06DE`, `06E5`) | `EXPLOD.BMP` (8 frames of 4) with the score on it, added 8 frames after the hit |

## Scoring and the end

| What | Arcade | Ours |
|---|---|---|
| An invader | by row from the bottom: 10, 10, 20, 20, 30 (`AlienScoreValue` `097C`, `1DA0`) | **x 10**: 100, 100, 200, 200, 300 (INV's +100). A cleared rack is 3600 (the original's was 2000) |
| The saucer | 50 to 300 | **x 10**: 500, 1000, 1500, 3000 (the original's flat 500 is the 50 here) |
| A bomb hit | no points | **-500** (the original's rule, kept: INV's score reaches NOITE, a loss costs) |
| The wave | clearing the rack starts the next, lower (`09EF`) | clearing it **wins**: WM_DESTROY with 0xffff (the original's result) after 30 frames |
| The loss | the last ship, or an invasion | the last cannon, or a landing: WM_DESTROY with 0, the score |
| Result to NOITE | | 0x40a with the won flag and `g_score`, as the original's; a closed window or Esc reports a loss with the score at that moment |

## The bunkers

| What | Arcade | Ours |
|---|---|---|
| Shape | `ShieldImage` (`1D20`): 22 columns of 16 pixels, the top corners cut at 45 degrees, a notch 4 deep with sloped sides in the bottom (294 lit pixels) | the same bytes, each pixel a **3 x 3 px block** drawn in a green of INV's palette (no art for a bunker on the disc): 66 x 48 px |
| Where | four, 45 px apart (22 wide), centred; 8 px above the cannon (`0224`: 0x2806, +45) | four, 128 px apart, centred (x 95, 223, 351, 479), 20 px above the cannon's top (y 312) |
| A shot hits | the 8 x 8 picture `ShotExploding` (`1C91`: 99 3C 7E 3D BC 3E 7C 99) is drawn at the shot's (x - 2, y - 3) and erased again (`03EB`-`03F0`, `EndOfBlowup`): the pixels of the picture are **cleared** from what is under it, the bunker's | the same picture clears the same blocks, placed 6 rows below the first block the shot touched, 2 columns left of its middle (a bite from below, two rows deep) |
| A bomb hits | its own 3 x 7 pixels are erased, then the 6 x 8 picture `AShotExplo` (`1CDC`: 4A 15 BE 3F 5E 25) at (x - 2, y - 2) (`0657`-`065E`) | the bomb's footprint is cleared, then the picture 2 rows below the bomb's foot, 2 columns left of its middle (a pit from above, about three rows deep) |
| The rack | an invader on a bunker erases it where it stands (it is drawn over it) | the same: the visible part of an invader clears the blocks it covers when the rack is placed each frame |

## What is not taken

Two players, credits, the attract mode and the splash screens, the DIP switches (ships 3-6, the extra ship at
1000 or 1500), the cocktail table, the tilt, the high score, the fleet's four-tone beat (INV has one march
sound: it plays on each march, no oftener than 7 times a second), the saucer's looped sound (INV's `nave.wav`
plays once at launch), the second and later racks and their lower starts, the arcade's colour overlay.

## What the owner may overrule

| Choice | Now | Where |
|---|---|---|
| Invaders | 4 x 5 = 20 | `sim.cols`, `pitch_x`, `rack_x0` |
| Waves | one; clearing it is the win | `Sim.playFrame` |
| Score scale | arcade x 10: a rack 3600, saucer 500-3000 | `sim.score_scale` |
| A hit costs | 500 (the original's) | `sim.hit_penalty` |
| The saucer's timer | 768 frames (arcade 1536) | `sim.saucer_period` |
| The reload tiers | scaled by 20/55 | `sim.reloadRate` |
| Bunkers | procedural 3-px blocks, green | `bunker.zig`, `view.zig` |
| Lives | 3, no extra | `Sim.lives` |
| A shot and a bomb that meet | both burst | `updateShot` |
| The cannon starts, and returns, at the left | the arcade's | `Sim.dyingFrame` |
