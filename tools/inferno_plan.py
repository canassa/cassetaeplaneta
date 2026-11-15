#!/usr/bin/env python3
"""Plan an INFERNO game that survives the 3 minutes, against the port.

    nix develop -c python3 tools/inferno_plan.py [--start MS] [-o FILE]
        [--exe PATH] [-j N]

INFERNO has no randomness: a game follows from the key times relative to
INFERNO's WM_CREATE (0 alone; from NOITE's 3fpapmal, the pope's video's
end + 1500 ms). So the planner asks the port, as tools/inv_plan.py does:
a probe runs `noite --minigame inferno` with the jumps planned so far and
closes the window at a time T. With `inferno_close_forfeits` and
`inferno_loss_reports` the close reports `(0, g_score - 1000)`, so the
probe reads the score at T: +150 per stomp, -500 per life lost (the hero
stands at x 153, under no platform, so no drink is ever taken). The
probes also turn on `inferno_side_hit_costs_life` (BUGS.md H5): a jump
that runs into a hazard from the side would play a free death in the
Original and cost a life in the Corrigida, so it must show.

The hero never walks (no scroll zone: H7 never matters) and loses no life
(H6 never matters), so the Original and the Corrigida (`--fix all`) play
the same game. A probe whose game ended before T (the lives ran out:
alone, no report at all) counts as a hit. The plan is greedy: find the first life lost (bisection on
the close time), then try UP presses from 2.5 s before it, 60 ms apart,
and keep the first after which the hit is gone (the score at the old hit
time + 1.5 s is not below the score before, and is a multiple of 150);
repeat until no life is lost before the time-out (180 s).

The keys are written with absolute times from `--start`. Probes and
checks run INFERNO alone, shifted back to 0.
"""

import argparse
import concurrent.futures as cf
import os
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
WORK = ROOT / "zig-out" / "inferno-plan"
RESULT = re.compile(r"^\[(\d+)\] inferno: (won|lost), score (-?\d+)$", re.M)
PROBE_FIXES = "inferno_close_forfeits,inferno_loss_reports,inferno_side_hit_costs_life"
TIMEOUT = 180000
GAP = 60  # candidate spacing
LOOKBACK = 2500  # the earliest candidate before a hit
SETTLE = 1500  # a candidate is judged this long after the old hit


class Prober:
    def __init__(self, exe):
        self.exe = exe
        self.n = 0
        WORK.mkdir(parents=True, exist_ok=True)

    def score(self, jumps, t):
        """The game's score at `t` (None: the game ended before, all lives lost)."""
        self.n += 1
        path = WORK / f"p{os.getpid()}-{self.n}.input"
        lines = [f"{j} key up" for j in jumps if j < t]
        lines.append(f"{t} close")
        path.write_text("\n".join(lines) + "\n")
        out = subprocess.run(
            [self.exe, "--headless", "--minigame", "inferno", "--ms", str(t + 500), "--fix", PROBE_FIXES, "--input", str(path)],
            capture_output=True, text=True,
        ).stderr
        path.unlink()
        res = RESULT.findall(out)
        if not res:
            return None  # the lives ran out: no report alone (BUGS.md H3)
        at, _, score = res[-1]
        if int(at) < t:
            return None
        return int(score) + 1000


def clean(s, base):
    return s is not None and s >= base and s % 150 == 0


def first_hit(p, jumps, lo, base):
    """The first time in (lo, TIMEOUT) the score is no longer clean, by bisection; None: none."""
    if clean(p.score(jumps, TIMEOUT - 100), base):
        return None
    hi = TIMEOUT - 100
    while hi - lo > 20:
        mid = (lo + hi) // 2
        if clean(p.score(jumps, mid), base):
            lo = mid
        else:
            hi = mid
    return hi


def plan(exe, jobs):
    p = Prober(exe)
    jumps = []
    safe, base = 0, 0
    with cf.ThreadPoolExecutor(jobs) as pool:
        while True:
            hit = first_hit(p, jumps, safe, base)
            if hit is None:
                return jumps
            earliest = max(safe + 1, (jumps[-1] + 2200) if jumps else 0, hit - LOOKBACK)
            cands = list(range(earliest, hit, GAP))
            if not cands:
                sys.exit(f"no room for a jump before the hit at {hit}")
            scores = list(pool.map(lambda c: p.score(jumps + [c], hit + SETTLE), cands))
            for c, s in zip(cands, scores):
                if clean(s, base):
                    jumps.append(c)
                    safe, base = hit, s
                    print(f"hit at {hit}: UP at {c}, score {s}", file=sys.stderr)
                    break
            else:
                sys.exit(f"no UP between {earliest} and {hit} avoids the hit at {hit}")


def check(exe, jumps, fixes):
    path = WORK / "check.input"
    lines = [f"{j} key up" for j in jumps] + [f"{TIMEOUT + 500} result won 500"]
    path.write_text("\n".join(lines) + "\n")
    args = [exe, "--headless", "--minigame", "inferno", "--ms", str(TIMEOUT + 900), "--input", str(path)]
    if fixes:
        args += ["--fix", fixes]
    r = subprocess.run(args, capture_output=True, text=True)
    return r.returncode == 0, r.stderr


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--start", type=int, default=0, help="INFERNO's WM_CREATE in the target run (ms)")
    ap.add_argument("-o", "--out", type=pathlib.Path)
    ap.add_argument("--exe", default=str(ROOT / "zig-out" / "bin" / "noite"))
    ap.add_argument("-j", "--jobs", type=int, default=os.cpu_count())
    args = ap.parse_args()
    jumps = plan(args.exe, args.jobs)
    for fixes in ("", "all"):
        ok, err = check(args.exe, jumps, fixes)
        if not ok:
            sys.exit(f"the plan fails with --fix {fixes or 'none'}:\n{err}")
    text = "".join(f"{j + args.start} key up\n" for j in jumps)
    if args.out:
        args.out.write_text(text)
    else:
        sys.stdout.write(text)
    print(f"{len(jumps)} jumps", file=sys.stderr)


if __name__ == "__main__":
    main()
