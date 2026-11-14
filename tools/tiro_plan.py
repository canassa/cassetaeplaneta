#!/usr/bin/env python3
"""Plan a TIRO (Tiro ao Álvaro) game and write it as an input script.

    nix develop -c python3 tools/tiro_plan.py [--start MS] (--win|--lose)
        [--relative-to MS] [-o FILE]
    nix develop -c python3 tools/tiro_plan.py --start MS --check FILE [--fix all]
    nix develop -c python3 tools/tiro_plan.py --start MS --trace FILE

The targets' pictures come from `rand() % 10` after `srand(GetTickCount())`
in tiro_create_targets, at TIRO's WM_CREATE: `--start` is that time (0
alone, WinExec + 1500 ms from NOITE's 3fhall). The planner simulates the
game as docs/tiro/GAME.md describes it, on the virtual clock, down to
what decides a hit:

- the system timers in USER's table order (a killed timer set again goes
  to the end; several due at once fire in table order; a key pressed at
  a time is handled after the timers due then);
- the targets (100 ms steps of 20 px, the wraps and re-arms, the pair
  guards, the 8-tick hit animation at 55 ms and the respawn), every
  `rand()` in the game's order;
- the arrow (Bresenham steps of 10 px every 55 ms) and the occupancy grid
  it queries (32-px cells: counts and last occupant, the wall cells, every
  occupy/vacate the targets and the arrow do, stale cells included), so
  the first hit stage (`projectile_try_step`) is the game's; then the
  second stage (BUGS.md T5) in both versions.

It plays 15 SPACE presses (TIRO ends at the first target tick after the
15th, BUGS.md T3/T4), each fired with the arrow free and at least 110 ms
after the last, so the Original and the Corrigida (`--fix all`; T2 and T4
are not in it) play the same game: a win hits girls and never a
traveco; a loss hits nothing but travecos. The aim keys come before a
shot. It checks its own plan in both versions; the scripts are then
checked by running them (`result won N`). `--check FILE` simulates a
script (`key`/`hold` lines, absolute or `+N` times relative to
`--relative-to`), `--trace FILE` too and prints every tick.
"""

import argparse
import copy
import sys

# ---- the game's constants (src/tiro/*.zig, docs/tiro/GAME.md) ----------------

BG_W = 640
CELL = 5  # 32-px cells
GRID_STRIDE, GRID_CELLS = 81, 81 * 65
T_W, T_H = 75, 95  # target strips (hit box 0, 0, 75, 95)
A_W, A_H = 55, 27  # arrow strips
CB_X, CB_Y = 200, 0x17C  # the crossbow
TARGET_PERIOD, HIT_PERIOD, ARROW_PERIOD, CB_PERIOD, APP_PERIOD = 100, 0x37, 0x37, 0x3C, 50
STEP_T, STEP_A = 20, 10
HIT_FRAMES = 8
ROW_Y = (0x55, 0x55, 0x82, 0x82)
GIRLS = 3  # identities 0-2 are girls, 3-9 travecos
LIVES = 16
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


class Obj:
    """A Mover (target or arrow): position, Bresenham line, timer."""

    def __init__(self, kind, timer, w, h, x, y):
        self.kind, self.timer, self.w, self.h = kind, timer, w, h
        self.x, self.y, self.nx, self.ny = x, y, x, y
        self.moving = 0
        self.step_x = self.step_y = STEP_T if kind == "target" else STEP_A
        self.tx = self.ty = 0
        self.err = self.inc_x = self.inc_y = self.inc_diag = 0
        self.strip = 0
        # Target only.
        self.dir = 0
        self.running = 0
        self.hit_frame = -1
        self.index = -1


class Sim:
    def __init__(self, start, fixes=False):
        self.now = start
        self.fixes = fixes  # Fixes.all(): T1, T3, T5, T6 (T2, T4 are choices)
        self.rand = Rand(start)
        self.timers = []  # [id, period, due], USER's table order
        self.grid = {}  # index -> [count, occupant]
        self.score = 0
        self.lives = LIVES
        self.aim = 0  # mover_show leaves curFrame 0: the crossbow starts aimed left
        self.held = {VK_SPACE: 0, VK_LEFT: 0, VK_RIGHT: 0}
        self.result = None  # (time, score) of WM_DESTROY
        self.hits = []  # (time, target index, identity)
        self.shots = []  # (time, aim)
        self.trace = None
        # tiro_backdrop_create: the wall cells.
        for row in range(5, 0xE):
            self.set_cell(0, row, -1)
            self.set_cell(0x13, row, -1)
        for col in range(0x13):
            self.set_cell(col, 0xD, -1)
        # game_init: the crossbow (rows 11-15, never queried: left out);
        # tiro_create_targets.
        self.targets = []
        xs = (44, 207, 124, 287)
        for i in range(4):
            t = Obj("target", 0xC + i, T_W, T_H, xs[i], ROW_Y[i])
            t.index = i
            self.targets.append(t)
        for i in range(2):
            self.targets[i].strip = self.rand.rand() % 10
            self.targets[2 + i].strip = self.rand.rand() % 10
        for t in self.targets:
            self.occupy(t)
            if t.index < 2:
                self.move_to_edge_h(t, 2)
                t.dir = 2
            else:
                self.move_to_edge_h(t, 1)
                t.dir = 1
            t.hit_frame = -1
        # tiro_create_arrows: shown at (0, 0x17c) with strip 0.
        self.arrow = Obj("arrow", 0x10, A_W, A_H, 0, CB_Y)
        self.occupy(self.arrow)
        self.arrow.strip = 1
        # AppWndProc's WM_CREATE: system timer 1.
        self.set_timer(1, APP_PERIOD)

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

    # ---- the occupancy grid (src/tiro/backdrop.zig) -------------------------

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

    # ---- the Mover (src/tiro/behaviour/movement.zig) -------------------------

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
        o.tx = BG_W - o.w if d == 2 else -(o.w // 2)
        o.ty = o.y
        o.nx, o.ny = o.x, o.y
        dx = o.tx - o.nx
        if dx < 0:
            o.step_x, dx = -o.step_x, -dx
        elif dx == 0:
            o.moving = 0
            return
        self.line(o, dx, 1)
        self.set_timer(o.timer, TARGET_PERIOD)

    def move_to(self, o, x, y):
        o.step_x, o.step_y = abs(o.step_x), abs(o.step_y)
        o.moving = 1
        half = o.w // 2
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
        self.set_timer(o.timer, ARROW_PERIOD)

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

    def stop_mover(self, o):
        o.moving = 0
        self.kill_timer(o.timer)
        o.step_x, o.step_y = abs(o.step_x), abs(o.step_y)
        o.tx, o.ty = o.x, o.y

    def target_stop(self, t):
        """target_stop_moving_dc: stop, hide (vacate), place where it is."""
        self.stop_mover(t)
        self.vacate(t)
        self.place_at(t, t.x, t.y)

    def arrow_stop(self, a):
        """projectile_stop_moving_dc: stop, hide (vacate)."""
        self.stop_mover(a)
        self.vacate(a)

    # ---- the targets (src/tiro/target.zig, gallery.zig) --------------------

    def target_move_tick(self, t):
        if not t.moving:
            return
        self.step(t)
        self.place_at(t, t.nx, t.ny)  # target_can_step: always free
        if self.at_target(t):
            self.target_stop(t)

    def check_edge(self, t):
        if t.x <= t.w // 2 and t.dir == 1:
            self.target_stop(t)
            self.vacate(t)
            t.x = t.tx = t.nx = BG_W - t.w
        elif t.x >= BG_W - 2 * t.w and t.dir == 2:
            self.target_stop(t)
            self.vacate(t)
            t.x = 0x18
        else:
            self.target_move_tick(t)

    def rearm(self, t):
        if t.index < 2:
            t.dir, t.y = 2, 0x55
            t.strip = self.rand.rand() % 10
            self.move_to_edge_h(t, 2)
            t.tx, t.x = BG_W, 0x18
        else:
            t.dir, t.y = 1, 0x82
            t.strip = self.rand.rand() % 10
            self.move_to_edge_h(t, 1)
            t.tx, t.x = 0, BG_W - t.w
        t.hit_frame = -1

    def anim_tick(self, t):
        """target_tick: the next hit frame, redrawn (occupies again)."""
        self.occupy(t)

    def hit(self, t):
        self.stop_mover(t)
        self.set_timer(t.timer, HIT_PERIOD)
        girl = t.strip < GIRLS
        self.score += 150 if girl else -150
        self.hits.append((self.now, t.index, t.strip))
        self.log(f"HIT T{t.index} strip={t.strip}")
        t.running = 1
        self.set_timer(t.timer, HIT_PERIOD)
        self.anim_tick(t)
        t.hit_frame += 1

    def respawn(self, t):
        t.strip = 0
        t.running = 0
        self.kill_timer(t.timer)
        self.occupy(t)  # the redraw
        self.set_timer(t.timer, TARGET_PERIOD)
        self.vacate(t)  # hideAndInvalidate
        t.strip = self.rand.rand() % 10
        i = t.index
        if i < 2:
            t.dir = 2
            t.x = t.tx = t.nx = 0x18
            if i == 0 or abs(self.targets[0].x - t.x) > 0x58:
                self.move_to_edge_h(t, 2)
        else:
            t.dir = 1
            t.x = t.nx = t.tx = BG_W - t.w
            if i == 3 or abs(t.x - self.targets[3].x) > 0xB0:
                self.move_to_edge_h(t, 1)
        t.hit_frame = -1

    @staticmethod
    def pair_guard(a, b, limit):
        d = b.x - a.x
        if abs(d) >= limit:
            return False
        if d < 0 and abs(d) <= limit:
            return False
        return True

    def game_over(self):
        if self.fixes:
            return self.lives <= 1
        return self.lives == 1

    def end_test(self):
        if self.result is None and self.game_over():
            self.result = (self.now, self.score)
            self.log(f"DESTROY score={self.score}")

    def target_tick(self, i):
        t = self.targets[i]
        if i != 2:
            self.end_test()
        if not t.running:
            if i == 2:
                self.end_test()
            waits = False
            if i == 0:
                waits = self.pair_guard(t, self.targets[1], 0x58)
            elif i == 3:
                waits = self.pair_guard(self.targets[2], t, 0xB0)
            if not waits:
                self.check_edge(t)
            if not t.moving:
                self.rearm(t)
        else:
            t.hit_frame += 1
            if t.hit_frame < HIT_FRAMES:
                self.anim_tick(t)
            else:
                self.respawn(t)
        self.log(f"T{i} x={t.x} strip={t.strip} mv={t.moving} hf={t.hit_frame} lives={self.lives}")

    # ---- the arrow (src/tiro/arrow.zig, gallery.zig) -------------------------

    def try_step(self, a):
        """projectile_try_step: (moves on, hit)."""
        free, linked = self.can_step(a)
        if free:
            return True, False
        if linked is None or linked.kind != "target":
            return False, False
        return True, abs(linked.y - a.ny) <= linked.h // 2

    def overlaps(self, a, t):
        if self.fixes:  # T5
            return a.x <= t.x + 0x4B and t.x <= a.x + 0x37 and a.y <= t.y + 0x5F and t.y <= a.y + 0x1B
        if t.x < a.x and a.x + 0x37 < t.x + 0x4B:
            return True
        if a.x < t.x < a.x + 0x37:
            return True
        return t.x < a.x and t.x + 0x4B < a.x + 0x37 and a.x < t.x + 0x4B

    def arrow_tick(self):
        a = self.arrow
        hit = False
        if a.moving:
            self.step(a)
            moves, hit = self.try_step(a)
            if not moves:
                self.arrow_stop(a)
                self.vacate(a)
            else:
                self.place_at(a, a.nx, a.ny)
                if self.at_target(a):
                    self.arrow_stop(a)
        self.log(f"A x={a.x} y={a.y} nx={a.nx} ny={a.ny} mv={a.moving} dir={3 if hit else 0}")
        if not hit:
            return
        self.arrow_stop(a)
        for i in (2, 3, 1, 0):
            t = self.targets[i]
            if self.overlaps(a, t):
                self.hit(t)
                return

    # ---- the keys (gallery.zig) ----------------------------------------------

    def key_space(self):
        if self.held[VK_SPACE]:
            return
        if self.fixes:  # T1
            self.held[VK_SPACE] = 1
        self.lives -= 1  # T2: before the arrow is looked at
        a = self.arrow
        if a.moving:
            self.log(f"SPACE (arrow flying) lives={self.lives}")
            return
        self.shots.append((self.now, self.aim))
        self.log(f"FIRE aim={self.aim} lives={self.lives}")
        if self.aim == 2:
            a.x, a.y, a.strip, dest = CB_X + 0xA2, CB_Y - 0x14, 2, 0x280
        elif self.aim == 1:
            a.x, a.y, a.strip, dest = CB_X + 0x75, CB_Y - 0x1E, 1, 0x14F
        else:
            a.x, a.y, a.strip, dest = CB_X + 0x48, CB_Y - 0x1E, 0, 0
        self.move_to(a, dest, 10)

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
            self.set_timer(10, CB_PERIOD)  # crossbow_play

    # ---- the loop ------------------------------------------------------------

    def systimer(self, tid):
        if tid == 10 or tid == 1:
            return  # the crossbow's redraw; the app's timer
        for t in self.targets:
            if t.timer == tid:
                self.target_tick(t.index)
                return
        if tid == self.arrow.timer:
            self.arrow_tick()

    def run(self, events, until):
        """`events`: sorted (time, key, down). Runs to `until` or the end."""
        ev = list(events)
        k = 0
        while self.result is None:
            due = self.next_due()
            et = ev[k][0] if k < len(ev) else None
            if due is not None and (et is None or due <= et):
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


# ---- scripts -------------------------------------------------------------------


def parse_script(path, relative_to):
    """(time, key, down) from a script's `key`/`hold` lines."""
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
            out += [(t, parts[2], True), (t + int(parts[3]), parts[2], False)]
    return sorted(out, key=lambda e: e[0])


def outcome(sim, t0):
    """The new hits since time t0 (by identity class)."""
    return [(i, s) for (t, i, s) in sim.hits if t >= t0]


def plan(start, win, horizon=120_000):
    """Greedy: each shot is the earliest (aim, time) whose arrow, in both
    versions, hits a girl (win) / a traveco or nothing (lose), and
    nothing else. Returns the events and the comments."""
    sims = [Sim(start, False), Sim(start, True)]
    events, notes = [], []
    t = start + 300
    last_fire = None
    for n in range(15):
        found = None
        tries = 0
        while found is None:
            tries += 1
            if t > start + horizon or tries > 4000:
                raise SystemExit(f"shot {n + 1}: nothing found by {t} ms")
            for aim in ((1, 0, 2) if win else (1, 2, 0)):
                trial = []
                pre = []
                cur = sims[0].aim
                # The aim keys, 120 ms apart, before the shot (at least 110
                # ms after the last press).
                k = aim_keys(cur, aim)
                at = t - 120 * len(k)
                if last_fire is not None and at < last_fire + 110:
                    continue
                for j, name in enumerate(k):
                    pre += [(at + 120 * j, name, True), (at + 120 * j + 50, name, False)]
                pre += [(t, VK_SPACE, True), (t + 50, VK_SPACE, False)]
                ok = True
                for s in sims:
                    c = copy.deepcopy(s)
                    c.run(pre[:-2], t - 1)
                    if c.arrow.moving or c.result is not None:
                        ok = False
                        break
                    shot = len(c.shots)
                    c.run(pre[-2:], t + 50)
                    c.run([], t + 3000)
                    if len(c.shots) != shot + 1 or (n < 14 and (c.arrow.moving or c.result is not None)):
                        ok = False
                        break
                    got = [cls(x) for x in outcome(c, t)]
                    if trial and trial[0] != got:
                        ok = False
                        break
                    trial.append(got)
                    if n < 14 and not (got == ["girl"] if win else got in ([], ["traveco"])):
                        ok = False
                        break
                if not ok:
                    continue
                got = trial[0]
                if n == 14:
                    good = True  # the 15th press ends the game before it lands
                elif win:
                    good = got == ["girl"]
                else:
                    good = got in ([], ["traveco"])
                if good:
                    found = (aim, pre, got)
                    break
            if found is None:
                t += 10
        aim, pre, got = found
        for s in sims:
            s.run(pre, t + 50)
        events += pre
        notes.append((t, aim, got))
        last_fire = t
        t += 110 if n == 13 else 200
    for s in sims:
        s.run([], start + horizon)
    return events, notes, sims


def aim_keys(cur, want):
    """The LEFT/RIGHT presses from aim `cur` to `want` (right wraps 2 → 0)."""
    if cur == want:
        return []
    if (cur + 1) % 3 == want:
        return [VK_RIGHT]
    return [VK_LEFT]


def cls(hit):
    return "girl" if hit[1] < GIRLS else "traveco"


AIMS = {0: "left", 1: "straight", 2: "right"}


def script_lines(events, notes):
    """`key` lines, each shot's aim keys and SPACE under one comment."""
    lines = []
    shots = [t for t, _, _ in notes]
    k = 0
    for i, (t, aim, got) in enumerate(notes):
        what = ", ".join(got) if got else "hits nothing"
        if i == len(notes) - 1:
            what = "TIRO ends at the next target tick"
        lines.append(f"# shot {i + 1}: {AIMS[aim]}, {what}")
        while k < len(events) and events[k][0] <= t:
            et, name, down = events[k]
            if down:
                lines.append(f"{et} key {name}")
            k += 1
    assert len(shots) == 15
    return lines


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--start", type=int, default=0, help="ms of TIRO's WM_CREATE (srand seed)")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--win", action="store_true")
    g.add_argument("--lose", action="store_true")
    g.add_argument("--check", metavar="FILE", help="simulate a script and print the result")
    g.add_argument("--trace", metavar="FILE", help="simulate a script and print every tick")
    ap.add_argument("--fix", help="with --check/--trace: 'all' for the Corrigida")
    ap.add_argument("--ms", type=int, default=120_000, help="with --check/--trace: run until")
    ap.add_argument("--relative-to", type=int, metavar="MS",
                    help="write `+N` times, the first from MS (a `wait` line's entry); "
                         "with --check, read them so")
    ap.add_argument("-o", "--output")
    a = ap.parse_args()
    if a.check or a.trace:
        s = Sim(a.start, a.fix == "all")
        if a.trace:
            s.trace = []
        s.run(parse_script(a.check or a.trace, a.relative_to), a.ms)
        if a.trace:
            print("\n".join(s.trace))
        for t, i, strip in s.hits:
            print(f"{t} hit target {i}: {cls((i, strip))} ({strip})")
        if s.result:
            print(f"{s.result[0]} result {'won' if s.result[1] > 0 else 'lost'} {s.result[1]}")
        else:
            print("result none")
        return
    events, notes, sims = plan(a.start, a.win)
    (r0, r1) = (sims[0].result, sims[1].result)
    if r0 != r1 or r0 is None:
        raise SystemExit(f"the two versions differ: {r0} / {r1}")
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
    girls = sum(1 for _, _, got in notes if got == ["girl"])
    print(f"# {len(notes)} shots, {girls} girl(s); TIRO ends at {r0[0]} ms, "
          f"result {'won' if r0[1] > 0 else 'lost'} {r0[1]}", file=sys.stderr)


if __name__ == "__main__":
    main()
