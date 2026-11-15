#!/usr/bin/env python3
"""Plan JARDIM's Corrigida routes (the Wolf-like movement and the fair enemies) against the port.

    nix develop -c python3 tools/jardim_plan.py --win OUT      # the three phases, the goal
    nix develop -c python3 tools/jardim_plan.py --lose OUT     # stand by the Seios until lost
    nix develop -c python3 tools/jardim_plan.py --check FILE   # the probe's summary of a script

The enemies chase and attack on their own clocks and react to where the player is, so the
planner asks the port instead of simulating it: a probe build (`zig build -Djardim-probe
--prefix zig-out/probe`: no motion frames, which change no state, and the fair enemies' log
on every game tick, src/jardim/enemies.zig) runs `--minigame jardim --fix all` with the
script so far; the planner reads the player, the enemies and the map's objects and doors at
the script's end, adds the next action and probes again (the run is deterministic and the
script's times are relative to JARDIM's WM_CREATE, so what came before does not change).

The route rules: a crossbow first in phase 1; shoot an enemy the weapon kills (phase 1: the
crossbow kills Bussuf, the bra Seios; phase 2: any weapon Alemao, the bazooka Siri; phase 3:
any weapon Chato and Bicho) when it is within 7 cells in a clear line; walk around the rest
(a BFS over the map, enemy cells closed, the cells next to them dear, beers and phase 1's bras
avoided); a medkit within 14 steps when health is low, arrows or a crossbow when ammunition is
low; doors opened with E on the way; the exit doors with E (phase 1 row 77 col 0, phase 2 row
79 col 42), the goal walked into. The moves are the Corrigida's keys: Left/Right held
for the turn's tics (14 angle units each), W (Shift+W beyond 2.5 cells) for a straight run of
at most 4 cells to a cell's centre, A/D to centre the player across the run, E, Space.
"""

import argparse
import collections
import heapq
import math
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PROBE = ROOT / "zig-out/probe/bin/noite"
SCRATCH = ROOT / "zig-out/jardim-plan"

TIC_MS = 1000 / 70
WALK = 168000 / 65536  # units a tic
RUN = 2 * WALK
TURN = 14  # angle units a tic
FULL = 2880

LINE_RE = re.compile(
    r"^\[(\d+)\] fair player (-?\d+),(-?\d+) a(\d+) hp (-?\d+) lives (-?\d+) ammo (-?\d+) "
    r"weapon (\d+) shot (\d+) score (-?\d+) level (\d+) hits (\d+)/(\d+) \|(.*)$"
)
MAP_RE = re.compile(r"^\[(\d+)\] map(.*)\| doors(.*)$")


def load_map(n):
    walls = {}
    lines = (ROOT / f"assets/JARDIM/RAYMAP{n}.DAT").read_bytes().split(b"\r\n")
    for k in range(80):
        row = 79 - k
        for col, ch in enumerate(lines[k][:57]):
            c = chr(ch)
            v = 0 if c == " " else int(c, 16)
            walls[(col, row)] = v
    return walls


MAPS = {n: load_map(n) for n in (1, 2, 3)}


class State:
    pass


def probe(lines, end, name="probe"):
    """Run the probe to `end` ms; the state at the last tick before it (None if JARDIM ended)."""
    SCRATCH.mkdir(parents=True, exist_ok=True)
    script = SCRATCH / f"{name}.input"
    script.write_text("\n".join(lines) + "\n")
    out = subprocess.run(
        [str(PROBE), "--minigame", "jardim", "--headless", "--ms", str(end), "--fix", "all", "--input", str(script)],
        capture_output=True, text=True, cwd=ROOT,
    )
    st = None
    mp = None
    last_t = 0
    for ln in out.stderr.splitlines() + out.stdout.splitlines():
        m = LINE_RE.match(ln)
        if m:
            t = int(m.group(1))
            if t > end:
                continue
            st = State()
            st.t = t
            st.x, st.y, st.a = int(m.group(2)), int(m.group(3)), int(m.group(4))
            st.hp, st.lives, st.ammo = int(m.group(5)), int(m.group(6)), int(m.group(7))
            st.weapon, st.shot, st.score, st.level = int(m.group(8)), int(m.group(9)), int(m.group(10)), int(m.group(11))
            st.enemies = []
            for tok in m.group(14).split():
                kind, rest = tok.split("@")
                cr, state = rest.split(":")
                c, r = map(int, cr.split(","))
                st.enemies.append((kind, c, r, state))
            last_t = t
            continue
        m = MAP_RE.match(ln)
        if m and int(m.group(1)) <= end:
            objs = {}
            for tok in m.group(2).split():
                cr, k = tok[:-1], tok[-1]
                c, r = map(int, cr.split(","))
                objs[(c, r)] = k
            doors = set()
            for tok in m.group(3).split():
                c, r = map(int, tok.split(","))
                doors.add((c, r))
            mp = (objs, doors)
    if st is None:
        return None, out
    st.objs, st.doors = mp if mp else ({}, set())
    st.ended = last_t < end - 250
    return st, out


def cell(v):
    return v >> 5


def angle_to(dx, dy):
    return int(round(math.atan2(dy, dx) * FULL / (2 * math.pi))) % FULL


def adiff(target, a):
    d = (target - a) % FULL
    return d - FULL if d >= FULL // 2 else d


DIRS = {(1, 0): 0, (0, 1): 720, (-1, 0): 1440, (0, -1): 2160}

KILLS = {  # phase -> kind -> weapons that kill it
    1: {"bussuf": {1}, "seios": {2}},
    2: {"alemao": {1, 2}, "siri": {2}},
    3: {"chato": {1, 2}, "bicho": {1, 2}},
}


class Planner:
    def __init__(self, mode, start_lines, t0):
        self.mode = mode
        self.lines = list(start_lines)
        self.t = t0
        self.stuck = 0
        self.last_pos = None
        self.probes = 0
        self.verbose = True

    def add(self, line):
        self.lines.append(line)

    def wall(self, st, c, r):
        w = MAPS[st.level].get((c, r), 1)
        if 9 <= w <= 12 and (c, r) not in st.doors:
            return 0  # opened
        return w

    def los(self, st, x0, y0, x1, y1, ignore=()):
        n = int(max(abs(x1 - x0), abs(y1 - y0)) / 4) + 1
        for i in range(1, n + 1):
            x = x0 + (x1 - x0) * i / n
            y = y0 + (y1 - y0) * i / n
            c, r = int(x) >> 5, int(y) >> 5
            if (c, r) in ignore:
                continue
            if self.wall(st, c, r) > 0:
                return False
            if (c, r) != (st.x >> 5, st.y >> 5) and (c, r) in st.objs:
                return False
        return True

    def avoid(self, st, k):
        if k == "R":
            return True
        if st.level == 1 and k == "W":
            return True
        if st.level > 1 and k == "W" and st.weapon == 1 and st.ammo >= 3:
            return True
        if k == "C" and st.weapon == 2 and st.level == 1:
            return True
        return False

    def bfs(self, st, goals, allow_goal_obj=False):
        """Dijkstra from the player's cell to any of `goals` (a set); the path of cells."""
        start = (st.x >> 5, st.y >> 5)
        enemy_cells = {(c, r) for _, c, r, s in st.enemies if s not in ("dying",)}
        near = collections.Counter()
        for kind, c, r, s in st.enemies:
            if s == "dying":
                continue
            w = 3 if s == "idle" else 12
            for dc in (-1, 0, 1):
                for dr in (-1, 0, 1):
                    near[(c + dc, r + dr)] += w
        dist = {start: 0}
        prev = {}
        pq = [(0, start)]
        while pq:
            d, cur = heapq.heappop(pq)
            if d > dist.get(cur, 1e9):
                continue
            if cur in goals and cur != start:
                path = [cur]
                while path[-1] != start:
                    path.append(prev[path[-1]])
                return path[::-1]
            for (dc, dr) in DIRS:
                nb = (cur[0] + dc, cur[1] + dr)
                w = self.wall(st, *nb)
                if w > 0 and not (9 <= w <= 12):
                    continue
                cost = 1 + near[nb]
                if 9 <= w <= 12:
                    cost += 2
                if nb in enemy_cells and not (allow_goal_obj and nb in goals):
                    continue
                k = st.objs.get(nb)
                if k and k not in "*" and nb not in goals and self.avoid(st, k):
                    cost += 60
                nd = d + cost
                if nd < dist.get(nb, 1e9):
                    dist[nb] = nd
                    prev[nb] = cur
                    heapq.heappush(pq, (nd, nb))
        return None

    # ---- actions ----

    def turn(self, st, target, t):
        d = adiff(target, st.a)
        tics = round(abs(d) / TURN)
        if tics == 0:
            return t
        ms = int(round(tics * TIC_MS)) + 2
        self.add(f"{t} hold {'left' if d > 0 else 'right'} {ms}")
        return t + ms + 20

    def walk(self, dist_units, t, back=False):
        if dist_units < 2:
            return t
        run = dist_units > 80 and not back
        speed = RUN if run else (WALK * 2 / 3 if back else WALK)
        ms = int(round(dist_units / speed * TIC_MS))
        if ms < 15:
            return t
        if run:
            self.add(f"{t} hold shift {ms + 20}")
        self.add(f"{t} hold {'s' if back else 'w'} {ms}")
        return t + ms + 20

    def strafe(self, dist_units, left, t):
        ms = int(round(abs(dist_units) / WALK * TIC_MS))
        if ms < 15:
            return t
        self.add(f"{t} hold {'a' if left else 'd'} {ms}")
        return t + ms + 20

    # ---- the loop ----

    def step(self):
        st, out = probe(self.lines, self.t, "probe-" + self.mode)
        self.probes += 1
        if st is None:
            raise SystemExit("no state: " + out.stderr[-2000:])
        return st

    def threat_shot(self, st):
        """An enemy to shoot now: (angle, distance cells) or None."""
        if st.ammo <= 0 or st.weapon == 0 or st.shot:
            return None
        kills = KILLS[st.level]
        best = None
        for kind, c, r, s in st.enemies:
            if s in ("dying", "idle") and not (s == "idle" and max(abs(c - (st.x >> 5)), abs(r - (st.y >> 5))) <= 3):
                continue
            if st.weapon not in kills.get(kind, ()):
                continue
            ex, ey = c * 32 + 16, r * 32 + 16
            d = math.hypot(ex - st.x, ey - st.y) / 32
            if d > 7:
                continue
            if not self.los(st, st.x, st.y, ex, ey, ignore={(c, r)}):
                continue
            if best is None or d < best[1]:
                best = (angle_to(ex - st.x, ey - st.y), d, kind)
        return best

    def goals(self, st):
        """The cells to walk to and what to do there."""
        objs = st.objs
        pc = (st.x >> 5, st.y >> 5)

        def of(k):
            return {p for p, v in objs.items() if v == k}

        if self.mode == "lose":
            b = {(c, r) for kind, c, r, s in st.enemies if kind == "seios" and s != "dying"}
            near = set()
            for c, r in b:
                for dc, dr in DIRS:
                    if self.wall(st, c + dc, r + dr) == 0:
                        near.add((c + dc, r + dr))
            return near, "wait"
        if st.level == 1 and st.weapon != 1 and st.ammo <= 0:
            return of("C"), None
        if st.hp < 55 and of("M"):
            p = self.bfs(st, of("M"))
            if p and len(p) <= 15:
                return of("M"), None
        if st.weapon == 1 and st.ammo < 4:
            p = self.bfs(st, of("a") | of("C"))
            if p and len(p) <= 9:
                return of("a") | of("C"), None
        if st.weapon != 1 and st.ammo <= 0:
            p = self.bfs(st, of("C"))
            if p and len(p) <= 20:
                return of("C"), None
        if st.level == 1:
            return {(1, 77)}, ("exit", 1440)
        if st.level == 2:
            return {(42, 78)}, ("exit", 720)
        return of("F"), "final"

    def run(self, limit_ms):
        while self.t < limit_ms:
            st = self.step()
            if st.ended:
                return st
            if self.mode == "lose" and st.lives <= 0:
                return st
            t = self.t
            pos = (st.x, st.y, st.a)
            if self.verbose:
                near = [e for e in st.enemies if e[3] not in ("idle",)]
                print(f"[{st.t}] L{st.level} ({st.x},{st.y}) c{st.x >> 5},{st.y >> 5} a{st.a} hp {st.hp} lives {st.lives} ammo {st.ammo} w{st.weapon} score {st.score} {near[:4]}", file=sys.stderr)
            if self.mode == "lose":
                # A Seios in sight within 4 cells: face it and wait for it.
                face = None
                for kind, c, r, s_ in st.enemies:
                    if kind != "seios" or s_ == "dying":
                        continue
                    ex, ey = c * 32 + 16, r * 32 + 16
                    if math.hypot(ex - st.x, ey - st.y) <= 4.5 * 32 and self.los(st, st.x, st.y, ex, ey, ignore={(c, r)}):
                        face = angle_to(ex - st.x, ey - st.y)
                if face is not None:
                    t2 = self.turn(st, face, t) if abs(adiff(face, st.a)) > 40 else t
                    self.t = max(t2, t) + 300
                    continue
            # Shoot first.
            sh = self.threat_shot(st)
            if sh:
                t = self.turn(st, sh[0], t)
                self.add(f"{t} key space")
                self.t = t + int(sh[1] * 105) + 250
                continue
            goals, what = self.goals(st)
            pc = (st.x >> 5, st.y >> 5)
            if what == "wait" and pc in goals:
                self.t = t + 1000
                continue
            if isinstance(what, tuple) and pc in goals:
                # Centre, face the exit door, E.
                t = self.centre(st, t, None)
                st2 = st
                t = self.turn(st2, what[1], t)
                self.add(f"{t} key e")
                self.t = t + 400
                continue
            path = self.bfs(st, goals, allow_goal_obj=(what == "final"))
            if path is None or len(path) < 2:
                self.t = t + 300
                continue
            nxt = path[1]
            dirv = (nxt[0] - pc[0], nxt[1] - pc[1])
            ang = DIRS[dirv]
            # A closed door ahead: open it.
            w = self.wall(st, *nxt)
            if 9 <= w <= 12:
                t = self.centre(st, t, dirv)
                t = self.turn(st, ang, t)
                self.add(f"{t} key e")
                self.t = t + 300
                continue
            # The straight run: up to 4 cells.
            n = 1
            while n + 1 < len(path) and n < 4:
                a, b = path[n], path[n + 1]
                if (b[0] - a[0], b[1] - a[1]) != dirv or 9 <= self.wall(st, *b) <= 12:
                    break
                n += 1
            target = path[n]
            # Lateral centring first (strafe), then the turn, then the walk.
            t = self.centre(st, t, dirv)
            t = self.turn(st, ang, t)
            if dirv[0]:
                dist = abs(target[0] * 32 + 16 - st.x)
            else:
                dist = abs(target[1] * 32 + 16 - st.y)
            if what == "final" and target in goals:
                dist += 8
            t = self.walk(dist, t)
            if self.last_pos == pos:
                self.stuck += 1
            else:
                self.stuck = 0
            self.last_pos = pos
            if self.stuck >= 3:
                t = self.walk(10, t, back=True)
                self.stuck = 0
            self.t = t + 100
        return None

    def centre(self, st, t, dirv):
        """Strafe the player onto the cell's centre across the direction `dirv` (both axes if
        None), relative to the current facing."""
        ox = st.x - ((st.x >> 5) * 32 + 16)
        oy = st.y - ((st.y >> 5) * 32 + 16)
        if dirv is None:
            # Walk to the centre: turn is not needed for small offsets; strafe/walk relative.
            off = [(ox, (1, 0)), (oy, (0, 1))]
        else:
            off = [(ox, (1, 0))] if dirv[1] else [(oy, (0, 1))]
        for o, axis in off:
            if abs(o) <= 3:
                continue
            # The axis direction relative to the view: left is angle + 720.
            want = DIRS[(-axis[0] if o > 0 else axis[0], -axis[1] if o > 0 else axis[1])]
            rel = adiff(want, st.a)
            if abs(rel - 720) < 200:
                t = self.strafe(abs(o), True, t)
            elif abs(rel + 720) < 200:
                t = self.strafe(abs(o), False, t)
            elif abs(rel) < 200:
                t = self.walk(abs(o), t)
            elif abs(abs(rel) - 1440) < 200:
                t = self.walk(abs(o), t, back=True)
        return t


def main():
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--win", metavar="OUT")
    g.add_argument("--lose", metavar="OUT")
    g.add_argument("--check", metavar="FILE")
    ap.add_argument("--ms", type=int, default=400000)
    args = ap.parse_args()
    if not PROBE.exists():
        subprocess.run(["zig", "build", "-Djardim-probe", "--prefix", "zig-out/probe"], cwd=ROOT, check=True)
    if args.check:
        lines = [l for l in pathlib.Path(args.check).read_text().splitlines() if l and not l.startswith("#")]
        st, _ = probe(lines, args.ms)
        print(vars(st))
        return
    mode = "win" if args.win else "lose"
    p = Planner(mode, ["300 key return", "500 dump start"], 400)
    st = p.run(args.ms)
    out = pathlib.Path(args.win or args.lose)
    out.write_text("\n".join(p.lines) + "\n")
    print(f"probes {p.probes}, end {p.t}", file=sys.stderr)
    if st:
        print({k: v for k, v in vars(st).items() if k not in ("objs", "doors")}, file=sys.stderr)


if __name__ == "__main__":
    main()
