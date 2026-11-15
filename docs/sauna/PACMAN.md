# Arcade Pac-Man: the rules the Corrigida's SAUNA plays by

Research notes for `Fixes.sauna_arcade_rules` (docs/sauna/DESIGN.md "Arcade rules"). Everything here is
the 1980 arcade game (level 1 only: SAUNA has one level); "Mapped" says what the port does with it.

## Sources

- **The Pac-Man Dossier**, Jamey Pittman (<https://pacman.holenet.info/>, also on Game Developer):
  the reference. Maze and tiles, speeds, cornering, targets, modes, house, frightened mode, tables A.1.
- **GameInternals, "Understanding Pac-Man Ghost Behavior"** (Chad Birch, 2010,
  `gameinternals.com/understanding-pac-man-ghost-behavior`): the ghost rules in prose (targets, the
  tie-break, the one-tile-ahead decision). The domain now serves an unrelated page, so the Dossier,
  which says the same, was read instead.
- **masonicGIT/pacman** (<https://github.com/masonicGIT/pacman>, a fork of **shaunlebron/pacman**,
  "Pac-Man in JS", GPL-3.0): a faithful implementation built on the Dossier. Read:
  `src/Actor.js` (the speed-control table, `update`), `Player.js` (`step`, `steer`: cornering and
  input), `Ghost.js` (`steer`, the house), `targets.js` (the four targets), `ghostCommander.js`
  (the schedule), `ghostReleaser.js` (the dot counters), `energizer.js`, `elroyTimer.js`,
  `direction.js` (`getTurnClosestToTarget`, `getOpenTiles`). Its README: the coordinate space,
  speeds and timers match the arcade; collision is checked twice a frame.

## The grid and the clock

- 8-px tiles; an actor is in the tile that holds its centre. The game runs at 60 frames a second, and
  the "100 %" speed is 75.757576 px/s (1.2626 px per frame, 9.47 tiles/s).
- An actor moves in whole pixels. A **speed-control table** of 16 entries a level class says how many
  steps (0, 1 or 2) it takes on each of 16 consecutive frames (`frames % 16`); a frame has two
  sub-steps (`j` = 0, 1), actor `update(j)` does nothing when `j >= steps`. Level 1:

| Pattern | Steps in 16 frames | px/s | % of max |
|---|---|---|---|
| Pac-Man, normal | `1111111111111111` | 60.0 | 80 % (79) |
| Pac-Man, energizer (fright) | `1111211111112111` | 67.5 | 90 % |
| Ghosts, normal | `0111111111111111` | 56.25 | 75 % |
| Ghosts, frightened | `0110110101101101` | 37.5 | 50 % |
| Ghosts, tunnel / in the house | `0101010101010101` | 30.0 | 40 % |
| Blinky, Elroy 1 (20 dots left) | `1111111111111111` | 60.0 | 80 % |
| Blinky, Elroy 2 (10 dots left) | `1111111121111111` | 63.75 | 85 % |

- Eating a dot stops Pac-Man for 1 frame (about 10 % slower on a dot row), an energizer for 3.
  Ghosts never pause. (Levels 2-4 and 5+ have faster tables; SAUNA has one level.)

## Pac-Man: input and cornering

- A four-way joystick: the direction held is the one wanted; there is no key buffer as such, but a
  direction held before a junction takes effect the first moment it is possible.
- He does not wait for the centre of a turn: pre-turn (before the centre) and post-turn (after it).
  Entering a tile from the left there are 3 pre-turn pixels and 4 post-turn; from the right, 4 and 3
  (top and bottom as the sides). In the JS implementations: if the tile next to his current tile in
  the wanted direction is floor, he turns at once, wherever he is in the tile.
- **The cut**: while off the centre line of the lane he is in, he drifts one pixel toward it for each
  pixel he moves (a 45 degree path, so he moves "twice as fast" across the corner). Each pixel of
  lateness in a turn costs one frame. `step`: stop at the tile centre if the tile ahead is wall;
  otherwise move one pixel ahead and `sign(distance to the centre line)` sideways.
- A reversal is always possible at once.

## Ghosts: movement

- A ghost moves in a straight line to the **centre of a tile**; one pixel after passing the centre
  of tile T it decides which exit it will take from the **next** tile N (the tile ahead), and
  commits to that direction when it reaches N's centre. It never turns before the centre.
- At N it looks at the neighbours of N that are floor, **never the one behind it** (the reverse; but
  it may if there is no other), and picks the one whose tile is nearest (straight-line distance,
  squared) to its **target tile**. Ties: **up, then left, then down, then right**.
- **Forced reversal** (the only way a ghost reverses): when the mode changes chase to scatter,
  scatter to chase, or either to frightened (not frightened back to chase or scatter); applied when
  it reaches the next tile centre.
- Two "no up-turn" zones (above the house door and near the bottom) forbid upward turns in scatter
  and chase (not frightened).
- **Frightened**: at each decision it draws a pseudo-random direction, and if that is a wall (or
  behind it) tries the next ones in turn; the generator is reset to the same seed at each level
  start and each life lost, so the paths repeat.

## Ghosts: targets (chase)

- **Blinky** (red): Pac-Man's tile.
- **Pinky** (pink): the tile 4 ahead of Pac-Man in his direction; facing up, 4 up **and 4 left**
  (an overflow bug of the original code, kept by the faithful clones).
- **Inky** (cyan): take the tile 2 ahead of Pac-Man (facing up: 2 up and 2 left), draw the vector from
  **Blinky's** tile to it, double it: the end is the target.
- **Clyde** (orange): Pac-Man's tile when 8 or more tiles away (straight-line), else his own scatter
  corner.
- Scatter: each ghost's corner, a fixed tile outside the maze above or below its corner (Blinky
  top right, Pinky top left, Inky bottom right, Clyde bottom left). Blinky ("Cruise Elroy") chases
  also in scatter once he is in Elroy mode.
- **Eaten**: the ghost becomes eyes, goes to the house door at twice the speed and re-enters; it
  leaves again at once.

## The schedule (level 1)

Seconds: scatter 7, chase 20, scatter 7, chase 20, scatter 5, chase 20, scatter 5, chase forever. It
starts in scatter, every change reverses the ghosts, and the clock stops while an energizer is on.
(Levels 2-4: 7, 20, 7, 20, 5, 1033, 1/60; level 5 and up: 5, 20, 5, 20, 5, 1037, 1/60.)

## Energizers (frightened)

- Level 1: 6 s, 5 flashes (the ghosts alternate blue and white every 14 frames over the last ten
  intervals). Pac-Man runs at 90 % and the ghosts at 50 %. Ghosts eaten in one energizer score 200,
  400, 800, 1600; the game freezes about a second on each. Eating an energizer reverses the ghosts.
- Cruise Elroy: Blinky speeds up when few dots are left: 20 left (80 %), 10 left (85 %) on level 1 of
  244 dots; he waits for Clyde to leave the house after a death.

## The house

- Pinky leaves at once; Inky and Clyde are released by **dot counters**, one at a time in the order
  Pinky, Inky, Clyde, counting the dots Pac-Man eats while that ghost is the first one in the
  house: Level 1 Inky 30, Clyde 60. A **timer** also releases the first ghost inside when Pac-Man
  has eaten nothing for 4 s (3 s from level 5).
- After a death the **global counter** is used until Clyde leaves: Pinky at 7 dots, Inky at 17, Clyde
  at 32. Blinky starts outside. Ghosts in the house bob up and down; they leave to the left of the
  door by default; the door is closed to Pac-Man and to ghosts that are not eyes.
- A death sends everything back to the start; the schedule restarts.

## Mapped to SAUNA (Corrigida: `sauna_arcade_rules`)

docs/sauna/DESIGN.md "Arcade rules (Corrigida)" and GAME.md say what the port does with these rules
on SAUNA's maze: the 16-px lattice, speeds scaled to 16-px tiles, dot-count thresholds scaled from
244 to SAUNA's 100 dots, the corks as energizers, and every place where SAUNA's own rules stay.
