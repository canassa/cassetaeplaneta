#!/usr/bin/env python3
"""Plan the fair fight (Corrigida, `fight_fair`) of SALGIN or XILINDRO against the port.

    nix develop -c python3 tools/fight_plan.py SCRIPT [--block NAME]
        [--player react|mash|idle] [--check] [-- NOITE_ARGS...]

The fight follows from the keys and the opponent's rand(), which is
seeded from the clock: a simulation would have to model the whole engine,
so the planner asks the port instead. SCRIPT holds a block between the
lines `# fair-plan NAME begin` and `# fair-plan NAME end` (NAME defaults
to `fight`); its lines are `?fight_fair` lines with `+N` times, the first
counted from the line before the block. A probe runs the script's
`--fix all` command (its header's `zig-out/bin/noite ... --fix ...` line,
or NOITE_ARGS) with the block so far plus `+0 ?fight_fair log
fair-anchor` and `+0 ?fight_fair key f9`: F9 turns on the fight's debug
overlay, which in a Debug build also logs every beat
(`[ms] fair gap G PHASE LEFT atk A beat N last OUTCOME fx X ox X strips F/O
energy F/O ...`, core/fight_fair.zig). The planner reads the beats,
adds the next action after the last one, and probes again (the run is
deterministic, so what came before does not change).

`--player react` (the default) is the reactor of docs/fights/FAIRNESS.md
"Checks": it answers each tell 300 ms after the wind-up shows. With room
behind it, it steps back (Left; the strike whiffs), then, as the strike
comes, steps in (Right) and kicks (S, 4 points) in the follow-through;
against the wall it blocks (Down) a punch or a kick, or jumps (Insert)
the sweep, and kicks (S) as soon as it is free while the opponent still
stands in range. While the opponent stands back it walks right to keep
room behind it. It never throws a blow out of reach, so the opponent's
whiff punish never comes.

`--player mash` presses A (the punch) every beat (200 ms) from the round's
start; `--player idle` presses nothing. Both are written whole at once.

`--check` runs the script as it is and prints the beats' summary.
"""

import argparse
import pathlib
import re
import shlex
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
WORK = ROOT / "zig-out" / "fight-plan"
BEAT = re.compile(
    r"^\[(\d+)\] fair gap (-?\d+)  (\w+) (\d+)  atk (-?\d+)  beat (\d+)  last (\w+)  "
    r"fx (-?\d+) ox (-?\d+)  strips (-?\d+)/(-?\d+)  energy (-?\d+)/(-?\d+)  tells (\d+) cut (\d+)  clock (-?\d+)$",
    re.M,
)
ANCHOR = re.compile(r"^\[(\d+)\] log: fair-anchor$", re.M)
RESULT = re.compile(r"^\[(\d+)\] (?:xilindro|salgin): (won|lost), score (-?\d+)$", re.M)
CMD = re.compile(r"^#\s+zig-out/bin/noite\s(.*--fix.*)$")

REACT_MS = 300  # the reactor answers a tell this long after it shows
BEAT_MS = 200
REACH = 100  # the fighter's reach (fight_fair Tuning.fighter_reach)
KICK = 4  # S, the middle kick (fight_fair Tuning.fighter_damage[1])
FREE = (4, 6)  # the fighter's strips with no move running (walk, guard)


class Beat:
    def __init__(self, m):
        g = m.groups()
        self.t = int(g[0])
        self.gap = int(g[1])
        self.phase = g[2]
        self.left = int(g[3])
        self.atk = int(g[4])
        self.n = int(g[5])
        self.last = g[6]
        self.fx, self.ox = int(g[7]), int(g[8])
        self.fs, self.os = int(g[9]), int(g[10])
        self.fe, self.oe = int(g[11]), int(g[12])
        self.tells, self.cut = int(g[13]), int(g[14])
        self.clock = int(g[15])


def split(text, name):
    lines = text.split("\n")
    b = lines.index(f"# fair-plan {name} begin")
    e = lines.index(f"# fair-plan {name} end")
    return lines[: b + 1], lines[b + 1 : e], lines[e:]


def command(script):
    for line in script.read_text().splitlines():
        if line.strip() and not line.startswith("#"):
            break
        m = CMD.match(line)
        if m:
            argv = shlex.split(re.sub(r"\[[^\]]*\]", "", m.group(1)))
            if "--input" in argv:
                i = argv.index("--input")
                del argv[i : i + 2]
            return argv
    sys.exit(f"{script}: no `zig-out/bin/noite ... --fix ...` line in the header")


def block_lines(actions, base):
    """The actions [(ms, cmd)] as `+N ?fight_fair cmd` lines from `base`."""
    out, t = [], base
    for ms, cmd in sorted(actions, key=lambda a: a[0]):
        out.append(f"+{ms - t} ?fight_fair {cmd}")
        t = ms
    return out


def probe(script, name, argv, lines, ms=None, probe_lines=True):
    pre, _, post = split(script.read_text(), name)
    extra = ["+0 ?fight_fair log fair-anchor", "+0 ?fight_fair key f9"] if probe_lines else []
    WORK.mkdir(parents=True, exist_ok=True)
    tmp = WORK / f"{script.stem}.{name}.input"
    tmp.write_text("\n".join(pre + extra + lines + post))
    args = list(argv)
    if ms is not None and "--ms" in args:
        i = args.index("--ms")
        args[i + 1] = str(min(int(args[i + 1]), ms))
    out = subprocess.run(
        [str(ROOT / "zig-out" / "bin" / "noite"), *args, "--input", str(tmp)],
        cwd=ROOT, capture_output=True, text=True,
    )
    text = out.stdout + out.stderr
    anchor = ANCHOR.search(text)
    beats = [Beat(m) for m in BEAT.finditer(text)]
    res = RESULT.search(text)
    return (int(anchor.group(1)) if anchor else None), beats, res, text


def plan_react(script, name, argv, total_ms, fast=False, ko_at=None, end_at=None):
    actions = []
    anchor = None
    cursor = 0  # no action before this time
    handled = set()  # tells answered (or given up)
    while True:
        lines = block_lines(actions, anchor or 0) if anchor is not None else []
        a, beats, res, _ = probe(script, name, argv, lines, ms=cursor + 4000 if cursor else None)
        anchor = anchor or a
        if anchor is None:
            sys.exit("no fair-anchor in the log (is the block reached? a Debug build?)")
        if not beats:
            sys.exit("no beats in the log")
        added = None
        prev = None
        for b in beats:
            if b.t <= cursor:
                prev = b
                continue
            if b.oe < 1 or b.fe < 1:
                break
            free = b.fs in FREE
            # With --ko-at: one kick left (the kick's 4 points), hold it
            # back, only dodging, until the beat before the KO's.
            stall = ko_at is not None and b.oe <= KICK
            if stall and ko_at - BEAT_MS <= b.t < ko_at:
                if not free or b.phase == "reel":
                    sys.exit(f"--ko-at {ko_at}: the fighter is busy or the opponent reels at {b.t}")
                steps = max(0, -(-(b.gap - REACH) // 32))
                added = [(b.t + 1 + 12 * i, "hold right 5") for i in range(steps)]
                kick = b.t + 12 * steps + 23
                # With --end-at inside the KO's window, the kick is the
                # block's last line, where the lines it replaces ended.
                if end_at is not None and kick < anchor + end_at < ko_at:
                    kick = anchor + end_at
                added.append((kick, "key s"))
                cursor = ko_at + 1000
                break
            arrival = b.phase == "windup" and (prev is None or b.tells > prev.tells)
            if arrival and b.tells not in handled:
                handled.add(b.tells)
                at = b.t + REACT_MS
                strike = b.t + b.left * BEAT_MS
                if not free:
                    pass
                elif fast and not stall and b.gap <= REACH:
                    added = [(at, "key s")]
                    cursor = at
                elif b.fx >= 32:
                    added = [(at, "hold left 20")]
                    if not stall:
                        added += [(strike + 30, "hold right 20"), (strike + 70, "key s")]
                    cursor = added[-1][0]
                elif b.atk == 2:
                    added = [(at, "key insert")]
                    cursor = at
                else:
                    added = [(at, "key down")]
                    cursor = at
                if added:
                    break
            elif free and not stall and b.phase in ("strike", "recovery") and b.gap <= REACH + 32:
                if b.gap > REACH:
                    added = [(b.t + 30, "hold right 20"), (b.t + 70, "key s")]
                    cursor = b.t + 70
                else:
                    added = [(b.t + 30, "key s")]
                    cursor = b.t + 30
                break
            elif free and b.phase in ("pause", "approach") and b.gap > 170 and b.fx < 64:
                added = [(b.t + 30, "hold right 20")]
                cursor = b.t + 30
                break
            prev = b
        if not added:
            if cursor and beats[-1].t > cursor and beats[-1].t < total_ms - 1000 and beats[-1].oe > 0 and beats[-1].fe > 0:
                # The probe stopped short: look further.
                cursor = beats[-1].t
                continue
            break
        actions += added
        print(f"  {added[0][0]}: {' / '.join(c for _, c in added)}  (energy {beats[-1].fe}/{beats[-1].oe})", file=sys.stderr)
    return actions, anchor


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("script", type=pathlib.Path)
    ap.add_argument("--block", default="fight")
    ap.add_argument("--player", choices=("react", "fast", "mash", "idle"), default="react")
    ap.add_argument("--ko-at", type=int, help="the KO's beat (ms of the run): the last kick waits for it")
    ap.add_argument("--end-at", type=int, help="end the block with a `log` line this many ms after the line before it")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("noite", nargs="*")
    args = ap.parse_args()
    argv = args.noite or command(args.script)
    total = int(argv[argv.index("--ms") + 1]) if "--ms" in argv else 120000
    pre, block, post = split(args.script.read_text(), args.block)
    if args.check:
        a, beats, res, _ = probe(args.script, args.block, argv, block)
        summary(beats, res)
        return
    if args.player in ("react", "fast"):
        actions, anchor = plan_react(args.script, args.block, argv, total, args.player == "fast", args.ko_at, args.end_at)
    else:
        a, beats, _, _ = probe(args.script, args.block, argv, [])
        anchor = a
        actions = []
        if args.player == "mash":
            start = beats[0].t + 50
            actions = [(t, "key a") for t in range(start, start + 90000, BEAT_MS)]
    if args.end_at is not None:
        end = anchor + args.end_at
        if actions and max(a[0] for a in actions) > end:
            sys.exit(f"--end-at {args.end_at}: the plan goes on past it")
        actions.append((end, "log fair-plan end"))
    lines = block_lines(actions, anchor)
    args.script.write_text("\n".join(pre + lines + post))
    a, beats, res, _ = probe(args.script, args.block, argv, lines)
    summary(beats, res)


def summary(beats, res):
    if beats:
        last = beats[-1]
        print(f"tells {last.tells}, cut {last.cut}, energy fighter {last.fe} opponent {last.oe}, clock {last.clock}")
    if res:
        print(f"result {res.group(2)} {res.group(3)} at {res.group(1)}")


if __name__ == "__main__":
    main()
