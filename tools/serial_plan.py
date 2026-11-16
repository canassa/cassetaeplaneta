#!/usr/bin/env python3
"""Plan a SERIAL (Serial Killer) game and write it as an input script.

    nix develop -c python3 tools/serial_plan.py [--start MS] (--win|--lose)
        [--relative-to MS] [--lookahead MS,...] [-o FILE]
    nix develop -c python3 tools/serial_plan.py --start MS --check FILE [--fix all]
        [--key-repeat DELAY,PERIOD|off]
    nix develop -c python3 tools/serial_plan.py --start MS --trace FILE

The figures that walk in come from `rand()` after `srand(time(NULL))` in
serial_create_targets, at SERIAL's WM_CREATE: `--start` is that time (0
alone, WinExec + 1500 ms from NOITE's 3farmcai); the seed is the headless
clock's `time()`, 800000000 + start / 1000. The planner simulates the
game as docs/serial/GAME.md describes it, on the virtual clock, down to
what decides a hit and a life:

- the system timers in USER's table order (a timer set again keeps its
  slot, a killed one set again goes to the end; several due at once fire
  in table order; a key pressed at a time is handled after the timers due
  then, a repeat of a held key before them);
- the spawns every 5 s (lane 0 `rand() % 7`, lane 1 `rand() % 6`, lane 2
  every second tick, its `rand() % 2` drawn before the busy test; with
  K5's fix lane 2 also on its own 5-s timer, id 9), the
  walks (20 px a tick with the Bresenham line, frames with wrap, the edge
  tests), the killers' shots and `g_lives`, the 120-s clock;
- the bullet (20-px Bresenham steps every 55 ms) and the occupancy grid it
  queries (32-px cells: counts and last occupant, the wall cells, every
  occupy/vacate the figures and the bullet do, stale cells included), so
  the first hit stage (`projectile_try_step`) is the game's; then the
  second stage (BUGS.md K3) in both versions.

The gun's own cells (rows 11-15) are left out: no query reaches them.

A plan presses SPACE with the bullet free, at least 110 ms after the last
press, with LEFT/RIGHT before it. The Original and the Corrigida (`--fix
all`: K1-K5) play different games, since K5 spawns lane 2 on its own
timer (more `rand()` draws, other figures), so one script plays both: a
shot is kept when, in each version, it hits at most one figure, only of
the wanted kind, and it hits one in at least one version:
- `--win` shoots the killers (kind 2) only, as soon as a shot can reach
  one: the game lasts the 120 s with lives left in both;
- `--lose` shoots kinds 0 and 1 only (each hit frees a lane for the next
  spawn, so more killers come) until the killers take the five lives in
  both.
When that fails it tries again (`--lookahead`): a shot that hits in one
version only gives way to one hitting in both within the lookahead; then
every shot must hit in the Corrigida, then in the Original; then, for a
win, the other version's shot may hit any figure (a win's result does
not depend on the score).
The planner prints both results. `--check FILE`
simulates a script (`key`/`hold` lines, absolute or `+N` times relative to
`--relative-to`; a `hold` repeats its key as a run does, `--key-repeat
DELAY,PERIOD|off`), `--trace FILE` too and prints every tick.
"""

import argparse
import copy
import sys

# ---- the game's constants (src/serial/*.zig, docs/serial/GAME.md) -----------

BG_W = 640
CELL = 5  # 32-px cells
GRID_STRIDE, GRID_CELLS = 81, 81 * 65
FRAMES = (6, 10, 12, 13, 12, 10, 11, 9, 4, 16, 10, 12, 12, 2, 6)
WIDTHS = (80, 88, 88, 92, 88, 52, 40, 88, 48, 124, 74, 128, 52, 200, 188)
HEIGHTS = (177, 100, 99, 127, 121, 111, 136, 105, 95, 105, 102, 147, 120, 67, 60)
KINDS = (0, 0, 2, 0, 1, 0, 1, 0, 0, 2, 1, 1, 0, 1, 1)
B_W, B_H = 47, 31  # bala.bmp
GUN_X, GUN_Y = 200, 0x17C
WALK, WALK2, SPAWN, CLOCK, LANE2, GUN, BULLET, APP = 3, 6, 7, 8, 10, 10, 0xC, 1
LANE2_OWN = 9  # K5's id for lane 2 (g_timerIds[6])
STEP = 20
LIVES = 5
EPOCH = 800_000_000
VK_SPACE, VK_LEFT, VK_RIGHT = "space", "left", "right"


class Rand:
    """The MSVC CRT LCG (src/core/crt.zig)."""

    def __init__(self, seed):
        self.s = seed & 0xFFFF

    def rand(self):
        self.s = (self.s * 0x343FD + 0x269EC3) & 0xFFFFFFFF
        return (self.s >> 16) & 0x7FFF


def i8(v):
    v &= 0xFF
    return v - 0x100 if v >= 0x80 else v


def i16(v):
    v &= 0xFFFF
    return v - 0x10000 if v >= 0x8000 else v


def trunc_div(a, b):
    q = abs(a) // abs(b)
    return q if (a >= 0) == (b >= 0) else -q


class Obj:
    """A Mover (figure or bullet): position, Bresenham line."""

    def __init__(self, kind, index, w, h, x, y, frames):
        self.kind, self.index, self.w, self.h = kind, index, w, h
        self.x, self.y, self.nx, self.ny = x, y, x, y
        self.frames, self.frame = frames, 0
        self.moving = 0
        self.dir = 0
        self.step_x = self.step_y = STEP
        self.tx = self.ty = 0
        self.err = self.inc_x = self.inc_y = self.inc_diag = 0


class Sim:
    def __init__(self, start, fixes=False, k5=None, arm=None):
        # `arm`: when the game's timers start (the Corrigida's intro screen
        # stops them until a key); the seed is still `start`'s.
        self.now = start if arm is None else arm
        self.fixes = fixes  # Fixes.all(): K1-K4
        self.k5 = fixes if k5 is None else k5  # serial_lane2_own_timer, in `all`
        self.rand = Rand(EPOCH + start // 1000)
        self.timers = []  # [id, period, due], USER's table order
        self.grid = {}  # index -> [count, occupant]
        self.score = 0
        self.lives = LIVES
        self.aim = 0  # mover_show leaves curFrame 0: the gun starts aimed left
        self.held = {VK_SPACE: 0, VK_LEFT: 0, VK_RIGHT: 0}
        self.result = None  # (time, lives, score) at WM_DESTROY
        self.hits = []  # (time, figure)
        self.shots = []  # (time, aim)
        self.shot_at = []  # (time, figure): the killers' shots
        self.trace = None
        self.busy = [0, 0, 0]
        self.toggle = 0
        self.clock = 0
        # serial_backdrop_create: the wall cells.
        for row in range(5, 0xE):
            self.set_cell(0, row, -1)
            self.set_cell(0x13, row, -1)
        for col in range(0x13):
            self.set_cell(col, 0xD, -1)
        # game_init: the gun (its cells are never queried: left out).
        # serial_create_targets: 15 figures at (0, 0x118), hidden.
        self.figs = [Obj("target", i, WIDTHS[i], HEIGHTS[i], 0, 0x118, FRAMES[i]) for i in range(15)]
        self.set_timer(SPAWN, 5000)
        self.set_timer(CLOCK, 60000)
        # K5: id 10 replaces the gun's timer (its branch is dead); with the
        # fix lane 2 gets id 9, after the clock in the table.
        self.set_timer(LANE2_OWN if self.k5 else LANE2, 5000)
        # serial_create_bullets: hidden at (0, 0x17c).
        self.bullet = Obj("bullet", -1, B_W, B_H, 0, GUN_Y, 3)
        # AppWndProc's WM_CREATE: system timer 1.
        self.set_timer(APP, 50)

    # ---- USER --------------------------------------------------------------

    def set_timer(self, tid, period):
        for t in self.timers:
            if t[0] == tid:
                t[1], t[2] = period, self.now + period
                return
        self.timers.append([tid, period, self.now + period])

    def kill_timer(self, tid):
        self.timers = [t for t in self.timers if t[0] != tid]

    def next_due(self):
        return min((t[2] for t in self.timers), default=None)

    def log(self, text):
        if self.trace is not None:
            self.trace.append(f"{self.now} {text}")

    # ---- the occupancy grid (src/serial/backdrop.zig) -----------------------

    @staticmethod
    def index(col, row):
        return (row * GRID_STRIDE + col) & 0xFFFF

    def set_cell(self, col, row, count, obj=None):
        self.grid[self.index(col, row)] = [count, obj]

    def cell(self, idx):
        if idx >= GRID_CELLS:
            return [0, None]
        return self.grid.get(idx, [0, None])

    def span(self, o):
        return range(o.y >> CELL, ((o.h + o.y) >> CELL) + 1), range(o.x >> CELL, ((o.w + o.x) >> CELL) + 1)

    def occupy(self, o):
        if o.x < 0 or o.y < 0:
            return
        rows, cols = self.span(o)
        for col in cols:
            for row in rows:
                idx = self.index(col, row)
                if idx >= GRID_CELLS:
                    continue
                c = self.cell(idx)[0]
                self.grid[idx] = [i8(c - 1 if c < 0 else c + 1), o]

    def vacate(self, o):
        if o.x < 0 or o.y < 0:
            return
        rows, cols = self.span(o)
        for col in cols:
            for row in rows:
                idx = self.index(col, row)
                if idx >= GRID_CELLS:
                    continue
                c = self.cell(idx)[0]
                self.grid[idx] = [i8(c + 1 if c < 1 else c - 1), None]

    def query(self, x, y, w, h):
        """occupancy_grid_query_rect: (result, flag, obj, first)."""
        res, flag, obj, first = 0, 0, None, None
        if x < 0 or y < 0:
            return -1, 0, None, None
        r0, c0 = y >> CELL, x >> CELL
        for row in range(r0, (h >> CELL) + r0 + 1):
            for col in range(c0, (w >> CELL) + c0 + 1):
                c, o = self.cell(self.index(col, row))
                if c == -1:
                    flag = -1
                elif res == 0:
                    if o is not None:
                        if first is None:
                            first = o
                        obj = o
                    if c > 0:
                        res = c
                    elif c < 0:
                        res = -1 - c
                        flag = -1
                elif c < 0:
                    flag = -1
        if res == 0:
            res = flag
        return res, flag, obj, first

    def can_step(self, o):
        """mover_can_step: (free, linked)."""
        res, flag, obj, first = self.query(o.nx, o.ny, o.w, o.h)
        if res <= 0:
            return res == 0, None
        if flag == -1:
            return False, None
        if obj is None:
            return True, obj
        if obj is o:
            if first is o:
                return True, None
            return False, first
        return False, obj

    # ---- the Mover (src/serial/behaviour/movement.zig) ------------------------

    def line(self, o, dx, dy):
        if dy < dx:
            o.inc_x = dy << 1
            o.err = o.inc_x - dx
            o.inc_diag = o.err - dx
            o.inc_y = 0
        else:
            o.inc_y = dx * -2
            o.err = o.inc_y + dy
            o.inc_diag = o.err + dy
            o.inc_x = 0

    def move_to_edge_h(self, o, d):
        o.step_x, o.step_y = abs(o.step_x), abs(o.step_y)
        o.moving = 1
        o.tx = BG_W - o.w if d == 2 else -trunc_div(o.w, 2)
        o.ty = o.y
        o.nx, o.ny = o.x, o.y
        dx = o.tx - o.nx
        if dx < 0:
            o.step_x, dx = -o.step_x, -dx
        elif dx == 0:
            o.moving = 0
            return
        self.line(o, dx, 1)
        self.set_timer(WALK2 if o.index >= 13 else WALK, 100 if o.index >= 13 else 200)

    def move_to(self, o, x, y):
        o.step_x, o.step_y = abs(o.step_x), abs(o.step_y)
        o.moving = 1
        half = trunc_div(o.w, 2)
        o.tx = BG_W - o.w if BG_W - half < x else x - half
        o.ty = y - o.h  # the background is 480 high: never clamped here
        o.nx, o.ny = o.x, o.y
        dx, dy = o.tx - o.nx, o.ty - o.ny
        if dx < 0:
            o.step_x, dx = -o.step_x, -dx
        if dy < 0:
            o.step_y, dy = -o.step_y, -dy
        elif dy == 0:
            dy = 1
        if dx == 0 and dy == 1:
            o.moving = 0
            return
        self.line(o, dx, dy)
        self.set_timer(BULLET, 0x37)

    @staticmethod
    def step(o):
        e = o.err
        if o.inc_x == 0:
            if e < 1:
                o.nx += o.step_x
                o.ny += o.step_y
                e += o.inc_diag
            else:
                e += o.inc_y
                o.ny += o.step_y
        elif e < 1:
            e += o.inc_x
            o.nx += o.step_x
        else:
            e += o.inc_diag
            o.nx += o.step_x
            o.ny += o.step_y
        o.err = e

    @staticmethod
    def at_target(o):
        if o.inc_x == 0:
            return not abs(o.step_y) < abs(o.ny - o.ty)
        return not abs(o.step_x) < abs(o.nx - o.tx)

    def place_at(self, o, x, y):
        self.vacate(o)
        o.x, o.y = x, y
        self.occupy(o)

    @staticmethod
    def stop_fields(o):
        o.moving = 0
        o.step_x, o.step_y = abs(o.step_x), abs(o.step_y)
        o.tx, o.ty = o.x, o.y

    def fig_stop(self, t):
        """target_stop_moving_dc: no timer kill; hide (vacate)."""
        self.stop_fields(t)
        self.vacate(t)

    def bullet_stop(self, b):
        """projectile_stop_moving_dc: the timer killed, hide (vacate)."""
        self.stop_fields(b)
        self.kill_timer(BULLET)
        self.vacate(b)

    # ---- the figures (src/serial/target.zig, gallery.zig) ---------------------

    @staticmethod
    def lane(i):
        return 0 if i < 7 else 1 if i < 13 else 2

    def destroy(self):
        if self.result is None:
            self.result = (self.now, self.lives, self.score)
            self.log(f"DESTROY lives={self.lives} score={self.score}")

    def move_tick(self, t):
        if not t.moving:
            return
        self.step(t)
        # target_can_step: always free (it only sets `linked`).
        t.frame = 0 if t.frames - t.frame == 1 else t.frame + 1
        self.place_at(t, t.nx, t.ny)
        if KINDS[t.index] == 2 and t.frames - t.frame == 2:
            self.lives = i16(self.lives - 1)
            self.shot_at.append((self.now, t.index))
            self.log(f"SHOT F{t.index} lives={self.lives}")
            if self.lives == 0:
                self.destroy()

    def check_edge(self, t):
        w = t.w
        if t.x <= -trunc_div(w, 2) and t.dir == 1:
            self.fig_stop(t)
            self.busy[self.lane(t.index)] = 0
            self.vacate(t)
            t.x = t.tx = t.nx = BG_W - w
        elif t.x > 0x275 and t.dir == 2:
            self.fig_stop(t)
            self.busy[self.lane(t.index)] = 0
            self.vacate(t)
            t.x = 0x18
        self.move_tick(t)

    def set_pos(self, t, x, y):
        t.x = t.tx = t.nx = x
        t.y = t.ty = t.ny = y

    def place(self, t, x, y, d):
        self.place_at(t, x, y)
        self.occupy(t)  # show
        t.frame = 0
        t.dir = d
        t.moving = 1
        self.move_to_edge_h(t, d)

    def spawn_tick(self):
        if not self.busy[0]:
            t = self.figs[self.rand.rand() % 7]
            t.frame = 0
            self.busy[0] = 1
            self.set_pos(t, 0x14, 1)
            self.place(t, 0x14, 1, 2)
            self.set_pos(t, 0x14, 1)
            self.log(f"SPAWN F{t.index}")
        if not self.busy[1]:
            t = self.figs[self.rand.rand() % 6 + 7]
            x = BG_W - t.w
            t.frame = 0
            self.busy[1] = 1
            self.set_pos(t, x, 0x2D)
            self.place(t, t.nx, 0x2D, 1)
            self.set_pos(t, BG_W - t.w, 0x2D)
            self.log(f"SPAWN F{t.index}")
            self.check_edge(t)
        if self.toggle == 0:
            self.toggle = 1
        else:
            self.toggle = 0
            self.spawn_lane2()

    def spawn_lane2(self):
        if self.rand.rand() % 2 == 0:
            t, x, d = self.figs[13], 0x14, 2
        else:
            t = self.figs[14]
            x, d = BG_W - t.w, 1
        t.frame = 0
        if self.busy[2]:
            return
        self.set_pos(t, x, 0xBE)
        self.busy[2] = 1
        self.place(t, x, 0xBE, d)
        self.set_pos(t, x, 0xBE)
        self.log(f"SPAWN F{t.index}")

    def hit(self, t):
        k = KINDS[t.index]
        self.score = i16(self.score + (100 if k == 1 else 200 if k == 2 else -100))
        self.hits.append((self.now, t.index))
        self.log(f"HIT F{t.index} score={self.score}")
        self.fig_stop(t)
        self.busy[self.lane(t.index)] = 0
        self.vacate(t)  # target_hide_and_blit

    # ---- the bullet (src/serial/bullet.zig, gallery.zig) ----------------------

    def try_step(self, b):
        """projectile_try_step: (moves on, hit)."""
        free, linked = self.can_step(b)
        if free:
            return True, False
        if linked is None or linked.kind != "target":
            return False, False
        return True, abs(linked.y - b.ny) <= trunc_div(linked.h, 2)

    def overlaps(self, b, t):
        w = t.w
        if self.fixes:  # K3
            return b.x <= t.x + w and t.x <= b.x + B_W and b.y <= t.y + t.h and t.y <= b.y + B_H
        if t.x < b.x and b.x + 0x37 < t.x + w:
            return True
        if b.x < t.x < b.x + 0x37:
            return True
        return t.x < b.x and t.x + w < b.x + 0x37 and b.x < t.x + w

    def bullet_tick(self):
        b = self.bullet
        hit = False
        if b.moving:
            self.step(b)
            moves, hit = self.try_step(b)
            if not moves:
                self.bullet_stop(b)
                self.vacate(b)
            else:
                self.place_at(b, b.nx, b.ny)
                if self.at_target(b):
                    self.bullet_stop(b)
        self.log(f"B x={b.x} y={b.y} mv={b.moving} dir={3 if hit else 0}")
        if not hit:
            return
        self.bullet_stop(b)
        for lane, first, last in ((2, 13, 14), (1, 7, 12), (0, 0, 6)):
            if not self.busy[lane]:
                continue
            for i in range(first, last + 1):
                t = self.figs[i]
                if t.moving and self.overlaps(b, t):
                    self.hit(t)
                    return

    # ---- the keys (gallery.zig) ----------------------------------------------

    def key_space(self):
        if self.held[VK_SPACE]:
            return
        if self.fixes:  # K4
            self.held[VK_SPACE] = 1
        b = self.bullet
        if b.moving:
            self.log("SPACE (bullet flying)")
            return
        self.shots.append((self.now, self.aim))
        self.log(f"FIRE aim={self.aim}")
        if self.aim == 2:
            b.x, b.y, dest = GUN_X + 0xA2, GUN_Y - 0x14, 0x280
        elif self.aim == 1:
            b.x, b.y, dest = GUN_X + 0x61, GUN_Y - 0x1E, 0x145
        else:
            b.x, b.y, dest = GUN_X + 0x2A, GUN_Y - 0x1E, 0
        self.move_to(b, dest, 10)

    def key(self, name, down):
        if not down:
            if name in self.held:
                self.held[name] = 0
            return
        if name == VK_SPACE:
            self.key_space()
        elif name in (VK_LEFT, VK_RIGHT) and not self.held[name]:
            self.held[name] = 1
            if name == VK_LEFT:
                self.aim = {0: 2, 1: 0, 2: 1}[self.aim]
            else:
                self.aim = {0: 1, 1: 2, 2: 0}[self.aim]
            self.set_timer(GUN, 0x3C)  # gun_play

    # ---- the loop ------------------------------------------------------------

    def walk(self, i):
        t = self.figs[i]
        if t.moving:
            self.check_edge(t)
            self.log(f"F{i} x={t.x} f={t.frame} mv={t.moving} lives={self.lives}")

    def systimer(self, tid):
        if tid == GUN or tid == APP:
            return  # the gun's redraw (and the dead lane-2 branch, K5); the app's timer
        if tid == LANE2_OWN and self.k5:
            self.spawn_lane2()  # K5: lane 2's own 5-s timer
            return
        if tid == WALK:
            for i in range(13):
                self.walk(i)
        elif tid == WALK2:
            self.walk(13)
            self.walk(14)
        elif tid == SPAWN:
            self.spawn_tick()
        elif tid == BULLET:
            self.bullet_tick()
        elif tid == CLOCK:
            if self.clock < 1:
                self.clock += 1
            else:
                self.destroy()

    def run(self, events, until):
        """`events`: sorted (time, key, down). Runs to `until` or the end."""
        ev = list(events)
        k = 0
        while self.result is None:
            due = self.next_due()
            et = ev[k][0] if k < len(ev) else None
            early = k < len(ev) and len(ev[k]) > 3
            if due is not None and (et is None or due < et or (due == et and not early)):
                if due > until:
                    break
                self.now = max(self.now, due)
                for t in self.timers:
                    if t[2] <= self.now:
                        t[2] = self.now + t[1]
                        self.systimer(t[0])
                        break
                continue
            if et is None or et > until:
                break
            self.now = max(self.now, et)
            self.key(ev[k][1], ev[k][2])
            k += 1
        return self.result

    def reported(self):
        """The 0x40a result as the host records it: (won, score)."""
        if self.result is None:
            return None
        _, lives, score = self.result
        hi = score if lives < 1 else 500
        won = lives > 0 if self.fixes else True  # K1
        if self.fixes:  # K2
            return won, hi
        v = ((hi & 0xFFFF) << 16) | (lives & 0xFFFF)
        return won, v - (1 << 32) if v >= 1 << 31 else v


# ---- scripts -------------------------------------------------------------------


REPEAT = (500, 33)  # Windows' key repeat (sim.KeyRepeat), what a run has by default


def parse_script(path, relative_to, repeat=REPEAT):
    """(time, key, down) from a script's `key`/`hold` lines. A `hold`
    repeats its key (a WM_KEYDOWN each) as the harness does: after
    `repeat[0]` ms, then every `repeat[1]` ms, while it is held (4th item
    True: the repeat goes before the timers due at that time, a script's
    own key goes after them); `key` (50 ms) never lasts that long. `repeat`
    None: held keys do not repeat. One held key at a time."""
    out = []
    prev = relative_to
    for line in open(path):
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        parts = line.split()
        if parts[0].startswith("+"):
            t = (prev or 0) + int(parts[0][1:])
        else:
            try:
                t = int(parts[0])
            except ValueError:
                continue
        prev = t
        if parts[1] == "key":
            out += [(t, parts[2], True), (t + 50, parts[2], False)]
        elif parts[1] == "hold":
            ms = int(parts[3])
            out += [(t, parts[2], True), (t + ms, parts[2], False)]
            if repeat:
                out += [(r, parts[2], True, True) for r in range(t + repeat[0], t + ms, repeat[1])]
    return sorted(out, key=lambda e: e[0])


def aim_keys(cur, want):
    """The LEFT/RIGHT presses from aim `cur` to `want` (right wraps 2 → 0)."""
    if cur == want:
        return []
    if (cur + 1) % 3 == want:
        return [VK_RIGHT]
    return [VK_LEFT]


AIMS = {0: "left", 1: "straight", 2: "right"}
NAMES = ("3sarab", "3sbaba", "3sbabt", "3sclu", "3sfada", "3shitl", "3slenn", "3smafi",
         "3snoel", "3snoem", "3svelh", "3sesco", "3spira", "3skenn", "3scoel")


def wanted(win, i):
    return KINDS[i] == 2 if win else KINDS[i] != 2


def candidate(sims, t, last_press, win, lead=None, loose=False):
    """The first aim (straight, left, right) whose shot at `t` the plan
    keeps (one that hits in version `lead` when it is given; `loose`: the
    other version may hit a figure of the other kind): (aim,
    events, (figure hit in each version or None)); None if
    none; "skip" when no shot is possible near `t` (a bullet flying, no
    wanted figure walking); "end" when a game is over."""
    probes = [copy.deepcopy(s) for s in sims]
    for p in probes:
        p.run([], t)
    if any(p.result is not None for p in probes):
        return "end"
    if any(p.bullet.moving for p in probes) or not any(
            f.moving and wanted(win, f.index) for p in probes for f in p.figs):
        return "skip"
    for aim in (1, 0, 2):
        k = aim_keys(sims[1].aim, aim)
        at = t - 120 * len(k)
        if last_press is not None and at < last_press + 110:
            continue
        pre = []
        for j, name in enumerate(k):
            pre += [(at + 120 * j, name, True), (at + 120 * j + 50, name, False)]
        pre += [(t, VK_SPACE, True), (t + 50, VK_SPACE, False)]
        got = []
        for s in sims:
            c = copy.deepcopy(s)
            c.run(pre[:-2], t - 1)
            if c.bullet.moving or c.result is not None:
                got = None
                break
            n = len(c.hits)
            c.run(pre[-2:], t + 50)
            c.run([], t + 3000)
            if c.bullet.moving:
                got = None
                break
            got.append([i for (_, i) in c.hits[n:]])
        if got is None or any(len(h) > 1 for h in got):
            continue
        good = [bool(h) and wanted(win, h[0]) for h in got]
        if not loose and any(h and not ok for h, ok in zip(got, good)):
            continue
        if not any(good) or (lead is not None and not good[lead]):
            continue
        return aim, pre, tuple(h[0] if h else None for h in got)
    return None


def plan(start, win, horizon=120_000, lookahead=0, lead=None, loose=False):
    """Greedy: each shot is the earliest (aim, time) whose bullet hits at
    most one figure in each version, only of the wanted kind (win: a
    killer; lose: anything else), and one in at least one version, with no
    key after either game's end; a shot that hits in one version only
    gives way to one that hits in both within `lookahead` ms; with `lead`
    (0 the Original, 1 the Corrigida) every shot hits in that version;
    `loose` lets a shot hit a figure of the other kind in one version
    (the win's result does not depend on the score). The versions
    play different games (K5 changes the spawns), so a shot may hit two
    figures or one and miss in the other. Returns the events, the notes
    and the two simulations."""
    sims = [Sim(start, False), Sim(start, True)]
    events, notes = [], []
    t = start + 300
    last_press = None
    end = start + horizon
    while t < end - 1500:
        found = candidate(sims, t, last_press, win, lead, loose)
        if found == "end":
            break
        if found == "skip":
            t += 50
            continue
        if found is None:
            t += 10
            continue
        if None in found[2] and lookahead:
            u = t + 10
            while u <= t + lookahead and u < end - 1500:
                c = candidate(sims, u, last_press, win, lead, loose)
                if c == "end":
                    break
                if isinstance(c, tuple) and None not in c[2]:
                    t, found = u, c
                    break
                u += 50
        aim, pre, figs = found
        for s in sims:
            s.run(pre, t + 50)
        events += pre
        notes.append((t, aim, figs))
        last_press = t
        t += 160
    for s in sims:
        s.run([], end + 100)
    return events, notes, sims


def fig_name(fig):
    return "a miss" if fig is None else f"{NAMES[fig]} (figure {fig}, kind {KINDS[fig]})"


def script_lines(events, notes):
    """`key` lines, each shot's aim keys and SPACE under one comment."""
    lines = []
    k = 0
    for i, (t, aim, figs) in enumerate(notes):
        if figs[0] == figs[1]:
            hit = fig_name(figs[0])
        else:
            hit = f"Original {fig_name(figs[0])}, Corrigida {fig_name(figs[1])}"
        lines.append(f"# shot {i + 1}: {AIMS[aim]}, {hit}")
        while k < len(events) and events[k][0] <= t:
            et, name, down = events[k]
            if down:
                lines.append(f"{et} key {name}")
            k += 1
    return lines


def describe(s):
    if s.result is None:
        return "no result"
    won, score = s.reported()
    return f"{'won' if won else 'lost'} {score} at {s.result[0]} ms (lives {s.result[1]}, score {s.result[2]})"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--start", type=int, default=0, help="ms of SERIAL's WM_CREATE (srand seed)")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--win", action="store_true")
    g.add_argument("--lose", action="store_true")
    g.add_argument("--check", metavar="FILE", help="simulate a script and print the result")
    g.add_argument("--trace", metavar="FILE", help="simulate a script and print every tick")
    ap.add_argument("--fix", help="with --check/--trace: 'all' for the Corrigida "
                                  "('all,-serial_lane2_own_timer': without K5)")
    ap.add_argument("--ms", type=int, default=130_000, help="with --check/--trace: run until")
    ap.add_argument("--relative-to", type=int, metavar="MS",
                    help="write `+N` times, the first from MS (a `wait` line's entry); "
                         "with --check, read them so")
    ap.add_argument("--key-repeat", default="500,33", metavar="DELAY,PERIOD|off",
                    help="with --check/--trace: the repeat of a held key (the run's --key-repeat)")
    ap.add_argument("--lookahead", type=lambda v: [int(x) for x in v.split(",")],
                    default=[0, 2000], metavar="MS,…",
                    help="the lookaheads tried in turn until the plan works, with no lead "
                         "version, then the Corrigida's, then the Original's")
    ap.add_argument("-o", "--output")
    a = ap.parse_args()
    if a.check or a.trace:
        fix = (a.fix or "").split(",")
        s = Sim(a.start, "all" in fix, "all" in fix and "-serial_lane2_own_timer" not in fix)
        if a.trace:
            s.trace = []
        rep = None if a.key_repeat == "off" else tuple(int(v) for v in a.key_repeat.split(","))
        s.run(parse_script(a.check or a.trace, a.relative_to, rep), a.ms)
        if a.trace:
            print("\n".join(s.trace))
        for t, i in s.hits:
            print(f"{t} hit figure {i} ({NAMES[i]}, kind {KINDS[i]})")
        for t, i in s.shot_at:
            print(f"{t} figure {i} ({NAMES[i]}) shoots")
        print(f"{len(s.shots)} shots; result {describe(s)}")
        return
    looses = (False, True) if a.win else (False,)
    tries = [(look, lead, lo) for lo in looses for lead in (None, 1, 0) for look in a.lookahead]
    for look, lead, lo in tries:
        events, notes, sims = plan(a.start, a.win, lookahead=look, lead=lead, loose=lo)
        if all(x.result is not None and (x.result[1] > 0) == a.win for x in sims):
            break
    for s in sims:
        if s.result is None:
            raise SystemExit(f"no result: {describe(sims[0])} / {describe(sims[1])}")
        if (s.result[1] > 0) != a.win:
            raise SystemExit(f"the plan does not {'win' if a.win else 'lose'}: "
                             f"{describe(sims[0])} / {describe(sims[1])}")
        if events and events[-1][0] >= s.result[0]:
            raise SystemExit("a key comes after the end")
    lines = script_lines(events, notes)
    if a.relative_to is not None:
        prev = a.relative_to
        rel = []
        for line in lines:
            if line.startswith("#"):
                rel.append(line)
                continue
            t, rest = line.split(" ", 1)
            rel.append(f"+{int(t) - prev} {rest}")
            prev = int(t)
        lines = rel
    text = "\n".join(lines) + "\n"
    if a.output:
        open(a.output, "w").write(text)
    else:
        sys.stdout.write(text)
    print(f"# {len(notes)} shots; Original: {describe(sims[0])}; Corrigida: {describe(sims[1])}",
          file=sys.stderr)


if __name__ == "__main__":
    main()
