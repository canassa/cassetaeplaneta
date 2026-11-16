# Mortal Kombat 3 mechanics, from the leaked UMK3 source

Research notes for the Zig fighting-game engine. Every number is tagged
**[V]** (verified from source: file + function), **[V*]** (verified structure, an
operand count unknown) or **[A]** (approximated, with the reason).

## 0. What the source actually is, and what is missing

- The repo (`ArchivesML/UMK3-3DO-src`, cloned to `zig-out/umk3-src/`; `docs/fights/EASY_AI.md` section 1.1 calls it 3DO, as the repo does) is sold as "3DO",
  but the code is the **Sony PlayStation port** by Williams Entertainment
  (`SYSTEM.H:17 #define SONY_PSX 1`, libgpu, `PadRead`, `psxcd_*`, `VSyncCallback`).
  No 3DO code exists in it. It is a C translation of the arcade 68K/TMS34010-style
  assembly, so the logic (process scheduler, `act_mframew`, `strike_check`, drone AI)
  is the arcade's. Constants are written in **arcade units wrapped in `SCX()/SCY()`**
  (`SYSTEM.H:116-121`, `SCF_X 80`, `SCF_Y 85`): `SCX(v) = 0.8*v`, `SCY(v) = 0.85*v`.
  The arcade screen is therefore **400 x 254**, the PSX buffer 320 x 240
  (`MKSONY.H:98-99`, `SCRRGT = BUFFER_WIDTH-1`). All numbers below are given in
  **arcade units** (what you read in the source once you drop the `SCX/SCY` wrapper).
- **Missing from the repo** (they were separate `.S`/data files): the per-character
  strike tables (`strike_tables`, hit boxes, **per-move damage, block damage, flags,
  reaction index**, declared `MKUTIL.H:172`), the combo tables (`ct_*`, `mkcombo.s`),
  all animation scripts (frame counts / frame images), the stage headers
  (`left_edge/right_edge`, `ground_y`, scroll tables) and the button/AI tables in
  assembly. So **per-move damage and exact frame data cannot be verified**. What the
  source does give: the *timing structure* of every move (ticks per animation
  frame, hit-check windows, hold-on-hit sleeps), all reaction velocities, block
  stun, throws, AI logic and probabilities. The number of animation frames per part
  is unknown, so startup/recovery are expressed as `n x ticks` and then **[A]**.

## 1. Time and space units

| Item | Value | Source |
|---|---|---|
| Game tick | `process_sleep(1)` = one main-loop iteration = one `process_dispatch()` pass. `ONE_SECOND = 55` ticks/s (arcade rate, 54.8 Hz) | `MKUTIL.H:19`, `MKOS.C:350-410`, `MKINIT.C` main loop **[V]** |
| PSX build | Loop waits for a vblank each pass (`while(irq_timer==0)`, `MKINIT.C:469`), so it steps at the display rate: **60 ticks/s NTSC** (`tick = irq_tick*55/60`, `MKSONY.C:230`, only normalises the *clock* counter). The PSX therefore plays about 9% faster than the arcade. | **[V]** |
| Position / velocity | 16.16 fixed (`POS`, `MKBKGD.H:178-182`). Velocity is added to position **once per tick**; gravity is added to Y velocity once per tick (`gravity_n_bounds`, `MKOBJ.C:568-590`; position update `MKOBJ.C:262-263`). Order each tick: processes run, `vy += g`, `y += vy`. | **[V]** |
| Source velocity literal | `0x40000` = 4.0 px/tick; `0x8000` = 0.5 px/tick^2 (arcade px) | **[V]** |

Recommended canonical tick: **55 Hz** (arcade). If the engine is fixed at 60 Hz, use the
per-tick numbers unchanged and accept the same +9% speed as the PSX port, or multiply
all per-second values by 55/60. All "ticks" below are source ticks; seconds use /55.

### Fighter sizes (arcade px, playfield 400 x 254)

| Item | Value | Source |
|---|---|---|
| Standing height | **144** (Kano; the roster 136-158: Sonya 143, Sub-Zero 142, Kang 139, Kitana/Jade/Mileena 139, Shang Tsung 136, Jax and She-Goro 158, Motaro 170, Kahn 173) | `ochar_ground_offsets[]`, `MKGUYS.C:114`: `ground_ochar` puts the object at `ground_y - offset` (`MKGUYS.C:694`), so the offset is the stance's extent from the object's origin to the floor. **[V*]**: the offset is the height if the origin is the top of the stance image, as it is for these multipart sprites; the wrapper `SCY()` is dropped, the `-2/-3` are the PSX's own pixels |
| Standing, as the code tells it | taller than 128 | `get_my_height() > SCY(0x80)` picks `ANIM_HITLO` over `ANIM_DUCKHIT`, `MKREACT.C:1428-1508` **[V]** |
| Crouching height | at most 96 (`<= 0x60`: "not standing"), "short" below 103 | `MKJOY.C:333`, `am_i_short` `MKUTIL.C:906` **[V]**; so crouch / stand is about 0.67 |
| Ground line | not in the source: `ground_y` is read from each stage module's header (`MKBKGD.C:270`), which is missing. About 88% of the playfield down (feet near y 224 of 254) **[A]**, from the arcade's pictures | |
| Jump apex over standing height | 95 / 144 = 0.66 in MK3 (of the object origin, the head line of the stance; the port's arc is at `SY`: 1.0); the tucked flip then reaches about 1.8 x standing | computed from the two **[V]**; the flip from the owner's MK3 screenshot, section 3 "Where the figure hangs in the air" |

The arcade's pixels are not square: the 400 x 254 frame was shown on a 4:3 monitor (about 1.18 taller than wide;
Fabien Sanglard's Midway T-Unit notes, [fabiensanglard.net/nbajamte](https://fabiensanglard.net/nbajamte/);
MAME's 400x254 raster, [mametesters.org/view.php?id=6700](https://mametesters.org/view.php?id=6700)). We ignore that and scale
x and y alike.

### Conversion to the 640 x 480 screen

- Reference width **400 arcade px** (verified: `SCRRGT` 319 = 400*0.8-1; `SCREEN_DISTANCE` etc. are < 400). The engine uses
  one scale **`S = 1.25` screen px per arcade px** (`tables.S`), **uniformly in X and Y** (the PSX's .80/.85 is not
  used). So a 640-px screen shows 512 arcade px of width, a fighter stands 144 x 1.25 = **180 px**, a crouching one
  about 120. **Vertical arcs** (the jump, gravity, the air-hit pop) use a second scale, **`SY = 480/254 = 1.89`**
  (`tables.SY`, `tables.fy`): MK3's 254-line playfield on our 480 lines, so a jump rises the same share of the screen
  as MK3's (the owner found the jump at `S` too low): the apex is 95 x 1.89 = **180 px**, one standing height, and the head
  line at the top of a jump is 360 px over the floor. Airtime (39 ticks) does not change with the scale.
  The 1.25 is a choice, not MK3's: MK3's own proportions fix only the ratios. At `S = 1.6` (the first version; 400 arcade
  px to a 640 screen) a fighter would be 230 px of 480 and a jump's head would touch the HUD bar; the owner found the
  characters too big. 1.25 also makes every per-tick number an exact multiple of 1/256 px (gravity 160, jump
  velocity 3200, jump vx 1280).
- `px = arcade_px * S`; `px/tick = arcade_px/tick * S`; `px/s = arcade_px/tick * S * 55`; `px/s^2 = arcade_px/tick^2 * S * 55^2`.
- Gravity 0.5 arcade px/tick^2 = 0.625 px/tick^2 (1891 px/s^2 at 55 ticks/s).

## 2. Ground movement

| Mechanic | Arcade units | 640 px | Source / tag |
|---|---|---|---|
| Walk forward (per character) | 3.0 / 3.125 / 3.25 / 3.5 px/tick, e.g. Kano 3.5, Sonya/Jax/Swat/Tusk/SG 3.0, Kang/ST 3.125, most others 3.25, Noob/SK 5.0, Motaro/old Smoke 4.0 | 3.75 / 3.9 / 4.06 / 4.4 px/tick (S = 1.25) = 206-241 px/s | `get_walk_info_f`, `MKGUYS.C:850-890` (`short <<4` makes `0x3800` = 3.5) **[V]** |
| Walk backward | 2.25 px/tick for nearly everyone (old Smoke 2.5, Noob 3.0) | 2.8 px/tick = 155 px/s | `get_walk_info_b`, `MKGUYS.C:910-950` **[V]** |
| Walk anim speed | 5 ticks/frame (SK 3) | | same **[V]** |
| Run (forward only, run button) | 8.0 px/tick (`0x80000`), no air boost | 10 px/tick = 550 px/s | `run_setup`, `MKJOY.C:2394-2430`; run needs the run button held, `turbo > 0`, and direction **toward** the opponent (`MKJOY.C:392-410`) **[V]** |
| Run fuel ("turbo bar") | `FULL_TURBO = 0x30 = 48` ticks of running; -1 per run tick; recharge +1/tick after `TURBO_RAISE_DELAY = 40` ticks idle; a jab/air-punch hit zeroes the attacker's bar | 48 ticks = 0.87 s ~ 384 arcade px = 614 px | `MKSCORE.H:28`, `MKJOY.H:127`, `reduce_turbo_bar` `MKJOY.C:2470`, `MKINIT.C:535-545` **[V]** |
| Crouch | Down: `do_duck` = `act_mframew(ACT_DUCK,2)`, 2 ticks per frame, **buttons disabled** during it; then `bt_duck` buttons (uppercut/duck punch/duck blocks/duck kicks). Stand up: `backwards_ani(2,ANIM_DUCK)` 2 ticks/frame, buttons disabled. | frames unknown: **~3 frames -> ~6 ticks each way [A]** | `MKJOY.C:1361-1385`, `bt_duck` `MKJOY.C:66` **[V*]** |
| Movement during attacks | Ground attacks call `stop_me()` first (xvel = 0). Walking/blocking are mutually exclusive: block calls `stop_me`. | | `MKJOY.C:690`, `do_block_hi` `MKSTAT.C:2046` **[V]** |
| Turn around | Ground states check `am_i_facing_him()` every tick; if wrong -> `turn_around`: `mframew(2)` (2 ticks/frame), buttons disabled. | ~2 frames -> ~4 ticks **[A]** | `MKJOY.C:310`, `MKSTAT.C:2069` **[V*]** |

## 3. Jumping

Input: Up = straight jump (`do_jump_up`); Up+Forward/Back = angle jump ("flip", `do_flip`).
Both use the **same Y launch**; velocity is set once, **no air control** (nothing in the air
reads the stick). Run does not extend jumps (`f_superjumps` is a cheat flag, `MKJOY.C:1425`).

| Quantity | Arcade | 640 px | Source |
|---|---|---|---|
| Initial Y velocity | -10 px/tick (`UP_VEL = -0xa0000`) | -18.9 px/tick (SY = 1.89) | `MOVES.H:22-23`, `do_jump_up` `MKSTAT.C:2591`, `do_flip` `flight_call(...,-SCY(0xa0000),SCY(0x8000),3,..)` `MKJOY.C:1450` **[V]** |
| Gravity | 0.5 px/tick^2 (`0x8000`) | 0.625 px/tick^2 | same **[V]** |
| Horizontal velocity | straight 0; forward or back angle jump **+/-4.0 px/tick** (`0x40000`), identical forward and back | 5 px/tick = 275 px/s | `MKJOY.C:641-650` **[V]** |
| Airtime | **39 ticks** (landing when `y >= ground`, exact zero at tick 39) = 0.71 s at 55 Hz, 0.65 s at 60 Hz (computed from the integration order above) | | `flight_call` `MKUTIL.C:2682-2720` **[V]** |
| Peak height | **95 px** (ticks 19-20) | 180 px (SY) | computed **[V]** |
| Jump distance (angle jump) | 39 x 4 = **156 px** | 195 px | computed **[V]** |
| Landing | `jump_up_land_jsrp`: `ACT_LAND`, two 3-tick frames (6 ticks); **buttons are re-enabled immediately** (`allow_moves`), so a new attack can start during landing; opponent cannot be thrown while you are in `ACT_LAND` | | `MKSTAT.C:2621-2650`, `toss_check` `MKJOY.C:2159` **[V]** |
| Air block | none: `is_he_blocking` returns false if the defender is airborne | | `MKUTIL.C:565` **[V]** |

**Jump-in attacks.** Straight jump: `bt_jump` maps HP/LP to jump punch (strike table 9),
HK/LK to jump kick (0xa). Angle jump: `bt_angle_jump` maps punches to flip punch (0xc), kicks to
flip kick (0xb) (`MKJOY.C:52-110`, `MKSTAT.C:2153-2310`). Attack runs `air_strike`: 3 ticks per
animation frame, hit checks during the **first 15 (punch) / 16 (kick) ticks after the first animation
part finishes**, then no more hits that jump. On a hit: `combo_air_pause(8)` (attacker freezes 8 ticks in
the air) then falls with gravity 0.4375 (straight) / 0.375 (angle). Attacks stop being allowed when within 20 px of the
ground on the way down (`angle_jump_call`, `MKJOY.C:1488`). Defender takes `r_flip_kick`/`r_flip_punch`
(see 6). Hit boxes: not in source **[A]**.

### Where the figure hangs in the air

MK3 places an object by its **origin**, which for a fighter is the **top of the stance**, not the feet: `ground_ochar` sets
`oypos = ground_y - ochar_ground_offsets[ochar]` (`MKGUYS.C:114, 686-696`, Kano 0x90-2 = 142; the offset is the distance from
the origin down to the floor), and `p_ganiy` is that ground-level origin y (`ground_player`, `MKANI.H:127`; `MKJOY.C:254`). Every animation
frame is drawn relative to the origin by its own table entry (`frame->anixoff/aniyoff`, `MKANI.C:337-349`; the entries are in the
image tables, not in the source), so the frame's offset is what keeps the feet on the floor in a stance, a crouch or a walk.
A jump does not touch it: `flight_call` (`MKUTIL.C:2682-2765`) only integrates the origin (`oyvel`, `ograv`; the loop ends when
`oypos >= p_ganiy`, i.e. the origin is back at the stance height), `do_jump_up` / `do_flip` just switch animation (`get_char_ani`,
`MKSTAT.C:2591`), and `hit_ground_yet` compares `oypos + osize.ypos` with `p_ganiy - 8` (`MKUTIL.C:2255`). So in the air **the
origin, the head line, rises by the arc (95 arcade px) and the frames hang from it**: a stand-height frame has its top at
standing height + arc (0.66), and a frame shorter than the stance (the tuck of a flip, drawn around the body's centre in MK3's own
art) keeps hanging from that line, not from the feet. The owner's MK3 screenshot (Kano at the top of an angle jump over a
standing Sub-Zero, 240-line picture): Sub-Zero 116 px, the ball's bottom about 164 px (1.4 x standing) and its top about 211 px
(1.8 x standing) over the floor; the ball is about 47 px tall, so its centre is at about the origin's height (stand + 0.66 stand =
1.66 x; the ball's centre 1.6 x). It is entirely above the opponent's head: a jump over him clears him by 0.4 x his height.

What the port does (`sim.airLift`, `tables.air_ramp`, `air_tuck`): the pack's frames are feet-anchored (section 11), so in the air
(origin above the floor) each frame is lifted by `(stand - frame's body height) x 1.3` (a stand-height frame: 0, its top at the head
line; a tuck 55 source px tall of the stance's 104 rises 64 source px (110 screen px at 1.73 each): its top at the head line + 0.3 of the missing
height, as the screenshot), eased in over the first 100 px of the rise (the feet anchor on the floor, so take-off and landing do
not pop), a frame taller than the stance hangs from the head line (feet lower, never under the floor). The same lift moves the
hurt and hit boxes (`Sim.lift`, `toWorld`) and the picture (`match.view`), so a jump-over, an air hit and the side switch work on
what is drawn. The 0.3 is fitted to the one screenshot, not read from the source (the frames' offsets are not in it).

With the jump at `S` (these ratios; the port now raises the arc by `SY / S`, section 1, so the figure goes higher still): measured on SF3 Ryu at the apex (`tools/fight_mk3_jump.py` on `--headless --minigame xilindro --fix all` with the jump at 2900 ms, the
opponent standing beside; 180 px is one standing height; the floor is y 424): the angle jump's tuck is **246 px to 327 px over
the floor, 1.37 x to 1.82 x standing** (MK3: 1.4 and 1.8); before, with the feet anchored, 119 to 200 px (0.66 x to 1.11 x: the
ball barely cleared the head). The straight jump's tuck frame, 85 source px: 161 to 308 px (0.89 x to 1.71 x).
`reports/fight-mk3/mk3-jump-fixed.gif`, `mk3-jump-apex.png`.

Fighters can overlap only while one is in the air: `faceAndSeparate` (`sim.zig`, MK3's `repell`, `MKREPELL.C:114`) skips the
separation unless both are on the floor, so a jumper passes over, and on landing inside the other he is eased apart at about 5 screen
px/tick (`separate_per_tick`). Two Ryus at the same x in a picture is a jump-over, not stacking.

## 4. Attack set (input -> move -> timing structure)

Button/direction mapping verified from `joy_proc` (`MKJOY.C:279-1040`) and the `bt_*` tables.
"Tick structure" = what the code does; frame counts (`n`) are not in the source. "Strike #" is the
strike-table offset that holds hit box, damage, flags (table itself missing).

| Move | Input | Strike # | Tick structure **[V*]** | Approx total (n=2-3 frames) **[A]** |
|---|---|---|---|---|
| High punch | HP | 2 | part1 `3 x n` ticks, check hit on the tick after; `punch_sleep(5)` re-checks 5 ticks; same button again within the window chains the next punch immediately (unlimited); retract 2 parts at 3 ticks/frame | startup ~6, active 5, recovery ~12 |
| Low punch (called "med punch") | LP | 3 (repeat jabs use 2) | as above | same |
| High kick | HK | 0 | `kick2(1,..)`: part1 at **1 tick/frame**; hit check every tick for **6 ticks**; if hit hold 12 ticks; retract 3 ticks/frame | startup ~3-4, active 6, recovery ~8 (+12 hold on hit) |
| Low kick | LK | 1 | same, `ANIM_MEDKICK` | same |
| Elbow (close HP) | HP when `\|dx\| <= 0x4a = 74` and opponent grounded | 0xf | speed 1, hit checks 5 ticks; on hit combo window / sleep 10; retract 3/frame | `elbow_check` `MKJOY.C:2115` |
| Knee (close HK/LK) | HK or LK when `\|dx\| <= 74`, opponent grounded | 0xe | speed 1, 1 check; on hit sleep 15; retract `retract_strike(6)` | `knee_check` `MKJOY.C:2137` |
| Roundhouse | Back + HK | 0xd | 3 ticks/frame, 3 check ticks, hit hold 10, retract 4/frame | |
| Sweep | Back + LK | 4 | 3 ticks/frame, **1 check only**; hit hold 6 then retract 6 ticks/frame; miss retract 5 ticks/frame (`ACT_SWEEP_SD`: long punishable recovery) | `stat_do_sweep_kick` `MKSTAT.C:502` |
| Uppercut | Crouch + HP | 8 | 2 x 1-tick frames, then speed 2, 1 check; miss: sleep 10; blocked: 18; hit: waits until victim is within 80 px of the ground, min 32 ticks | `stat_do_uppercut` `MKSTAT.C:620` |
| Duck punch | Crouch + LP | 5 | speed 3, 1 check, retract 3 | `MKSTAT.C:533` |
| Duck kick high | Crouch + HK | 6 | speed 3, 5 checks; hit sleep 16 / miss 8; retract 4 | `MKSTAT.C:565`, `MKJOY.C:935` |
| Duck kick low | Crouch + LK | 7 | speed 2, 2 checks; sleep 6; retract 2 | `MKSTAT.C:592` |
| Jump punch / kick | in air | 9 / 0xa (straight), 0xc / 0xb (angle) | see 3 | |
| **Close throw** | **LP**, see below | none | `body_slam_init` + `grab_animation(3)` + sleep + `double_mframew(...)`; thrower is untouchable by the same-tick check | `MKSLAM.C` |

Per-move damage, reach, hit box height: **not in source**. Approximated reaches (centre-to-centre, arcade px),
inferred from AI thresholds (drone uses `close < 0x78=120` for sweeps/low kicks, `0x60=96` as
"punch can reach", `0x90=144` to start a jump-kick) and the 64-px fighter separation **[A]**:
LP 80, HP 88, LK 100, HK 112, sweep 104, roundhouse 120, uppercut 76, jump punch 84, jump kick 100, flip kick 110.
Hit test (verified): attacker box = fighter origin + (`sxoff`,`syoff`) with size (`sxsize`,`sysize`); defender box =
bounding box of all multipart sprite pieces (`strike_check`, `MKJOY.C:1833-1925`); an optional squeeze flag
shrinks the defender's width to 1/4 (`cbox_squeeze`, `MKJOY.C:2072`). A high attack whiffs over a crouching
defender because the defender box shrinks.

### Close throw (verified)

`JOY_LO_PUNCH` -> `toss_check(obj, 0x40)` (`MKJOY.C:793-802`, `2159-2209`). Throw happens when **all** hold:
- not a boss, `f_sans_throws == 0`, victim not `M_NOFLIP` (set during hit/block reactions),
- victim **not airborne** and not in `ACT_LAND`,
- `|dx| <= 0x40 = 64 arcade px (102 px at 640)`, and thrower faces victim,
- (human thrower) distance to the wall behind the thrower `>= CLOSE_TO_EDGE+8 = 0x68+8 = 112`,
- victim is **not holding away from the thrower** (`is_stick_away`): holding back refuses the throw -> LP falls to a normal low punch.
- Not blockable: there is no strike check; a victim that is merely holding block (not in block stun) is thrown.
- CPU victim: `toss_drone_check` reverses with `rt_drone_reverse[diff]` per mille = `{0,100,200,300,400,500,700,700,800,900}`; **0% at diff 0**.
- Damage `ochar_slam_damage[]`: **0x18 = 24 (14.5% of 166)** for all fighters except Noob/Motaro/SK-class slots (0x25 = 37). Kano air slam 0x10 = 16. (`MKSLAM.C:100-130`.)
- Timing (Kano): grab 3 ticks/frame, sleep 3, throw 4 ticks/frame, `sleep 16`, 8 ticks/frame recover. Victim flies 10 px/tick away for ~5 ticks (g 0.375), lands on back, takes the damage on landing (`thrown_by_kano`, `MKSLAM.C:548`). During any slam `f_norepell = 0x30` (48 ticks) disables fighter separation. Total ~60-90 ticks **[A]**.

## 5. Blocking (verified: `is_he_blocking`, `MKUTIL.C:546-585`; `strike_check`, `MKJOY.C:1833`)

- Dedicated **block button** (`MASK_JBLOCK`). For a human defender it is evaluated **live at the instant of the hit**,
  not from an animation: if block is held, defender is **not airborne**, and `M_NOBLOCK` is not set -> blocked. There is **no
  blocking startup**. It also applies during the defender's own recovery frames. `M_NOBLOCK` is set only by special
  moves/reactions (morphs, some flip/elbow/knee hits).
- Block held **+ Down**: blocks everything.
- Block held, standing: blocks everything **except strikes whose flags have `SF_DUCK` (bit 2, "must duck/block to block")**.
  Which strike entries carry `SF_DUCK` is in the missing table; the usual MK3 set is sweeps and low-hitting duck kicks **[A]**.
  Nothing in the game is an overhead: a crouch block stops everything blockable.
- Throws, and the strike checks with no `sdamage` hi-byte path (specials marked unblockable in `block_xfers`), are not blocked.
- CPU defender uses `p_action`: `ACT_BLOCKHI` blocks everything incl. sweeps, `ACT_BLOCKLO` same (no `SF_DUCK` check).
- **Chip damage**: each strike's `sdamage` word is `hit<<8 | block`; blocked hit deals the **low byte** through `bar_reducer`.
  **Chip cannot kill**: if `strength - chip <= 0` the block is ignored and the full hit damage and reaction are applied (`MKJOY.C:1894-1920`).
  `bar_reducer` enforces **minimum damage 1** (`MKJOY.C:2018`). Actual chip values are in the missing table; use ~10-15% of hit damage, min 1 **[A]**.
- **Block stun** (`block_shake_n_exit(scnt, sleep)` = `scnt x 2 frames x sleep` ticks, `MKREACT.C:3624`): normal `b_weak/b_hard/b_punch` = (3,2) = **12 ticks**;
  `b_sweep` (2,2) = 8; `b_lo_punch` (2,3) = 12; `b_combo_hard` (4,3) = 24; `b_combo` (3,2) = 12 (`MKREACT.C:3417-3520, 4643-4790`).
  Defender cannot be thrown during it (`M_NOFLIP`).
- **Blocked-hit pushback**: velocity set once, kept for the whole stun, then stop: `b_hard`/`b_punch`/`b_duck_hit` 2.0 px/tick x 12 = **24 px**; `b_lo_punch` 3.0 (5.0 if crouching) x 12 = 36 / 60 px; `b_combo` 3.75, `b_combo_hard` 4.75; `b_weak`, `b_sweep` 0 or `repell_one_of_us(3.0)`. 640 px: x1.6.
- Anti-wall-spam: when the defender is within `CLOSE_TO_EDGE = 104` px of the wall behind him and has taken >= N consecutive hits/blocks
  (`avoid_corner_trap`, `MKREACT.C:2111`), the **attacker** is thrown away (`ken_masters_xfer`: 7 px/tick for 10 ticks then halving). Punches: `ccp3(hold 6 HP / 5 LP, pull_away 4 / 3)` consecutive punch hits push the defender back 3 px/tick (`MKREACT.C:2364`). Blocking resets the count.

## 6. Damage, hit reactions, knockdown, juggles

- **Health bar**: `FULL_STRENGTH = 0xa6 = 166` units (`MKMAIN.H:19`). Percentages below are of 166.
- `bar_reducer` (`MKJOY.C:1971`): damage x 3/4 (`(d>>1)+(d>>2)`) against SK/Motaro/Noob; if victim has `M_HALF_DAMAGE` or `M_QUARTER_DAMAGE`
  the damage is `>>2` (the half flag is coded as a quarter in this build); `f_pN_half_damage` further halves; minimum 1.
  `M_HALF_DAMAGE` is set on a victim by flip kick/flip punch, air slams and several specials, and cleared by `back_to_normal` when he gets up (`MKUTIL.C:83`).
  This is the only juggle-scaling in the engine; hits on uppercut victims carry normal damage.
- **Per-move damage: not in source [A].** `sdamage` hi-byte = hit damage. Provide these working values (percent of 166), calibrated against the verified
  throw (24 = 14.5%), air-slam 16, `ZOOM_DAMAGE` 32, `damage_to_me(35)`, and typical arcade MK3:

  | Move | units | % bar |
  |---|---|---|
  | LP | 7 | 4 |
  | HP | 10 | 6 |
  | LK | 8 | 5 |
  | HK | 12 | 7 |
  | Elbow / knee | 10 | 6 |
  | Duck punch | 8 | 5 |
  | Duck kick H / L | 10 / 7 | 6 / 4 |
  | Sweep | 12 | 7 |
  | Uppercut | 22 | 13 |
  | Roundhouse | 18 | 11 |
  | Jump punch / kick | 13 / 15 | 8 / 9 |
  | **Throw** | **24 [V]** | **14.5 [V]** |

- **Hit reactions** (all `MKREACT.C`; velocity set via `away_x_vel`; "ticks" = frames x speed, frame counts unknown -> **[A]** assumed 2-3):

  | Hit | Reaction behaviour | Knockdown? |
  |---|---|---|
  | HP / LP (`r_hi_punch`/`r_lo_punch`, 2027-2090) | no pushback, `animate_a9(3)`; hit stun ~6-9 ticks | no |
  | HK (`r_hi_kick`, 1337) | away 4.5 px/tick for 8 ticks, then 10 ticks of damping (x(1-1/64)), then 4 ticks/frame tail: **~75 px stumble, ~26 ticks stun** | no |
  | LK (`r_lo_kick`, 1387) | away 4.0 px/tick through `animate_a9(4)`: ~30 px, ~8 ticks | no |
  | Duck punch (1418) | away 4.0, `animate_a9(3)` ~24 px | no |
  | Elbow / knee (`rek3`, 1787) | away 1.0 px/tick, 4 ticks/frame; sets `M_NOBLOCK` | no |
  | Sweep (`r_sweep`+`sweep3`, 1877-1940) | falls in place: `animate_a9(5)` + `mframew(4)` + sweepup; **~35-40 ticks** | **yes** |
  | Uppercut (`r_uppercut`, 1692) | flight x 2.0, y -12, g 0.375: **airtime 63 ticks, height 186 px, 126 px away**, then `reaction_land` (shake, 4/frame, sleep 3), getup | **yes** |
  | Roundhouse (`r_roundhouse`, 2215) | x 6.0, y -8, g 0.5: **31 ticks, 60 px high, 186 px away** | **yes** |
  | Flip kick on standing (`r_flip_kick`, `onback3`) | x 3.0, y -8, g 0.5: 31 ticks, 60 px high, sets half damage | **yes** |
  | Any hit on an **airborne** defender | `generic_airborn_hit`: x 3.5, y -6, g 0.5: **23 ticks**, 33 px high; air punch hit `r_airpunch`: x 3.0, y -6, g 0.4375: 27 ticks | **yes** (all air hits knock down) |
  | Cornered blow-through, spacing | `ken_masters_xfer`, see 5 | |

- **Knockdown -> getup**: `land_on_my_back` = `shake_on_my_back(3,1)` (~6 ticks) + sleep 4; then `gup2`: `back_to_normal` (flags cleared), getup animation at **4 ticks/frame** (`getup_speeds[] = 4`, `MKREACT.C:3723`) + sleep 2.
  Total ground time ~ **24-30 ticks [A]**. During getup a human may hold Down (becomes crouch) or Up (jumps) to cancel it. No invulnerability is coded; the loser of the round never gets up (`check_stay_down`).
- Hit counters: `p_hit` / `p_block` count hits/blocks since the defender last recovered (the AI's "repeat detection" and corner-escape both read them). Hit history of the last 6 hits per player (`p?_hitq`, `HQS = 6`) stores the attacker's action number.
- **Combos**: the chain tables are missing. The elbow/knee/hit-confirm chains exist (`process_combo_table`), and `diff < 2` disables CPU combos (`MKCOMBO.C:256`). A diff-0 CPU never chains.

## 7. Facing, separation and arena

- **Facing**: opponent is "right" when `other.x > me.x` (strict 16.16 compare, `is_he_right`, `MKUTIL.C`). Facing is **not** re-evaluated mid-air or mid-attack. It is corrected (a) instantly (`face_opponent`) at jump start, at the start of each attack, on getting hit, (b) every tick in ground idle/walk/duck/block states by `turn_around` (~2 frames x 2 ticks, buttons disabled, `MKJOY.C:310, 2069`). Jumping over an opponent therefore keeps your sprite flipped until you land; once the x order changes, the next ground tick plays the turn-around.
- **Separation**: `REPELL_DISTANCE = 64` arcade px (80 px at S = 1.25) centre-to-centre (`MKREPELL.H:19`, process `repell`, `MKREPELL.C:114`). Closer than 61 and `f_norepell == 0`: pushed apart at 3.0 px/tick each. Walking into each other: both move at **half speed** (the walker pushes the other). Fighters walking toward each other face-to-face stop (both zeroed). **No collision while vertically apart**: repel is skipped when `feet(A) - 48 < head(B)` (or vice versa), i.e. a jumper whose feet are above the defender's head + 48 px passes over (`GRACE_PIXELS = 0x30`). During throws repel is off for 48 ticks.
- **Maximum separation**: `SCREEN_DISTANCE = 0x130 = 304` px (486 px at 640) (`stuff_a6a7`, `MKREPELL.C:39-83`). Beyond it outward velocity is zeroed and positions are pulled together by half the error per tick, so the player walking away from a stationary opponent drags him. Skipped if either has `M_NOEDGE`.
- **Arena / walls**: fighters clamp to `[left_edge + 0x3a, right_edge + SCRRGT - 0x30]` = 58 px from the world's left limit and 48 px from the right (`gravity_n_bounds`, `MKOBJ.C:568`, `LEFT_PADDING/RIGHT_PADDING`, `MKOBJ.H:26-27`); outward velocity is zeroed on contact. `left_edge/right_edge` are scroll limits from each stage module (data **not in source**); the world is scrolling, wider than one screen **[A]**: use arena = 1.5 screens (600 arcade / 960 px at 640).
- **Camera** (`scroller`, `MKBKGD.C:1953`): if fighters are <= 100 px apart, keep their midpoint within +/-75 px of screen centre; otherwise keep both at least `SCROLL_GRACE_SIZE = 40` px inside the screen edges; scroll speed chosen from a table to match the faster fighter. Vertical scroll follows the highest jumper.

## 8. Round flow

- Best of 3 (`p?_matchw == 2` ends the match, `MKMAIN.C:233`). 
- **Clock**: starts at 99 (`clk_tens = clk_ones = 9`, `CLOCK_INIT_DIGIT`), decrements once per `CLOCK_SPEED = 11` x `process_sleep(3)` = **33 ticks** (0.60 s at 55 Hz, 0.55 s at 60 Hz) => full round **3267 ticks = 59.4 s** at arcade rate (`MKMAIN.C:1078-1137`, `MKMAIN.H:32-33`). 2-on-2 mode halves the speed.
- **KO**: the master loop polls `p1_bar == 0 || p2_bar == 0` every 3 ticks and calls `round_is_over`. The loser lands and stays down; winner does a per-character victory animation (`victory_animation`, 5-12 tick frames). Flow after KO: ~16 ticks, round-end chord, winner announcement of ~170+ ticks wait (`bonus_count`, `MKBONUS.C:100-170`); KO -> next round ~ **5-7 s [A]**.
- **Time out**: `results_of_round(ROUND_TIMEOUT)` -> `round_is_over`: higher bar wins; **equal bars = tie, no point awarded, round repeated** (`ROUND_P1_P2_TIE`, `MKMAIN.C:1215`). Anti-farm: both bars full or round >= 5 -> game over (`weed_out_cheaters`, `MKMAIN.C:1666`).

## 9. CPU "drone" AI at diff 0 (`MKDRONE.C`)

### 9.1 Where `diff` comes from
`diff` 0-9 is the global difficulty (`MKGAME.H:708`). It is **0 at game start and after game over** (`MKMAIN.C:825`); first match opponent: `diff = mhe_match_1_diffs = {0,3,0}[ladder_order]` (`MKLADDER.C:1679`); after a human wins a match `diff += {1,2,2,3}[ladder]`; a CPU win lowers it (`diff_adjust`, `MKMAIN.C:2279-2345`). Everything below is for **diff 0**. All probabilities are `randper(x)` = x per mille (`MKUTIL.C`: `(rnd>>7)%1000 < x`); `random_do` picks uniformly among table entries (`randu(count)`).

### 9.2 Structure
- The AI has **no fixed decision interval**: one `drone_entry` (`MKDRONE.C:94`) decision, run the action to completion, `reaction_exit` returns to `drone_entry`. Cadence = animation length of what it chose (~20-60 ticks of attack, plus walking).
- `drone_entry`: (1) `hangout_check`, (2) if human `p_action == ACT_REACTING` (in hit stun): wait, (3) else `d_attack` by distance.
- Every tick of every AI state calls `d_beware()` (`MKDRONE.C:4011`): it **reacts only when the human's `p_action` changes**, via a table indexed by the human's action (`counter_attack_table`, `MKDRONE.C:3811+`).

### 9.3 Decision table (diff 0)

Distance `d = |dx|` (arcade px / 640 px):

**Idle ("hangout")** (`hangout_check`, `MKDRONE.C:1590`): `diff <= 4` and `dv_hangout > 0` (2 per round, `d_init`): **20%** per `drone_entry` -> stand in stance `0x30 + randu(0x80) - 1` = **48-175 ticks** (avg 111 = 2.0 s), still reacting to attacks.

**Human in hit stun** (`d_wait_finish_react`, 686): if `d < 0x60` (96 / 154): back off ~up to 64 ticks until `d > 0x80` (128 / 205); else wait up to 96 ticks. **The CPU never follows up a hit and never attacks a player in hit stun.**

**Cornered** (`q_am_i_cornered`: distance behind it to the world edge `<= 0x90` = 144 / 230; `cornered_attack`, 145): 10% `run_in_close` (= `perhaps_flipk` at diff < 2), else `stalk_in_close`.

`d_attack` (158) by distance, then:

| Range (arcade / 640) | Table (`random_do` uniform unless stated) | What diff 0 turns it into |
|---|---|---|
| `d < 0x45` (69 / 110) "very close" | 30% first goes to *zone* (below); else {elbow, knee, **slam (throw)**, stalk_crossk}, each 25% | elbow/knee are 5-tick strikes; **throw = 24 dmg, always succeeds** (no throw check; vs airborne -> 7 rapid HPs); crossk = walk in, jump a flip kick |
| `d < 0x78` (120 / 192) "close" | {sweep, lo kick, stalk_crossk, rapid lo punches (<=7), walk_in_4_combos (walk <=48 ticks to <74 px, then elbow/knee 50/50), propell (=> lo kick)}, 1/6 each | no combos (needs diff >= 2) |
| `d < 0xf0` (240 / 384) "far" | 30% zone; else {stalk_in_close, run_in_close(=perhaps_flipk), perhaps_flipk, d_zap, propell} 1/5 each | `d_zap` and `propell` -> `diff_no_zap`: lo kick if `d < 0x48` else **stalk**. `perhaps_flipk`: flip-kick jump only if `181 <= d <= 240`, else stalk. **No projectiles/specials at diff 0.** ~60% walk-in |
| `d >= 240` "very far" | 30% zone; {front-flip jump (no attack), run_in_close, run_in_close, zap} 1/4 each | 25% blind front flip (4 px/tick, 156 px), 75% walk in |

- **Stalk** (`stalk_in_close`, 729; `d_stalk_a11`): walk toward opponent at the character walk speed (3.25 px/tick = 286 px/s) until `d < 0x40` (64 / 102), timeout 6400 ticks, then `d_attack_close`. At diff 0 `run_in_close` goes through `perhaps_flipk`, so the CPU **never runs** (running needs diff >= 2) and never jumps at you unprovoked except the flip/flip-kick.
- **Zone** (`nr_drone_zone`, 387): if `clk_tens > 3` and `randper(300)` (30%): retreat (back-walk 2.25 px/tick) up to 192 ticks to `d > 0xd0` (208 / 333), then hover (`drone_zone`, 397): up to 128 ticks in stance; if `d < 0x88` (136 / 218) run in (flipk), if `< 0xd0` back up, if `> 0x100` (256 / 410) walk forward; then back to `drone_entry`. This is the "keep-away dance".

### 9.4 Blocking / reaction decision table (`d_beware` -> `counter_attack_table`, diff 0)

Reaction gate (`react_jump_table`, `MKDRONE.C:7670`): `count` = how many of the CPU's last 6 received hits were by this same action
(`count_q_repeats`; this is the **repeat detection**). `repeat_table[0] = 3`.
- if `count >= 3` -> always take the **counter** entry (2nd table slot).
- else: `d_randpers[0] = 150` -> **15%** react at all (85% ignore). If reacting: `rpt_counter[0] = 100` -> 10% counter, 90% the **avoid** entry (1st slot).

| Human action | Condition | Avoid (90% of reactions) / counter | Net at diff 0 |
|---|---|---|---|
| Punch (HP/LP) | `d <= 0x60` (96) | sweep / sweep | 15% sweep; 100% sweep if you landed >= 3 of the same punch on it in its last 6 hits |
| HK / LK | your strike box would reach it now | block / `ct_kicks` (duck then uppercut, or sweep) | 13.5% block, 1.5% duck-counter, plus `nr_sweep_if_u_can`: if its sweep reaches you **it sweeps (100%)** (whiff punish, `MKDRONE.C:7308`; possibly an artifact of the C port, drop it for a gentler CPU) |
| Roundhouse | `d <= 0xd0` and reaches | `ct_kicks` **unconditionally** (duck -> uppercut, else sweep) | 100% counter when it would connect: the single most dangerous move to use on it |
| Sweep | reaches | backflip (or crouch-block when cornered) / `ct_sweep` | 15% |
| Uppercut | reaches | crouch fast, wait, uppercut/sweep | 15% |
| Duck punch / duck kick | reaches | block / crossover kick | 15% |
| Jump kick / flip | `d <= 0x60` | duck | 15% |
| Knee / elbow | any | `d_avoid_elbow_knee`: 90% block, 10% throw if `d < 0x4a` | ~15% (13.5% block) |
| Angle jump (flip) | any | `rpt_angle[0] = 100`: 10% react (then jump-kick / punish) | 10% |
| Human airborne at its `d_attack` | | `rpt_counter_airborns[0] = 100`: 10% anti-air jump kick | 10% |
| Projectiles / specials | | n/a for basic-move characters | |

### 9.5 What a casual player can exploit at diff 0
- **No specials, no projectiles, no running, no combos, no reverse-throws.** It walks in at 286 px/s (the same as you) and then uses 1-of-6 simple poke.
- **It rarely blocks** (~13%/attack), does not tech throws (reversal 0%) and the human's throw is free at range <= 102 px.
- It **never attacks you while you are in hit stun** and retreats when you are hit, so there are no setups on your wake-up.
- The "repeat detection": three of the same attack in its last six hits flips the 15% reaction to 100% counter -> mix moves.
- Hang-out windows (up to two per round, 2 s each) are free approach time.
- Real threats: its throw (25% of very-close decisions, unblockable, 14.5%), the sweep, the 100% roundhouse counter, and the whiff-sweep.

### 9.6 Recommended Zig diff-0 CPU (derived from the above; the distances below are at the first version's 1.6 px per arcade px, `tables.ref` scales them to `S`)
- Decision on every action end (no timer). Distances in 640 px: very-close < 110, close < 192, far < 384, stalk stop 102, throw range 102, elbow/knee 118.
- Probabilities as in 9.3/9.4. To make it clearly beatable keep: no specials, no run, no combos, 15% reaction gate, the 100% roundhouse counter only if the roundhouse will connect, and cut the free whiff-punish to a 25% chance and the throw weight to 12-15%. (Gentler tuning above the source's own diff 0 is a design choice, flag it before shipping.)

## 10. Verified vs approximated at a glance

Verified from source: tick rate (55 arcade / 60 PSX), 16.16 integration order, scale factors, walk and run speeds, run fuel, jump
velocities/gravity/airtime/height, angle-jump horizontal speed, health max 166, throw conditions/range/damage, block rules (including
chip-cannot-kill and minimum 1), block-stun ticks and pushback, all knockdown flight arcs, repel distance 64, screen distance 304, wall paddings 58/48,
clock/round structure, every AI decision above.

Approximated: per-move damage, chip percent, hit-box reaches, startup/active/recovery in ticks (animation frame counts missing),
get-up duration, arena width, KO-to-next-round time, which strikes have `SF_DUCK`, strike->reaction/block mapping.


## 11. The engine built from it (`src/core/fight_mk3/`, `fixes.fight_mk3`)

XILINDRO's Corrigida fight with these mechanics, SF3 Ryu on both sides (in `--fix all`; `--fix all,-fight_mk3` and the web
page's `?mk3=0` play the old fair fight, which is also what plays without the pack). It is sprite-agnostic: a character is a pack of frames and clips (`character.zig`), the moves are
tables (`tables.zig`), the simulation (`sim.zig`) reads the hurt and hit boxes of the frame each fighter shows.
The original Casseta sprites will be mapped onto the same engine later (a pack with the same clip names).

### 11.1 Files

| File | What |
|---|---|
| `character.zig` | the pack's format and loader; `Anim` is the list of moves a character must have |
| `tables.zig` | every number (below), one place to tune |
| `sim.zig` | the fixed-step simulation: control, physics, hits, blocks, throws, knockdowns, facing, walls |
| `cpu.zig` | the drone at diff 0; `bot.zig` the test players (`idle`, `masher`, `casual`, `decent`) |
| `match.zig` | a round: the 55-Hz clock, the controllers, `view` (the picture between ticks) |
| `render.zig` | 8-bit drawing (nearest game-palette colours, a palette swap, fractional nearest-neighbour scale, mirrored) |
| `xilindro.zig` | XILINDRO's side: loads the pack, energies, the picture; the handler's part is `arena.zig` `mk3Update` |
| `tests.zig`, `testing.zig` | the mechanics' tests, on a synthetic pack (no private art) |

### 11.2 Time and pictures

The simulation runs at **55 ticks a second** (`ONE_SECOND`, MK3.md section 1), decoupled from the game's 200 ms beat:
`Match.advance(now)` runs the ticks due, from the message handler (every message, at least the 50 ms timer) and from
`view`. `view` is the host's presentation hook (`host.Program.view`): SDL asks it every loop turn (at most 16 ms
apart), the web page every animation frame, the harness at every dump; it interpolates the fighters between the last
two ticks, so the picture is as smooth as the display. The game's own screen only supplies the clock and the
portraits; the arena band is rebuilt each frame from the background.

### 11.3 What is used, from where, and how true it is

| Mechanic | Value in the engine | Status |
|---|---|---|
| Tick rate | 55 / s | verified (`ONE_SECOND`) |
| Scale | arcade px x `S` = 1.25 (uniform in x and y), fighter 144 arcade px = 180 px, `tables.S` / `tables.stand_arcade`; every pixel constant below is at this scale (`tables.fx`, `tables.ref`) | heights verified (`ochar_ground_offsets`), the scale chosen (1.6 gave 230 px: too big) |
| Walk | forward 4.06 px/tick (223 px/s), back 2.8 (155 px/s) | verified (3.25 / 2.25 arcade) |
| Run | not implemented | gap |
| Jump | vy 18.9 px/tick, gravity 0.945 (`SY`), gravity then move each tick: 39 ticks, 180 px high (95 arcade); forward / back vx 5 px/tick = 195 px (156 arcade); no air control | verified (`jump_tables`); tested; the figure hangs from the head line (section 3) |
| Crouch | holding down; no stand-up delay | approximated (source has ~6 ticks each way) |
| Moves | LP, HP, LK, HK; crouching LP, uppercut (down + HP), crouching LK, sweep (down + HK, and back + LK as MK3's); roundhouse (back + HK); jumping LP, HP, LK, HK; close throw (LP within 155 px) | inputs verified; the owner's mapping for the sweep |
| Frame data | startup / active / recovery per move in `tables.zig` (HP 7/5/14, LK 5/5/10, sweep 8/3/18, ...) | approximated: the source's animation scripts are not in the repo; the structure (hit-check windows) is the source's |
| Damage of 166 | LP 7, HP 10, LK 8, HK 12, crouching punch 8, crouching kick 7, sweep 12, uppercut 22, roundhouse 18, jump punch 13, jump kick 15, throw 24 | throw verified; the others approximated |
| Block | a dedicated button (Space), live at the hit, no startup, not in the air; standing stops everything but lows (sweep, crouching kick), crouching stops everything; throws unblockable | verified (`is_he_blocking`), the low flags approximated |
| Chip | 12% of the hit, at least 1, never lethal | rule verified, percent approximated |
| Block stun, push | 12 ticks (sweep 8), 30 px | verified |
| Hit stun, push | punch 10-12 ticks, LK 11, HK 16 (94 px), crouching 10-11; tuned shorter than the attacker's recovery: no combos | approximated (no combo tables in the source) |
| Knockdown | sweep (in place), uppercut (44 ticks, 102 px), roundhouse (31 ticks, 117 px), throw (63 px), any hit on a fighter in the air; 26 ticks on the floor, 12 getting up, the first 6 safe | structure verified, flights shortened (the source's 298 px uppercut flight is half a screen here) |
| Hit in the air | thrown back 4.4 px/tick with a hop of 7.5 px/tick | verified |
| Throw | LP, other on the ground, in reach (MK3 64 arcade = 80 px, here 121 for Ryu's reach), not holding away, not in stun, 24, unblockable | verified |
| Facing | grounded fighters face each other every tick; a jumper keeps his facing, so crossing flips it on landing | verified in structure; the source flips instantly at attacks/hits too |
| Overlap | fighters on the ground keep 109 px apart (MK3 80; Ryu is wider), eased 5 px/tick; a jumper passes through | verified rule, wider value |
| Walls | x 72 to 580 (58 and 48 arcade px from the edges of a 512-arcade-px screen); a blow into the corner pushes the attacker back instead | the corner rule verified, the walls ours (a fixed screen: MK3 scrolls) |
| Round | one round: KO, or at 0 on the 90 s clock the better health wins (a tie is XILINDRO's: the player) | XILINDRO's rules over MK3's health |
| Close moves | elbow and knee (close HP, HK, LK) | not implemented |
| Juggles, combos, run, specials | not implemented | gap (the owner's request: "if simple") |

### 11.4 Controls (keyboard)

| Key | Move |
|---|---|
| ← / → | walk (toward / away from the opponent by his side) |
| ↑ | jump; with ← or → a jump back or forward |
| ↓ | crouch |
| A / S | low / high punch (↓ + S: uppercut; A close up: the throw) |
| D / F | low / high kick (↓ + F: sweep; back + F: roundhouse; back + D: sweep) |
| Space (or Z) | block (↓ + Space: crouching block) |
| F9 | the hurt (blue) and hit (red) boxes (Debug builds) |

The old XILINDRO keys (PgUp, Home, End, Insert) do nothing in this fight; the controls screen lists the new ones.
The web pad (the Corrigida's XILINDRO, unless `?mk3=0`) has the arrows, A S D F and a block button in the middle of the arrows; the low and back
moves are a held arrow and a tap (multi-touch); a tap that is held still repeats like a keyboard.

### 11.5 Sprites

`tools/ryu_pack.py` (run in the `explorer` dev shell: Pillow) turns Zweifuss' per-move GIFs of the SF3 3rd Strike Ryu
(the rip behind `zig-out/sprite-viewer`'s `sf3-ryu`; copyright Capcom, private use only) into
`zig-out/sprites/ryu/pack.bin`: 29 clips, 317 frames, 46 colours (2.4 MB). **The pack is not in git; the public
web deploy carries it** (`NOITE_SPRITES`, `docs/WEB.md`); the game loads it as `ryu\pack.bin` (a third file root after `save` and `assets`, `Sim.Options.sprites_dir`;
the private web build adds it to its manifest, `docs/WEB.md`). Missing: the feature is off and the old fight plays.

Move to clip (Ryu GIF): stance, crouch (`crouch`), walk (`walkf`, `walkb`), jumps (`jump`, `jumpf`, `jumpb`, stretched over
the 39-tick flight; in the air they hang from MK3's head line, section 3), LP `wp`, HP `hp`, LK `wk`, HK `mk`, roundhouse `hk`, crouching `crouch-wp`, uppercut `crouch-hp`,
`crouch-wk`, sweep `crouch-hk`, jumping `jump-lp/hp/lk/hk`, throw `throw-forward`, block `block-high` (standing) and
`block-low` (crouching), hits `stand-hit` / `crouch-hit` (the first frames), fall and down `slam`, win `win1`.
Clips are drawn at the engine's scale (`Character.scale_fp`, 1/256 px per source pixel, nearest-neighbour: the pack's `stand` is the stance's 104 source px, sized to MK3's 144 arcade px x `S` = 180 px, so about 1.73 px per source pixel; the first version drew a flat 2: 208 px) and the animations are fitted to the engine's ticks, not the other
way round: an attack's frames before its active frames are spread over the move's startup ticks, the active ones over
its active ticks, the rest over its recovery (`sim.attackFrame`); stuns and falls stretch their clip over their length.

How the anchors and boxes are derived (the rip has none; `tools/ryu_pack.py` header): the x anchor of a still clip is the
feet's x of its first frame (the GIF frames of a move share one registration), of a travelling clip (walks, jumps,
reactions, the throw) each frame's silhouette centroid smoothed over three frames; the y anchor is the picture's bottom
(ground), for the air clips each frame's silhouette bottom. The hurt box is the silhouette within 26 source px of the
anchor (the trunk and legs: an outstretched limb is not hittable); the hit box, on the active frames only (those whose
reach past the trunk is at least 80% of the clip's longest, at least 12 px; the uppercut and jump punch hand-set), is the
silhouette beyond 20 px in front of the anchor (the uppercut: the top half within 14 px behind to 40 ahead). Fighters on the
floor have no hurt box. `--preview FILE` draws every clip with its anchor and boxes; `--report` prints the feet's jitter.

The opponent is the same pack with a palette swap (`render.Swap`: the gi's greys to blue, the reds to gold). Colours are
mapped to the nearest of the game's 256 (the minigame's palette is fixed), so the whites come out grey-ish.

### 11.6 The CPU

`cpu.zig` is MK3's drone at diff 0 (section 9): no specials, no running, no combos; it decides when it has finished an
action, by the distance bands (110, 192, 384 px at the first version's scale, x 0.78 now: very close: HP, LK, throw, HK; close: sweep, LK, walk in and HK, three
LPs, walk in and HP; far: walk in, a jump kick from 290 px); it stands in its stance (20% of decisions); it never
strikes a human in hit stun; it reacts to a new attack of the human's by blocking (crouching against lows) or, 10% of
the time, a sweep counter. **Gentler or different from the source**: it reacts 30% (MK3: 15%) and counters a move that
has hit it three times in its last six hits 60% of the time (MK3: always: a button-masher would be swept forever), it
stands in its stance once a round (MK3: twice), it waits only 2-10 ticks after a strike (MK3: none), and it has no keep-away
retreat, crossover kick or whiff sweep. The knobs are at the top of `cpu.zig`.

Win rates of the player bots (`tools/fight_bots.py --fixes mk3=all,fight_mk3`, 60 seeds; the bots read the screen like a
person and have a reaction time, `bot.zig` here, `core/fight_bot.zig` for the old fight; the bots' keys go straight to
the simulation) are in `docs/fights/MK3.md` section 11.8.

### 11.7 Checks

`zig build test` (the mechanics on the synthetic pack: the jump arc, the side switch, blocks, chip, throws, knockdowns, KO,
walls, and that the CPU beats a bot that does nothing and loses to a casual one), `tools/fight_mk3_smooth.py` on a
headless run's frame trace (`--fight-bot masher,5,log --dump-every 16`), `tools/play_all.py` (the flag is off by default:
144 of 144), `tools/smoke.py --minigame xilindro [--fix all]`.

### 11.8 Results

`tools/fight_bots.py --seeds 60 --game xilindro --fixes easy=all,-fight_mk3 mk3=all` (the real Ryu pack; `easy` is the old fight with
the Corrigida's easy opponent; win% includes a clock win; the bots press nothing the keys could not):

| fight | bot | win % | KO % | round ends (s) | bot's energy left | CPU's energy left | hits landed / taken |
|---|---|---|---|---|---|---|---|
| old (easy) | idle | 0 | 5 | 96.6 | 15.4 | 91.0 | 0.0 / 21.5 |
| old (easy) | masher | 47 | 3 | 96.6 | 29.3 | 34.4 | 19.3 / 17.2 |
| old (easy) | novice | 67 | 0 | 96.8 | 32.5 | 21.8 | 23.2 / 16.6 |
| old (easy) | decent | 100 | 3 | 96.7 | 80.1 | 17.2 | 24.8 / 3.2 |
| MK3 | idle | 0 | 100 | 38.4 | 0.0 | 91.0 | 0.0 / 15.2 |
| MK3 | masher | 98 | 100 | 20.2 | 59.2 | 0.1 | 9.4 / 6.4 |
| MK3 | novice | 92 | 100 | 36.6 | 36.5 | 1.0 | 14.2 / 10.2 |
| MK3 | decent | 100 | 100 | 32.9 | 48.0 | 0.0 | 14.4 / 8.2 |

A player who does nothing is knocked out in 38 s (the CPU does fight); a novice who walks in, pokes and sometimes blocks
wins 92 rounds in 100, a masher (random blows, never blocks: it throws at close range, the LP) 98 of them, with 59 of 91
energy left. That is easier than the old fight's easy opponent (47% / 67%): the owner found that one too hard; the
dials are in `cpu.zig` (`react_pct`, `anti_spam_pct`, `pause_*`, `max_hangouts`) and `tables.zig` (the damage). The
synthetic-art test (`zig build test`) gives the same order (idle 0, masher about 95%, casual about 95% of 30).

Smoothness (`tools/fight_mk3_smooth.py` on `--fight-bot masher,5,log --dump-every 16`, 36 s of fighting, 5100 frames): the
picture is rebuilt at least every 16 ms (a presentation every loop turn in SDL and every animation frame on the web; the
headless dump run shows 80 a second); the feet of a fighter move at most **14 px between two frames** (a knock-back at
about 19 px a tick is the fastest motion), the 99th percentile 6 px: no frame where the feet jump. A hit on a jumper
used to drop him to the floor in one frame (found by that script's trace): he now falls with the physics.
The sprite registration is the rip's own, per clip (`--report` of the converter): the still clips' feet stay within 2.4 source
px of their anchor (stance 0.9, crouch 0.1, blocks, punches 2.4); the moving ones (walks, kicks) move their feet by design.

### 11.9 Gaps and choices for the owner

- Close elbow and knee, run, juggles and combos are not implemented; the pack has the clips for none of the specials.
- The frame data and damage numbers are approximations (the source lacks the tables); they are in `tables.zig`.
- Down + HK is the sweep (as asked); MK3's own input (back + LK) works too.
- The CPU is gentler than diff 0 (6.), tuned so a button-masher or a novice wins about nine rounds in ten (the table above); harder
  is a constant in `cpu.zig`.
- The PORRADA banner is not drawn in this fight; there is no round counter (one round, as XILINDRO).
- The art is Capcom's: the pack stays out of git; the public site serves it (the owner's call).
