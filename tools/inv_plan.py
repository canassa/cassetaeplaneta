#!/usr/bin/env python3
"""Plan an INV (Invasores) game against the port and write it as an input script.

    nix develop -c python3 tools/inv_plan.py (--win|--lose) [--start MS]
        [--relative-to MS] [-o FILE] [--exe PATH] [-j N]

INV has no randomness: a game follows from the key times relative to
INV's WM_CREATE (0 alone; from NOITE's 4fsacaet, the disco wave's end +
1500 ms). So instead of simulating it (as tools/tiro_plan.py and
tools/serial_plan.py do for the games with `rand()`), the planner asks
the port: a probe runs `noite --minigame inv` with the keys planned so
far and closes the window at a time T; the result INV posts then (the
`close` is a WM_DESTROY with wParam 0, a loss carrying `g_score`) is the
score at T: +100 per invader, +500 per saucer, -500 per bomb hit.

The plan is a depth-first search (from 600 ms, after the formation's
first step), one kill at a time: from the last kill,
candidate moves (wait, then nothing or an arrow pressed or held, then one
SPACE press) are tried in order of their length, each probed 1.1 s after
the SPACE; the first that kills one invader (+100, or +600 with the saucer)
without a bomb hit is kept, the kill time found by bisection, and the
search goes on from there. When no candidate works it backs up a kill.

Every key is pressed at least 110 ms after the last press and SPACE is
never held (no key repeat: BUGS.md I1 never matters), and the cannon
takes no bomb hit (no explosion: I2 never matters), so the Original and
the Corrigida (`--fix all`) play the same game; the plan is checked in
both at the end. `--win` kills the 20 invaders (`result won 2000`, plus
500 per saucer hit on the way); `--lose` writes no key: the bombs hit the
cannon four times (`result lost -2000`).

The keys are written with absolute times from `--start` (INV's WM_CREATE
in the run the script is for), or `+N` times from `--relative-to MS`
(a `wait` line's entry). Probes and checks always run INV alone, shifted
back to 0: INV's timers are set relative to its WM_CREATE.
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
WORK = ROOT / "zig-out" / "inv-plan"
RESULT = re.compile(r"^\[(\d+)\] inv: (won|lost), score (-?\d+)$", re.M)

GAP = 110  # ms between two presses
EVAL = 1100  # a SPACE is judged this long after it (the shot's longest flight is ~700 ms)
STEP_MS = 60  # the cannon's timer: one 20-px step per tick while an arrow is held
MAX_DELAY = 3000  # the longest candidate (wait + move) before backing up
INVADERS = 20
# The first SPACE comes after the formation's first step (500 ms): until
# then the cells' y are wrong (BUGS.md, INV Harmless, init_cells adds 44*i
# twice) and a kill leaves the dead invader drawn and bursts over the cannon.
FIRST = 600

_counter = itertools.count()


def script(events):
    return "\n".join(f"{t} {cmd}" for t, cmd in sorted(events, key=lambda e: e[0])) + "\n"


def run(exe, events, ms, fix=None, close=None):
    """Runs INV alone with `events`; returns its first result (at, won, score) or None."""
    WORK.mkdir(parents=True, exist_ok=True)
    path = WORK / f"probe-{os.getpid()}-{next(_counter)}.input"
    evs = list(events)
    if close is not None:
        evs.append((close, "close"))
    path.write_text(script(evs))
    cmd = [exe, "--headless", "--quiet", "--minigame", "inv", "--ms", str(ms), "--input", str(path)]
    if fix:
        cmd += ["--fix", fix]
    out = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, errors="replace")
    path.unlink(missing_ok=True)
    if out.returncode != 0:
        raise SystemExit(f"noite failed ({out.returncode}):\n{out.stdout}{out.stderr}")
    m = RESULT.search(out.stdout + out.stderr)
    return None if m is None else (int(m.group(1)), m.group(2) == "won", int(m.group(3)))


def probe(exe, events, t):
    """The result of closing INV at t (or of the game, if it ended first)."""
    return run(exe, events, t + 200, close=t)


def candidates(t_now, last_press):
    """(length, events, fire time): wait, then nothing / a press / a hold, then SPACE."""
    out = []
    holds = [None] + [(d, 50) for d in ("left", "right")] + [
        (d, k * STEP_MS + 30) for k in range(1, 12) for d in ("left", "right")]
    for w in range(0, MAX_DELAY, STEP_MS):
        t0 = max(t_now + w, last_press + GAP)
        for h in holds:
            evs = []
            if h is None:
                fire = t0
            else:
                d, ms = h
                evs.append((t0, f"key {d}" if ms == 50 else f"hold {d} {ms}"))
                fire = t0 + max(GAP, ms + 20)
            evs.append((fire, "key space"))
            length = fire - t_now
            if length <= MAX_DELAY:
                out.append((length, evs, fire))
    out.sort(key=lambda c: c[0])
    # Several (wait, move) pairs give the same events; keep the first.
    seen, uniq = set(), []
    for c in out:
        k = tuple(c[1])
        if k not in seen:
            seen.add(k)
            uniq.append(c)
    return uniq


def kill_time(exe, events, fire, score):
    """The first ms after `fire` at which the score is past `score` (bisection)."""
    lo, hi = fire, fire + EVAL
    while hi - lo > 1:
        mid = (lo + hi) // 2
        r = probe(exe, events, mid)
        if r[2] > score and r[0] == mid:
            hi = mid
        else:
            lo = mid
    return hi


def plan_win(exe, jobs, log):
    pool = cf.ThreadPoolExecutor(jobs)
    stack = []  # (events, t_now, score, candidates iterator)

    def push(events, t_now, last_press, score):
        stack.append((events, t_now, score, iter(candidates(t_now, last_press))))

    push([], FIRST, -GAP, 0)
    while stack:
        events, t_now, score, it = stack[-1]
        kills = len(stack) - 1
        found = None
        while found is None:
            batch = list(itertools.islice(it, jobs))
            if not batch:
                break
            futs = [pool.submit(probe, exe, events + c[1], c[2] + EVAL) for c in batch]
            for c, f in zip(batch, futs, strict=True):
                r = f.result()
                if r is None:
                    continue
                at, won, s = r
                if won and kills + 1 == INVADERS and s >= score + 100:
                    found = (c, at, s, True)
                    break
                if at == c[2] + EVAL and s - score in (100, 600):
                    found = (c, at, s, False)
                    break
        if found is None:
            log(f"no move after kill {kills} at {t_now} ms; backing up")
            stack.pop()
            if not stack:
                raise SystemExit("no plan found")
            continue
        c, at, s, done = found
        evs = events + c[1]
        if done:
            log(f"kill {kills + 1}: won at {at} ms, score {s}")
            return evs, at, s
        t = kill_time(exe, evs, c[2], score)
        log(f"kill {kills + 1} at {t} ms, score {s} (SPACE at {c[2]})")
        push(evs, t + 1, c[2], s)
    raise SystemExit("no plan found")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--win", action="store_true")
    g.add_argument("--lose", action="store_true")
    ap.add_argument("--start", type=int, default=0, help="ms of INV's WM_CREATE in the target run")
    ap.add_argument("--relative-to", type=int, metavar="MS",
                    help="write `+N` times, the first from MS")
    ap.add_argument("--exe", default=str(ROOT / "zig-out" / "bin" / "noite"))
    ap.add_argument("-j", "--jobs", type=int, default=os.cpu_count() or 4)
    ap.add_argument("-o", "--output")
    a = ap.parse_args()

    def log(s):
        print(s, file=sys.stderr, flush=True)

    events = []
    if a.win:
        events, _, _ = plan_win(a.exe, a.jobs, log)
    results = [run(a.exe, events, 120_000, fix) for fix in (None, "all")]
    for name, r in zip(("Original", "Corrigida"), results, strict=True):
        if r is None:
            log(f"# {name}: no result")
        else:
            log(f"# {name}: {'won' if r[1] else 'lost'} {r[2]} at {r[0]} ms")
    if results[0] is None or results[0][1:] != results[1][1:]:
        raise SystemExit("the two versions differ")
    if results[0][1] != a.win:
        raise SystemExit("the plan does not " + ("win" if a.win else "lose"))

    lines = [f"# {len(events)} key lines; INV ends at {results[0][0]} ms (Original), "
             f"{results[1][0]} ms (Corrigida) after its WM_CREATE: "
             f"result {'won' if results[0][1] else 'lost'} {results[0][2]}"]
    prev = a.relative_to
    for t, cmd in sorted(events, key=lambda e: e[0]):
        t += a.start
        if prev is None:
            lines.append(f"{t} {cmd}")
        else:
            lines.append(f"+{t - prev} {cmd}")
            prev = t
    text = "\n".join(lines) + "\n"
    if a.output:
        pathlib.Path(a.output).write_text(text)
    else:
        sys.stdout.write(text)


if __name__ == "__main__":
    main()
