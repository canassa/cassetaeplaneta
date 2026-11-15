#!/usr/bin/env python3
"""Plan a SAUNA (Sauna Mista) win against the port and write it as an input script.

    nix develop -c python3 tools/sauna_plan.py [--scene 3fsauna --prefix FILE --start MS]
        [-o FILE] [--exe PATH] [-j N]

SAUNA's ghosts turn at random: `srand(GetTickCount())` on 0x401, so a game
follows from the absolute time SAUNA starts and from the moves. The planner
does not model the ghosts; it asks the port, as tools/inv_plan.py does. A
probe runs the target run (`--minigame sauna` alone, or `--scene 3fsauna`
with the `--prefix` lines that start it) with the moves planned so far and
closes SAUNA's window at a time T: the result (a WM_DESTROY with wParam 0)
carries `g_score - 1000`, so the probe reads the score at T. A catch costs
500 (or the game), an eaten ghost adds 500; a peanut adds 100.

The planner models Pacman alone (GAME.md, "Pacman"): the maze's 16-px
cells, his 2x2 block of cells that must hold no wall, one cell per 55 ms
from the arrow that started the run (`moveToEdge` restarts his timer), the
dot test on the four cells at the top left of his position (the first '2'
or '3': +100 a peanut, 0 a cork), the start at (19, 19), whose peanut he
eats as he is placed. So it knows the score at any time; a probe whose
score differs met a ghost (a catch, or an eaten ghost under power, which
stops Pacman off the model).

The moves: an arrow pressed 10 ms after Pacman steps onto a junction turns
him there without a stop (no turn buffering: the arrow must find the first
cell of the new way free), or turns him back anywhere; a run left alone
ends at the wall; a left click one cell past a junction, pressed as he
reaches the cell before it, stops him there (`mover_at_target` stops a walk
within one step of its target); from standing, an arrow after a wait of 0
to 4.4 s. Each move is probed in both versions (Original and `--fix all`)
at its horizon: four cells into the new run, or 150 ms after a stop.

The search is a beam: each level probes the 24 best-ranked moves (the
time they take plus the steps from where they leave Pacman to the nearest
dot left, less 4 per dot eaten on the way) of each of the 10 states kept,
and keeps the 10 best that score as modelled in both versions (fewest dots
left, then nearest the next dot, then soonest), at most 3 from one state
and 2 on one cell; a level that keeps none falls back on the best states
left over. (A
depth-first search, one move at a time, stalled for hours on the last
dots: the ghosts follow Pacman's row or column, and one line of play gets
cornered.) Pacman never meets a
ghost, so P1, P2, P6 and P7 never act and P4, P5, P8 only change pictures:
both versions play the same game (`result won`, 96 peanuts + 1000 =
10600).

Alone, SAUNA starts at 0. From NOITE (`--scene 3fsauna`), `--prefix` is a
script with the right click on the attendant and `--start` the time SAUNA
can take input (after its 0x40c); the probes run the whole NOITE run.
"""

import argparse
import concurrent.futures as cf
import itertools
import os
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
WORK = ROOT / "zig-out" / "sauna-plan"
RESULT = re.compile(r"the minigame (won|lost) \(score (-?\d+)\)")

STEP = 55  # Pacman's timer: one 16-px cell per tick
PRESS = 10  # an arrow or click this long after the step it follows
SETTLE = 30  # after a stop, before the next move
LOOK = 150  # a stop is probed this long after it
AHEAD = 4  # a run is probed this many cells in
WAITS = [0, 110, 275, 550, 825, 1100, 1650, 2200, 3300, 4400]
FIXES = ["", "all"]
BEAM = 10  # states kept per level
PER_PARENT = 3  # of them from one state
PER_CELL = 2  # of them where Pacman stands on one cell
CANDIDATES = 24  # moves probed per state
SPARE = 200  # passing states kept to fall back on
START = (19, 19)  # (300, 304): x = 16 col - 4, y = 16 row
DIRS = {"left": (0, -1), "right": (0, 1), "up": (-1, 0), "down": (1, 0)}
OPPOSITE = {"left": "right", "right": "left", "up": "down", "down": "up"}

_counter = itertools.count()


def load_maze():
    src = (ROOT / "src" / "sauna" / "core" / "game.zig").read_text()
    block = src[src.index("pub const initial_maze"):]
    rows = re.findall(r'^\s*"([ 123]{40})",$', block, re.M)[:30]
    assert len(rows) == 30, len(rows)
    return [list(r) for r in rows]


MAZE = load_maze()


def wall(r, c):
    return r < 0 or c < 0 or r >= 30 or c >= 40 or MAZE[r][c] == "1"


def free(r, c):
    """Pacman at (row, col) (x = 16 col - 4, y = 16 row): his 2x2 block holds no wall."""
    return c >= 1 and not any(wall(r + i, c + j) for i in (0, 1) for j in (0, 1))


def step(pos, d):
    return (pos[0] + DIRS[d][0], pos[1] + DIRS[d][1])


def run_cells(pos, d):
    """The cells of a straight run from `pos` in direction d, to the wall."""
    out = []
    p = step(pos, d)
    while free(*p):
        out.append(p)
        p = step(p, d)
    return out


def eat_cell(dots, r, c):
    """The dot `pacman_restore_background` takes at (r, c): (y>>4, x>>4),
    (y+16, x), (y, x+16), (y+16, x+16), the first with a dot; x>>4 is col-1."""
    for cell in ((r, c - 1), (r + 1, c - 1), (r, c), (r + 1, c)):
        if cell in dots:
            return cell
    return None


def eat_along(dots, score, cells):
    """`dots` and `score` after Pacman steps onto each of `cells`."""
    dots = set(dots)
    for p in cells:
        e = eat_cell(dots, *p)
        if e:
            dots.discard(e)
            if MAZE[e[0]][e[1]] == "2":
                score += 100
    return frozenset(dots), score


def bfs(sources):
    """Steps from the nearest of `sources` to every position."""
    dist = {p: 0 for p in sources}
    frontier = list(sources)
    while frontier:
        nxt = []
        for p in frontier:
            for d in DIRS:
                q = step(p, d)
                if q not in dist and free(*q):
                    dist[q] = dist[p] + 1
                    nxt.append(q)
        frontier = nxt
    return dist


ALL_DOTS = frozenset((r, c) for r in range(30) for c in range(40) if MAZE[r][c] in "23")
POSITIONS = list(bfs([START]))
# DIST[dot][pos]: steps from pos to the nearest position whose dot test covers the dot.
DIST = {
    d: bfs([p for p in POSITIONS if d in ((p[0], p[1] - 1), (p[0] + 1, p[1] - 1), p, (p[0] + 1, p[1]))])
    for d in ALL_DOTS
}


def dist_to_dot(pos, dots):
    """Steps from `pos` to the nearest position that eats a dot left."""
    return min((DIST[d].get(pos, 999) for d in dots), default=0)


class Probe:
    def __init__(self, args):
        self.exe = args.exe
        self.scene = args.scene
        self.prefix = args.prefix.read_text().splitlines() if args.prefix else []
        self.count = 0
        WORK.mkdir(parents=True, exist_ok=True)

    def run(self, moves, close, fix, want_end=False):
        """What SAUNA reports for `moves`, its window closed at `close` (or
        left to win, `want_end`): ('won'|'lost', score before the ±1000),
        or None (no result)."""
        self.count += 1
        path = WORK / f"p{os.getpid()}-{next(_counter)}.input"
        lines = list(self.prefix)
        lines += [f"{t} {cmd}" for t, cmd in moves]
        if not want_end:
            lines.append(f"{close} close")
        lines.append(f"{close + 300} result none")
        path.write_text("\n".join(lines) + "\n")
        cmd = [self.exe, "--headless", "--ms", str(close + 400), "--input", str(path)]
        cmd += ["--scene", self.scene] if self.scene else ["--minigame", "sauna"]
        if fix:
            cmd += ["--fix", fix]
        out = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, errors="replace").stderr
        path.unlink(missing_ok=True)
        if "panic" in out:
            sys.exit(f"the port panicked on a probe:\n{out}")
        m = RESULT.search(out)
        if not m:
            return None
        kind, score = m.group(1), int(m.group(2))
        return kind, score + (1000 if kind == "lost" else -1000)


class State:
    """Pacman at `pos` at time `at`, running `dir` (None: standing), with
    `dots` left and `score`. Running, `at` is the arrow that turned him at
    `pos`: he steps on every 55 ms after it. `moves` are (time, command),
    None for a run that ends at the wall; `probe` is the (time, score, game
    still on) the last move is checked at, `rank` how good it looks from
    its parent."""

    def __init__(self, moves, pos, at, dir, dots, score, probe=None, rank=0.0):
        self.moves, self.pos, self.at, self.dir, self.dots, self.score = moves, pos, at, dir, dots, score
        self.probe, self.rank = probe, rank


def child(st, cmd, t, pos, at, dir, passed, cost, penalty=0.0):
    """The state after `cmd` at `t`, Pacman having stepped onto `passed`."""
    dots, score = eat_along(st.dots, st.score, passed)
    if dir is None:
        probe = (at + LOOK, score, bool(dots))
    else:
        ahead = run_cells(pos, dir)[:AHEAD]
        left, ahead_score = eat_along(dots, score, ahead)
        probe = (at + STEP * len(ahead) + (LOOK if len(ahead) < AHEAD else 20), ahead_score, bool(left))
    eaten = len(st.dots) - len(dots)
    rank = cost / STEP + dist_to_dot(pos, dots) - 4 * eaten + penalty
    if not dots:
        rank = -1000
    return State(st.moves + [(t, cmd)], pos, at, dir, dots, score, probe, rank)


def candidates(st):
    """Every move from `st`, best first."""
    out = []
    if st.dir is not None and not free(*step(st.pos, st.dir)):
        # An arrow into a wall: the next tick finds the step blocked and
        # stops him where he is.
        st = State(st.moves, st.pos, st.at + STEP, None, st.dots, st.score)
    if st.dir is None:
        for d in DIRS:
            if not free(*step(st.pos, d)):
                continue
            for w in WAITS:
                t = st.at + SETTLE + w
                out.append(child(st, f"key {d}", t, st.pos, t, d, [], SETTLE + w, w / STEP * 0.6))
        return sorted(out, key=lambda s: s.rank)[:40]
    run = run_cells(st.pos, st.dir)
    for k, cell in enumerate(run, start=1):
        arrive = st.at + STEP * k
        passed = run[:k]
        if k == len(run):
            # The wall: he stops.
            out.append(child(st, None, None, cell, arrive, None, passed, arrive - st.at))
            continue
        turns = [d for d in DIRS if d not in (st.dir, OPPOSITE[st.dir]) and free(*step(cell, d))]
        t = arrive + PRESS
        for d in turns:
            out.append(child(st, f"key {d}", t, cell, t, d, passed, t - st.at))
        if turns or k <= 2:
            back = OPPOSITE[st.dir]
            out.append(child(st, f"key {back}", t, cell, t, back, passed, t - st.at, 6))
        if turns:
            # Stop on this junction: a click one cell past it as he reaches
            # the cell before (the walk restarts his timer).
            tc = st.at + STEP * (k - 1) + PRESS
            past = step(cell, st.dir)
            cmd = f"click {16 * past[1] + 16} {16 * past[0] + 40}"
            out.append(child(st, cmd, tc, cell, tc + STEP, None, passed, tc + STEP - st.at, 1))
    return sorted(out, key=lambda s: s.rank)[:40]


def check(probe, st):
    """True when the move scores as modelled in both versions."""
    moves = [m for m in st.moves if m[1] is not None]
    when, score, on = st.probe
    for fix in FIXES:
        if on:
            res = probe.run(moves, when, fix)
            if res != ("lost", score):
                return False
        else:
            # The last dot falls within the probe: the game is won.
            res = probe.run(moves, when + 500, fix, want_end=True)
            if res != ("won", score):
                return False
    return True


def plan(probe, start, jobs):
    """A beam search: every move of the `BEAM` best states is probed at
    once; the next beam keeps the best that score as modelled (`value`,
    at most `PER_PARENT` from one state and `PER_CELL` on one cell). A level with
    none falls back to the best states left over from the levels before."""
    dots0 = set(ALL_DOTS)
    dots0.discard(eat_cell(dots0, *START))
    root = State([], START, start - SETTLE, None, frozenset(dots0), 100)
    beam, spare = [root], []
    level = 0
    with cf.ThreadPoolExecutor(jobs) as pool:
        while True:
            level += 1
            children = [(i, ch) for i, st in enumerate(beam) for ch in candidates(st)[:CANDIDATES]]
            ok = list(pool.map(lambda ich: check(probe, ich[1]), children))
            passing = [(i, ch) for (i, ch), k in zip(children, ok) if k]
            won = [ch for _, ch in passing if not ch.dots]
            if won:
                return min(won, key=lambda s: s.probe[0])
            passing.sort(key=lambda ich: value(ich[1]))
            nxt, per, at = [], {}, {}
            for i, ch in passing:
                if per.get(i, 0) < PER_PARENT and at.get(ch.pos, 0) < PER_CELL and len(nxt) < BEAM:
                    per[i] = per.get(i, 0) + 1
                    at[ch.pos] = at.get(ch.pos, 0) + 1
                    nxt.append(ch)
                else:
                    spare.append(ch)
            if not nxt:
                if not spare:
                    sys.exit("no plan: every way is caught")
                spare.sort(key=value)
                nxt, spare = spare[:BEAM], spare[BEAM:]
                print("  no move kept: back to the best states left", file=sys.stderr)
            spare = sorted(spare, key=value)[:SPARE]
            beam = nxt
            best = beam[0]
            (WORK / f"best-{os.getpid()}.input").write_text("".join(f"{t} {cmd}\n" for t, cmd in best.moves if cmd))
            print(f"level {level}: best {len(best.dots)} dots left, score {best.score} at {best.at}, {best.pos} ({probe.count} probes)", file=sys.stderr)


def value(st):
    """Smaller is better: fewest dots left, then the steps to the next one
    and, a fifth as much, the time taken (a state that waits for a ghost to
    pass near the last dots must not lose to earlier ones further away)."""
    return (len(st.dots), dist_to_dot(st.pos, st.dots) + st.at / STEP * 0.2)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--scene", help="the NOITE scene the probes start in (3fsauna)")
    ap.add_argument("--prefix", type=pathlib.Path, help="script lines before the moves (the launch)")
    ap.add_argument("--start", type=int, default=500, help="the first move's earliest time (ms)")
    ap.add_argument("-o", "--out", type=pathlib.Path)
    ap.add_argument("--exe", default=str(ROOT / "zig-out" / "bin" / "noite"))
    ap.add_argument("-j", "--jobs", type=int, default=os.cpu_count())
    args = ap.parse_args()
    probe = Probe(args)
    st = plan(probe, args.start, args.jobs)
    moves = [m for m in st.moves if m[1] is not None]
    end = st.probe[0] + 500
    text = "".join(f"{t} {cmd}\n" for t, cmd in moves)
    text += f"{end} result won {st.score + 1000}\n"
    if args.out:
        args.out.write_text(text)
    else:
        sys.stdout.write(text)
    print(f"{len(moves)} moves, won {st.score + 1000} by {end}, {probe.count} probes", file=sys.stderr)


if __name__ == "__main__":
    main()
